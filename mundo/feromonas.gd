class_name Feromonas
extends Node2D
## Las unidades más cercanas al cursor responden mientras se mantiene el clic.
const MAX_ATRAIDAS := 24
var activa := false
var posicion := Vector2.ZERO
var seleccionadas: Dictionary = {}
var _reloj := 0.0
var _espera := 0.0
var _desvanecer := 0.0
var _desde_mouse := false
var _pantalla := Vector2.ZERO
@onready var run: Run = get_parent()


func radio_visual() -> float:
	return 80.0 / maxf(get_canvas_transform().get_scale().x, 0.01)


func cantidad_atraidas() -> int:
	return clampi(int(Juego.stat("feromona_cantidad")), 1, 64)


func mantener_en(pos: Vector2, desde_mouse := false) -> void:
	var era_activa := activa
	activa = true
	posicion = pos
	_desde_mouse = desde_mouse
	_desvanecer = 1
	if not era_activa:
		_actualizar_cercanas()
	queue_redraw()


func soltar() -> void:
	activa = false
	_desde_mouse = false
	seleccionadas.clear()
	queue_redraw()


func limpiar() -> void:
	soltar()
	_desvanecer = 0


func llama_a(hormiga: Hormiga) -> bool:
	return activa and seleccionadas.has(hormiga.get_instance_id())


func _actualizar_cercanas() -> void:
	seleccionadas.clear()
	if not activa or not run.activa or posicion.length() > run.radio_actual:
		return
	var candidatas: Array[Dictionary] = []
	for h in run.colonia.hormigas:
		if h.estado == Hormiga.Estado.QUIETA or h.estado == Hormiga.Estado.VOLVIENDO or h.carga > 0:
			continue
		var d := h.global_position.distance_squared_to(posicion)
		candidatas.append({"id": h.get_instance_id(), "distancia": d})
	candidatas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distancia < b.distancia)
	for i in mini(cantidad_atraidas(), candidatas.size()):
		seleccionadas[candidatas[i].id] = true


func _unhandled_input(event: InputEvent) -> void:
	if not run.activa or run.camara.arrastrando:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pantalla = event.position
			mantener_en(get_canvas_transform().affine_inverse() * _pantalla, true)
		else:
			soltar()
	if event is InputEventMouseMotion and activa and _desde_mouse:
		_pantalla = event.position
		posicion = get_canvas_transform().affine_inverse() * _pantalla


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		soltar()


func _process(delta: float) -> void:
	_reloj += delta
	if activa:
		if not run.activa or run.camara.arrastrando or (_desde_mouse and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			soltar()
		else:
			if _desde_mouse:
				posicion = get_canvas_transform().affine_inverse() * _pantalla
			_espera -= delta
			if _espera <= 0:
				_espera = 0.1
				_actualizar_cercanas()
	else:
		_desvanecer = move_toward(_desvanecer, 0, delta * 6)
	queue_redraw()


func _draw() -> void:
	if _desvanecer <= 0:
		return
	var zoom := maxf(get_canvas_transform().get_scale().x, 0.01)
	var color := Color("72c4b0") if posicion.length() <= run.radio_actual else Color("bb8c72")
	var radio := radio_visual()
	for i in range(8, 0, -1):
		draw_circle(posicion, radio * i / 8.0, Color(color, 0.012 * _desvanecer))
	for i in 40:
		var angulo := TAU * i / 40
		draw_arc(posicion, radio, angulo, angulo + 0.075, 3, Color(color, 0.35 * _desvanecer), 1 / zoom, true)
	for i in 3:
		var t := fposmod(_reloj * 0.55 + i / 3.0, 1.0)
		draw_arc(posicion, (12 + t * 38) / zoom, 0, TAU, 40, Color(color, (1 - t) * 0.55 * _desvanecer), 1.5 / zoom, true)
	draw_circle(posicion, 4 / zoom, Color(color, _desvanecer))
	# Guías tenues hacia las elegidas; nunca queda un camino al soltar.
	if activa:
		for h in run.colonia.hormigas:
			if seleccionadas.has(h.get_instance_id()):
				draw_line(h.global_position, posicion, Color(color, 0.12), 1 / zoom, true)
