extends Node
func _ready() -> void:
	Juego.guardado_habilitado = false
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	for id in Mundos.ORDEN:
		Juego.lugar_actual = id
		Juego.lugares_completados[id] = true
		var run: Run = preload("res://mundo/run.tscn").instantiate()
		add_child(run)
		run.process_mode = Node.PROCESS_MODE_DISABLED
		run.radio_actual = 9500
		run.niebla.hide()
		run.hud.hide()
		run.camara.ver_casa()
		await captura("destino_" + id)
		if id == "eiffel":
			run.hud.show()
			run.hud._process(0)
			run.camara.ver_objetivo()
			get_window().size = Vector2i(1000, 620)
			await captura("destino_eiffel_hud_1000")
			get_window().size = Vector2i(1280, 720)
		run.queue_free()
		await get_tree().process_frame
	Juego.coronas = 3
	Juego.legado = 2
	Juego.hitos = {"primera_silla": true, "primer_derrumbe": true, "primer_tesoro": true}
	Juego._cache_stats.clear()
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	tienda._cambiar_pestana("viajes")
	await captura("campana_viajes")
	get_window().size = Vector2i(1000, 620)
	await captura("campana_viajes_1000")
	tienda._cambiar_pestana("legado")
	await captura("campana_legado_1000")
	tienda._panel_legado._pedir_fundacion()
	await captura("campana_confirmar_legado")
	tienda.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + ".png")
	print(nombre)
