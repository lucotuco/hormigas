extends Node
## Integración con el despachador REAL de entrada y renderer. No sustituye
## la lógica por llamadas a colocar/cancelar ni mide FPS.
var total := 0
var fallas := 0

class CocinaControlada extends Cocina:
	func _ready() -> void:
		pass
	func libre(pos: Vector2, margen := 0.0, _volando := false) -> bool:
		return pos.is_finite() and pos.x < 500 and margen == EntradasHormiguero.MARGEN_ACCESO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	if DisplayServer.get_name() == "headless":
		verificar(false, "esta revisión requiere renderer y ventana reales")
		get_tree().quit(1)
		return
	if not Graficos.listo:
		await Graficos.preparado
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	for tam: Vector2i in [Vector2i(1920, 1080), Vector2i(1000, 620)]:
		get_window().size = tam
		await cuadros(4)
		await probar(tam)
	print("Entrada real de poderes: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func probar(tam: Vector2i) -> void:
	get_tree().paused = false # Una falla anterior no contamina la otra ventana.
	Juego.reiniciar_estado()
	Juego.runs_jugadas = 12
	Juego.niveles = {"entradas": 2, "excavar": 8, "mordida_madera": 1}
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(run)
	run.set_process(false)
	run.colonia.set_process(false)
	run.eventos.set_process(false)
	var original := run.cocina
	original.set_process(false)
	var cocina := CocinaControlada.new()
	run.add_child(cocina)
	cocina.set_process(false)
	run.cocina = cocina
	run.radio_actual = 620
	run.camara.ajustar_a_radio(620, true)
	run.camara._manual = true
	run.camara.position = Vector2(200, 100)
	run.camara.zoom = Vector2.ONE * 0.7
	run.camara._zoom_objetivo = 0.7
	run.camara.force_update_scroll()
	run.poderes.carga_entregas = run.poderes.entregas_necesarias()
	run.hud._actualizar_poderes()
	await cuadros(3)
	get_viewport().gui_release_focus()
	var valida := Vector2(220, 100)
	var invalida := Vector2(520, 100)
	await mover(run, valida)
	await boton(run, valida, true)
	verificar(run.feromonas.activa, "%s: el clic real de referencia sí inicia feromonas" % tam)
	await tecla(KEY_N)
	verificar(run.poderes.colocando_entrada and not run.feromonas.activa,
		"%s: N real entra en colocación y corta el llamado previo" % tam)
	await boton(run, valida, false)
	await mover(run, invalida)
	await boton(run, invalida, true)
	await boton(run, invalida, false)
	verificar(run.poderes.colocando_entrada and run.entradas_disponibles() == 2
		and not run.feromonas.activa and not get_tree().paused,
		"%s: clic inválido real no gasta acceso, no llama ni pausa" % tam)
	await tecla(KEY_ESCAPE)
	verificar(not run.poderes.colocando_entrada and not get_tree().paused
		and run.entradas_disponibles() == 2 and not run.feromonas.activa,
		"%s: Esc real cancela colocación y no se propaga al menú de pausa" % tam)
	await tecla(KEY_N)
	var enemigo: Evento = run.eventos.aparecer("cucaracha")[0]
	enemigo.set_process(false)
	enemigo.position = valida
	var golpes := enemigo.golpes
	var ingreso := Juego.migas_run
	await mover(run, valida)
	await boton(run, valida, true)
	await boton(run, valida, false)
	print("INPUT QA ", tam, ": accesos=", run.entradas.puntos,
		" esperado=", valida, " colocando=", run.poderes.colocando_entrada)
	verificar(run.entradas_disponibles() == 1 and run.entradas.puntos.size() == 2
		and run.entradas.puntos[1].distance_to(valida) < 2.0
		and not run.poderes.colocando_entrada,
		"%s: N y clic real colocan exactamente un acceso en el piso elegido" % tam)
	verificar(not run.feromonas.activa and run.feromonas.seleccionadas.is_empty()
		and enemigo.golpes == golpes and Juego.migas_run == ingreso,
		"%s: confirmar y soltar no inician llamado ni golpean la amenaza debajo" % tam)
	# Preparar la prueba independiente de pausa mediante otra entrada REAL;
	# la colocación fallida ya quedó registrada, no se corrige por API.
	if run.poderes.colocando_entrada:
		await tecla(KEY_ESCAPE)
	await tecla(KEY_ESCAPE)
	verificar(get_tree().paused and run.hud.pausado(),
		"%s: fuera de colocación Esc real sigue abriendo pausa" % tam)
	await tecla(KEY_ESCAPE)
	verificar(not get_tree().paused and not run.hud.pausado(),
		"%s: el siguiente Esc real cierra la ventana sin abrir otra" % tam)
	run.hud._actualizar_poderes()
	await cuadros(3)
	var pantalla := get_viewport().get_visible_rect()
	for control in [run.hud._boton_entrada, run.hud._boton_rafaga, run.hud._boton_objetivo]:
		verificar(control.visible and pantalla.encloses(control.get_global_rect()),
			"%s: acción visible y completa dentro del HUD responsive" % tam)
	ingreso = Juego.migas_run
	await tecla(KEY_E)
	verificar(run.poderes.activa_restante > 0 and run.poderes.carga_entregas == 0,
		"%s: E real activa la misma Ráfaga que el botón" % tam)
	verificar(run.efectos._pausa_epico > 0 and not run.efectos._particulas.is_empty()
		and Juego.migas_run == ingreso,
		"%s: E real también dispara el feedback épico sin crear ingresos" % tam)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/activa_input_poderes_%dx%d.png" % [tam.x, tam.y])
	if get_tree().paused:
		run.hud.reanudar()
	run.cocina = original
	run.queue_free()
	await cuadros(2)


func posicion_ventana(run: Run, mundo: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * run.a_pantalla(mundo)


func mover(run: Run, mundo: Vector2) -> void:
	var evento := InputEventMouseMotion.new()
	evento.position = posicion_ventana(run, mundo)
	evento.global_position = evento.position
	Input.parse_input_event(evento)
	await cuadros(1)


func boton(run: Run, mundo: Vector2, presionado: bool) -> void:
	var evento := InputEventMouseButton.new()
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.position = posicion_ventana(run, mundo)
	evento.global_position = evento.position
	evento.pressed = presionado
	if presionado and run.poderes.colocando_entrada:
		print("INPUT QA ", get_window().size, ": ventana=", evento.position,
			" evento_mundo=", get_viewport().get_canvas_transform().affine_inverse() * (get_viewport().get_final_transform().affine_inverse() * evento.position),
			" cursor_mundo=", run.get_global_mouse_position(),
			" valido=", run.entradas.puede_colocar(mundo))
	Input.parse_input_event(evento)
	await cuadros(1)


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


func verificar(condicion: bool, detalle: String) -> void:
	total += 1
	if not condicion:
		fallas += 1
	print("OK " if condicion else "FALLA ", detalle)
