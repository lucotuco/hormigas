extends Node
## Galería reproducible: escenas reales, sin progreso ni preferencias guardadas.
func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	if not Graficos.listo:
		await Graficos.preparado
	print("ATLAS ESTÉTICO %dx%d · %.1f MiB · %d acabados" % [Graficos.textura.get_width(), Graficos.textura.get_height(), Graficos.textura.get_width() * Graficos.textura.get_height() * 4 / 1048576.0, Graficos._mueble_claves.size()])
	for destino in Mundos.ORDEN:
		Juego.reiniciar_estado()
		Juego.lugar_actual = destino
		seed(818)
		var r: Run = preload("res://mundo/run.tscn").instantiate()
		add_child(r)
		r.process_mode = Node.PROCESS_MODE_DISABLED
		r.niebla.hide()
		r.hud.hide()
		r.camara.zoom = Vector2.ONE * 0.12
		r.camara.position = PlanoCasa.limites().get_center()
		r.camara.force_update_scroll()
		await captura("estetica_" + destino)
		if destino == "casa":
			var vistas := {"cocina": Vector2(420, 100), "comedor": Vector2(3100, 200), "living": Vector2(5500, 650), "dormitorio": Vector2(450, 3250), "estudio": Vector2(3200, 3150), "bano": Vector2(5550, 3550)}
			for nombre in vistas:
				r.camara.zoom = Vector2.ONE * 0.38
				r.camara.position = vistas[nombre]
				r.camara.force_update_scroll()
				await captura("estetica_" + nombre)
			# Inicio real con HUD y niebla, no sólo la casa totalmente revelada.
			r.camara.centrar()
			r.camara.ajustar_a_radio(r.radio_actual, true)
			r.camara.force_update_scroll()
			r.niebla.show()
			r.hud.show()
			r.colonia._process(3)
			r.hud._process(0)
			await captura("estetica_inicio")
		r.queue_free()
		await get_tree().process_frame
	Juego.reiniciar_estado()
	get_tree().quit()

func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + ".png")
	print(nombre)
