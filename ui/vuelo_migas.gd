class_name VueloMigas
extends Control
## Un solo CanvasItem y un pool fijo: ninguna textura, nodo ni Tween por miga.
signal llegaron
const MAXIMO := 40
class MigaVista:
	var activa := false
	var desde := Vector2.ZERO
	var control := Vector2.ZERO
	var hasta := Vector2.ZERO
	var pos := Vector2.ZERO
	var anterior := Vector2.ZERO
	var tiempo := 0.0
	var duracion := 0.6
	var radio := 3.0
var migas: Array[MigaVista] = []
var cantidad := 0
var _cerrado := false
var _azar := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_azar.randomize()
	for i in MAXIMO:
		migas.append(MigaVista.new())
	set_process(false)

func emitir(desde: Vector2, hasta: Vector2, cuantas: int) -> void:
	if _cerrado:
		return
	var faltan := mini(cuantas, MAXIMO - cantidad)
	for m in migas:
		if faltan <= 0:
			break
		if m.activa:
			continue
		m.activa = true
		m.desde = desde + Vector2(_azar.randf_range(-8, 8), _azar.randf_range(-8, 8))
		m.hasta = hasta
		m.control = m.desde.lerp(hasta, 0.35) + Vector2(_azar.randf_range(-80, 80), -80)
		m.pos = m.desde
		m.anterior = m.desde
		m.tiempo = -_azar.randf() * 0.1
		m.duracion = _azar.randf_range(0.45, 0.7)
		m.radio = _azar.randf_range(5.0, 6.8)
		cantidad += 1
		faltan -= 1
	set_process(cantidad > 0)
	queue_redraw()

func _process(delta: float) -> void:
	var hubo_llegadas := false
	for m in migas:
		if not m.activa:
			continue
		m.tiempo += delta
		m.anterior = m.pos
		var t := clampf(m.tiempo / m.duracion, 0, 1)
		t *= t
		m.pos = m.desde.lerp(m.control, t).lerp(m.control.lerp(m.hasta, t), t)
		if m.tiempo >= m.duracion:
			m.activa = false
			cantidad -= 1
			hubo_llegadas = true
	if hubo_llegadas:
		llegaron.emit()
	set_process(cantidad > 0)
	queue_redraw()

func _draw() -> void:
	for m in migas:
		if m.activa and m.tiempo >= 0:
			var direccion := (m.pos - m.anterior).normalized()
			var cola := m.pos - direccion * 24.0
			draw_line(cola, m.pos, Color(0.5, 0.3, 0.12, 0.35), m.radio * 1.5, true)
			draw_line(m.pos - direccion * 16.0, m.pos, Color(1.0, 0.81, 0.35, 0.65), m.radio * 0.8, true)
			draw_circle(m.pos, m.radio + 1.3, Color("70512d"))
			draw_circle(m.pos, m.radio, Color("f5c965"))
			draw_circle(m.pos - Vector2(1.5, 1.5), m.radio * 0.35, Color("fff1b7"))

func limpiar() -> void:
	_cerrado = true
	for m in migas:
		m.activa = false
	cantidad = 0
	set_process(false)
	queue_redraw()
