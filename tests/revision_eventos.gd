extends Node
## Revisión visual de las amenazas de cada destino y la miga dorada, en la
## run real. Guarda .godot/qa/evento_<tipo>.png. Con IDIOMA=en, en inglés.
##   godot --path . res://tests/revision_eventos.tscn
const CASOS := [["casa", "arana"], ["restaurante", "mozo"], ["museo", "aspiradora"], ["obelisco", "paloma"], ["coliseo", "gato"], ["eiffel", "rata"], ["casa", "dorada"]]


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma(OS.get_environment("IDIOMA") if OS.has_environment("IDIOMA") else "es")  # IDIOMA=en para revisar en inglés
	Sonido.silenciado = true
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	if not Graficos.listo and DisplayServer.get_name() != "headless":
		await Graficos.preparado
	for caso in CASOS:
		Juego.reiniciar_estado()
		Juego.lugar_actual = caso[0]
		Juego.niveles = {"mas_obreras": 12, "excavar": 3}
		Juego._cache_stats.clear()
		var run: Run = preload("res://mundo/run.tscn").instantiate()
		add_child(run)
		run.eventos._reloj_amenaza = 1e9
		run.eventos._reloj_dorada = 1e9
		Engine.time_scale = 3.0
		await get_tree().create_timer(4.0, true, false, false).timeout
		var eventos := run.eventos.aparecer(caso[1])
		await get_tree().create_timer(4.5 if caso[1] in ["paloma", "rata", "arana"] else 1.5, true, false, false).timeout
		Engine.time_scale = 0.0
		if not eventos.is_empty() and is_instance_valid(eventos[0]):
			run.camara._manual = true
			run.camara.position = run.eventos.punto_de_clic(eventos[0])
			run.camara._zoom_objetivo = 1.4
			run.camara.zoom = Vector2.ONE * 1.4
			run.camara.force_update_scroll()
		await captura("evento_" + caso[1])
		Engine.time_scale = 1.0
		run.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + ".png")
	print(nombre)
