extends Node
## Estrés gráfico real, no duración/balance. Ejecutar solo, sin headless.
## Misma colonia de500, presupuesto de navegación y material físico vigente.
const CONFIGURACIONES := [
	{"destino": "museo", "equipo": ["sondeo", "barrido"]},
	{"destino": "coliseo", "equipo": ["cantera", "contagio"]},
	{"destino": "eiffel", "equipo": ["cantera", "puente"]},
]


func _ready() -> void:
	Juego.guardado_habilitado = false
	Ajustes.pausar_sin_foco = false
	get_tree().paused = false
	Sonido.silenciado = true
	get_window().size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	assert(DisplayServer.get_name() != "headless", "Este perfil necesita el renderizador real")
	for configuracion in CONFIGURACIONES:
		await medir(configuracion)
	get_tree().quit()


func medir(configuracion: Dictionary) -> void:
	Juego.reiniciar_estado()
	seed(827)
	Juego.lugar_actual = configuracion.destino
	# Configuración de estrés explícita, no usada para medir horas de juego.
	Juego.niveles = {"entradas": 5, "mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1, "excavar": 30, "rastro_persistente": 10, "pisoton": 10}
	for evolucion in configuracion.equipo:
		Juego.evoluciones_desbloqueadas[evolucion] = true
	Juego.evoluciones_equipadas.assign(configuracion.equipo)
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.set_process(false)
	run.set_process_unhandled_input(false)
	run.colonia.set_process(false)
	run.eventos.set_process(false) # Aislar logística; no perder unidades por amenazas.
	run.feromonas.set_process_unhandled_input(false)
	run.camara.set_process(false)
	run.camara.set_process_input(false)
	run.camara.set_process_unhandled_input(false)
	run.radio_actual = 9500
	run.niebla.radio = 9500
	run.camara.zoom = Vector2.ONE * 0.28
	run.camara.position = Vector2(1200, 700)
	run.camara.force_update_scroll()
	var frente := run.objetivo_actual()
	# Daño de estrés explícito para activar cortes, tesoros y montones también
	# frente a objetivos tardíos; no fuerza sus HP ni sirve para medir balance.
	var dano_estres := maxf(20.0, frente.vida_max * 0.005) if is_instance_valid(frente) else 20.0
	for i in 500:
		var origen := run.entradas.puntos[i % run.entradas.puntos.size()]
		var h := run.colonia._nacer(["obrera", "carpintera", "cargadora", "roja", "voladora", "demoledora"][i % 6], origen)
		h._velocidad = 300
		h._dano = dano_estres
		h._capacidad = 6
		h._olfato = 180
	for i in 90:
		await get_tree().process_frame
	var tiempos: Array[float] = []
	var mascaras_vistas: Dictionary = {}
	for parte in run.comidas.partes:
		if parte.mordiscos != null:
			mascaras_vistas[parte.get_instance_id()] = true
	var antes := Time.get_ticks_usec()
	var max_pedidos := 0
	var dibujos := 0.0
	for i in 360:
		if i % 30 == 0:
			var objetivo := run.objetivo_actual()
			if is_instance_valid(objetivo):
				var punto := objetivo.punto_mordida(Vector2.ZERO, run.radio_actual)
				if punto != Vector2.INF:
					run.feromonas.mantener_en(punto)
		await get_tree().process_frame
		var ahora := Time.get_ticks_usec()
		var ms := (ahora - antes) / 1000.0
		tiempos.append(ms)
		antes = ahora
		var preparacion := 0.0
		var nombres: Array[String] = []
		for parte in run.comidas.partes:
			if parte.mordiscos != null and not mascaras_vistas.has(parte.get_instance_id()):
				mascaras_vistas[parte.get_instance_id()] = true
				preparacion += parte.mordiscos.tiempo_configuracion_usec / 1000.0
				nombres.append("%s %s" % [parte.pieza.get("tipo", ""), parte.mordiscos.tamano_mascara()])
		if ms > 40.0 or preparacion > 10.0:
			print("PICO %s cuadro%d: %.2f ms | proceso %.2f ms | física %.2f ms | preparar %.2f ms | %s" % [configuracion.destino, i, ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, preparacion, "; ".join(nombres)])
		max_pedidos = maxi(max_pedidos, run.cocina._pedidos_cuadro)
		dibujos += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	tiempos.sort()
	assert(not get_tree().paused and run.colonia.cantidad() == 500 and run.cocina.consultas_ruta > 0, "El perfil requiere500hormigas y navegación activa")
	var suma := 0.0
	for ms in tiempos:
		suma += ms
	print("PROYECTOS %s %s: %.2f ms media | %.2f p95 | %.2f peor | dibujos %.0f | rutas/cuadro %d | restos %d/%d" % [configuracion.destino, "+".join(configuracion.equipo), suma / tiempos.size(), tiempos[341], tiempos.back(), dibujos / tiempos.size(), max_pedidos, run.comidas.fragmentos.size(), Comidas.MAX_FRAGMENTOS])
	print("EROSIÓN %s: %d operaciones/cuadro máx | operación %.2f ms máx | %d recursos pendientes | trabajo emitido %.2f / admitido %.2f | ingresos reales %.2f" % [configuracion.destino, run.cola_erosion.max_operaciones_cuadro, run.cola_erosion.max_operacion_usec / 1000.0, run.cola_erosion.cantidad_pendientes(), run.cola_erosion.trabajo_emitido, run.cola_erosion.trabajo_admitido, run.cola_erosion.ingresos_reales])
	run.queue_free()
	await get_tree().process_frame
