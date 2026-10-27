extends Node2D
## Piso de baldosas de cocina. Se dibuja una sola vez.

const TAMANO := 64.0
const RADIO_MUNDO := 2600.0
const COLOR_A := Color("e9dcc3")
const COLOR_B := Color("dccdaf")
const COLOR_JUNTA := Color("c9b898")


func _draw() -> void:
	var n := int(ceil(RADIO_MUNDO / TAMANO))
	draw_rect(Rect2(-n * TAMANO, -n * TAMANO, 2 * n * TAMANO, 2 * n * TAMANO), COLOR_JUNTA)
	for x in range(-n, n):
		for y in range(-n, n):
			var color := COLOR_A if (x + y) % 2 == 0 else COLOR_B
			draw_rect(Rect2(x * TAMANO + 1.0, y * TAMANO + 1.0, TAMANO - 2.0, TAMANO - 2.0), color)
