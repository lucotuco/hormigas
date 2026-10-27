class_name RetratoCasta
extends Control

var tipo := "reina"
var reloj := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	reloj += delta
	queue_redraw()


func _draw() -> void:
	if not Juego.castas_por_id.has(tipo):
		return
	var c: Dictionary = Juego.castas_por_id[tipo]
	var centro := size * 0.5
	var radio := minf(size.x, size.y) * 0.43
	draw_circle(centro, radio, Color(c.color, 0.08))
	draw_arc(centro, radio, 0, TAU, 64, Color(c.color, 0.18), 1, true)
	var escala := minf(size.x, size.y) / 25.0
	draw_set_transform(centro, -0.35, Vector2.ONE * escala)
	AspectoHormiga.dibujar(self, tipo, c.color, reloj * 4)
	draw_set_transform(Vector2.ZERO)
