extends Node
## Capturas de gameplay real con HUD, mordidas y navegación normales.
## Dos contextos separados, NO un montaje de progreso comprado: arranque
## verdadero con una obrera y colonia QA declarada con mejoras existentes.
## No hay créditos, HP ni daño artificiales; el atajo lo terminan hormigas.
const RUN := preload("res://mundo/run.tscn")
const PASO := 1.0 / 60.0
var total := 0
var fallas := 0
var run: Run


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	var partida := huella(Juego.RUTA_PARTIDA)
	var ajustes := huella(Ajustes.RUTA)
	if DisplayServer.get_name() == "headless":
		verificar(false, "la revisión de casa requiere renderer real")
		get_tree().quit(1)
		return
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	if not Graficos.listo:
		await Graficos.preparado
	await mostrar_inicio()
	await mostrar_atajo()
	verificar(partida == huella(Juego.RUTA_PARTIDA) and ajustes == huella(Ajustes.RUTA),
		"las capturas conservan archivos de partida y configuración personales")
	Juego.reiniciar_estado()
	print("Revisión de recorrido casa: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func huella(ruta: String) -> String:
	return FileAccess.get_sha256(ruta) if FileAccess.file_exists(ruta) else "ausente"


func crear() -> void:
	seed(417)
	run = RUN.instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.eventos._reloj_amenaza = 1e9
	run.eventos._reloj_dorada = 1e9
	run.camara._manual = true
	run.camara._zoom_objetivo = 1.35
	run.camara.zoom = Vector2.ONE * 1.35
	run.camara.position = Vector2(130, 0)
	run.camara.force_update_scroll()
	Input.warp_mouse(Vector2(1900, 1000))


func paso() -> void:
	run._process(PASO)
	run.cocina.procesar_cambios()
	run.preparador_mordiscos.procesar()
	run.cola_erosion.procesar()
	run.feromonas._process(PASO)
	run.colonia._process(PASO)
	for h in run.colonia.hormigas:
		h._process(PASO)
	for parte in run.comidas.partes.duplicate():
		if is_instance_valid(parte):
			parte._process(PASO)
	run.efectos._process(PASO)
	run.hud._process(PASO)
	run.hud._vuelo_migas._process(PASO)
	run.hormiguero.queue_redraw()
	await get_tree().process_frame


func mostrar_inicio() -> void:
	Juego.reiniciar_estado()
	crear()
	var miga: Comida
	var distancia := INF
	for comida in run.comidas.lista:
		if comida.id == "miga" and comida.position.length_squared() < distancia:
			miga = comida
			distancia = comida.position.length_squared()
	verificar(miga != null and Juego.migas == 0 and Juego.stat("hormigas_iniciales") == 1,
		"arranque sin compras ni dinero, con una obrera y alimentos generados")
	if miga == null:
		run.queue_free()
		await get_tree().process_frame
		return
	var entrega := {"cantidad": 0.0, "veces": 0}
	run.entrega_real.connect(func(cantidad: float, _categoria: int) -> void:
		entrega.cantidad += cantidad
		entrega.veces += 1
	)
	for i in 30:
		await paso()
	await captura("casa_pulida_00_inicio_una_obrera")
	for i in 900:
		if entrega.veces > 0:
			break
		run.feromonas.mantener_en(miga.position)
		await paso()
	verificar(entrega.veces == 1 and entrega.cantidad > 0 and run.colonia.cantidad() == 1,
		"una sola hormiga extrae y regresa físicamente sin nuevos recursos ni pagos de fixture")
	await captura("casa_pulida_01_primera_entrega_real")
	verificar(run.hud._lbl_ganancia.visible and run.hud._lbl_ganancia.text != "+0",
		"el primer cobro real fraccional es legible en el HUD")
	run._cerrar()
	run.queue_free()
	await get_tree().process_frame


func mostrar_atajo() -> void:
	Juego.reiniciar_estado()
	# Colonia de prueba ya mejorada. No se presenta como el resultado de la
	# primera compra ni se infiere duración: sólo prueba la escena física.
	Juego.niveles = {"mas_obreras": 23, "mandibulas": 20, "mordida_rapida": 12,
		"mordida_madera": 1, "buche": 10, "patas_largas": 12, "reservas": 12,
		"segundo_aire": 5, "rastro_persistente": 8, "antenas": 1, "pisoton": 8}
	Juego._cache_stats.clear()
	crear()
	var silla: PiezaCasa
	for parte in run.comidas.partes:
		if parte.pieza.get("perfil", "") == "silla_inicial":
			silla = parte
	verificar(silla != null and silla.disponible() and not run.cocina.segmento_libre(Vector2.ZERO, PlanoCasa.PREMIO_ATAJO),
		"la escena mejorada conserva la silla y el atajo todavía cerrado")
	if silla == null:
		run.queue_free()
		await get_tree().process_frame
		return
	var resultado := {"premio": null, "aperturas": 0}
	run.comidas.atajo_abierto.connect(func(comida: Comida) -> void:
		resultado.premio = comida
		resultado.aperturas += 1
	)
	await captura("casa_pulida_02_silla_intacta_colonia_qa")
	var recorte := false
	for i in 9000:
		if resultado.aperturas > 0 or run.terminada:
			break
		run.feromonas.mantener_en(silla.position)
		await paso()
		if not recorte and is_instance_valid(silla) and silla.vida < silla.vida_max * 0.7:
			recorte = true
			await captura("casa_pulida_03_silla_recorte_real")
		if i % 1800 == 1799 and is_instance_valid(silla):
			print("Silla: %.1f%% restante, %.1f s de expedición, %d cambios de navegación pendientes." % [silla.vida / silla.vida_max * 100, run.tiempo_restante, run.cocina._cambios.size()])
	verificar(recorte and resultado.aperturas == 1, "la colonia retira partes de verdad y abre el atajo una sola vez")
	if resultado.aperturas > 0:
		# El aviso se celebra diferido; no se avanza la simulación durante
		# estas dos imágenes, así el hallazgo sigue entero y sin cobrar.
		await captura("casa_pulida_04_atajo_abierto_galletita")
		var premio: Comida = resultado.premio
		verificar(is_instance_valid(premio) and premio.position == PlanoCasa.PREMIO_ATAJO
			and run.cocina.segmento_libre(Vector2.ZERO, premio.position),
			"el hueco abre un camino de navegación al alimento físico nativo")
		if is_instance_valid(premio):
			var antes := run.ingresos[0]
			for i in 900:
				if run.ingresos[0] > antes or run.terminada:
					break
				if not premio.muerta:
					run.feromonas.mantener_en(premio.position)
				await paso()
			verificar(run.ingresos[0] > antes, "la galletita descubierta sólo aumenta ingresos al extraerla y volver al nido")
			await captura("casa_pulida_05_hallazgo_transportado")
		get_window().size = Vector2i(1000, 620)
		await captura("casa_pulida_06_interfaz_1000")
		get_window().size = Vector2i(1920, 1080)
	run._cerrar()
	run.queue_free()
	await get_tree().process_frame


func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var imagen := get_viewport().get_texture().get_image()
	verificar(imagen.save_png("res://.godot/qa/" + nombre + ".png") == OK, "captura real: " + nombre)


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("OK " if ok else "FALLA ", mensaje)
