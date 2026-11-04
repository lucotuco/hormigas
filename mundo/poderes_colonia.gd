class_name PoderesColonia
extends Node2D
## Una sola máquina de estados por expedición; ningún reloj por hormiga.
## Las entregas transportadas cargan Ráfaga. Los premios y la erosión no.
var run: Run
var carga_entregas := 0
var activa_restante := 0.0
var descanso_restante := 0.0
var colocando_entrada := false
var _entregas_necesarias := 1
var _duracion := 0.0
var _descanso := 0.0
var _multiplicador := 1.0
var _multiplicador_ritmo := 1.0
var _reloj_vista := 0.0
var _posicion_vista := Vector2.INF
var _valida_vista := false


func iniciar(r: Run) -> void:
	run = r
	z_index = 20
	_entregas_necesarias = maxi(1, int(Juego.stat("rafaga_entregas")))
	_duracion = maxf(0, Juego.stat("rafaga_duracion"))
	_descanso = maxf(0, Juego.stat("rafaga_descanso"))
	_multiplicador = maxf(1, Juego.stat("rafaga_multiplicador_dano"))
	_multiplicador_ritmo = maxf(1, Juego.stat("rafaga_multiplicador_ritmo"))
	set_process(false)


func registrar_entrega() -> void:
	if is_instance_valid(run) and run.activa and not run.terminada:
		carga_entregas = mini(_entregas_necesarias, carga_entregas + 1)


func procesar(delta: float) -> void:
	if not is_instance_valid(run) or not run.activa:
		return
	activa_restante = maxf(0, activa_restante - maxf(0, delta))
	descanso_restante = maxf(0, descanso_restante - maxf(0, delta))


func lista() -> bool:
	return is_instance_valid(run) and run.activa and not run.terminada and carga_entregas >= _entregas_necesarias and activa_restante <= 0 and descanso_restante <= 0


func activar() -> bool:
	if not lista():
		return false
	carga_entregas = 0
	activa_restante = _duracion
	# El descanso empieza al activar, no se puede acumular ni extender el poder.
	descanso_restante = _descanso
	run.hud.mostrar_aviso(tr("¡Ráfaga! Mordidas más fuertes por unos segundos"))
	return true


func multiplicador_dano() -> float:
	return _multiplicador if is_instance_valid(run) and run.activa and activa_restante > 0 else 1.0


func multiplicador_ritmo() -> float:
	return _multiplicador_ritmo if is_instance_valid(run) and run.activa and activa_restante > 0 else 1.0


func entregas_necesarias() -> int:
	return _entregas_necesarias


func iniciar_colocacion() -> bool:
	if not is_instance_valid(run) or not run.activa or (run.entradas.disponibles() <= 0 and run.entradas._manuales.is_empty()):
		return false
	colocando_entrada = true
	run.feromonas.soltar()
	run.entradas.mostrar_guardadas(true)
	_reloj_vista = 0
	set_process(true)
	run.hud.mostrar_aviso(tr("Elegí piso libre para la entrada · clic sobre una entrada la levanta · Esc cancela"))
	return true


func cancelar_colocacion() -> void:
	colocando_entrada = false
	_posicion_vista = Vector2.INF
	if is_instance_valid(run) and is_instance_valid(run.entradas):
		run.entradas.cancelar_reubicacion()
	set_process(false)
	queue_redraw()


func colocar(pos: Vector2) -> bool:
	if not colocando_entrada:
		return false
	# Clic sobre una entrada ya puesta: se levanta para moverla. El modo sigue
	# abierto para elegir su lugar nuevo.
	if run.entradas.quitar(pos):
		run.hud.mostrar_aviso(tr("Entrada levantada · elegí su lugar nuevo"))
		return true
	if not run.entradas.colocar(pos):
		return false
	cancelar_colocacion()
	run.hud.mostrar_aviso(tr("Entrada colocada"))
	return true


func cerrar() -> void:
	activa_restante = 0
	cancelar_colocacion()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		cancelar_colocacion()


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(run) or not run.activa:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_N:
			if colocando_entrada:
				cancelar_colocacion()
			else:
				iniciar_colocacion()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E:
			run.activar_rafaga()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and colocando_entrada:
			cancelar_colocacion()
			get_viewport().set_input_as_handled()
	if colocando_entrada and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# El evento conserva el punto exacto de ESA presión incluso
				# al recibir varios movimientos juntos o entrada remota.
				colocar(get_canvas_transform().affine_inverse() * event.position)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancelar_colocacion()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not colocando_entrada or not run.activa:
		cancelar_colocacion()
		return
	_reloj_vista -= delta
	if _reloj_vista > 0:
		return
	_reloj_vista = 1.0 / 30.0
	_posicion_vista = get_global_mouse_position()
	_valida_vista = run.entradas.puede_levantar(_posicion_vista) or run.entradas.puede_colocar(_posicion_vista)
	queue_redraw()


func _draw() -> void:
	if not colocando_entrada or not _posicion_vista.is_finite():
		return
	var tono := Color("b7d68b") if _valida_vista else Color("d97961")
	draw_circle(_posicion_vista, EntradasHormiguero.MARGEN_ACCESO, Color(tono, 0.16))
	draw_arc(_posicion_vista, EntradasHormiguero.MARGEN_ACCESO, 0, TAU, 24, tono, 2)
