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
var veneno_restante := 0.0
var _veneno_dps := 0.0
var _veneno_acumulado := 0.0
var _run_veneno: Run
var _usar_cache := true


func configurar(tipo: Dictionary, semilla: int) -> void:
	id = tipo.id
	nombre = tr(tipo.nombre)
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
	if _usar_cache and not Graficos.listo:
		Graficos.preparado.connect(queue_redraw, CONNECT_ONE_SHOT)

func disponible() -> bool:
	return not muerta

func distancia_a(pos: Vector2) -> float:
	return maxf(0, pos.distance_to(global_position) - radio)

func contiene_punto(pos: Vector2, margen := 0.0) -> bool:
	return pos.distance_squared_to(global_position) <= pow(radio + margen, 2)

func en_territorio(radio_territorio: float) -> bool:
	return position.length() - radio * 0.5 <= radio_territorio

func alcanza_desde(pos: Vector2) -> bool:
	return distancia_a(pos) <= 3

func punto_mordida(_desde: Vector2, territorio: float, _volando := false) -> Vector2:
	return global_position.limit_length(territorio - 6)


## Aplica daño y devuelve las migas que corresponden a ese daño.
func morder(dano: float) -> float:
	if muerta or dano <= 0.0:
		return 0.0
	var real := minf(dano, vida)
	vida -= real
	if get_parent() is Comidas:
		get_parent().get_parent().registrar_extraccion(real)
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


## Conserva el efecto más fuerte y renueva su duración; no suma DPS sin límite.
func aplicar_veneno(dano_por_segundo: float, duracion: float, run: Run) -> void:
	if muerta or not run.activa or dano_por_segundo <= 0:
		return
	_veneno_dps = maxf(_veneno_dps, dano_por_segundo)
	veneno_restante = maxf(veneno_restante, duracion)
	_run_veneno = run
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if muerta:
		return
	if veneno_restante > 0:
		if not is_instance_valid(_run_veneno) or not _run_veneno.activa:
			veneno_restante = 0
			_veneno_acumulado = 0
			_veneno_dps = 0
		else:
			var tiempo := minf(delta, veneno_restante)
			veneno_restante = maxf(0, veneno_restante - tiempo)
			_veneno_acumulado += tiempo
			if _veneno_acumulado >= 0.5 or veneno_restante <= 0:
				var migas := morder(_veneno_dps * _veneno_acumulado)
				_veneno_acumulado = 0
				Juego.sumar_migas_run(migas)
				_run_veneno.efectos.numero(global_position + Vector2(0, -radio), migas, Color("b7d68b"), 0.7)
				if veneno_restante <= 0:
					_veneno_dps = 0
				if muerta:
					return
	_sacudida = move_toward(_sacudida, 0.0, delta * 18.0)
	_destello = maxf(0.0, _destello - delta)
	if _sacudida <= 0.0 and _destello <= 0.0 and veneno_restante <= 0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var desplazamiento := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _sacudida
	draw_set_transform(desplazamiento)
	var c := color.lerp(Color.WHITE, 0.65) if _destello > 0.0 else color
	var oscuro := c.darkened(0.3)
	var r := radio
	# El veneno va antes del atajo del atlas para que se vea en toda la comida.
	if veneno_restante > 0:
		draw_circle(Vector2.ZERO, r + 4, Color(0.57, 0.76, 0.32, 0.2))
		draw_arc(Vector2.ZERO, r + 3, 0, TAU, 32, Color(0.67, 0.85, 0.43, 0.75), 1.5, true)
	if _usar_cache and Graficos.listo and Graficos.regiones.has("comida:" + id):
		Graficos.dibujar(self, "comida:" + id, Vector2.ZERO, Color(1.3, 1.3, 1.3) if _destello > 0 else Color.WHITE)
		_dibujar_dano(desplazamiento)
		return
	# Sombra consistente, también para las formas pequeñas.
	draw_circle(Vector2(1.5, 2.5), r * 0.93, Color(0.18, 0.12, 0.08, 0.14))
	match forma:
		"aro":
			draw_circle(Vector2.ZERO, r, oscuro)
			draw_circle(Vector2(0, -1), r * 0.87, c)
			draw_circle(Vector2.ZERO, r * 0.32, Color("ac9878"))
			draw_arc(Vector2.ZERO, r * 0.64, -2.8, -0.7, 20, c.lightened(0.3), maxf(1.0, r * 0.12), true)
			if r > 12:
				for i in 12:
					var p := Vector2.from_angle(i * TAU / 12) * r * 0.65
					draw_line(p, p + Vector2(2, 2), Color("fff0cf") if i % 2 == 0 else Color("af687b"), 2, true)
		"fideo":
			draw_arc(Vector2.ZERO, r * 0.65, -2.8, 1.8, 24, oscuro, r * 0.65, true)
			draw_arc(Vector2(0, -1), r * 0.65, -2.8, 1.8, 24, c, r * 0.43, true)
		"frutilla":
			draw_colored_polygon(PackedVector2Array([Vector2(-r, -r * 0.3), Vector2(-r * 0.6, -r * 0.8), Vector2(r * 0.65, -r * 0.8), Vector2(r, -r * 0.3), Vector2(0, r)]), c)
			for i in 7:
				var p := Vector2(sin(i * 2.4) * r * 0.48, -r * 0.4 + i * r * 0.17)
				draw_line(p, p + Vector2(0, 2), Color("f6dd9d"), 1.2, true)
			for i in 3:
				var p := Vector2((i - 1) * r * 0.45, -r * 0.9)
				draw_colored_polygon(PackedVector2Array([Vector2(0, -r * 0.6), p - Vector2(3, 4), p + Vector2(3, -3)]), Color("6b9153"))
		"pizza":
			var triangulo := PackedVector2Array([Vector2(-r, -r * 0.75), Vector2(r, 0), Vector2(-r, r * 0.75)])
			draw_colored_polygon(triangulo, Color("bb7850"))
			draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.78, -r * 0.58), Vector2(r * 0.86, 0), Vector2(-r * 0.78, r * 0.58)]), c)
			for p in [Vector2(-0.4, -0.25), Vector2(0.25, 0), Vector2(-0.4, 0.28)]:
				draw_circle(p * r, r * 0.15, Color("b85443"))
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

	_dibujar_dano(desplazamiento)

func _dibujar_dano(desplazamiento: Vector2) -> void:
	var r := radio
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
	if veneno_restante > 0:
		for i in 3:
			var p := Vector2((i - 1) * r * 0.5, -r - 5 - sin(veneno_restante * 4 + i) * 3)
			draw_circle(p, 1.5, Color("b7d68b"))
	draw_set_transform(Vector2.ZERO)
