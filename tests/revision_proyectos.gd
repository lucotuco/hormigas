extends Node
## Fixtures visuales, no partidas ni mediciones de duración.
var fallas := 0
var total := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	for idioma in ["es", "en"]:
		Juego.usar_idioma(idioma)
		_preparar("restaurante")
		var tienda := preload("res://ui/tienda.tscn").instantiate()
		add_child(tienda)
		tienda._cambiar_pestana("viajes")
		await captura("proyectos_viajes_" + idioma + "_1920")
		_verificar_viajes(tienda._panel_viajes)
		get_window().size = Vector2i(1000, 620)
		await captura("proyectos_viajes_" + idioma + "_1000")
		_verificar_viajes(tienda._panel_viajes)
		tienda.queue_free()
		await get_tree().process_frame
		get_window().size = Vector2i(1920, 1080)
		_preparar("eiffel")
		for proyecto in ["museo_vitrinas", "eiffel_libros"]:
			for objetivo in ProyectosCampana.por_id(proyecto).objetivos:
				Juego.registrar_objetivo_proyecto(objetivo.id)
		var castas := preload("res://ui/tienda.tscn").instantiate()
		add_child(castas)
		castas._cambiar_pestana("castas")
		castas._panel_castas._seleccionar("voladora")
		await captura("proyectos_evoluciones_" + idioma + "_1920")
		get_window().size = Vector2i(1000, 620)
		await captura("proyectos_evoluciones_" + idioma + "_1000")
		castas.queue_free()
		await get_tree().process_frame
		get_window().size = Vector2i(1920, 1080)
		_preparar("museo")
		var run: Run = preload("res://mundo/run.tscn").instantiate()
		add_child(run)
		run.process_mode = Node.PROCESS_MODE_DISABLED
		run.radio_actual = 9500
		run.niebla.hide()
		run.camara.ver_objetivo()
		var hover_antes := run.comidas.comida_en(run.get_global_mouse_position(), run.radio_actual, true)
		print("QA inspección antes de apartar cursor (%s): %s" % [idioma, hover_antes.nombre if is_instance_valid(hover_antes) else "vacío"])
		await _apartar_cursor(run)
		run.hud._process(0.3)
		run.recorrido.queue_redraw()
		await captura("proyectos_objetivo_" + idioma + "_1920")
		verificar(run.objetivo_actual() != null and run.hud._objetivo_paso == run.objetivo_actual(), "el HUD y el encuadre muestran el mismo objeto físico")
		verificar(run.objetivo_actual().nombre in run.hud._lbl_objetivo.text and not run.objetivo_mapa.nombre in run.hud._lbl_objetivo.text, "sin hover, la información secundaria muestra el objeto del recorrido y no la canónica")
		run.queue_free()
		await get_tree().process_frame
	Juego.reiniciar_estado()
	print("Revisión de proyectos: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func _preparar(destino: String) -> void:
	Juego.reiniciar_estado()
	for anterior in Mundos.ORDEN:
		if anterior == destino:
			break
		Juego.lugar_actual = anterior
		Juego.completar_destino()
	Juego.elegir_destino(destino)
	Juego.niveles = {"mandibulas": 8, "mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1, "excavar": 30}
	Juego.reclutadas = {"voladora": 3, "demoledora": 1}
	Juego._cache_stats.clear()
	Juego.actualizar_evoluciones()


func _verificar_viajes(panel: PanelCampana) -> void:
	verificar(panel._tarjetas_destino.size() == 6 and panel._filas_proyectos.size() == 4, "viajes conserva seis destinos y cuatro proyectos del lugar actual")
	var limites := panel.get_global_rect()
	for tarjeta: Control in panel._tarjetas_destino.values():
		var rect := tarjeta.get_global_rect()
		verificar(rect.position.x >= limites.position.x - 1 and rect.end.x <= limites.end.x + 1, "las tarjetas de destino caben en el ancho disponible")
	if limites.size.x >= 900:
		verificar(panel._grid_proyectos.columns == 2, "en Full HD el recorrido usa dos columnas")
		var visibles := true
		for proyecto: Control in panel._filas_proyectos.values():
			visibles = visibles and proyecto.get_global_rect().end.y <= limites.end.y + 1
		verificar(visibles, "los cuatro proyectos se ven sin desplazar la lista en Full HD")


func _apartar_cursor(run: Run) -> void:
	var tam := get_viewport().get_visible_rect().size
	for punto: Vector2 in [Vector2(5, 5), Vector2(tam.x - 5, 5), Vector2(5, tam.y - 5), tam - Vector2.ONE * 5]:
		var mundo: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * punto
		if run.comidas.comida_en(mundo, run.radio_actual, true) != null:
			continue
		Input.warp_mouse(punto)
		await get_tree().process_frame
		if run.comidas.comida_en(run.get_global_mouse_position(), run.radio_actual, true) == null:
			verificar(true, "la captura del recorrido no inspecciona otro objeto bajo el cursor")
			return
	verificar(false, "no se encontró espacio vacío para apartar el cursor de la captura")


func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + ".png")
	verificar(error == OK, "captura " + nombre)


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)
