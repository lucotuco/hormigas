class_name AspectoHormiga
extends RefCounted
## El mismo dibujo se usa en el mundo y en las fichas de la tienda.

static func dibujar(lienzo: CanvasItem, tipo: String, color: Color, fase: float, carga := false, color_carga := Color.WHITE) -> void:
	var patas := color.darkened(0.28)
	lienzo.draw_circle(Vector2(-1, 1.4), 4.0, Color(0.1, 0.08, 0.06, 0.12))
	if tipo == "voladora":
		var aleteo := 0.65 + absf(sin(fase * 2.0)) * 0.4
		for lado in [-1, 1]:
			var origen := Vector2(-0.7, lado * 3.0)
			var ala := PackedVector2Array()
			for p in [Vector2(-3, 0), Vector2(-7, lado * 6), Vector2(0, lado * 8), Vector2(4, lado * 3), Vector2(2, 0)]:
				ala.append(Vector2(p.x, p.y * aleteo).rotated(lado * 0.45) + origen)
			lienzo.draw_colored_polygon(ala, Color(0.79, 0.94, 0.96, 0.65))
			lienzo.draw_line(origen, Vector2(-3, lado * 6 * aleteo).rotated(lado * 0.45) + origen, Color(0.43, 0.65, 0.69, 0.7), 0.4, true)
	for i in 3:
		var x := -1.4 + i * 1.9
		var paso := sin(fase + i * PI * 0.75) * 1.2
		for lado in [-1, 1]:
			var rodilla := Vector2(x - 0.5, lado * 2.2)
			lienzo.draw_polyline(PackedVector2Array([Vector2(x, 0), rodilla, Vector2(x - 1.4 + paso * lado, lado * 4.1)]), patas, 0.7, true)
	var abdomen := 2.7 if tipo == "reina" or tipo == "cargadora" else 2.2
	lienzo.draw_circle(Vector2(-3.4, 0), abdomen + 0.3, patas)
	lienzo.draw_circle(Vector2(-3.4, -0.15), abdomen, color)
	lienzo.draw_arc(Vector2(-3.4, 0), abdomen * 0.7, -2.7, -0.6, 12, color.lightened(0.22), 0.55, true)
	lienzo.draw_circle(Vector2.ZERO, 1.35, color.darkened(0.1))
	lienzo.draw_circle(Vector2(2.5, 0), 1.65, color)
	for lado in [-1, 1]:
		lienzo.draw_line(Vector2(3.5, lado * 0.6), Vector2(5.4, lado * 2.2), patas, 0.55, true)
		lienzo.draw_circle(Vector2(3.15, lado * 0.8), 0.32, Color("171c17"))
	match tipo:
		"reina":
			lienzo.draw_colored_polygon(PackedVector2Array([Vector2(-2, -2), Vector2(-3, -4), Vector2(-0.8, -3), Vector2(0, -5), Vector2(0.8, -3), Vector2(2.5, -4), Vector2(2, -2)]), Color("edcc79"))
		"roja":
			lienzo.draw_circle(Vector2(-4.4, 0), 0.85, Color("bad784"))
		"veloz":
			for i in 2:
				lienzo.draw_line(Vector2(-3.7 + i * 1.5, -1.8), Vector2(-3.7 + i * 1.5, 1.8), Color("705135"), 0.65, true)
		"cargadora":
			lienzo.draw_line(Vector2(-3.3, -2.4), Vector2(-3.3, 2.4), Color("64543b"), 0.8, true)
			lienzo.draw_arc(Vector2(3.8, 0), 1.8, -1.4, 1.4, 10, patas, 0.8, true)
	if carga:
		lienzo.draw_circle(Vector2(5, 0), 2.1 if tipo == "cargadora" else 1.9, color_carga)
		lienzo.draw_arc(Vector2(5, 0), 1.8, -2.8, -0.7, 12, color_carga.lightened(0.3), 0.5, true)
