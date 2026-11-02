class_name DibujoHallazgo
extends RefCounted
## Papel plegado cenital. La geometría opaca es la misma que recibe Mordiscos;
## etiquetas y pliegues se pintan DENTRO de ella, no ocultan otro cuerpo comido.
const FORMAS := ["papel_galletita", "sobre_azucar", "bolsa_cereal"]


static func tiene_forma(forma: String) -> bool:
	return forma in FORMAS


static func silueta(forma: String, radio: float) -> Array[Rect2]:
	var zonas: Array[Rect2] = []
	# Coordenadas sobre una grilla de 1/64: los pliegues comparten bordes
	# representables exactamente en Vector2 (float32), sin tiras solapadas por
	# redondear, por ejemplo, -0.94 + 0.22 y -0.72 por caminos distintos.
	match forma:
		"papel_galletita":
			zonas = [Rect2(-60, -60, 120, 120),
				Rect2(-64, -36, 4, 72), Rect2(60, -36, 4, 72)]
		"sobre_azucar":
			zonas = [Rect2(-48, -48, 96, 96),
				Rect2(-40, -60, 80, 12), Rect2(-40, 48, 80, 12)]
		"bolsa_cereal":
			zonas = [Rect2(-48, -48, 96, 96),
				Rect2(-50, -64, 100, 16), Rect2(-38, 48, 76, 12)]
	var resultado: Array[Rect2] = []
	if not is_finite(radio) or radio <= 0:
		return resultado
	for zona in zonas:
		resultado.append(Rect2(zona.position * (radio / 64.0), zona.size * (radio / 64.0)))
	return resultado


static func dibujar(lienzo: CanvasItem, forma: String, radio: float, color: Color) -> void:
	var formas := silueta(forma, radio)
	if formas.is_empty():
		return
	var tinta := Color("74694e")
	for zona in formas:
		lienzo.draw_rect(zona, color.darkened(0.20))
		var margen := minf(0.6, minf(zona.size.x, zona.size.y) * 0.12)
		lienzo.draw_rect(zona.grow(-margen), color)
	match forma:
		"papel_galletita":
			lienzo.draw_rect(Rect2(-radio * 0.53, -radio * 0.32, radio * 1.06, radio * 0.64), Color("89775b"))
			lienzo.draw_rect(Rect2(-radio * 0.48, -radio * 0.27, radio * 0.96, radio * 0.54), Color("d9c391"))
			# Una impresión sobre papel, no la galletita reservada debajo.
			lienzo.draw_circle(Vector2.ZERO, radio * 0.21, Color("b58b58"))
			for punto in [Vector2(-0.07, -0.07), Vector2(0.08, -0.05), Vector2(0.01, 0.10)]:
				lienzo.draw_circle(punto * radio, radio * 0.028, tinta)
			for x in [-0.97, 0.97]:
				lienzo.draw_line(Vector2(x * radio, -radio * 0.24), Vector2(x * radio, radio * 0.24), tinta, 0.65)
			lienzo.draw_line(Vector2(-radio * 0.57, -radio * 0.43), Vector2(radio * 0.57, -radio * 0.43), color.lightened(0.18), 0.7)
		"sobre_azucar":
			lienzo.draw_rect(Rect2(-radio * 0.55, -radio * 0.62, radio * 1.10, radio * 0.24), Color("809d9d"))
			for x in [-0.22, 0.02, 0.25]:
				lienzo.draw_rect(Rect2(Vector2(x - 0.09, -0.04) * radio, Vector2(0.18, 0.20) * radio), Color("faf5e8"))
			for y in [-0.82, 0.83]:
				lienzo.draw_line(Vector2(-radio * 0.46, y * radio), Vector2(radio * 0.46, y * radio), tinta, 0.6)
			lienzo.draw_line(Vector2(-radio * 0.46, radio * 0.48), Vector2(radio * 0.40, radio * 0.48), Color("a5b5aa"), 0.8)
		"bolsa_cereal":
			lienzo.draw_rect(Rect2(-radio * 0.50, -radio * 0.38, radio, radio * 0.83), Color("d9c291"))
			lienzo.draw_rect(Rect2(-radio * 0.50, -radio * 0.38, radio, radio * 0.18), Color("9d7958"))
			for punto in [Vector2(-0.18, 0.08), Vector2(0.18, 0.16)]:
				lienzo.draw_arc(punto * radio, radio * 0.14, 0, TAU, 12, Color("ac824d"), radio * 0.075)
			for y in [-0.87, 0.83]:
				lienzo.draw_line(Vector2(-radio * 0.46, y * radio), Vector2(radio * 0.46, y * radio), tinta, 0.6)
