extends Node
## Capturas reales del tutorial, destrucción y equipo en ambas resoluciones.
func _ready() -> void:
	Juego.guardado_habilitado = false
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	seed(417)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	var r: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	r.colonia._process(3)
	r.hud._process(0)
	r.hud.mostrar_inspeccion(r.objetivo_practica)
	await captura("enjambre_inicio")
	r.feromonas.mantener_en(r.objetivo_practica.position)
	r.hud._process(0.2)
	await captura("enjambre_llamado")
	r.objetivo_practica.morder_en(7, r.objetivo_practica.rect_mundo.position)
	r.objetivo_practica._process(0.1)
	r.hud._process(0.2)
	r.hud.mostrar_inspeccion(r.objetivo_practica)
	await captura("enjambre_roturas")
	r.queue_free()
	await get_tree().process_frame
	Juego.niveles = {"mandibulas": 8, "mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego.reclutadas = {"reina": 1, "carpintera": 1, "roja": 3, "cargadora": 3}
	Juego.migas = 50000
	Juego.runs_jugadas = 10
	Juego._cache_stats.clear()
	Juego.actualizar_evoluciones()
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	tienda._cambiar_pestana("castas")
	tienda._panel_castas._seleccionar("carpintera")
	await captura("enjambre_equipo")
	get_window().size = Vector2i(1000, 620)
	await captura("enjambre_equipo_1000")
	var ficha: ScrollContainer = tienda._panel_castas._detalle_evolucion.get_parent().get_parent()
	ficha.scroll_vertical = 9999
	await captura("enjambre_evolucion_1000")
	tienda._panel_castas._seleccionar("reina")
	await captura("enjambre_reina_1000")
	tienda.queue_free()
	await get_tree().process_frame
	get_window().size = Vector2i(1280, 720)
	for destino in ["restaurante", "museo", "obelisco", "coliseo", "eiffel"]:
		Juego.lugar_actual = destino
		r = preload("res://mundo/run.tscn").instantiate()
		add_child(r)
		r.process_mode = Node.PROCESS_MODE_DISABLED
		r.radio_actual = 12000
		r.niebla.hide()
		var p := r.objetivo_mapa
		r.camara.position = p.position
		r.camara.zoom = Vector2.ONE * minf(0.6, minf(800 / p.rect_mundo.size.x, 390 / p.rect_mundo.size.y))
		r.camara.force_update_scroll()
		r.hud._process(0.2)
		r.hud.mostrar_inspeccion(p)
		await captura("enjambre_" + destino)
		if destino == "eiffel":
			p.morder_en(p.vida_max * 0.25, p.rect_mundo.end)
			p._process(0.1)
			r.hud._actualizar_meta()
			r.hud.mostrar_inspeccion(p)
			await captura("enjambre_eiffel_sin_base")
		r.queue_free()
		await get_tree().process_frame
	get_tree().quit()

func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + ".png")
	print(nombre)
