extends Node
## Benchmark gráfico repetible, sin VSync y sin escribir la partida.
var run: Run

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")  # las verificaciones leen textos en español
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	seed(171)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.set_process(false)
	run.set_process_unhandled_input(false)
	run.feromonas.set_process_unhandled_input(false)
	run.camara.set_process_input(false)
	run.camara.set_process_unhandled_input(false)
	run.colonia.set_process(false)
	run.radio_actual = 9500
	run.niebla.radio = 9500
	run.camara.ver_casa()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if Graficos.listo:
		print("ATLAS %dx%d · %.1f MiB RGBA8" % [Graficos.textura.get_width(), Graficos.textura.get_height(), Graficos.textura.get_width() * Graficos.textura.get_height() * 4 / 1048576.0])
	for cantidad in [5, 150, 500]:
		while run.colonia.cantidad() < cantidad:
			run.colonia._nacer()
		run.feromonas.mantener_en(Vector2(460, 0))
		await medir("casa_%d" % cantidad)
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1, "rastro_persistente": 10}
	Juego._cache_stats.clear()
	Juego.prioridad = "muebles"
	var i := 0
	for h in run.colonia.hormigas:
		h.position = Vector2(40 + (i % 10) * 6, -130 + (i % 25) * 10)
		h.casta = ["obrera", "carpintera", "cargadora", "roja", "demoledora", "voladora"][i % 6]
		h._evolucion = 2
		h._dano = 15
		h._capacidad = 4
		h._velocidad = 300
		h._olfato = 180
		h.carga = 0
		h._carga_origen.fill(0.0)
		h.comida = null
		h.estado = Hormiga.Estado.EXPLORANDO
		h._meta_ruta = Vector2.INF
		i += 1
	await medir("demolicion_500")
	for h in run.colonia.hormigas:
		h._contagio = h.casta == "roja"
		h._barrido = h.casta == "cargadora"
	await medir("evoluciones_500")
	print("COTAS restos %d/%d · partículas %d/%d · textos %d/%d" % [run.comidas.fragmentos.size(), Comidas.MAX_FRAGMENTOS, run.efectos._particulas.size(), Efectos.MAX_PARTICULAS, run.efectos._textos.size(), Efectos.MAX_TEXTOS])
	get_tree().quit()

func medir(nombre: String) -> void:
	for i in 60:
		await get_tree().process_frame
	var cuadros: Array[float] = []
	var dibujos := 0.0
	var anterior := Time.get_ticks_usec()
	for i in 300:
		if nombre in ["demolicion_500", "evoluciones_500"] and i % 30 == 0:
			for parte in run.comidas.partes:
				if parte.disponible() and parte.position.length() < 1800:
					run.feromonas.mantener_en(parte.position)
					break
		await get_tree().process_frame
		var ahora := Time.get_ticks_usec()
		cuadros.append((ahora - anterior) / 1000.0)
		anterior = ahora
		dibujos += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	cuadros.sort()
	var suma := 0.0
	for ms in cuadros:
		suma += ms
	print("PERFIL %s: frame %.2f ms | p95 %.2f ms | peor %.2f ms | drawcalls %.0f" % [nombre, suma / cuadros.size(), cuadros[284], cuadros.back(), dibujos / 300])
