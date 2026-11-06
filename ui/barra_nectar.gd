class_name BarraNectar
extends Control
## Barra de néctar bajo el reloj: cuánto falta para el próximo nivel de la
## run, el nivel actual y un destello al subir. Se dibuja sola (un rectángulo
## y dos textos); sólo se redibuja cuando cambia el valor mostrado.

const ANCHO := 380.0
const ALTO := 10.0
const COLOR_FONDO := Color("231d2c")
const COLOR_INICIO := Color("8c5cff")
const COLOR_FIN := Color("ffc847")

var evolucion: EvolucionRun
var _mostrado := 0.0
var _destello := 0.0
var _nivel_visto := 0
var _fuente: Font


const ARRIBA := 78.0


func _ready() -> void:
	# Cuelga del CanvasLayer del HUD: se centra con el ancho de la pantalla,
	# como el reloj de arriba, y no recibe el mouse.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(queue_redraw)
	_fuente = get_theme_default_font()
	if is_instance_valid(evolucion):
		evolucion.nivel_subido.connect(_on_nivel)


func _on_nivel(_nivel: int) -> void:
	_destello = 1.0
	_mostrado = 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(evolucion):
		return
	var objetivo := evolucion.progreso()
	var anterior := _mostrado
	_mostrado = lerpf(_mostrado, objetivo, 1.0 - exp(-12.0 * delta))
	if absf(_mostrado - objetivo) < 0.002:
		_mostrado = objetivo
	var cambio := absf(anterior - _mostrado) > 0.0005 or _destello > 0.0 or _nivel_visto != evolucion.nivel or _mostrado > 0.85
	_destello = maxf(0.0, _destello - delta * 1.6)
	_nivel_visto = evolucion.nivel
	if cambio:
		queue_redraw()


func _draw() -> void:
	if not is_instance_valid(evolucion):
		return
	var caja := Rect2(Vector2(roundf((get_viewport_rect().size.x - ANCHO) * 0.5), ARRIBA), Vector2(ANCHO, ALTO))
	draw_style_box(Estilo.caja(COLOR_FONDO, 5, Color("4a3d5c"), 1, 0), caja)
	var lleno := clampf(_mostrado, 0.0, 1.0)
	if lleno > 0.0:
		var relleno := Rect2(caja.position, Vector2(maxf(ALTO, caja.size.x * lleno), ALTO))
		var color := COLOR_INICIO.lerp(COLOR_FIN, lleno)
		# Cerca de llenarse, late: anticipa el nivel.
		if lleno > 0.85:
			color = color.lightened(0.18 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.018)))
		draw_style_box(Estilo.caja(color, 5, Color.TRANSPARENT, 0, 0), relleno)
		draw_rect(Rect2(relleno.position + Vector2(3, 2), Vector2(maxf(0, relleno.size.x - 6), 2)), Color(1, 1, 1, 0.22))
	if _destello > 0.0:
		draw_style_box(Estilo.caja(Color(1.0, 0.95, 0.7, _destello * 0.85), 5, Color.TRANSPARENT, 0, 0), caja.grow(2.0 * _destello))
	# Placa con el nivel, pegada a la izquierda de la barra.
	var texto := tr("NIVEL %d") % evolucion.nivel
	var tamano := 13
	var ancho := _fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	var placa := Rect2(Vector2(caja.position.x - ancho - 22, caja.get_center().y - 11), Vector2(ancho + 16, 22))
	draw_style_box(Estilo.caja(Color("2b2140f2"), 8, COLOR_FIN.lerp(Color.WHITE, _destello) * Color(1, 1, 1, 0.7), 1, 0), placa)
	var pos := Vector2(placa.position.x + 8, placa.get_center().y + tamano * 0.36)
	draw_string(_fuente, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, COLOR_FIN.lerp(Color.WHITE, _destello))
