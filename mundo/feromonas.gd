class_name Feromonas
extends Node2D
## Las unidades más cercanas al cursor responden mientras se mantiene el clic.
const MAX_ATRAIDAS := 24
const INTERVALO_SELECCION := 0.2
const INTERVALO_VISUAL := 1.0 / 30.0
var activa := false
var posicion := Vector2.ZERO
var seleccionadas: Dictionary = {}
var objetivo_comida: Comida
var _reloj := 0.0
var _espera := 0.0
var _desvanecer := 0.0
var _desde_mouse := false
var _pantalla := Vector2.ZERO
var _reloj_visual := 0.0
var _candidatas: Array[Hormiga] = []
var _distancias := PackedFloat64Array()
var _destinos: Dictionary = {}
var _pos_destinos := Vector2.INF
var _version_destinos := -1
var _radio_destinos := -1.0
var _limites_jugables := Rect2()
@onready var run: Run = get_parent()

func _ready() -> void:
	_limites_jugables = PlanoCasa.limites()
	set_process(false)


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
	set_process(true)
	if not era_activa:
		_espera = INTERVALO_SELECCION
		_actualizar_cercanas()
		queue_redraw()


func soltar() -> void:
	if not activa:
		return
	activa = false
	_desde_mouse = false
	seleccionadas.clear()
	objetivo_comida = null
	_destinos.clear()
	_pos_destinos = Vector2.INF
	queue_redraw()


func limpiar() -> void:
	soltar()
	_desvanecer = 0
	set_process(false)
	queue_redraw()


func llama_a(hormiga: Hormiga) -> bool:
	return activa and _punto_permitido() and seleccionadas.has(hormiga.get_instance_id())


func _punto_permitido() -> bool:
	# El paisaje lejano no es un objetivo: no llamar ni buscar accesos hacia
	# árboles/fachadas decorativos, aunque entren en el radio de una colonia grande.
	return _limites_jugables.has_point(posicion) and posicion.length_squared() <= run.radio_actual * run.radio_actual


func _actualizar_cercanas() -> void:
	seleccionadas.clear()
	objetivo_comida = null
	if not activa or not run.activa or not _punto_permitido():
		return
	objetivo_comida = run.comidas.comida_en(posicion, run.radio_actual)
	# Heap máximo de K elementos: no crear un Dictionary por hormiga ni ordenar
	# toda la colonia diez veces por segundo. Memoria acotada a las elegidas.
	_candidatas.clear()
	_distancias.clear()
	var limite := cantidad_atraidas()
	for h in run.colonia.hormigas:
		if h.estado == Hormiga.Estado.QUIETA or h.estado == Hormiga.Estado.VOLVIENDO or h.carga > 0:
			continue
		var d := h.global_position.distance_squared_to(posicion)
		if _candidatas.size() < limite:
			_candidatas.append(h)
			_distancias.append(d)
			var i := _candidatas.size() - 1
			while i > 0:
				var padre := (i - 1) / 2 as int
				if _distancias[padre] >= _distancias[i]:
					break
				_intercambiar(i, padre)
				i = padre
		elif d < _distancias[0]:
			_candidatas[0] = h
			_distancias[0] = d
			var i := 0
			while i * 2 + 1 < limite:
				var hijo := i * 2 + 1
				if hijo + 1 < limite and _distancias[hijo + 1] > _distancias[hijo]:
					hijo += 1
				if _distancias[i] >= _distancias[hijo]:
					break
				_intercambiar(i, hijo)
				i = hijo
	for h in _candidatas:
		seleccionadas[h.get_instance_id()] = h
		# Respuesta rápida sin sincronizar las 64 decisiones en un solo cuadro.
		h._reloj_pensar = minf(h._reloj_pensar, (seleccionadas.size() % 4) / 60.0)
	if is_instance_valid(objetivo_comida):
		run.colonia.avistar(objetivo_comida)

func resumen() -> Dictionary:
	var datos := {"atraidas": 0, "trabajando": 0, "cargando": 0, "esperando": 0}
	for h in seleccionadas.values():
		if not is_instance_valid(h):
			continue
		datos.atraidas += 1
		if h.carga > 0 or h.estado == Hormiga.Estado.VOLVIENDO:
			datos.cargando += 1
		elif h.estado == Hormiga.Estado.MORDIENDO:
			datos.trabajando += 1
		elif h._esperando_ruta or h._ruta_fallida:
			datos.esperando += 1
	return datos


func _intercambiar(a: int, b: int) -> void:
	var hormiga := _candidatas[a]
	var distancia := _distancias[a]
	_candidatas[a] = _candidatas[b]
	_distancias[a] = _distancias[b]
	_candidatas[b] = hormiga
	_distancias[b] = distancia


func destino_para(volando: bool) -> Vector2:
	if not _punto_permitido():
		return Vector2.INF
	# El cursor sobre un mueble puede requerir cientos de pruebas geométricas.
	# Resolver una vez por tipo de movimiento, no una vez por hormiga y cuadro.
	if _version_destinos != run.cocina.version or _pos_destinos.distance_squared_to(posicion) > 144 or absf(_radio_destinos - run.radio_actual) > 6:
		_destinos.clear()
		_pos_destinos = posicion
		_version_destinos = run.cocina.version
		_radio_destinos = run.radio_actual
	if not _destinos.has(volando):
		_destinos[volando] = run.cocina.ajustar_destino(posicion, run.radio_actual, volando)
	return _destinos[volando]


func _unhandled_input(event: InputEvent) -> void:
	if not run.activa or run.camara.arrastrando:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pantalla = event.position
			var punto := get_canvas_transform().affine_inverse() * _pantalla
			if run.eventos.pisar(punto):
				return
			mantener_en(punto, true)
		else:
			soltar()
	if event is InputEventMouseMotion and activa and _desde_mouse:
		_pantalla = event.position
		posicion = get_canvas_transform().affine_inverse() * _pantalla


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
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
				_espera = INTERVALO_SELECCION
				_actualizar_cercanas()
	else:
		_desvanecer = move_toward(_desvanecer, 0, delta * 6)
		if _desvanecer <= 0:
			set_process(false)
			queue_redraw() # Borrar el último cuadro aunque no toque el tick visual.
	_reloj_visual -= delta
	if _reloj_visual <= 0:
		_reloj_visual = INTERVALO_VISUAL
		queue_redraw()


func _draw() -> void:
	if _desvanecer <= 0:
		return
	var zoom := maxf(get_canvas_transform().get_scale().x, 0.01)
	var color := Color("72c4b0") if _punto_permitido() else Color("bb8c72")
	var radio := radio_visual()
	draw_circle(posicion, radio, Color(color, 0.022 * _desvanecer))
	draw_arc(posicion, radio, 0, TAU, 48, Color(color, 0.18 * _desvanecer), 1 / zoom, true)
	var pulso := fposmod(_reloj * 0.55, 1.0)
	draw_arc(posicion, (12 + pulso * 38) / zoom, 0, TAU, 40, Color(color, (1 - pulso) * 0.3 * _desvanecer), 1 / zoom, true)
	draw_circle(posicion, 3 / zoom, Color(color, _desvanecer * 0.85))
	# Guías tenues hacia las elegidas; nunca queda un camino al soltar.
	if activa and _punto_permitido():
		var guias := 0
		for h in seleccionadas.values():
			if is_instance_valid(h) and h.en_pantalla and h.carga <= 0 and h.estado != Hormiga.Estado.VOLVIENDO:
				draw_line(h.global_position, posicion, Color(color, 0.055), 1 / zoom, true)
				guias += 1
				if guias >= 16:
					break
		# Agrupar puntos rellenos: intercalar arcos y líneas cortaba el batching.
		for h in seleccionadas.values():
			if is_instance_valid(h) and h.en_pantalla and h.carga <= 0:
				draw_circle(h.global_position - Vector2(0, 8 / zoom), 2.2 / zoom, Color("c6e6b8"))
