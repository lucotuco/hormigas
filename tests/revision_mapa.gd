extends Node
## Escenas reales para revisar el plano y cada ambiente sin tocar el guardado.
func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma(OS.get_environment("IDIOMA") if OS.has_environment("IDIOMA") else "es")  # IDIOMA=en para revisar en inglés
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	seed(818)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.colonia._process(3)
	run.hud._process(0)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	await captura("casa_inicio")
	run.feromonas.mantener_en(Vector2(40, 130))
	await captura("casa_atraccion")
	run.feromonas.limpiar()
	run.camara.ver_casa()
	await captura("casa_plano")
	run.radio_actual = 9500
	run.niebla.radio = 9500
	run.niebla.hide()
	run.hud.hide()
	await captura("casa_completa")
	run.niebla.show()
	run.hud.show()
	var vistas := {"cocina": Vector2(520, 130), "comedor": Vector2(3000, 180), "living": Vector2(5500, 600), "dormitorio": Vector2(480, 3270), "estudio": Vector2(3200, 3260), "bano": Vector2(5550, 3550)}
	for nombre in vistas:
		run.camara.zoom_hacia(0.32 / run.camara.zoom.x, get_viewport().get_visible_rect().size * 0.5)
		run.camara.position = vistas[nombre]
		run.camara.force_update_scroll()
		run.camara.vista_cambiada.emit()
		await captura("casa_" + nombre)
	run.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	Juego.migas = 25000
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	Juego.cambiar_cantidad_compra(10)
	await captura("tienda_lotes_10")
	get_window().size = Vector2i(1000, 620)
	await captura("tienda_lotes_1000")
	get_window().size = Vector2i(1280, 720)
	Juego.cambiar_cantidad_compra(0)
	await captura("tienda_lotes_max")
	tienda._cambiar_pestana("castas")
	await captura("castas_lotes_max")
	tienda.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + ".png")
	print(nombre)
