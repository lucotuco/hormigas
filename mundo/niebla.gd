class_name Niebla
extends Node2D
## Oscuridad fuera del territorio. Lo que está afuera se adivina en sombra:
## es la meta que el jugador ve desde el principio.
## Se dibuja como anillos de cuadriláteros con degradé en el borde.

const COLOR_NIEBLA := Color(0.07, 0.045, 0.03, 0.84)
const RADIO_EXTERIOR := 8000.0
const BORDE_INTERIOR := 30.0   # degradé hacia adentro del territorio
const BORDE_EXTERIOR := 8.0    # degradé hacia afuera
const SEGMENTOS := 128

var radio := 200.0:
	set(valor):
		if absf(valor - radio) > 0.05:
			radio = valor
			queue_redraw()


func _draw() -> void:
	var zoom := maxf(get_viewport().get_canvas_transform().get_scale().x, 0.01)
	var transparente := Color(COLOR_NIEBLA, 0.0)
	var medio := Color(COLOR_NIEBLA, COLOR_NIEBLA.a * 0.7)
	_anillo(maxf(radio - BORDE_INTERIOR, 0.0), radio, transparente, medio)
	_anillo(radio, radio + BORDE_EXTERIOR, medio, COLOR_NIEBLA)
	_anillo(radio + BORDE_EXTERIOR, RADIO_EXTERIOR, COLOR_NIEBLA, COLOR_NIEBLA)
	draw_arc(Vector2.ZERO, radio, 0, TAU, SEGMENTOS, Color(1.0, 0.8, 0.45, 0.45), 2.0 / zoom, true)


func _anillo(r_interior: float, r_exterior: float, color_interior: Color, color_exterior: Color) -> void:
	var colores := PackedColorArray([color_interior, color_exterior, color_exterior, color_interior])
	for i in SEGMENTOS:
		var a := Vector2.from_angle(TAU * i / SEGMENTOS)
		var b := Vector2.from_angle(TAU * (i + 1) / SEGMENTOS)
		draw_polygon(PackedVector2Array([a * r_interior, a * r_exterior, b * r_exterior, b * r_interior]), colores)
