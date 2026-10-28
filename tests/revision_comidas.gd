extends Node2D
## Todas las comidas, con su nombre y en qué destinos aparecen, para revisar
## el dibujo. Guarda .godot/qa/comidas.png.
##   godot --path . res://tests/revision_comidas.tscn
func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma(OS.get_environment("IDIOMA") if OS.has_environment("IDIOMA") else "es")  # IDIOMA=en para revisar en inglés
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	RenderingServer.set_default_clear_color(Color("cfc2a6"))
	var columnas := 7
	var i := 0
	for tipo in Juego.comidas:
		if tipo.id == "banquete":
			continue
		var c := Comida.new()
		c._usar_cache = false
		add_child(c)
		c.configurar(tipo, 7)
		c.rotation = 0.3
		c.scale = Vector2.ONE * clampf(52.0 / tipo.radio, 1.0, 3.2)
		c.position = Vector2(95 + (i % columnas) * 180, 80 + floorf(i / float(columnas)) * 170)
		var nombre := Label.new()
		nombre.text = "%s\n%s" % [tr(tipo.nombre), "|".join(tipo.destinos) if not tipo.destinos.is_empty() else "*"]
		nombre.add_theme_color_override("font_color", Color("2b2118"))
		nombre.add_theme_font_size_override("font_size", 12)
		nombre.position = c.position + Vector2(-80, 64)
		nombre.size.x = 160
		nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(nombre)
		i += 1
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/comidas.png")
	print("comidas")
	get_tree().quit()
