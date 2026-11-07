extends Node
## Integración sobre la mesa real de la captura: salir, morder localmente,
## perder el frente, volver y acercarse al hueco nuevo. Daño, intervalo y
## velocidad de fixture aceleran el ensayo; no estiman balance ni duración.
## Con renderer real guarda tres capturas, sin leer pantalla ni guardar partida.
const PASO := 1.0 / 60.0
const CUADROS := 7200
var total := 0
var fallas := 0


func _init() -> void:
	Juego.guardado_habilitado = false


func _ready() -> void:
	var huellas := huellas_guardados()
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	Juego.usar_idioma("es")
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		if not Graficos.listo:
			await Graficos.preparado
	await probar_mesa(false)
	await probar_mesa(true)
	verificar(huellas == huellas_guardados(), "el ensayo no modifica partida ni ajustes")
	print("Frente real de mesa: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func probar_mesa(llamado: bool) -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	seed(421)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.radio_actual = 12000.0
	run.niebla.hide()
	run.hud.hide()
	var mesa: PiezaCasa
	for parte: PiezaCasa in run.comidas.partes:
		if parte.pieza.tipo == "mesa_comedor":
			mesa = parte
			break
	verificar(mesa != null and mesa.preparar_material(), "la mesa del comedor prepara su material real")
	if mesa == null or mesa.mordiscos == null:
		return
	# Aislar las candidatas, no el mueble ni su colisión. El acceso local es
	# explícito del fixture, como uno que el jugador puede colocar con N.
	run.comidas._indice.clear()
	run.comidas._indexar(mesa)
	run.colonia._hallazgos.clear()
	run.colonia.avistar(mesa)
	var lejos := Vector2(mesa.rect_mundo.position.x - 200.0, mesa.rect_mundo.get_center().y)
	var puesto := mesa.punto_mordida(lejos, run.radio_actual)
	var entrada := run.cocina.ajustar_destino(puesto + Vector2(-120, 0), run.radio_actual)
	verificar(puesto.is_finite() and entrada.is_finite() and run.cocina.libre(entrada, 40.0),
		"el acceso y el frente inicial están sobre piso libre de la casa")
	if not puesto.is_finite() or not entrada.is_finite():
		return
	run.entradas.puntos.append(entrada)
	run.entradas.queue_redraw()
	# Calibrar UNA porción base para aislar circulación/contacto de la IA.
	# Las metas ahora agrandan el bocado con el daño: usar vida_max forzaría
	# 48u y dejaría de cubrir esta regresión de frentes pequeños de 6u.
	# Compensar los mismos factores que recibe lado_para_dano(), sin cambiar
	# el tamaño real de la mesa ni los límites de localidad de las aserciones.
	var lado_base := Juego.stat("tamano_bocado")
	var densidad := mesa.vida_max / maxf(mesa.rect_mundo.get_area(), 1.0)
	var factor_dano := RolesHormiga.dano("obrera", mesa.nivel_requerido) * run.reglas.factor_dano(mesa)
	var dano_porcion_base := densidad * lado_base * lado_base / factor_dano
	for i in 8:
		var h := run.colonia._nacer("obrera", entrada + Vector2(0, (i - 4) * 2))
		h._capacidad = 8
		h._porciones_ciclo = 1
		h._dano = dano_porcion_base
		h._intervalo_mordida = 0.25
		h._velocidad = 200.0
	var observaciones: Array[Dictionary] = []
	for h: Hormiga in run.colonia.hormigas:
		observaciones.append({"pos": h.position, "carga": h.carga, "quieta": 0.0, "max_quieta": 0.0, "entregas": 0, "descarga": -10.0, "bocados": 0})
	run.camara.position = puesto + Vector2(180, 0)
	run.camara.zoom = Vector2.ONE * 1.6
	run.camara.force_update_scroll()
	if llamado:
		run.feromonas.mantener_en(puesto + Vector2(30, 0))
	await capturar("mesa_%s_antes" % llamado)
	var locales := true
	var seguras := true
	var cortes := 0
	var avance := 0.0
	var max_pedidos := 0
	var vida_inicial := mesa.vida
	var originales := mesa.mordiscos._pixeles.duplicate()
	var adentro_material_anterior := false
	for cuadro in CUADROS:
		run._reloj += PASO
		if llamado:
			run.feromonas._process(PASO)
		for i in run.colonia.hormigas.size():
			var h: Hormiga = run.colonia.hormigas[i]
			var dato: Dictionary = observaciones[i]
			var vida_previa := mesa.vida
			var boca := h.position
			h._process(PASO)
			if mesa.vida < vida_previa:
				var region := mesa._porcion_reciente
				locales = locales and region.has_area() and region.size.x <= 6.001 and region.size.y <= 6.001 and boca.distance_to(boca.clamp(region.position, region.end)) <= Cocina.MARGEN + 5.01
				cortes += 1
			seguras = seguras and run.cocina.libre(h.position, Cocina.MARGEN - 0.1)
			avance = maxf(avance, h.position.x - puesto.x)
			if h.comida == mesa and mesa.rect_mundo.has_point(h.position):
				var pixel := Vector2i(((h.position - mesa.mordiscos._rect_mundo.position) / mesa.mordiscos._paso).floor())
				if originales[pixel.y * mesa.mordiscos._ancho + pixel.x] != 0:
					adentro_material_anterior = true
			if h.carga > 0.0 and h.position.distance_squared_to(dato.pos) < 0.01 and h.carga == dato.carga:
				dato.quieta += PASO
			else:
				dato.quieta = 0.0
			dato.max_quieta = maxf(dato.max_quieta, dato.quieta)
			if h._tiempo_descarga > float(dato.descarga):
				dato.entregas += 1
				dato.descarga = h._tiempo_descarga
			dato.pos = h.position
			dato.carga = h.carga
			dato.bocados = h.bocados
		mesa._process(PASO)
		run.cocina.procesar_cambios()
		run.colonia._actualizar_visibilidad()
		run.efectos._process(PASO)
		max_pedidos = maxi(max_pedidos, run.cocina._pedidos_cuadro)
		if cuadro == CUADROS / 2:
			await capturar("mesa_%s_mitad" % llamado)
		await get_tree().process_frame
	await capturar("mesa_%s_despues" % llamado)
	var min_entregas := 100000
	var max_quieta := 0.0
	for dato: Dictionary in observaciones:
		min_entregas = mini(min_entregas, dato.entregas)
		max_quieta = maxf(max_quieta, dato.max_quieta)
	var modo := "manteniendo feromonas" if llamado else "sin feromonas"
	print("MESA %s: %d cortes; mínimo %d entregas por hormiga; avance %.2fu; quieta cargada máx %.2fs; %.6f HP retirados" % [modo, cortes, min_entregas, avance, max_quieta, vida_inicial - mesa.vida])
	verificar(locales and cortes >= 20, modo + ": todos los recortes salen de la boca real y miden como máximo 6u")
	verificar(seguras and adentro_material_anterior and avance > 8.0, modo + ": las hormigas avanzan por el hueco nuevo sin cruzar material vivo")
	verificar(min_entregas >= 3 and max_quieta < 5.0, modo + ": cada hormiga completa varios viajes, sin portadoras clavadas")
	verificar(max_pedidos <= run.cocina.limite_rutas_por_cuadro, modo + ": respeta la cola compartida de navegación")
	run.feromonas.soltar()
	run.queue_free()
	await get_tree().process_frame


func capturar(nombre: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/%s.png" % nombre)


func huellas_guardados() -> Dictionary:
	var huellas := {}
	for ruta: String in [Juego.RUTA_PARTIDA, Ajustes.RUTA]:
		huellas[ruta] = FileAccess.get_sha256(ruta) if FileAccess.file_exists(ruta) else "ausente"
	return huellas


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)
