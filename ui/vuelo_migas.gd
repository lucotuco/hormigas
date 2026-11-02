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
	var tiempo := 0.0
	var duracion := 0.6
	var radio := 3.0
var migas: Array[MigaVista] = []
var cantidad := 0
var _azar := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_azar.randomize()
	for i in MAXIMO:
		migas.append(MigaVista.new())
	set_process(false)

func emitir(desde: Vector2, hasta: Vector2, cuantas: int) -> void:
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
		m.tiempo = -_azar.randf() * 0.1
		m.duracion = _azar.randf_range(0.45, 0.7)
		m.radio = _azar.randf_range(2.5, 4.0)
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
			draw_circle(m.pos, m.radio + 0.8, Color("725534"))
			draw_circle(m.pos - Vector2(0.5, 0.5), m.radio, Color("ecc27d"))

func limpiar() -> void:
	for m in migas:
		m.activa = false
	cantidad = 0
	set_process(false)
	queue_redraw()
