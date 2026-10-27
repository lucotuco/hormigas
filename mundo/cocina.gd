class_name Cocina
extends Node2D
## Casa completa. Dos mapas compartidos: suelo y vuelo (las paredes son sólidas).
const MARGEN := 8.0
const CELDA := 32.0
var _suelo := AStarGrid2D.new()
var _aire := AStarGrid2D.new()
var _libres_suelo: Dictionary = {}
var _libres_aire: Dictionary = {}
var _radio_grafo := -1.0
var _preparada := false
var _cache: Dictionary = {}
var _fallidas: Dictionary = {}
var _destinos: Dictionary = {}
var version := 0
var piezas: Array[Dictionary] = []
var _obstaculos: Dictionary = {}
var _sectores: Dictionary = {}
var _celdas_preparadas: Dictionary = {}
var _cambios: Dictionary = {}
const SECTOR := 256.0
## Se reparten los pedidos, no se limita la cantidad de hormigas simuladas.
var limite_rutas_por_cuadro := 6
const PRESUPUESTO_RUTAS_USEC := 2000
var _cuadro_rutas := -1
var _pedidos_cuadro := 0
var _tiempo_rutas_cuadro := 0
var _cola_rutas: Array[Dictionary] = []
var _en_cola: Dictionary = {}
var _inicio_cola := 0
var _secuencia_ruta := 0
var _prioritarias_cuadro := 0
var consultas_ruta := 0
var busquedas_astar := 0
var aciertos_cache := 0

func _ready() -> void:
	piezas = MaterialesCasa.piezas()
	for pieza in piezas:
		_obstaculos[pieza.clave] = pieza
		var r: Rect2 = pieza.rect
		for x in range(floori(r.position.x / SECTOR), floori(r.end.x / SECTOR) + 1):
			for y in range(floori(r.position.y / SECTOR), floori(r.end.y / SECTOR) + 1):
				var celda := Vector2i(x, y)
				if not _sectores.has(celda):
					_sectores[celda] = []
				_sectores[celda].append(pieza.clave)

func _cercanos(rect: Rect2, volando: bool) -> Array[Rect2]:
	var resultado: Array[Rect2] = []
	var vistos: Dictionary = {}
	var a := Vector2i((rect.position / SECTOR).floor())
	var b := Vector2i((rect.end / SECTOR).floor())
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			for clave in _sectores.get(Vector2i(x, y), []):
				if vistos.has(clave) or not _obstaculos.has(clave):
					continue
				vistos[clave] = true
				var pieza: Dictionary = _obstaculos[clave]
				if not volando or pieza.pared:
					if pieza.has("recortes"):
						for recorte in pieza.recortes:
							if recorte.intersects(rect, true):
								resultado.append(recorte)
					else:
						if pieza.rect.intersects(rect, true):
							resultado.append(pieza.rect)
	return resultado

func quitar_pieza(clave: String) -> void:
	if not _obstaculos.has(clave):
		return
	var rect: Rect2 = _obstaculos[clave].rect
	_obstaculos.erase(clave)
	_encolar_cambio(rect)

func recortar_pieza(clave: String, rects: Array[Rect2], zona := Rect2()) -> void:
	if not _obstaculos.has(clave):
		return
	_obstaculos[clave].recortes = rects
	_encolar_cambio(zona if zona.has_area() else _obstaculos[clave].rect)

func _encolar_cambio(rect: Rect2) -> void:
	version += 1
	# Sólo se quitan obstáculos: una ruta positiva anterior sigue siendo segura.
	# Las negativas sí pueden cambiar al abrir una puerta o romper una silla.
	_fallidas.clear()
	_destinos.clear()
	if not _preparada:
		return
	# Sólo las celdas afectadas; no reconstruir toda la casa por cada silla.
	var r := rect.grow(CELDA * 2)
	for x in range(floori(r.position.x / CELDA), ceili(r.end.x / CELDA) + 1):
		for y in range(floori(r.position.y / CELDA), ceili(r.end.y / CELDA) + 1):
			var id := Vector2i(x, y)
			if not _suelo.is_in_boundsv(id):
				continue
			_cambios[id] = true

func _process(_delta: float) -> void:
	procesar_cambios()

func procesar_cambios(presupuesto := 384) -> void:
	if _cambios.is_empty():
		return
	_fallidas.clear()
	for id in _cambios.keys():
		var pos := _suelo.get_point_position(id)
		for volando in [false, true]:
			var grid := _aire if volando else _suelo
			var libres := _libres_aire if volando else _libres_suelo
			var transitable := libre(pos, MARGEN + CELDA * 0.71, volando)
			if transitable:
				libres[id] = true
			else:
				libres.erase(id)
			grid.set_point_solid(id, not transitable or pos.length() > _radio_grafo - 8)
		_cambios.erase(id)
		presupuesto -= 1
		if presupuesto <= 0:
			break


func libre(pos: Vector2, margen := 0.0, volando := false) -> bool:
	if not PlanoCasa.limites().grow(-50 - margen).has_point(pos):
		return false
	# Consulta puntual sin construir listas ni diccionarios temporales.
	var a := Vector2i(((pos - Vector2.ONE * margen) / SECTOR).floor())
	var b := Vector2i(((pos + Vector2.ONE * margen) / SECTOR).floor())
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			for clave in _sectores.get(Vector2i(x, y), []):
				if not _obstaculos.has(clave):
					continue
				var pieza: Dictionary = _obstaculos[clave]
				if volando and not pieza.pared:
					continue
				if pieza.has("recortes"):
					for rect in pieza.recortes:
						if rect.grow(margen).has_point(pos):
							return false
				elif pieza.rect.grow(margen).has_point(pos):
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
	var area := Rect2(a.min(b), (b - a).abs()).grow(MARGEN)
	for rect in _cercanos(area, volando):
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
	var limites := PlanoCasa.limites()
	var origen := Vector2i(floori(limites.position.x / CELDA), floori(limites.position.y / CELDA))
	var fin := Vector2i(ceili(limites.end.x / CELDA), ceili(limites.end.y / CELDA))
	for grid in [_suelo, _aire]:
		grid.region = Rect2i(origen, fin - origen)
		grid.cell_size = Vector2.ONE * CELDA
		grid.offset = Vector2.ONE * CELDA * 0.5
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.update()
		grid.fill_solid_region(grid.region, true)


func _actualizar_radio(radio: float) -> void:
	_preparar()
	if absf(radio - _radio_grafo) < 20:
		return
	var previo := pow(maxf(0, _radio_grafo - 8), 2) if _radio_grafo > 0 else -1.0
	var decrecio := radio < _radio_grafo
	_radio_grafo = radio
	_cache.clear()
	_fallidas.clear()
	_destinos.clear()
	var limite := pow(maxf(1, radio - 8), 2)
	if decrecio:
		for id in _libres_suelo:
			_suelo.set_point_solid(id, _suelo.get_point_position(id).length_squared() > limite)
		for id in _libres_aire:
			_aire.set_point_solid(id, _aire.get_point_position(id).length_squared() > limite)
		return
	# Procesar sólo el territorio nuevo, no 45.000 celdas por cada expansión.
	var zona := Rect2(-radio, -radio, radio * 2, radio * 2).intersection(PlanoCasa.limites())
	for x in range(floori(zona.position.x / CELDA), ceili(zona.end.x / CELDA)):
		for y in range(floori(zona.position.y / CELDA), ceili(zona.end.y / CELDA)):
			var id := Vector2i(x, y)
			if not _suelo.is_in_boundsv(id):
				continue
			var pos := _suelo.get_point_position(id)
			var d := pos.length_squared()
			if d > limite or d <= previo:
				continue
			if not _celdas_preparadas.has(id):
				_celdas_preparadas[id] = true
				if libre(pos, MARGEN + CELDA * 0.71):
					_libres_suelo[id] = true
				if libre(pos, MARGEN + CELDA * 0.71, true):
					_libres_aire[id] = true
			_suelo.set_point_solid(id, not _libres_suelo.has(id))
			_aire.set_point_solid(id, not _libres_aire.has(id))


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


func _reiniciar_presupuesto() -> void:
	var cuadro := Engine.get_process_frames()
	if cuadro != _cuadro_rutas:
		_cuadro_rutas = cuadro
		_pedidos_cuadro = 0
		_tiempo_rutas_cuadro = 0
		_prioritarias_cuadro = 0


func admitir_ruta(hormiga: Hormiga = null) -> bool:
	_reiniciar_presupuesto()
	if hormiga != null:
		hormiga._esperando_ruta = true
		var id := hormiga.get_instance_id()
		if not _en_cola.has(id):
			_secuencia_ruta += 1
			_en_cola[id] = _secuencia_ruta
			_cola_rutas.append({"hormiga": hormiga, "id": id, "ticket": _secuencia_ruta})
		# Las que ya llegaron, están mordiendo o terminaron no retienen el turno.
		while _inicio_cola < _cola_rutas.size():
			var pedido := _cola_rutas[_inicio_cola]
			var primera = pedido.hormiga
			var vigente: bool = _en_cola.get(pedido.id, -1) == pedido.ticket
			if vigente and is_instance_valid(primera) and primera._esperando_ruta and primera.estado != Hormiga.Estado.MORDIENDO and primera.estado != Hormiga.Estado.QUIETA:
				break
			if vigente:
				_en_cola.erase(pedido.id)
			_inicio_cola += 1
		if _inicio_cola >= 256:
			_cola_rutas = _cola_rutas.slice(_inicio_cola)
			_inicio_cola = 0
		# Hasta dos turnos prioritarios para responder al jugador y descargar.
		# El resto sigue FIFO: la exploración tampoco queda sin servicio.
		var prioritaria := _prioritarias_cuadro < 2 and (hormiga.estado == Hormiga.Estado.SIGUIENDO or hormiga.estado == Hormiga.Estado.VOLVIENDO)
		if not prioritaria and (_inicio_cola >= _cola_rutas.size() or _cola_rutas[_inicio_cola].hormiga != hormiga):
			return false
	if limite_rutas_por_cuadro > 0 and (_pedidos_cuadro >= limite_rutas_por_cuadro or _tiempo_rutas_cuadro >= PRESUPUESTO_RUTAS_USEC):
		return false
	if hormiga != null:
		_en_cola.erase(hormiga.get_instance_id())
		if _inicio_cola < _cola_rutas.size() and _cola_rutas[_inicio_cola].hormiga == hormiga:
			_inicio_cola += 1
		if hormiga.estado == Hormiga.Estado.SIGUIENDO or hormiga.estado == Hormiga.Estado.VOLVIENDO:
			_prioritarias_cuadro += 1
		hormiga._esperando_ruta = false
	_pedidos_cuadro += 1
	return true


func ruta(desde: Vector2, hasta: Vector2, radio: float, volando := false) -> PackedVector2Array:
	_reiniciar_presupuesto()
	consultas_ruta += 1
	var inicio := Time.get_ticks_usec()
	var resultado := _resolver_ruta(desde, hasta, radio, volando)
	_tiempo_rutas_cuadro += Time.get_ticks_usec() - inicio
	return resultado


func _resolver_ruta(desde: Vector2, hasta: Vector2, radio: float, volando: bool) -> PackedVector2Array:
	hasta = ajustar_destino(hasta, radio, volando)
	if hasta == Vector2.INF:
		return PackedVector2Array()
	if segmento_libre(desde, hasta, volando):
		return PackedVector2Array([hasta])
	_actualizar_radio(radio)
	procesar_cambios(32)
	var grid := _aire if volando else _suelo
	var a := _celda_cercana(desde, grid, volando)
	var b := _celda_cercana(hasta, grid, volando)
	if a.x == 100000 or b.x == 100000:
		return PackedVector2Array()
	var clave := "%s:%s:%s" % [a, b, volando]
	if _fallidas.has(clave):
		aciertos_cache += 1
		return PackedVector2Array()
	var base: PackedVector2Array
	if _cache.has(clave):
		aciertos_cache += 1
		base = _cache[clave]
	else:
		busquedas_astar += 1
		base = _solo_giros(grid.get_point_path(a, b))
		if base.is_empty():
			if _fallidas.size() >= 512:
				_fallidas.clear()
			_fallidas[clave] = true
			return base
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
		# Antes se probaba contra el final de la ruta por cada celda: cuadrático
		# en recorridos largos. Giros comprimidos + hasta ocho pruebas por tramo.
		var siguiente := mini(actual + 8, puntos.size() - 1)
		while siguiente > actual + 1 and not segmento_libre(puntos[actual], puntos[siguiente], volando):
			siguiente -= 1
		resultado.append(puntos[siguiente])
		actual = siguiente
	return resultado


func _solo_giros(puntos: PackedVector2Array) -> PackedVector2Array:
	if puntos.size() < 3:
		return puntos
	var resultado := PackedVector2Array([puntos[0]])
	var direccion := (puntos[1] - puntos[0]).sign()
	for i in range(2, puntos.size()):
		var siguiente := (puntos[i] - puntos[i - 1]).sign()
		if siguiente != direccion:
			resultado.append(puntos[i - 1])
			direccion = siguiente
	resultado.append(puntos[puntos.size() - 1])
	return resultado


func _draw() -> void:
	DibujoCasa.dibujar(self, false)
