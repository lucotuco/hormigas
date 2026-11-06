extends Node
## Despachador real durante la animación central. El combo se dispara como
## fixture VISUAL explícita: no hay piloto, entregas ni avance de economía.
## Sólo se detienen el reloj de expedición y los agentes de la simulación;
## HUD, cámara, entrada y feromonas conservan sus callbacks y pausa reales.
var total := 0
var fallas := 0
var _ultimo_evento_mouse := Vector2.ZERO
var _tipo_ultimo_mouse := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Ajustes.temblor = 1.0
	var partida := huella(Juego.RUTA_PARTIDA)
	var ajustes := huella(Ajustes.RUTA)
	if DisplayServer.get_name() == "headless":
		verificar(false, "esta revisión necesita renderer y ventana reales")
		get_tree().quit(1)
		return
	if not Graficos.listo:
		await Graficos.preparado
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	for tam: Vector2i in [Vector2i(1920, 1080), Vector2i(1000, 620)]:
		get_window().size = tam
		await cuadros(4)
		await probar(tam)
	verificar(huella(Juego.RUTA_PARTIDA) == partida and huella(Ajustes.RUTA) == ajustes,
		"los inputs y la revisión visual conservan SHA de partida y ajustes personales")
	print("Entrada durante combo: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func probar(tam: Vector2i) -> void:
	get_tree().paused = false
	Juego.reiniciar_estado()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.process_mode = Node.PROCESS_MODE_PAUSABLE
	run.preparacion_sincrona = true
	add_child(run)
	run.set_process(false)
	run.colonia.set_process(false)
	run.eventos.set_process(false)
	run.radio_actual = 620.0
	run.camara.ajustar_a_radio(run.radio_actual, true)
	run.camara._manual = true
	run.camara.position = Vector2(200, 100)
	run.camara.zoom = Vector2.ONE * 0.7
	run.camara._zoom_objetivo = 0.7
	run.camara.force_update_scroll()
	get_viewport().gui_release_focus()
	var reloj_run := run._reloj
	var reloj_hud := run.hud._reloj
	var ingreso := Juego.migas_run
	await cuadros(4)
	verificar(run.hud._reloj > reloj_hud and run._reloj == reloj_run
		and run.hud.can_process() and run.camara.can_process(),
		"%s: HUD y cámara procesan de verdad aunque no avance la simulación" % tam)
	var centro := get_viewport().get_visible_rect().get_center()
	await disparar_combo(run)
	verificar(run.hud._combo_visual.limites_etiqueta().has_point(centro),
		"%s: el clic de prueba está debajo del combo enorme" % tam)
	await mover(centro)
	await boton(centro, MOUSE_BUTTON_LEFT, true)
	diagnosticar_llamado(run, tam, centro, "al presionar")
	await cuadros(3)
	# El SO puede emitir un MouseMotion real después del clic sintético
	# (especialmente al redimensionar Full HD). El llamado tiene que seguir
	# el ÚLTIMO evento despachado, no quedarse pegado al clic inicial. Este
	# observador es independiente de Feromonas; la tolerancia sigue en 7 px.
	var punto := run.feromonas.get_canvas_transform().affine_inverse() * _ultimo_evento_mouse
	diagnosticar_llamado(run, tam, centro, "tras mantener")
	verificar(run.feromonas.activa and run.feromonas._desde_mouse
		and run.feromonas.is_processing() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		and run.feromonas._pantalla.distance_to(_ultimo_evento_mouse) < 1.0
		and run.feromonas.posicion.distance_to(punto) * run.camara.zoom.x < 7.0
		and run.hud._combo_visual.fase_cinematica() != "inactiva",
		"%s: mantener clic bajo el impacto inicia y mantiene las feromonas reales" % tam)
	verificar(run.camara._sacudida <= 3.0
		and maxf(absf(run.camara.offset.x), absf(run.camara.offset.y)) * run.camara.zoom.x <= 3.1,
		"%s: ordenar durante un golpe ya iniciado limita de verdad la sacudida a tres píxeles" % tam)
	await captura("combo_input_clic_%d" % tam.x)
	await boton(centro, MOUSE_BUTTON_LEFT, false)
	verificar(not run.feromonas.activa, "%s: soltar el clic corta el llamado aunque siga la animación" % tam)

	await disparar_combo(run)
	var zoom_previo := run.camara.zoom.x
	await rueda(centro, MOUSE_BUTTON_WHEEL_UP)
	verificar(run.camara.zoom.x > zoom_previo and run.hud._combo_visual.fase_cinematica() != "inactiva",
		"%s: la rueda real hace zoom durante el combo y no la absorbe el cartel" % tam)

	await disparar_combo(run)
	var posicion_previa := run.camara.position
	var desde := centro + Vector2(30, 40)
	var desplazamiento := Vector2(100, 50)
	await mover(desde)
	await boton(desde, MOUSE_BUTTON_MIDDLE, true)
	verificar(run.camara.arrastrando, "%s: botón central real inicia el arrastre debajo del combo" % tam)
	await mover(desde + desplazamiento, desplazamiento, MOUSE_BUTTON_MASK_MIDDLE)
	verificar(run.camara.position.distance_to(posicion_previa) > 30.0
		and run.hud._combo_visual.fase_cinematica() != "inactiva",
		"%s: mover el mouse arrastra el mapa durante el impacto o regreso" % tam)
	verificar(run.camara._sacudida <= 3.0
		and maxf(absf(run.camara.offset.x), absf(run.camara.offset.y)) * run.camara.zoom.x <= 3.1,
		"%s: el arrastre real también conserva el límite de tres píxeles" % tam)
	await boton(desde + desplazamiento, MOUSE_BUTTON_MIDDLE, false)
	verificar(not run.camara.arrastrando, "%s: soltar el botón central termina el arrastre real" % tam)

	await disparar_combo(run)
	await tecla(KEY_ESCAPE)
	var visual := run.hud._combo_visual
	verificar(get_tree().paused and run.hud.pausado() and visual.fase_cinematica() == "impacto",
		"%s: Esc real pausa en el pico de la animación" % tam)
	verificar(is_instance_valid(run.hud._ventana)
		and run.hud._ventana.z_index > visual.z_index,
		"%s: la ventana de pausa está por delante del combo central" % tam)
	var reloj_pausado := run.hud._reloj
	var progreso_pausado := visual.progreso_cinematica()
	var pose_pausada := visual.etiqueta.position
	var offset_pausado := run.camara.offset
	await cuadros(5)
	verificar(run.hud._reloj == reloj_pausado and visual.progreso_cinematica() == progreso_pausado
		and visual.etiqueta.position == pose_pausada and run.camara.offset == offset_pausado,
		"%s: la pausa congela reloj del HUD, viaje, palabra y sacudida" % tam)
	await captura("combo_input_pausa_%d" % tam.x)
	await tecla(KEY_ESCAPE)
	await cuadros(3)
	verificar(not get_tree().paused and not run.hud.pausado()
		and run.hud._reloj > reloj_pausado and visual.progreso_cinematica() > progreso_pausado,
		"%s: el siguiente Esc real cierra el modal y reanuda esa misma animación" % tam)

	await disparar_combo(run)
	var espera := 0
	while visual.fase_cinematica() == "impacto" and espera < 120:
		espera += 1
		await cuadros(1)
	verificar(visual.fase_cinematica() == "regreso",
		"%s: el cierre se ejercita en medio del vuelo, no con el combo ya apagado" % tam)
	run._cerrar()
	await cuadros(3)
	run.hud.mostrar_combo(1000)
	await cuadros(2)
	verificar(run.terminada and not visual.visible and not run.hud._lbl_combo.visible
		and visual.fase_cinematica() == "inactiva" and not run.hud._combo_sucio,
		"%s: el cierre real cancela el viaje y rechaza el callback tardío" % tam)
	verificar(Juego.migas_run == ingreso and run._reloj == reloj_run,
		"%s: el escenario de entrada no jugó ni acreditó una expedición" % tam)
	await captura("combo_input_cierre_%d" % tam.x)
	if get_tree().paused:
		run.hud.reanudar()
	run.queue_free()
	await cuadros(3)


func disparar_combo(run: Run) -> void:
	# Fixture de presentación, deliberadamente no llama run.depositar().
	run.hud.mostrar_combo(1)
	await cuadros(2)
	run.hud.mostrar_combo(250)
	await cuadros(2)
	verificar(run.hud._combo_visual.fase_cinematica() == "impacto",
		"%s: fixture visual inicia un impacto central sin depósito ficticio" % get_window().size)


func mover(pantalla: Vector2, relativo := Vector2.ZERO, botones: MouseButtonMask = 0) -> void:
	var evento := InputEventMouseMotion.new()
	evento.position = get_viewport().get_final_transform() * pantalla
	evento.global_position = evento.position
	evento.relative = get_viewport().get_final_transform().basis_xform(relativo)
	evento.button_mask = botones
	Input.parse_input_event(evento)
	await cuadros(1)


func boton(pantalla: Vector2, codigo: MouseButton, presionado: bool) -> void:
	var evento := InputEventMouseButton.new()
	evento.button_index = codigo
	evento.position = get_viewport().get_final_transform() * pantalla
	evento.global_position = evento.position
	evento.pressed = presionado
	Input.parse_input_event(evento)
	await cuadros(1)


func rueda(pantalla: Vector2, codigo: MouseButton) -> void:
	await boton(pantalla, codigo, true)
	await boton(pantalla, codigo, false)


func tecla(codigo: Key) -> void:
	for presionada in [true, false]:
		var evento := InputEventKey.new()
		evento.keycode = codigo
		evento.physical_keycode = codigo
		evento.pressed = presionada
		Input.parse_input_event(evento)
		await cuadros(1)


func cuadros(cantidad: int) -> void:
	for i in cantidad:
		await get_tree().process_frame


func _input(evento: InputEvent) -> void:
	# Observar el despachador sin consumirlo. También registra MouseMotion del
	# sistema operativo que llegue después de nuestra entrada sintética.
	if evento is InputEventMouseMotion:
		_ultimo_evento_mouse = evento.position
		_tipo_ultimo_mouse = "movimiento"
	elif evento is InputEventMouseButton:
		_ultimo_evento_mouse = evento.position
		_tipo_ultimo_mouse = "botón %d %s" % [evento.button_index, evento.pressed]


func diagnosticar_llamado(run: Run, tam: Vector2i, centro: Vector2, momento: String) -> void:
	var inversa := run.feromonas.get_canvas_transform().affine_inverse()
	var esperado_centro := inversa * centro
	var esperado_ultimo := inversa * run.feromonas._pantalla
	print("INPUT COMBO QA ", tam, " ", momento,
		" activa=", run.feromonas.activa,
		" desde_mouse=", run.feromonas._desde_mouse,
		" procesando=", run.feromonas.is_processing(),
		" pressed=", Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),
		" posicion=", run.feromonas.posicion,
		" centro_inicial=", centro,
		" pantalla_feromonas=", run.feromonas._pantalla,
		" ultimo_despachado=", _ultimo_evento_mouse,
		" tipo_ultimo=", _tipo_ultimo_mouse,
		" cursor_viewport=", get_viewport().get_mouse_position(),
		" esperado_centro=", esperado_centro,
		" esperado_ultimo=", esperado_ultimo,
		" distancia_centro_px=", run.feromonas.posicion.distance_to(esperado_centro) * run.camara.zoom.x,
		" distancia_ultimo_px=", run.feromonas.posicion.distance_to(esperado_ultimo) * run.camara.zoom.x,
		" fase=", run.hud._combo_visual.fase_cinematica())


func captura(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	verificar(get_viewport().get_texture().get_image().save_png("res://.godot/qa/%s.png" % nombre) == OK,
		"captura QA " + nombre)


func huella(ruta: String) -> String:
	return FileAccess.get_sha256(ruta) if FileAccess.file_exists(ruta) else "ausente"


func verificar(condicion: bool, detalle: String) -> void:
	total += 1
	if not condicion:
		fallas += 1
	print("OK " if condicion else "FALLA ", detalle)
