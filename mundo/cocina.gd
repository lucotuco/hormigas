class_name Cocina
extends Node2D
## Casa completa. Dos mapas compartidos: suelo y vuelo (las paredes son sólidas).
const MARGEN := 8.0
const CELDA := 32.0
var _suelo := AStarGrid2D.new()
var _aire := AStarGrid2D.new()
var _libres_suelo: Array[Vector2i] = []
var _libres_aire: Array[Vector2i] = []
var _radio_grafo := -1.0
var _preparada := false
var _cache: Dictionary = {}
var _destinos: Dictionary = {}


func libre(pos: Vector2, margen := 0.0, volando := false) -> bool:
	if not PlanoCasa.LIMITES.grow(-50 - margen).has_point(pos):
		return false
	for pared in PlanoCasa.PAREDES:
		if pared.grow(margen).has_point(pos):
			return false
	if not volando:
		for m in PlanoCasa.MUEBLES:
			var rect: Rect2 = m.rect
			if rect.grow(margen).has_point(pos):
				return false
	return true


func _corta_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var minimo := 0.0
	var maximo := 1.0
	var direccion := b - a
	for eje in 2:
		if absf(direccion[eje]) < 0.00001:
			if a[eje] < rect.position[eje] or a[eje] > rect.end[eje]:
				return false
		else:
			var t1: float = (rect.position[eje] - a[eje]) / direccion[eje]
			var t2: float = (rect.end[eje] - a[eje]) / direccion[eje]
			minimo = maxf(minimo, minf(t1, t2))
			maximo = minf(maximo, maxf(t1, t2))
			if minimo > maximo:
				return false
	return true


func segmento_libre(a: Vector2, b: Vector2, volando := false) -> bool:
	if not libre(a, MARGEN, volando) or not libre(b, MARGEN, volando):
		return false
	for pared in PlanoCasa.PAREDES:
		if _corta_rect(a, b, pared.grow(MARGEN)):
			return false
	if not volando:
		for m in PlanoCasa.MUEBLES:
			var rect: Rect2 = m.rect
			if _corta_rect(a, b, rect.grow(MARGEN)):
				return false
	return true


func ajustar_destino(pos: Vector2, radio: float, volando := false) -> Vector2:
	pos = pos.limit_length(maxf(1, radio - 6))
	if libre(pos, MARGEN, volando):
		return pos
	var clave := "%s:%s:%s" % [Vector2i(pos / 8), int(radio / 20), volando]
	if _destinos.has(clave):
		return _destinos[clave]
	# Acercarse al borde de un mueble o pared, sin quedarse empujándolo.
	var mejor := Vector2.INF
	var distancia := INF
	for anillo in range(1, 51):
		for i in 24:
			var p := pos + Vector2.from_angle(TAU * i / 24) * anillo * 16
			if p.length() < radio - 6 and libre(p, MARGEN, volando):
				var d := p.distance_squared_to(pos)
				if d < distancia:
					mejor = p
					distancia = d
		if mejor != Vector2.INF:
			if _destinos.size() > 512:
				_destinos.clear()
			_destinos[clave] = mejor
			return mejor
	_destinos[clave] = Vector2.INF
	return Vector2.INF


func _preparar() -> void:
	if _preparada:
		return
	_preparada = true
	var origen := Vector2i(floori(PlanoCasa.LIMITES.position.x / CELDA), floori(PlanoCasa.LIMITES.position.y / CELDA))
	var fin := Vector2i(ceili(PlanoCasa.LIMITES.end.x / CELDA), ceili(PlanoCasa.LIMITES.end.y / CELDA))
	for grid in [_suelo, _aire]:
		grid.region = Rect2i(origen, fin - origen)
		grid.cell_size = Vector2.ONE * CELDA
		grid.offset = Vector2.ONE * CELDA * 0.5
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.update()
	for x in range(origen.x, fin.x):
		for y in range(origen.y, fin.y):
			var id := Vector2i(x, y)
			var pos := (Vector2(id) + Vector2.ONE * 0.5) * CELDA
			if libre(pos, MARGEN + CELDA * 0.71):
				_libres_suelo.append(id)
			if libre(pos, MARGEN + CELDA * 0.71, true):
				_libres_aire.append(id)
			_suelo.set_point_solid(id, true)
			_aire.set_point_solid(id, true)


func _actualizar_radio(radio: float) -> void:
	_preparar()
	if absf(radio - _radio_grafo) < 20:
		return
	_radio_grafo = radio
	_cache.clear()
	var limite := pow(maxf(1, radio - 8), 2)
	for id in _libres_suelo:
		_suelo.set_point_solid(id, _suelo.get_point_position(id).length_squared() > limite)
	for id in _libres_aire:
		_aire.set_point_solid(id, _aire.get_point_position(id).length_squared() > limite)


func _celda_cercana(pos: Vector2, grid: AStarGrid2D, volando: bool) -> Vector2i:
	var centro := Vector2i(floori(pos.x / CELDA), floori(pos.y / CELDA))
	var mejor := Vector2i(100000, 100000)
	var distancia := INF
	for anillo in range(0, 5):
		for x in range(-anillo, anillo + 1):
			for y in range(-anillo, anillo + 1):
				if anillo > 0 and absi(x) != anillo and absi(y) != anillo:
					continue
				var id := centro + Vector2i(x, y)
				if not grid.is_in_boundsv(id) or grid.is_point_solid(id):
					continue
				var p := grid.get_point_position(id)
				var d := p.distance_squared_to(pos)
				if d < distancia and segmento_libre(pos, p, volando):
					mejor = id
					distancia = d
		if mejor.x != 100000:
			return mejor
	return mejor


func ruta(desde: Vector2, hasta: Vector2, radio: float, volando := false) -> PackedVector2Array:
	hasta = ajustar_destino(hasta, radio, volando)
	if hasta == Vector2.INF:
		return PackedVector2Array()
	if segmento_libre(desde, hasta, volando):
		return PackedVector2Array([hasta])
	_actualizar_radio(radio)
	var grid := _aire if volando else _suelo
	var a := _celda_cercana(desde, grid, volando)
	var b := _celda_cercana(hasta, grid, volando)
	if a.x == 100000 or b.x == 100000:
		return PackedVector2Array()
	var clave := "%s:%s:%s" % [a, b, volando]
	var base: PackedVector2Array
	if _cache.has(clave):
		base = _cache[clave]
	else:
		base = grid.get_point_path(a, b)
		if _cache.size() > 2048:
			_cache.clear()
		_cache[clave] = base
	if base.is_empty():
		return PackedVector2Array()
	var puntos := PackedVector2Array([desde])
	puntos.append_array(base)
	puntos.append(hasta)
	var resultado := PackedVector2Array()
	var actual := 0
	while actual < puntos.size() - 1:
		var siguiente := puntos.size() - 1
		while siguiente > actual + 1 and not segmento_libre(puntos[actual], puntos[siguiente], volando):
			siguiente -= 1
		resultado.append(puntos[siguiente])
		actual = siguiente
	return resultado


func _draw() -> void:
	DibujoCasa.dibujar(self)
