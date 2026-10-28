extends Node
## Renderiza las escenas reales sin alterar la partida. Capturas en .godot/qa/.


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma(OS.get_environment("IDIOMA") if OS.has_environment("IDIOMA") else "es")  # IDIOMA=en para revisar en inglés
	Juego.reiniciar_estado()
	Sonido.silenciado = true
	seed(731)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	await captura("tienda_inicial")
	Juego.migas = 2000
	tienda._refrescar()
	await captura("tienda_compras")
	tienda._comprar("mas_obreras")
	await get_tree().create_timer(0.5).timeout
	await captura("tienda_mejorada")
	for rama in tienda.SALAS:
		tienda._seleccionar(rama)
		await captura("sala_" + rama.to_lower())
	tienda._cambiar_pestana("castas")
	await captura("castas_reina")
	for id in tienda._panel_castas._filas:
		tienda._panel_castas._seleccionar(id)
		await captura("casta_" + id)
		tienda._panel_castas._reclutar()
	await get_tree().create_timer(0.4).timeout
	await captura("castas_reclutadas")
	get_window().size = Vector2i(1000, 620)
	await captura("castas_1000x620")
	tienda._cambiar_pestana("hogar")
	tienda._seleccionar("Mandíbulas")
	await captura("tienda_1000x620")
	get_window().size = Vector2i(1280, 720)
	tienda.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	var run := preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	await get_tree().create_timer(2).timeout
	await captura("cocina_inicial")
	run.queue_free()
	await get_tree().process_frame
	Juego.niveles = {"excavar": 12, "mas_obreras": 12}
	Juego._cache_stats.clear()
	run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	await get_tree().create_timer(2).timeout
	await captura("cocina_expandida")
	run.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	Juego.reclutadas = {"reina": 1, "roja": 3, "voladora": 2, "veloz": 3, "cargadora": 2}
	run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	await get_tree().create_timer(7.5).timeout
	await captura("colonia_castas")
	run.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var imagen := get_viewport().get_texture().get_image()
	imagen.save_png("res://.godot/qa/" + nombre + ".png")
	print("Captura: ", nombre)
