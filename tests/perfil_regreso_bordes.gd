extends Node
## Transporte sintético explícito desde tres pasillos reales de la casa.
## Las 500 cargas de 0,125 se crean en el fixture: no representan extracción
## ni balance. Sólo se acreditan al llegar físicamente a la entrada normal.
## Ejecutar con renderer real, --fixed-fps 60 y --resolution 1920x1080.
## Mide tiempo entre cuadros, incluido el observador de seguridad; no CPU aislada.
const CANTIDAD := 500
const CALENTAMIENTO := 30
const MAX_CUADROS := 600
const SEMILLA := 9081
const CARGA := 0.125
const VELOCIDAD_FIXTURE := 1500.0
const RADIO := 12000.0
const ORIGENES := [Vector2(1611, -593), Vector2(-632, 1281), Vector2(-861, 1019)]
const RUTA_RESULTADOS := "res://.godot/qa/perfil_regreso_bordes.json"
var _fallas := 0
var _verificaciones := 0


func _init() -> void:
	Juego.guardado_habilitado = false


func _ready() -> void:
	var huellas := _huellas_guardados()
	if DisplayServer.get_name() == "headless":
		_verificar(false, "este perfil exige renderer real; headless no mide FPS")
		get_tree().quit(1)
		return
	Ajustes.pausar_sin_foco = false
	Ajustes.temblor = 1.0 # En memoria; nunca guarda la preferencia personal.
	get_tree().paused = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Engine.time_scale = 1.0
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if not Graficos.listo:
		await Graficos.preparado
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not get_viewport().get_visible_rect().size.is_equal_approx(Vector2(1920, 1080)):
		_verificar(false, "ejecutar con --resolution 1920x1080: el perfil exige Full HD real")
		get_tree().quit(1)
		return
	_verificar(Graficos.textura != null, "atlas compartido terminado antes de calentar")
	Juego.reiniciar_estado()
	Juego.lugar_actual = "casa"
	Juego.niveles = {"mordida_madera": 1, "excavar": 30}
	Juego._cache_stats.clear()
	seed(SEMILLA)
	var huerfanos_antes := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var nodos_antes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true # No hay extracción; se aísla navegación/entrega.
	add_child(run)
	run.set_process(false) # Sin cronómetro, cierre ni pisotón; _reloj avanza abajo.
	run.set_process_unhandled_input(false)
	run.eventos.set_process(false) # Sin amenazas que retiren cargas del fixture.
	run.feromonas.set_process_unhandled_input(false)
	run.poderes.set_process_unhandled_input(false)
	run.colonia._activa = false # Mantiene el culling normal, sin nacimientos.
	run.colonia._por_salir = 0
	run.colonia._cola_castas.clear()
	run.colonia._intervalo_cria = 0.0
	run.objetivo_completado = true # Sin cámara lenta de conquista.
	run.radio_actual = RADIO
	run.niebla.radio = RADIO
	# La ida normal ya habría construido la grilla compartida. Sólo ésta se
	# precalienta: los quinientos puentes de origen llegan fríos a la medida.
	run.cocina._actualizar_radio(RADIO)
	run.camara.set_process(false)
	run.camara.set_process_input(false)
	run.camara.set_process_unhandled_input(false)
	run.camara.zoom = Vector2.ONE * 0.48
	run.camara.position = Vector2(400, 350)
	run.camara.force_update_scroll()
	var origenes_seguros := true
	for i in CANTIDAD:
		var punto: Vector2 = ORIGENES[i % ORIGENES.size()]
		if i % ORIGENES.size() == 1:
			punto.x += i * 0.03
		else:
			punto.y += i * 0.03
		origenes_seguros = origenes_seguros and run.cocina.libre(punto, Cocina.MARGEN)
		var h := run.colonia._nacer("obrera", punto)
		h.carga = CARGA
		h._velocidad = VELOCIDAD_FIXTURE
		h._volver()
		h.set_process(false)
		h._actualizar_sprite()
	_verificar(origenes_seguros and run.colonia.cantidad() == CANTIDAD,
		"quinientos orígenes distintos están sobre piso real, fuera del material")
	for cuadro in CALENTAMIENTO:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_verificar(run.cocina._enlaces_celda.is_empty() and run.cocina.consultas_enlace == 0,
		"el calentamiento construye la grilla, pero no adelanta ningún puente del regreso")
	var nodos_iniciales := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var hud_inicial := run.hud.get_child_count()
	var combo_inicial := run.hud._combo_visual.get_child_count()
	var saldo := Juego.migas_run
	var consultas := run.cocina.consultas_ruta
	var astar := run.cocina.busquedas_astar
	var tiempos: Array[float] = []
	var maximos := {"rutas": 0, "rutas_usec": 0, "cache_enlaces": 0, "pruebas_enlace": 0,
		"nodos": nodos_iniciales, "nodos_hud": hud_inicial, "nodos_combo": combo_inicial,
		"nodos_efectos": 0, "nodos_vuelos": 0, "particulas": 0, "ondas": 0,
		"textos": 0, "marcas": 0, "pool_particulas": 0, "pool_ondas": 0,
		"pool_textos": 0, "pool_marcas": 0, "vuelos": 0, "slots_vuelos": 0,
		"chispas_combo": 0, "dibujos": 0}
	var seguras := true
	var descargaron_en_entrada := true
	var pendientes := CANTIDAD
	var entregadas := 0
	var anterior := Time.get_ticks_usec()
	for h: Hormiga in run.colonia.hormigas:
		h.set_process(true)
	print("REGRESO CONFIG %s | Full HD | %d IA normales | %d warm | velocidad %.0f de fixture | cargas sintéticas %.3f | audio silenciado | VSync desactivado" % [RenderingServer.get_current_rendering_method(), CANTIDAD, CALENTAMIENTO, VELOCIDAD_FIXTURE, CANTIDAD * CARGA])
	for cuadro in MAX_CUADROS:
		run._reloj += 1.0 / 60.0
		run.camara.avanzar_sacudida(1.0 / 60.0) # Sin teclado, mouse, zoom ni arrastre.
		run.camara.force_update_scroll()
		await get_tree().process_frame
		var ahora := Time.get_ticks_usec()
		var ms := (ahora - anterior) / 1000.0
		tiempos.append(ms)
		anterior = ahora
		_observar(run, maximos)
		pendientes = 0
		for h: Hormiga in run.colonia.hormigas:
			if h.estado == Hormiga.Estado.QUIETA:
				continue
			seguras = seguras and run.cocina.libre(h.position, Cocina.MARGEN - 0.1)
			if h.carga > 0.0:
				pendientes += 1
			else:
				entregadas += 1
				# _descargar ya eligió su siguiente destino exploratorio; el único
				# acceso de este fixture sigue siendo el nido en Vector2.ZERO.
				descargaron_en_entrada = descargaron_en_entrada and h._tiempo_descarga > 0.0 and h.position.length_squared() <= pow(Hormiguero.RADIO_ENTRADA, 2)
				h.detener() # No recolectar comida nueva luego de entregar la carga única.
		if ms > 40.0:
			print("PICO REGRESO cuadro%d: %.2f ms | %d pendientes | %d rutas | %.3f ms navegación" % [cuadro, ms, pendientes, run.cocina._pedidos_cuadro, run.cocina._tiempo_rutas_cuadro / 1000.0])
		if pendientes == 0:
			break
	var importe := Juego.migas_run - saldo
	var resumen := _resumir(tiempos)
	_verificar(pendientes == 0 and entregadas == CANTIDAD and is_equal_approx(importe, CANTIDAD * CARGA),
		"las quinientas cargas entregan exactamente 62,5 migas, una vez por viaje")
	_verificar(seguras and descargaron_en_entrada,
		"ninguna atraviesa material ni acredita su carga antes de llegar a la entrada")
	_verificar(run.cocina.consultas_ruta > consultas and maximos.rutas <= run.cocina.limite_rutas_por_cuadro,
		"el transporte usa rutas reales y conserva el cupo compartido de seis pedidos")
	_verificar(maximos.cache_enlaces <= Cocina.MAX_CACHE_ENLACES and maximos.pruebas_enlace <= Cocina.MAX_PRUEBAS_ENLACE,
		"quinientos puestos no superan ciento veintiocho enlaces ni treinta y dos pruebas por enlace")
	_verificar(maximos.nodos <= nodos_iniciales and maximos.nodos_hud <= hud_inicial
		and maximos.nodos_combo == combo_inicial and maximos.nodos_efectos == 0 and maximos.nodos_vuelos == 0,
		"los depósitos y combos no agregan nodos al HUD, vuelos ni efectos")
	_verificar(maximos.pool_particulas <= Efectos.MAX_PARTICULAS and maximos.pool_ondas <= Efectos.MAX_ONDAS
		and maximos.pool_textos <= Efectos.MAX_TEXTOS and maximos.pool_marcas <= Efectos.MAX_MARCAS
		and maximos.slots_vuelos == VueloMigas.MAXIMO and maximos.vuelos <= VueloMigas.MAXIMO
		and maximos.chispas_combo == ComboVisual.MAX_CHISPAS,
		"activos y libres mantienen los techos de todos los pools visuales")
	var resultado := {"renderer": RenderingServer.get_current_rendering_method(), "resolucion": "1920x1080",
		"semilla": SEMILLA, "calentamiento": CALENTAMIENTO, "cuadros_hasta_entrega": tiempos.size(),
		"limite_cuadros": MAX_CUADROS, "paso_simulacion": "1/60; ejecutar con --fixed-fps 60",
		"velocidad_fixture": VELOCIDAD_FIXTURE, "cargas_sinteticas": CANTIDAD,
		"valor_sintetico_total": CANTIDAD * CARGA, "importe_entregado": importe,
		"entregadas": entregadas, "pendientes": pendientes, "cuadros_ms": tiempos,
		"cuadro": resumen, "maximos": maximos, "seguridad": seguras,
		"descargas_fisicas": descargaron_en_entrada, "consultas_ruta": run.cocina.consultas_ruta - consultas,
		"astar": run.cocina.busquedas_astar - astar, "enlaces_consultados": run.cocina.consultas_enlace,
		"aciertos_cache_enlace": run.cocina.aciertos_cache_enlace,
		"audio": "silenciado; mezcla no medida", "medicion": "tiempo entre cuadros con observador de seguridad incluido; no CPU aislada",
		"presupuesto_rutas_usec": Cocina.PRESUPUESTO_RUTAS_USEC,
		"nota_presupuesto": "la admisión respeta el tiempo acumulado; una operación individual puede sobrepasar el presupuesto blando",
		"nodos_base": nodos_iniciales, "nodos_hud_base": hud_inicial, "nodos_combo_base": combo_inicial}
	print("REGRESO 500: %d cuadros | %.2f ms media | %.2f p95 | %.2f peor | %d sobre16.67 | rutas máx %d / %.3f ms | caché máx %d | pruebas máx %d | %.3f migas" % [tiempos.size(), resumen.media, resumen.p95, resumen.peor, resumen.sobre_16_67, maximos.rutas, maximos.rutas_usec / 1000.0, maximos.cache_enlaces, maximos.pruebas_enlace, importe])
	run.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	resultado.nodos_despues_de_liberar = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - nodos_antes
	resultado.huerfanos_despues_de_liberar = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) - huerfanos_antes
	_verificar(resultado.nodos_despues_de_liberar <= 0 and resultado.huerfanos_despues_de_liberar <= 0,
		"liberar el ensayo no deja nodos ni huérfanos adicionales")
	_verificar(_huellas_guardados() == huellas, "partida y ajustes conservan existencia y SHA-256")
	resultado.guardados_antes = huellas
	resultado.guardados_despues = _huellas_guardados()
	resultado.fallas = _fallas
	resultado.verificaciones = _verificaciones
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/qa"))
	var archivo := FileAccess.open(RUTA_RESULTADOS, FileAccess.WRITE)
	if archivo != null:
		archivo.store_string(JSON.stringify(resultado, "\t"))
		archivo.close()
	else:
		_verificar(false, "se puede guardar el informe aislado en .godot/qa")
	print("Perfil de regreso por bordes: %d verificaciones; %d fallas. No estima duración de campaña ni garantiza FPS constantes." % [_verificaciones, _fallas])
	get_tree().quit(0 if _fallas == 0 else 1)


func _observar(run: Run, maximos: Dictionary) -> void:
	var fx := run.efectos
	var vuelo := run.hud._vuelo_migas
	var valores := {"rutas": run.cocina._pedidos_cuadro, "rutas_usec": run.cocina._tiempo_rutas_cuadro,
		"cache_enlaces": run.cocina._enlaces_celda.size(), "pruebas_enlace": run.cocina.pruebas_enlace_max,
		"nodos": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"nodos_hud": run.hud.get_child_count(), "nodos_combo": run.hud._combo_visual.get_child_count(),
		"nodos_efectos": fx.get_child_count(), "nodos_vuelos": vuelo.get_child_count(),
		"particulas": fx._particulas.size(), "ondas": fx._ondas.size(), "textos": fx._textos.size(), "marcas": fx._marcas.size(),
		"pool_particulas": fx._particulas.size() + fx._libres.size(),
		"pool_ondas": fx._ondas.size() + fx._ondas_libres.size(),
		"pool_textos": fx._textos.size() + fx._textos_libres.size(),
		"pool_marcas": fx._marcas.size() + fx._marcas_libres.size(),
		"vuelos": vuelo.cantidad, "slots_vuelos": vuelo.migas.size(),
		"chispas_combo": run.hud._combo_visual._chispas.size(),
		"dibujos": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))}
	for clave: String in valores:
		maximos[clave] = maxi(int(maximos[clave]), int(valores[clave]))


func _resumir(valores: Array[float]) -> Dictionary:
	if valores.is_empty():
		return {"media": 0.0, "p95": 0.0, "peor": 0.0, "sobre_16_67": 0}
	var ordenados: Array[float] = valores.duplicate()
	ordenados.sort()
	var suma := 0.0
	var sobre := 0
	for ms: float in ordenados:
		suma += ms
		sobre += int(ms > 1000.0 / 60.0)
	return {"media": suma / ordenados.size(), "p95": ordenados[ceili(ordenados.size() * 0.95) - 1],
		"peor": ordenados.back(), "sobre_16_67": sobre}


func _huellas_guardados() -> Dictionary:
	var huellas := {}
	for ruta: String in [Juego.RUTA_PARTIDA, Ajustes.RUTA]:
		huellas[ruta] = FileAccess.get_sha256(ruta) if FileAccess.file_exists(ruta) else "ausente"
	return huellas


func _verificar(condicion: bool, mensaje: String) -> void:
	_verificaciones += 1
	if condicion:
		print("OK " + mensaje)
	else:
		_fallas += 1
		push_error("FALLA " + mensaje)
