extends Node
## Revisión gráfica aislada: mapa, entradas, corrosión, cierre, viajes y legado.
func _ready() -> void:
	Juego.guardado_habilitado = false
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	seed(417)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	Juego.niveles = {"entradas": 4, "excavar": 15, "mandibulas": 8, "mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var r: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	r.niebla.hide()
	r.camara.zoom = Vector2.ONE * 0.25
	r.camara.position = Vector2(1400, 750)
	r.camara.force_update_scroll()
	r.entradas._process(0.6)
	r.hud.hide()
	for p in r.comidas.partes:
		if p.pieza.tipo == "mesa":
			p.morder_en(p.vida_max * 0.2, p.rect_mundo.position)
			p.aplicar_veneno(1, 3, r)
			p._process(0.1)
	await captura("logistica_mapa")
	r.hud.show()
	r.ingresos.assign([1500.0, 3900.0, 800.0])
	Juego.migas_run = 6200
	r.tiempo_jugado = 60
	r.tiempo_restante = 0
	r._terminar()
	r.process_mode = Node.PROCESS_MODE_INHERIT
	r.set_process(false)
	r.set_process_unhandled_input(false)
	r.camara.set_process(false)
	r.camara.set_process_input(false)
	r.camara.set_process_unhandled_input(false)
	await get_tree().create_timer(1.4, true, false, true).timeout
	await captura("logistica_resumen")
	get_window().size = Vector2i(1000, 620)
	await captura("logistica_resumen_1000")
	r.queue_free()
	await get_tree().process_frame
	Engine.time_scale = 1
	Juego.lugares_completados = {"casa": true, "restaurante": true, "museo": true}
	Juego.coronas = 6
	Juego._cache_stats.clear()
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	tienda._cambiar_pestana("viajes")
	await captura("logistica_viajes_1000")
	tienda._cambiar_pestana("legado")
	await captura("logistica_legado_1000")
	get_window().size = Vector2i(1280, 720)
	await captura("logistica_legado")
	get_tree().quit()

func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + ".png")
	print(nombre)
