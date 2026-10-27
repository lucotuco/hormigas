class_name Comida
extends Node2D
## Una comida del mapa: tiene vida, se agrieta al morderla y da migas.
## El dibujo es procedural según la "forma" definida en datos/comidas.csv.

signal destruida(comida: Comida)

const COLOR_GRIETA := Color(0.18, 0.11, 0.06, 0.75)
const COLOR_CONTORNO := Color(0.15, 0.09, 0.05, 0.55)

var id := ""
var nombre := ""
var forma := ""
var color := Color.WHITE
var vida := 1.0
var vida_max := 1.0
var recompensa := 1.0
var radio := 5.0
var muerta := false

var _sacudida := 0.0
var _destello := 0.0
var _grietas: Array[Vector3] = []          # ángulo, largo (0-1), quiebre
var _detalles: Array[Vector3] = []         # x, y, tamaño (en unidades de radio)
var _contorno := PackedVector2Array()      # para formas irregulares


func configurar(tipo: Dictionary, semilla: int) -> void:
	id = tipo.id
	nombre = tipo.nombre
	forma = tipo.forma
	color = tipo.color
	vida_max = maxf(1.0, tipo.vida)
	vida = vida_max
	recompensa = tipo.recompensa
	radio = tipo.radio

	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	rotation = rng.randf() * TAU
	for i in 7:
		_grietas.append(Vector3(rng.randf() * TAU, rng.randf_range(0.55, 1.0), rng.randf_range(-0.6, 0.6)))
	match forma:
		"miga":
			var puntos := 7
			for i in puntos:
				var a := TAU * i / puntos + rng.randf_range(-0.3, 0.3)
				_contorno.append(Vector2.from_angle(a) * radio * rng.randf_range(0.65, 1.15))
		"galletita":
			for i in 6:
				var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.15, 0.7)
				_detalles.append(Vector3(p.x, p.y, rng.randf_range(0.1, 0.17)))
		"queso":
			for i in 4:
				_detalles.append(Vector3(rng.randf_range(-0.35, 0.45), rng.randf_range(-0.3, 0.3), rng.randf_range(0.08, 0.16)))
		"sandwich":
			for i in 9:
				_detalles.append(Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.45, 0.45), 0.05))
		"torta":
			for i in 8:
				var p := Vector2.from_angle(TAU * i / 8.0) * 0.72
				_detalles.append(Vector3(p.x, p.y, 0.1))
	set_process(false)
	queue_redraw()


## Aplica daño y devuelve las migas que corresponden a ese daño.
func morder(dano: float) -> float:
	if muerta or dano <= 0.0:
		return 0.0
	var real := minf(dano, vida)
	vida -= real
	_sacudida = minf(_sacudida + 1.2, 3.0)
	_destello = 0.07
	set_process(true)
	queue_redraw()
	var migas := recompensa * real / vida_max * Juego.stat("multiplicador_migas")
	if vida <= 0.001:
		muerta = true
		destruida.emit(self)
		queue_free()
	return migas


func _process(delta: float) -> void:
	_sacudida = move_toward(_sacudida, 0.0, delta * 18.0)
	_destello = maxf(0.0, _destello - delta)
	if _sacudida <= 0.0 and _destello <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var desplazamiento := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _sacudida
	draw_set_transform(desplazamiento)
	var c := color.lerp(Color.WHITE, 0.65) if _destello > 0.0 else color
	var oscuro := c.darkened(0.3)
	var r := radio
	match forma:
		"miga":
			draw_colored_polygon(_contorno, c)
			draw_polyline(_contorno + PackedVector2Array([_contorno[0]]), COLOR_CONTORNO, 0.6)
		"cuadrado":
			var lado := r * 1.6
			draw_rect(Rect2(-lado / 2, -lado / 2, lado, lado), c)
			draw_rect(Rect2(-lado / 2, -lado / 2, lado, lado * 0.3), c.lightened(0.4))
			draw_rect(Rect2(-lado / 2, -lado / 2, lado, lado), COLOR_CONTORNO, false, 0.8)
		"galletita":
			draw_circle(Vector2.ZERO, r, oscuro)
			draw_circle(Vector2.ZERO, r * 0.86, c)
			for d in _detalles:
				draw_circle(Vector2(d.x, d.y) * r, d.z * r, Color(0.3, 0.16, 0.08))
		"queso":
			var triangulo := PackedVector2Array([Vector2(-r, -r * 0.75), Vector2(r, 0), Vector2(-r, r * 0.75)])
			draw_colored_polygon(triangulo, c)
			draw_colored_polygon(PackedVector2Array([Vector2(-r, -r * 0.75), Vector2(-r * 0.75, -r * 0.6), Vector2(-r * 0.75, r * 0.6), Vector2(-r, r * 0.75)]), oscuro)
			for d in _detalles:
				draw_circle(Vector2(d.x, d.y) * r, d.z * r, c.darkened(0.18))
		"sandwich":
			var rect := Rect2(-r, -r * 0.7, r * 2.0, r * 1.4)
			draw_rect(rect, Color(0.45, 0.7, 0.3))  # lechuga que asoma
			draw_rect(rect.grow(-r * 0.08), Color(0.62, 0.38, 0.2))  # corteza
			draw_rect(rect.grow(-r * 0.2), c)
			for d in _detalles:
				draw_circle(Vector2(d.x, d.y) * r, d.z * r, Color(0.96, 0.92, 0.8))
		"torta":
			draw_circle(Vector2.ZERO, r, c.darkened(0.25))
			draw_circle(Vector2.ZERO, r * 0.92, c)
			draw_arc(Vector2.ZERO, r * 0.72, 0, TAU, 48, Color(1, 1, 1, 0.85), r * 0.12)
			for d in _detalles:
				draw_circle(Vector2(d.x, d.y) * r, d.z * r, Color(0.85, 0.1, 0.18))
			draw_circle(Vector2.ZERO, r * 0.15, Color(0.85, 0.1, 0.18))
		_:
			draw_circle(Vector2.ZERO, r, c)

	# Grietas: aparecen a medida que pierde vida.
	var dano := 1.0 - vida / vida_max
	if dano > 0.0:
		var cantidad := int(ceil(dano * _grietas.size()))
		var ancho := maxf(0.6, r * 0.07)
		for i in cantidad:
			var g := _grietas[i]
			var dir := Vector2.from_angle(g.x)
			var medio := dir * r * g.y * 0.5 + dir.orthogonal() * g.z * r * 0.2
			draw_polyline(PackedVector2Array([Vector2.ZERO, medio, dir * r * g.y]), COLOR_GRIETA, ancho)

	# Barra de vida (sin rotar) para las comidas grandes.
	draw_set_transform(desplazamiento.rotated(-rotation), -rotation)
	if dano > 0.0 and vida_max >= 15.0:
		var ancho_barra := maxf(r * 1.6, 14.0)
		var alto := maxf(2.0, r * 0.12)
		var origen := Vector2(-ancho_barra / 2, -r - alto - 4.0)
		draw_rect(Rect2(origen, Vector2(ancho_barra, alto)), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(origen, Vector2(ancho_barra * (1.0 - dano), alto)), Color(0.55, 0.95, 0.4))
	draw_set_transform(Vector2.ZERO)
