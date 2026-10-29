class_name Camara
extends Camera2D
## Encuadre automático hasta que el jugador usa zoom o desplazamiento.
signal vista_cambiada

const MARGEN := 1.22      # cuánto espacio extra alrededor del territorio
const ZOOM_MAXIMO := 4.0
const ZOOM_MINIMO := 0.08
const PASO_ZOOM := 1.18
const VELOCIDAD_TECLADO := 700.0

var _zoom_objetivo := 1.0
var _sacudida := 0.0
var _zoom_auto := 1.0
var _manual := false
var arrastrando := false
var _boton_arrastre := 0
var _radio_encuadre := 1.0
var _pantalla := Vector2.ONE
var _limites_visuales := Rect2()
var _limites_jugables := Rect2()
var _zoom_minimo_vista := ZOOM_MINIMO
@onready var run: Run = get_parent()


func _ready() -> void:
	# Los planos son estáticos durante la expedición: ni el zoom ni el arrastre
	# recorren muebles, ambientes o navegación. Sólo cambia el tamaño visible.
	_limites_visuales = PlanoCasa.limites_visuales()
	_limites_jugables = PlanoCasa.limites()
	get_viewport().size_changed.connect(_al_cambiar_tamano)
	_al_cambiar_tamano()


func ajustar_a_radio(radio: float, inmediato := false) -> void:
	var nuevo_radio := maxf(radio, 1.0)
	if is_equal_approx(nuevo_radio, _radio_encuadre) and not inmediato:
		return
	_radio_encuadre = nuevo_radio
	_actualizar_zoom_auto()
	if not _manual:
		_zoom_objetivo = _zoom_auto
	if inmediato:
		zoom = Vector2.ONE * _zoom_objetivo
		_limitar_posicion()
		_limitar_sacudida()
		force_update_scroll()
		vista_cambiada.emit()


func _actualizar_zoom_auto() -> void:
	var lado := minf(_pantalla.x, _pantalla.y)
	_zoom_auto = _limitar_zoom(minf(lado / (2.0 * _radio_encuadre * MARGEN), 1.6))


func _al_cambiar_tamano() -> void:
	_pantalla = get_viewport_rect().size.max(Vector2.ONE)
	# Para no ver fuera del escenario, ambos ejes del viewport tienen que caber.
	# No alcanza con limitar el centro de cámara ni con un mínimo fijo de 0.08.
	_zoom_minimo_vista = maxf(ZOOM_MINIMO, maxf(_pantalla.x / maxf(_limites_visuales.size.x, 1.0), _pantalla.y / maxf(_limites_visuales.size.y, 1.0)))
	_actualizar_zoom_auto()
	_zoom_objetivo = _limitar_zoom(_zoom_objetivo) if _manual else _zoom_auto
	zoom = Vector2.ONE * _limitar_zoom(zoom.x if _manual else _zoom_auto)
	if not _manual:
		position = Vector2.ZERO
	_limitar_posicion()
	_limitar_sacudida()
	force_update_scroll()
	vista_cambiada.emit()


func _limitar_zoom(valor: float) -> float:
	return clampf(valor, _zoom_minimo_vista, maxf(ZOOM_MAXIMO, _zoom_minimo_vista))


func zoom_hacia(factor: float, pantalla: Vector2) -> void:
	var antes := get_canvas_transform().affine_inverse() * pantalla
	_manual = true
	_zoom_objetivo = _limitar_zoom(zoom.x * factor)
	zoom = Vector2.ONE * _zoom_objetivo
	force_update_scroll()
	var despues := get_canvas_transform().affine_inverse() * pantalla
	position += antes - despues
	_limitar_posicion()
	_limitar_sacudida()
	force_update_scroll()
	vista_cambiada.emit()


func desplazar(pixeles: Vector2) -> void:
	_manual = true
	position -= pixeles / maxf(zoom.x, ZOOM_MINIMO)
	_limitar_posicion()
	_limitar_sacudida()
	force_update_scroll()
	vista_cambiada.emit()


func centrar() -> void:
	_manual = false
	arrastrando = false
	position = Vector2.ZERO
	_zoom_objetivo = _zoom_auto
	zoom = Vector2.ONE * _zoom_auto
	offset = Vector2.ZERO
	_limitar_posicion()
	force_update_scroll()
	vista_cambiada.emit()


func _limitar_posicion() -> void:
	var mitad := _pantalla / (2.0 * maxf(zoom.x, ZOOM_MINIMO))
	var desde := _limites_visuales.position + mitad
	var hasta := _limites_visuales.end - mitad
	# La tolerancia numérica no debe invertir el intervalo al alejar al máximo.
	position = position.clamp(desde.min(hasta), hasta.max(desde))


func _limitar_sacudida() -> void:
	var mitad := _pantalla / (2.0 * maxf(zoom.x, ZOOM_MINIMO))
	var desde := _limites_visuales.position + mitad - position
	var hasta := _limites_visuales.end - mitad - position
	offset = offset.clamp(desde.min(hasta), hasta.max(desde))


func ver_casa() -> void:
	_manual = true
	arrastrando = false
	var limites := _limites_jugables
	position = limites.get_center()
	_zoom_objetivo = _limitar_zoom(minf(_pantalla.x / limites.size.x, _pantalla.y / limites.size.y) * 0.9)
	zoom = Vector2.ONE * _zoom_objetivo
	offset = Vector2.ZERO
	_limitar_posicion()
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
	mirar(r.get_center(), r.size)


## Encuadra un lugar del mundo con margen (gran objetivo, su derrumbe).
func mirar(centro: Vector2, tamano: Vector2) -> void:
	_manual = true
	arrastrando = false
	position = centro
	_zoom_objetivo = _limitar_zoom(minf(minf(_pantalla.x / (tamano.x + 1000), _pantalla.y / (tamano.y + 1000)), 0.7))
	zoom = Vector2.ONE * _zoom_objetivo
	offset = Vector2.ZERO
	_limitar_posicion()
	force_update_scroll()
	vista_cambiada.emit()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		arrastrando = false


## intensidad en píxeles de pantalla.
func sacudir(intensidad: float) -> void:
	_sacudida = minf(_sacudida + intensidad * Ajustes.temblor, 24.0)


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
	if absf(z - _zoom_objetivo) < 0.00001:
		z = _zoom_objetivo
	var zoom_nuevo := Vector2(z, z)
	var cambio := zoom_nuevo != zoom
	zoom = zoom_nuevo
	if cambio:
		if not _manual:
			position = Vector2.ZERO
		_limitar_posicion()
		force_update_scroll()
		vista_cambiada.emit()
	if _sacudida > 0.05:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _sacudida / z
		_sacudida *= exp(-12.0 * delta)
	else:
		_sacudida = 0.0
		offset = Vector2.ZERO
	if cambio or _sacudida > 0.0:
		_limitar_sacudida()
