class_name Hormiguero
extends Node2D
## La entrada del hormiguero, en el centro del mapa. Late cada vez que llega comida.

const RADIO_ENTRADA := 12.0
const COLOR_TIERRA := Color(0.55, 0.4, 0.26)
const COLOR_TIERRA_OSCURA := Color(0.42, 0.29, 0.18)
const COLOR_AGUJERO := Color(0.1, 0.06, 0.04)

var _tween: Tween


func _draw() -> void:
	draw_circle(Vector2.ZERO, 30.0, Color(COLOR_TIERRA, 0.35))
	draw_circle(Vector2.ZERO, 24.0, COLOR_TIERRA)
	for i in 10:  # granitos de tierra alrededor
		var p := Vector2.from_angle(TAU * i / 10.0 + 0.3) * (19.0 + (i % 3) * 3.0)
		draw_circle(p, 2.2, COLOR_TIERRA_OSCURA)
	draw_circle(Vector2.ZERO, 15.0, COLOR_TIERRA_OSCURA)
	draw_circle(Vector2.ZERO, RADIO_ENTRADA - 1.0, COLOR_AGUJERO)


func latir() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	scale = Vector2.ONE * 1.12
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
