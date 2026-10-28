extends Node
## QA real: clic de tarjeta no llama hormigas, tutorial y modal accesibles al redimensionar.
var total := 0
var fallas := 0

func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("OK " if ok else "FALLA ", detalle)

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma(OS.get_environment("IDIOMA") if OS.has_environment("IDIOMA") else "es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	if not Graficos.listo:
		await Graficos.preparado
	Juego.reiniciar_estado()
	Juego.niveles = {"mandibulas": 4, "mordida_madera": 1}
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.camara.mirar(run.hud._silla_inicial.position, Vector2(1100, 800))
	for tam in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1000, 620)]:
		get_window().size = tam
		await captura("claridad_madera_%d" % tam.x)
		run.hud._actualizar_meta()
		await get_tree().process_frame
		verificar(run.hud._panel_meta.get_global_rect().end.y < run.hud._lbl_lugar.get_global_rect().position.y, "el paso y el lugar no se superponen a %d" % tam.x)
	get_window().size = Vector2i(1280, 720)
	var indicador: HUD.IndicadorEventos
	for n in run.hud.get_child(0).get_children():
		if n is HUD.IndicadorEventos:
			indicador = n
	for tipo in ["paloma", "dorada"]:
		for e in run.eventos.aparecer(tipo):
			e.position = Vector2(6000, 3500)
	indicador.queue_redraw()
	await captura("claridad_avisos")
	verificar(indicador.etiquetas.size() == 2, "una tarjeta por tipo con acción y explicación")
	# Reactivar sólo la entrega de input: la simulación queda quieta para el clic.
	run.process_mode = Node.PROCESS_MODE_INHERIT
	run.set_process(false)
	run.colonia.detener()
	run.eventos.set_process(false)
	for e in run.eventos.activos:
		e.set_process(false)
	var destino := indicador._eventos[0].position
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.position = indicador.etiquetas[0].get_center()
	clic.pressed = true
	get_viewport().push_input(clic, true)
	await get_tree().process_frame
	clic = clic.duplicate()
	clic.pressed = false
	get_viewport().push_input(clic, true)
	await get_tree().process_frame
	verificar(run.camara.position.distance_to(destino) < 1 and not run.feromonas.activa, "el clic real encuadra el evento sin iniciar feromonas")
	run.queue_free()
	await get_tree().process_frame
	Juego.migas_colonia = 1.6e6
	Juego.coronas = 2
	Juego.niveles_jalea = {"herencia_madera": 1, "obreras_reales": 2}
	Juego._cache_stats.clear()
	var ventana := VentanaFundar.new()
	add_child(ventana)
	for tam in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1000, 620)]:
		get_window().size = tam
		await captura("claridad_fundar_%d" % tam.x)
		var area := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		verificar(area.encloses(ventana._boton_fundar.get_global_rect()), "la confirmación sigue accesible al redimensionar a %d" % tam.x)
		verificar(area.encloses(ventana._panel.get_global_rect()), "la ventana cabe entera a %d" % tam.x)
	ventana.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	print("Revisión claridad: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)

func captura(nombre: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var idioma := "_en" if TranslationServer.get_locale().begins_with("en") else ""
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + idioma + ".png")
