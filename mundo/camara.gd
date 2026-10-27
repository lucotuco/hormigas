class_name Camara
extends Camera2D
## Encuadre automático hasta que el jugador usa zoom o desplazamiento.
signal vista_cambiada

const MARGEN := 1.22      # cuánto espacio extra alrededor del territorio
const ZOOM_MAXIMO := 4.0
const ZOOM_MINIMO := 0.08
const PASO_ZOOM := 1.18
const LIMITE_MAPA := 9000.0
const VELOCIDAD_TECLADO := 700.0

var _zoom_objetivo := 1.0
var _sacudida := 0.0
var _zoom_auto := 1.0
var _manual := false
var arrastrando := false
var _boton_arrastre := 0
@onready var run: Run = get_parent()


func ajustar_a_radio(radio: float, inmediato := false) -> void:
	var tamano := get_viewport_rect().size
	var lado := minf(tamano.x, tamano.y)
	_zoom_auto = clampf(lado / (2.0 * maxf(radio, 1.0) * MARGEN), ZOOM_MINIMO, 1.6)
	if not _manual:
		_zoom_objetivo = _zoom_auto
	if inmediato:
		zoom = Vector2.ONE * _zoom_objetivo
		force_update_scroll()
		vista_cambiada.emit()


func zoom_hacia(factor: float, pantalla: Vector2) -> void:
	var antes := get_canvas_transform().affine_inverse() * pantalla
	_manual = true
	_zoom_objetivo = clampf(zoom.x * factor, ZOOM_MINIMO, ZOOM_MAXIMO)
	zoom = Vector2.ONE * _zoom_objetivo
	force_update_scroll()
	var despues := get_canvas_transform().affine_inverse() * pantalla
	position += antes - despues
	_limitar_posicion()
	force_update_scroll()
	vista_cambiada.emit()


func desplazar(pixeles: Vector2) -> void:
	_manual = true
	position -= pixeles / maxf(zoom.x, ZOOM_MINIMO)
	_limitar_posicion()
	force_update_scroll()
	vista_cambiada.emit()


func centrar() -> void:
	_manual = false
	arrastrando = false
	position = Vector2.ZERO
	_zoom_objetivo = _zoom_auto
	zoom = Vector2.ONE * _zoom_auto
	offset = Vector2.ZERO
	force_update_scroll()
	vista_cambiada.emit()


func _limitar_posicion() -> void:
	var limites := PlanoCasa.limites()
	position = position.clamp(limites.position, limites.end)


func ver_casa() -> void:
	_manual = true
	arrastrando = false
	var limites := PlanoCasa.limites()
	position = limites.get_center()
	var pantalla := get_viewport_rect().size
	_zoom_objetivo = clampf(minf(pantalla.x / limites.size.x, pantalla.y / limites.size.y) * 0.9, ZOOM_MINIMO, ZOOM_MAXIMO)
	zoom = Vector2.ONE * _zoom_objetivo
	offset = Vector2.ZERO
	force_update_scroll()
	vista_cambiada.emit()


func _input(event: InputEvent) -> void:
	# La liberación se recibe aunque el arrastre termine encima de un panel.
	if event is InputEventMouseButton and not event.pressed and event.button_index == _boton_arrastre:
		arrastrando = false
	if event is InputEventMouseMotion and arrastrando and run.activa:
		desplazar(event.relative)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not run.activa:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				zoom_hacia(PASO_ZOOM if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / PASO_ZOOM, event.position)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
				arrastrando = true
				_boton_arrastre = event.button_index
				get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		centrar()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		ver_casa()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		ver_objetivo()
		get_viewport().set_input_as_handled()

func ver_objetivo() -> void:
	_manual = true
	var plano := Mundos.plano(Juego.lugar_actual)
	var indice := int(str(plano.meta).get_slice(":", 1))
	var r: Rect2 = plano.muebles[indice].rect
	position = r.get_center()
	var pantalla := get_viewport_rect().size
	_zoom_objetivo = clampf(minf(pantalla.x / (r.size.x + 1000), pantalla.y / (r.size.y + 1000)), ZOOM_MINIMO, 0.7)
	zoom = Vector2.ONE * _zoom_objetivo
	force_update_scroll()
	vista_cambiada.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		arrastrando = false


## intensidad en píxeles de pantalla.
func sacudir(intensidad: float) -> void:
	_sacudida = minf(_sacudida + intensidad, 24.0)


func _process(delta: float) -> void:
	if run.activa:
		var direccion := Vector2(
			float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		if direccion != Vector2.ZERO:
			desplazar(-direccion.normalized() * VELOCIDAD_TECLADO * delta)
	else:
		arrastrando = false
	var z := lerpf(zoom.x, _zoom_objetivo, 1.0 - exp(-6.0 * delta))
	var cambio := absf(z - zoom.x) > 0.00001
	zoom = Vector2(z, z)
	if cambio:
		vista_cambiada.emit()
	if _sacudida > 0.05:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _sacudida / z
		_sacudida *= exp(-12.0 * delta)
	else:
		_sacudida = 0.0
		offset = Vector2.ZERO
