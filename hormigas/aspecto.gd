class_name AspectoHormiga
extends RefCounted
## El mismo dibujo se usa en el mundo y en las fichas de la tienda.
const DURACION_LEVANTADO := 0.28
const CICLOS_MASTICAR := 2.0


## Curvas puramente visuales: no consultan recursos, rutas, reloj de daño ni
## azar. La preparación no retrasa la mordida y el trozo conserva su tamaño.
static func preparar_bocado(progreso: float) -> float:
	# El apoyo ocupa el final del intervalo REAL de la mordida. Llegar a una
	# pequeña meseta permite leer el esfuerzo también en el tick de 12 Hz.
	var t := clampf((progreso - 0.15) / 0.65, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func pulso_bocado(edad: float, duracion: float) -> float:
	if edad < 0 or duracion <= 0.0 or edad >= duracion:
		return 0.0
	var t := edad / duracion
	# Una caída cuadrática casi desaparecía entre dos ticks. Se conserva el
	# primer apoyo y se afloja después, sin sumar tiempo al trabajo físico.
	return 1.0 - smoothstep(0.12, 1.0, t)


static func levantar_retazo(origen: Vector2, pinza: Vector2, edad: float) -> Vector2:
	if edad <= 0.0:
		return origen
	if edad >= DURACION_LEVANTADO:
		return pinza
	var t := clampf(edad / DURACION_LEVANTADO, 0.0, 1.0)
	var suave := t * t * (3.0 - 2.0 * t)
	var altura := clampf(origen.distance_to(pinza) * 0.14, 0.65, 1.6)
	return origen.lerp(pinza, suave) + Vector2(0, -altura * sin(t * PI))


## Pose del cuerpo, no de la hormiga física ni de la carga. El hocico se
## apoya hacia el objetivo y el tirón retrocede desde ese punto; el retazo
## continúa usando la región, el tamaño y el origen que realmente se retiró.
## Se evalúa en el tick visual ya presupuestado, sin consultas ni recursos.
static func postura_bocado(preparacion: float, tiron: float, entrega: float,
		cargando: bool, fase: float, material := 0) -> Transform2D:
	var apoyo := clampf(preparacion, 0.0, 1.0)
	var arranque := clampf(tiron, 0.0, 1.0)
	var soltar := clampf(entrega, 0.0, 1.0)
	var resistencia := 1.0 + clampi(material, 0, 3) * 0.08
	var peso := 1.0 if cargando else 0.0
	var balanceo := sin(fase * 0.5) * peso
	var posicion := Vector2(apoyo * 0.8 - arranque * 1.8 * resistencia - peso * 0.28 + soltar * 1.1,
		-arranque * 0.24 + soltar * 0.28 + balanceo * 0.12)
	var angulo := -apoyo * 0.045 + arranque * 0.09 * resistencia - balanceo * 0.012
	# Sólo compresión corporal breve (no cambia el tamaño de la casta ni el
	# zoom). El material transportado nunca hereda esta deformación.
	var escala := Vector2(1.0 - apoyo * 0.08 + arranque * 0.025,
		1.0 + apoyo * 0.045 - soltar * 0.065) / 3.0
	return Transform2D(angulo, escala, 0.0, posicion)

## La fase está en radianes: el reloj aplica CICLOS_MASTICAR una sola vez.
## Cuatro cuadros por vuelta conservan una apertura/cierre bien legible.
static func cierre_masticar(fase: float) -> float:
	return 0.5 - 0.5 * cos(fase)


static func dibujar(lienzo: CanvasItem, tipo: String, color: Color, fase: float, carga := false, color_carga := Color.WHITE, evolucion := 0, masticando := false) -> void:
	if masticando:
		_dibujar_masticando(lienzo, tipo, color, fase, carga, color_carga, evolucion)
		return
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
	var abdomen := (2.7 if tipo == "reina" or tipo == "cargadora" else 2.2) + evolucion * 0.18
	lienzo.draw_circle(Vector2(-3.4, 0), abdomen + 0.3, patas)
	lienzo.draw_circle(Vector2(-3.4, -0.15), abdomen, color)
	lienzo.draw_arc(Vector2(-3.4, 0), abdomen * 0.7, -2.7, -0.6, 12, color.lightened(0.22), 0.55, true)
	lienzo.draw_circle(Vector2.ZERO, 1.35, color.darkened(0.1))
	lienzo.draw_circle(Vector2(2.5, 0), 1.65, color)
	for lado in [-1, 1]:
		lienzo.draw_line(Vector2(3.5, lado * 0.6), Vector2(5.4, lado * 2.2), patas, 0.55, true)
		lienzo.draw_circle(Vector2(3.15, lado * 0.8), 0.32, Color("171c17"))
		if evolucion > 0:
			lienzo.draw_line(Vector2(3.3, lado * 0.8), Vector2(6.0 + evolucion * 0.45, lado * 1.8), Color("d9c999"), 0.7, true)
	if evolucion == 2:
		lienzo.draw_arc(Vector2(-3.4, 0), abdomen + 0.25, -1.9, 1.9, 12, Color("d9bd74"), 0.65, true)
	match tipo:
		"reina":
			lienzo.draw_colored_polygon(PackedVector2Array([Vector2(-2, -2), Vector2(-3, -4), Vector2(-0.8, -3), Vector2(0, -5), Vector2(0.8, -3), Vector2(2.5, -4), Vector2(2, -2)]), Color("edcc79"))
			if evolucion > 0:
				lienzo.draw_circle(Vector2(0, -3.3), 0.9, Color("b8d7c2") if evolucion == 1 else Color("d5b4ea"))
				if evolucion == 2:
					lienzo.draw_line(Vector2(-3, -4), Vector2(0, -6.5), Color("fff0b3"), 0.65, true)
					lienzo.draw_line(Vector2(0, -6.5), Vector2(2.5, -4), Color("fff0b3"), 0.65, true)
		"roja":
			lienzo.draw_circle(Vector2(-4.4, 0), 0.85, Color("bad784"))
		"veloz":
			for i in 2:
				lienzo.draw_line(Vector2(-3.7 + i * 1.5, -1.8), Vector2(-3.7 + i * 1.5, 1.8), Color("705135"), 0.65, true)
		"cargadora":
			lienzo.draw_line(Vector2(-3.3, -2.4), Vector2(-3.3, 2.4), Color("64543b"), 0.8, true)
			lienzo.draw_arc(Vector2(3.8, 0), 1.8, -1.4, 1.4, 10, patas, 0.8, true)
		"carpintera":
			for lado in [-1, 1]:
				lienzo.draw_polyline(PackedVector2Array([Vector2(3, lado), Vector2(6, lado * 2), Vector2(6.4, lado * 0.5)]), Color("e3bd86"), 1.0, true)
		"demoledora":
			lienzo.draw_circle(Vector2(2, 0), 2.0, Color("b8c7c7"))
			lienzo.draw_line(Vector2(3.8, -2.4), Vector2(3.8, 2.4), Color("daceb6"), 1.4, true)
	if carga:
		lienzo.draw_circle(Vector2(5, 0), 2.1 if tipo == "cargadora" else 1.9, color_carga)
		lienzo.draw_arc(Vector2(5, 0), 1.8, -2.8, -0.7, 12, color_carga.lightened(0.3), 0.5, true)


## Pose de trabajo horneada en el mismo atlas. No hace falta dibujar patas,
## mandíbulas ni alas por hormiga/cuadro. Incluidos contornos y evolución2,
## todos los trazos quedan dentro del encuadre COMER (-9,-9,18,18).
static func _dibujar_masticando(lienzo: CanvasItem, tipo: String, color: Color,
		fase: float, carga: bool, color_carga: Color, evolucion: int) -> void:
	var cierre := cierre_masticar(fase)
	var torsion := sin(fase) * 0.2
	var patas := color.darkened(0.28)
	var quitina := color.lightened(0.55).lerp(Color("d6bd89"), 0.55)
	var cabeza := Vector2(3.2 + cierre * 0.5, torsion)
	lienzo.draw_circle(Vector2(-1, 1.4), 4.0, Color(0.1, 0.08, 0.06, 0.12))
	if tipo == "voladora":
		# Plegadas sobre el lomo, no aleteando como si todavía caminara/volara.
		for lado in [-1, 1]:
			var ala := PackedVector2Array([Vector2(-1, lado * 0.5), Vector2(-5.6, lado * 1.9),
				Vector2(-4.8, lado * 3.3), Vector2(0.2, lado * 1.6), Vector2(1, lado * 0.5)])
			lienzo.draw_colored_polygon(ala, Color(0.79, 0.94, 0.96, 0.58))
			lienzo.draw_line(Vector2(0, lado * 0.6), Vector2(-4.8, lado * 2.7), Color(0.43, 0.65, 0.69, 0.72), 0.45, true)
	for i in 3:
		var x := -1.4 + i * 1.9
		var apoyo := sin(fase + i * PI * 0.75) * 0.12
		for lado in [-1, 1]:
			lienzo.draw_polyline(PackedVector2Array([Vector2(x, 0), Vector2(x - 0.5, lado * 2.3),
				Vector2(x - 1.4 + apoyo * lado, lado * 4.2)]), patas, 0.8, true)
	var abdomen := (2.7 if tipo == "reina" or tipo == "cargadora" else 2.2) + evolucion * 0.18
	lienzo.draw_circle(Vector2(-3.4, 0), abdomen + 0.3, patas)
	lienzo.draw_circle(Vector2(-3.4, -0.15), abdomen, color)
	lienzo.draw_arc(Vector2(-3.4, 0), abdomen * 0.7, -2.7, -0.6, 12, color.lightened(0.22), 0.55, true)
	lienzo.draw_circle(Vector2.ZERO, 1.35, color.darkened(0.1))
	if evolucion == 2:
		lienzo.draw_arc(Vector2(-3.4, 0), abdomen + 0.25, -1.9, 1.9, 12, Color("d9bd74"), 0.65, true)
	match tipo:
		"reina":
			lienzo.draw_colored_polygon(PackedVector2Array([Vector2(-2, -2), Vector2(-3, -4), Vector2(-0.8, -3),
				Vector2(0, -5), Vector2(0.8, -3), Vector2(2.5, -4), Vector2(2, -2)]), Color("edcc79"))
			if evolucion > 0:
				lienzo.draw_circle(Vector2(0, -3.3), 0.9, Color("b8d7c2") if evolucion == 1 else Color("d5b4ea"))
				if evolucion == 2:
					lienzo.draw_line(Vector2(-3, -4), Vector2(0, -6.5), Color("fff0b3"), 0.65, true)
					lienzo.draw_line(Vector2(0, -6.5), Vector2(2.5, -4), Color("fff0b3"), 0.65, true)
		"roja":
			lienzo.draw_circle(Vector2(-4.4, 0), 0.85, Color("bad784"))
		"veloz":
			for i in 2:
				lienzo.draw_line(Vector2(-3.7 + i * 1.5, -1.8), Vector2(-3.7 + i * 1.5, 1.8), Color("705135"), 0.65, true)
		"cargadora":
			lienzo.draw_line(Vector2(-3.3, -2.4), Vector2(-3.3, 2.4), Color("64543b"), 0.8, true)
	if carga:
		lienzo.draw_circle(Vector2(6, 0), 2.1 if tipo == "cargadora" else 1.9, color_carga)
		lienzo.draw_arc(Vector2(6, 0), 1.8, -2.8, -0.7, 12, color_carga.lightened(0.3), 0.5, true)
	lienzo.draw_circle(cabeza, 1.65, color)
	if tipo == "demoledora":
		lienzo.draw_circle(cabeza - Vector2(0.25, 0), 1.9, Color("b8c7c7"))
		lienzo.draw_line(cabeza + Vector2(0.85, -1.6), cabeza + Vector2(0.85, 1.6), Color("daceb6"), 1.0, true)
	for lado in [-1, 1]:
		# Antenas por arriba de las pinzas, con puntas claras y contorno fino.
		lienzo.draw_polyline(PackedVector2Array([cabeza + Vector2(0.4, lado * 0.9),
			cabeza + Vector2(1.25, lado * 2.1), cabeza + Vector2(2.1, lado * (2.7 + torsion))]), quitina.darkened(0.13), 0.6, true)
		lienzo.draw_circle(cabeza + Vector2(0.55, lado * 0.8), 0.32, Color("171c17"))
		var largo := 0.25 if evolucion > 0 or tipo == "carpintera" else 0.0
		var mandibula := PackedVector2Array([cabeza + Vector2(1.05, lado * 0.65),
			cabeza + Vector2(2.15, lado * (1.95 - cierre * 1.1)),
			cabeza + Vector2(3.45 + largo, lado * (1.7 - cierre * 1.55))])
		lienzo.draw_polyline(mandibula, patas, 1.45, true)
		lienzo.draw_polyline(mandibula, quitina, 0.85, true)
