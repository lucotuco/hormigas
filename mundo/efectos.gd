class_name Efectos
extends Node2D
## Partículas, ondas y números flotantes, todo dibujado desde un solo nodo
## (mucho más barato que crear un nodo por partícula).

const MAX_PARTICULAS := 600
const MAX_TEXTOS := 40
const MAX_ONDAS := 24
const COLOR_SOMBRA_TEXTO := Color(0.12, 0.07, 0.03)


class Particula:
	var pos: Vector2
	var vel: Vector2
	var vida: float
	var vida_max: float
	var color: Color
	var tamano: float


class Onda:
	var pos: Vector2
	var radio_max: float
	var vida: float
	var vida_max: float
	var color: Color


class TextoFlotante:
	var pos: Vector2
	var texto: String
	var color: Color
	var escala: float
	var vida: float
	var vida_max: float
	var ancho := 0.0


var _particulas: Array[Particula] = []
var _ondas: Array[Onda] = []
var _textos: Array[TextoFlotante] = []


## Chispitas rápidas de las mordidas. No generar efectos fuera de cámara.
func chispas(pos: Vector2, color: Color, cantidad: int) -> void:
	if not _en_vista(pos):
		return
	for i in mini(cantidad, MAX_PARTICULAS - _particulas.size()):
		_agregar_particula(pos, Vector2.from_angle(randf() * TAU) * randf_range(30.0, 90.0),
			randf_range(0.2, 0.4), color.lightened(randf_range(0.0, 0.3)), randf_range(1.0, 1.8))


## Explosión al destruir una comida: pedazos + onda expansiva.
func explosion(pos: Vector2, color: Color, radio: float) -> void:
	if not _en_vista(pos, radio * 2.5 + 100):
		return
	var cantidad := int(clampf(radio * 1.8, 10.0, 90.0))
	var fuerza := clampf(radio * 6.0, 60.0, 320.0)
	for i in mini(cantidad, MAX_PARTICULAS - _particulas.size()):
		var dir := Vector2.from_angle(randf() * TAU)
		_agregar_particula(pos + dir * randf() * radio * 0.6, dir * randf_range(0.3, 1.0) * fuerza,
			randf_range(0.45, 0.9), color.lerp(Color.WHITE, randf_range(0.0, 0.35)),
			randf_range(1.2, 2.0) + radio * 0.08)
	if _ondas.size() >= MAX_ONDAS:
		return
	var onda := Onda.new()
	onda.pos = pos
	onda.radio_max = radio * 2.5 + 12.0
	onda.vida_max = 0.35
	onda.vida = onda.vida_max
	onda.color = color.lightened(0.5)
	_ondas.append(onda)


## "+12" flotando hacia arriba.
func numero(pos: Vector2, cantidad: float, color: Color, escala := 1.0) -> void:
	texto(pos, "+" + Juego.formatear_corto(cantidad), color, escala)


func texto(pos: Vector2, contenido: String, color: Color, escala := 1.0) -> void:
	if not _en_vista(pos):
		return
	if _textos.size() >= MAX_TEXTOS:
		_textos.pop_front()
	var t := TextoFlotante.new()
	t.pos = pos
	t.texto = contenido
	t.ancho = ThemeDB.fallback_font.get_string_size(contenido, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	t.color = color
	t.escala = escala
	t.vida_max = 0.9
	t.vida = t.vida_max
	_textos.append(t)


func _agregar_particula(pos: Vector2, vel: Vector2, vida: float, color: Color, tamano: float) -> void:
	if _particulas.size() >= MAX_PARTICULAS:
		return
	var p := Particula.new()
	p.pos = pos
	p.vel = vel
	p.vida = vida
	p.vida_max = vida
	p.color = color
	p.tamano = tamano
	_particulas.append(p)


func _process(delta: float) -> void:
	if _particulas.is_empty() and _ondas.is_empty() and _textos.is_empty():
		return
	var zoom := _zoom()
	var friccion := pow(0.03, delta)
	for i in range(_particulas.size() - 1, -1, -1):
		var p := _particulas[i]
		p.vida -= delta
		if p.vida <= 0.0:
			# El orden no afecta a estos cuadrados; no desplazar hasta 600 referencias.
			_particulas[i] = _particulas.back()
			_particulas.pop_back()
			continue
		p.pos += p.vel * delta
		p.vel *= friccion
	for i in range(_ondas.size() - 1, -1, -1):
		_ondas[i].vida -= delta
		if _ondas[i].vida <= 0.0:
			_ondas.remove_at(i)
	for i in range(_textos.size() - 1, -1, -1):
		var t := _textos[i]
		t.vida -= delta
		if t.vida <= 0.0:
			_textos.remove_at(i)
			continue
		t.pos.y -= 38.0 / zoom * delta
	queue_redraw()


func _draw() -> void:
	var zoom := _zoom()
	var escala_minima := maxf(1.0, 0.8 / zoom)
	for p in _particulas:
		var alfa := clampf(p.vida / p.vida_max * 1.5, 0.0, 1.0)
		var lado := p.tamano * escala_minima
		draw_rect(Rect2(p.pos - Vector2.ONE * lado * 0.5, Vector2.ONE * lado), Color(p.color, alfa))
	for o in _ondas:
		var progreso := 1.0 - o.vida / o.vida_max
		draw_arc(o.pos, o.radio_max * ease(progreso, 0.4), 0, TAU, 40,
			Color(o.color, 0.8 * (1.0 - progreso)), 3.0 / zoom, true)
	var fuente := ThemeDB.fallback_font
	for t in _textos:
		var progreso := 1.0 - t.vida / t.vida_max
		var pop := 1.0 + 0.5 * maxf(0.0, 1.0 - progreso * 6.0)   # aparece grande y se acomoda
		# Tamaño fijo de fuente: no rasterizar cientos de glifos nuevos al hacer zoom.
		var tamano_fuente := 18
		var escala := 15.0 * t.escala * pop / (zoom * tamano_fuente)
		draw_set_transform(t.pos, 0, Vector2.ONE * escala)
		var alfa := clampf(t.vida / (t.vida_max * 0.4), 0.0, 1.0)
		var origen := -Vector2(t.ancho * 0.5, 0.0)
		draw_string_outline(fuente, origen, t.texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_fuente,
			maxi(2, int(tamano_fuente / 4.0)), Color(COLOR_SOMBRA_TEXTO, alfa))
		draw_string(fuente, origen, t.texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_fuente, Color(t.color, alfa))
	draw_set_transform(Vector2.ZERO)


func _zoom() -> float:
	return maxf(get_viewport().get_canvas_transform().get_scale().x, 0.01)


func _en_vista(pos: Vector2, margen_mundo := 100.0) -> bool:
	var transformacion := get_canvas_transform()
	return get_viewport_rect().grow(80 + margen_mundo * transformacion.get_scale().x).has_point(transformacion * pos)
