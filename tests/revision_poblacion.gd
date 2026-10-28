extends Node
## QA real Full HD: seis mapas poblados y nuevos tipos sobre el mismo atlas.
var fallas := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	get_window().size = Vector2i(1920, 1080)
	if not Graficos.listo:
		await Graficos.preparado
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	var atlas := Graficos.textura.get_image()
	print("ATLAS POBLADO ", atlas.get_width(), "x", atlas.get_height(), " regiones=", Graficos.regiones.size())
	if atlas.get_width() != 2048 or atlas.get_height() > 5504:
		fallas += 1
		print("FALLA el atlas supera el presupuesto de43MiB RGBA")
	for destino in Mundos.ORDEN:
		Juego.reiniciar_estado()
		Juego.lugar_actual = destino
		Juego.runs_jugadas = 20
		Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
		Juego._cache_stats.clear()
		seed(617)
		var run: Run = preload("res://mundo/run.tscn").instantiate()
		add_child(run)
		run.process_mode = Node.PROCESS_MODE_DISABLED
		run.hud.hide()
		run.niebla.hide()
		run.eventos.hide()
		var alimentos_validos := true
		for comida in run.comidas.lista:
			if comida.id != "banquete":
				alimentos_validos = alimentos_validos and run.cocina.libre(comida.position, comida.radio + 8)
		if not alimentos_validos:
			fallas += 1
			print("FALLA comida sobre material ", destino)
		print("CONTENIDO ", destino, " alimentos=", run.comidas.lista.size(), " piezas=", run.comidas.partes.size())
		run.camara.ver_casa()
		await captura("poblacion_" + destino)
		if destino == "obelisco":
			run.camara.position = Vector2(2750, 700)
			run.camara.zoom = Vector2.ONE * 0.33
			run.camara.force_update_scroll()
			await captura("poblacion_ba_cerca")
		if destino == "casa":
			run.camara.position = Vector2(200, 300)
			run.camara.zoom = Vector2.ONE * 0.46
			run.camara.force_update_scroll()
			await captura("poblacion_cocina_cerca")
		if destino == "eiffel":
			run.camara.position = Vector2(1000, 1550)
			run.camara.zoom = Vector2.ONE * 0.46
			run.camara.force_update_scroll()
			await captura("poblacion_paris_cerca")
		run.queue_free()
		await get_tree().process_frame
	Juego.reiniciar_estado()
	print("Revisión gráfica de población: ", fallas, " fallas.")
	get_tree().quit(1 if fallas else 0)

func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + ".png")
	print("CAPTURA ", nombre)
