class_name Efectos
extends Node2D
## Partículas, ondas y números flotantes, todo dibujado desde un solo nodo
## (mucho más barato que crear un nodo por partícula).

const MAX_PARTICULAS := 600
const MAX_TEXTOS := 40
const MAX_TEXTOS_VISIBLES := 10
const MAX_ONDAS := 24
const COLOR_SOMBRA_TEXTO := Color(0.12, 0.07, 0.03)


class Particula:
	var pos: Vector2
	var vel: Vector2
	var vida: float
	var vida_max: float
	var color: Color
	var tamano: float
	var material_id := -1


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
	var cantidad := 0.0
	var origen := Vector2.INF


var _particulas: Array[Particula] = []
var _libres: Array[Particula] = []
var _ondas: Array[Onda] = []
var _ondas_libres: Array[Onda] = []
var _textos: Array[TextoFlotante] = []
var _rect_textos: Array[Rect2] = []
var _marcas: Array[Dictionary] = []
const MAX_MARCAS := 16
var _pausa_marca := 0.0
var _pausa_entrega := 0.0
var _pausa_epico := 0.0
var _cerrado := false
var _azar := RandomNumberGenerator.new()


func _ready() -> void:
	_azar.seed = 41731 # El feedback no consume el azar de enemigos/IA.
	set_process(false)


## Una entrega ya cobrada: pequeño pulso hacia la entrada, no otra moneda.
## El gate global evita una ráfaga por cada una de las quinientas hormigas.
func entrega(pos: Vector2, cantidad: float, combo := 0, material_id := -1) -> void:
	if _cerrado or cantidad <= 0.0 or _pausa_entrega > 0.0 or not _en_vista(pos):
		return
	_pausa_entrega = 0.10
	var tinta := Color("f0d18c") if material_id < 1 else Color("c8b17d")
	var cantidad_particulas := 4 + mini(4, maxi(0, combo) / 8)
	for i in mini(cantidad_particulas, MAX_PARTICULAS - _particulas.size()):
		var direccion := Vector2.from_angle(TAU * i / cantidad_particulas + _azar.randf_range(-0.1, 0.1))
		_agregar_particula(pos + direccion * 12.0, -direccion * _azar.randf_range(15.0, 25.0),
			0.28, tinta, _azar.randf_range(1.4, 2.0))
	_agregar_onda(pos, 18.0, 0.22, tinta)
	_despertar()


## Sólo se llama por una victoria/hito REAL. Una ráfaga, máximo dos ondas,
## sin emisores ni nodos por fragmento ni cadenas de timers/tweens.
func epico(pos: Vector2, color: Color, radio := 70.0) -> void:
	if _cerrado or _pausa_epico > 0.0 or not _en_vista(pos, radio + 100.0):
		return
	_pausa_epico = 0.75
	var alcance := clampf(radio, 24.0, 160.0)
	for i in mini(36, MAX_PARTICULAS - _particulas.size()):
		var direccion := Vector2.from_angle(i * TAU / 36.0 + _azar.randf_range(-0.04, 0.04))
		_agregar_particula(pos + direccion * alcance * 0.12,
			direccion * _azar.randf_range(55.0, 160.0), _azar.randf_range(0.5, 0.85),
			color.lerp(Color("fff0bf"), _azar.randf() * 0.6), _azar.randf_range(1.8, 3.4))
	_agregar_onda(pos, alcance, 0.5, color)
	_agregar_onda(pos, alcance * 0.68, 0.7, color.lightened(0.3))
	_despertar()


func _despertar() -> void:
	set_process(true)
	queue_redraw()


## Terminal por instancia: callbacks tardíos no reviven la run abandonada.
func limpiar() -> void:
	_cerrado = true
	for p in _particulas:
		_libres.append(p)
	_particulas.clear()
	for o in _ondas:
		_ondas_libres.append(o)
	_ondas.clear()
	_textos.clear()
	_marcas.clear()
	_rect_textos.clear()
	_pausa_marca = 0.0
	_pausa_entrega = 0.0
	_pausa_epico = 0.0
	set_process(false)
	queue_redraw()

## Una señal breve por habilidad, con límite global; no un emisor por hormiga.
func habilidad(desde: Vector2, hasta: Vector2, color: Color) -> void:
	if _cerrado or _pausa_marca > 0 or _marcas.size() >= MAX_MARCAS or not _en_vista(desde):
		return
	_pausa_marca = 0.08
	_marcas.append({"a": desde, "b": hasta, "color": color, "vida": 0.35})
	_despertar()


## Chispitas rápidas de las mordidas. No generar efectos fuera de cámara.
func chispas(pos: Vector2, color: Color, cantidad: int, material_id := -1) -> void:
	if _cerrado or not _en_vista(pos):
		return
	for i in mini(cantidad, MAX_PARTICULAS - _particulas.size()):
		_agregar_particula(pos, Vector2.from_angle(_azar.randf() * TAU) * _azar.randf_range(30.0, 90.0),
			_azar.randf_range(0.2, 0.4), color.lightened(_azar.randf_range(0.0, 0.3)), _azar.randf_range(1.0, 1.8))
		_particulas.back().material_id = material_id
	_despertar()


## Explosión al destruir una comida: pedazos + onda expansiva.
func explosion(pos: Vector2, color: Color, radio: float) -> void:
	if _cerrado or not _en_vista(pos, radio * 2.5 + 100):
		return
	var cantidad := int(clampf(radio * 1.8, 10.0, 90.0))
	var fuerza := clampf(radio * 6.0, 60.0, 320.0)
	for i in mini(cantidad, MAX_PARTICULAS - _particulas.size()):
		var dir := Vector2.from_angle(_azar.randf() * TAU)
		_agregar_particula(pos + dir * _azar.randf() * radio * 0.6, dir * _azar.randf_range(0.3, 1.0) * fuerza,
			_azar.randf_range(0.45, 0.9), color.lerp(Color.WHITE, _azar.randf_range(0.0, 0.35)),
			_azar.randf_range(1.2, 2.0) + minf(radio * 0.08, 5.0))
	_agregar_onda(pos, radio * 2.5 + 12.0, 0.35, color.lightened(0.5))
	_despertar()


func _agregar_onda(pos: Vector2, radio: float, vida: float, color: Color) -> void:
	if _ondas.size() >= MAX_ONDAS:
		return
	var onda: Onda = _ondas_libres.pop_back() if not _ondas_libres.is_empty() else Onda.new()
	onda.pos = pos
	onda.radio_max = radio
	onda.vida_max = vida
	onda.vida = vida
	onda.color = color
	_ondas.append(onda)


## "+12" flotando hacia arriba.
func numero(pos: Vector2, cantidad: float, color: Color, escala := 1.0) -> void:
	if _cerrado or cantidad <= 0 or not _en_vista(pos):
		return
	# Agrupar durante una ventana fija: el texto termina aunque siga habiendo
	# depósitos. Se suman los valores, no se descartan ingresos visuales.
	var radio_agrupacion := maxf(96, 65.0 / _zoom())
	for t in _textos:
		if t.cantidad > 0 and t.vida > 0.55 and t.origen.distance_squared_to(pos) < radio_agrupacion * radio_agrupacion and t.color == color:
			t.cantidad += cantidad
			t.texto = "+" + Juego.formatear_corto(t.cantidad)
			t.ancho = ThemeDB.fallback_font.get_string_size(t.texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			return
	texto(pos, "+" + Juego.formatear_corto(cantidad), color, escala)
	_textos.back().cantidad = cantidad
	_textos.back().origen = pos


func texto(pos: Vector2, contenido: String, color: Color, escala := 1.0) -> void:
	if _cerrado or not _en_vista(pos):
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
	_despertar()


func _agregar_particula(pos: Vector2, vel: Vector2, vida: float, color: Color, tamano: float) -> void:
	if _particulas.size() >= MAX_PARTICULAS:
		return
	var p: Particula = _libres.pop_back() if not _libres.is_empty() else Particula.new()
	p.pos = pos
	p.vel = vel
	p.vida = vida
	p.vida_max = vida
	p.color = color
	p.tamano = tamano
	p.material_id = -1
	_particulas.append(p)


func _process(delta: float) -> void:
	_pausa_marca = maxf(0, _pausa_marca - delta)
	_pausa_entrega = maxf(0, _pausa_entrega - delta)
	_pausa_epico = maxf(0, _pausa_epico - delta)
	if _particulas.is_empty() and _ondas.is_empty() and _textos.is_empty() and _marcas.is_empty():
		if maxf(_pausa_marca, maxf(_pausa_entrega, _pausa_epico)) <= 0.0:
			set_process(false)
		queue_redraw()
		return
	for i in range(_marcas.size() - 1, -1, -1):
		_marcas[i].vida -= delta
		if _marcas[i].vida <= 0:
			_marcas.remove_at(i)
	var zoom := _zoom()
	var friccion := pow(0.03, delta)
	for i in range(_particulas.size() - 1, -1, -1):
		var p := _particulas[i]
		p.vida -= delta
		if p.vida <= 0.0:
			# El orden no afecta a estos cuadrados; no desplazar hasta 600 referencias.
			_particulas[i] = _particulas.back()
			_particulas.pop_back()
			_libres.append(p)
			continue
		p.pos += p.vel * delta
		p.vel *= friccion
	for i in range(_ondas.size() - 1, -1, -1):
		_ondas[i].vida -= delta
		if _ondas[i].vida <= 0.0:
			_ondas_libres.append(_ondas[i])
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
		if p.material_id == 1:
			draw_line(p.pos, p.pos + p.vel.normalized() * lado * 4, Color(p.color, alfa), lado)
		else:
			draw_rect(Rect2(p.pos - Vector2.ONE * lado * 0.5, Vector2.ONE * lado), Color(p.color, alfa))
	for marca in _marcas:
		draw_line(marca.a, marca.b, Color(marca.color, marca.vida / 0.35), 3 / zoom, true)
	for o in _ondas:
		var progreso := 1.0 - o.vida / o.vida_max
		draw_arc(o.pos, o.radio_max * ease(progreso, 0.4), 0, TAU, 40,
			Color(o.color, 0.8 * (1.0 - progreso)), 3.0 / zoom, true)
	var fuente := ThemeDB.fallback_font
	_rect_textos.clear()
	var transformacion := get_canvas_transform()
	var presupuesto := 6 if zoom < 0.25 else MAX_TEXTOS_VISIBLES
	# Priorizar los últimos ingresos y no tapar el mapa con nombres repetidos.
	for i in range(_textos.size() - 1, -1, -1):
		if _rect_textos.size() >= presupuesto:
			break
		var t := _textos[i]
		if t.cantidad > 0 and t.cantidad < 0.5:
			continue # Se sigue acumulando; no mostrar un premio redondeado a «+0».
		if zoom < 0.25 and t.cantidad <= 0:
			continue
		var progreso := 1.0 - t.vida / t.vida_max
		var pop := 1.0 + 0.12 * maxf(0.0, 1.0 - progreso * 6.0)
		# Tamaño fijo de fuente: no rasterizar cientos de glifos nuevos al hacer zoom.
		var tamano_fuente := 18
		var escala_pantalla := (13.0 if zoom < 0.25 else 15.0) * clampf(t.escala, 0.8, 1.25) * pop / tamano_fuente
		var posicion_pantalla := transformacion * t.pos
		var rect := Rect2(posicion_pantalla - Vector2(t.ancho * escala_pantalla * 0.5, 18 * escala_pantalla), Vector2(t.ancho + 8, 24) * escala_pantalla)
		if not get_viewport_rect().intersects(rect):
			continue
		var solapado := false
		for ocupado in _rect_textos:
			if rect.intersects(ocupado):
				solapado = true
				break
		if solapado:
			continue
		_rect_textos.append(rect)
		var escala := escala_pantalla / zoom
		draw_set_transform(t.pos, 0, Vector2.ONE * escala)
		var alfa := clampf(t.vida / (t.vida_max * 0.4), 0.0, 1.0)
		var origen := -Vector2(t.ancho * 0.5, 0.0)
		draw_string_outline(fuente, origen, t.texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_fuente,
			2, Color(COLOR_SOMBRA_TEXTO, alfa))
		draw_string(fuente, origen, t.texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_fuente, Color(t.color, alfa))
	draw_set_transform(Vector2.ZERO)


func _zoom() -> float:
	return maxf(get_viewport().get_canvas_transform().get_scale().x, 0.01)


func _en_vista(pos: Vector2, margen_mundo := 100.0) -> bool:
	var transformacion := get_canvas_transform()
	return get_viewport_rect().grow(80 + margen_mundo * transformacion.get_scale().x).has_point(transformacion * pos)
