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
## Puentes locales entre un puesto fino y la rejilla compartida. Sólo se
## guardan enlaces positivos de coordenadas exactas, nunca negativos por zona.
var _enlaces_celda: Dictionary = {}
var _radio_enlaces := -1.0
const MAX_CACHE_ENLACES := 128
const MAX_OBSTACULOS_ENLACE := 4
const MAX_VERTICES_ENLACE := 16
const MAX_PRUEBAS_ENLACE := 32
const MAX_PRUEBAS_ANCLA := 4
var version := 0
var piezas: Array[Dictionary] = []
var _obstaculos: Dictionary = {}
var _sectores: Dictionary = {}
var _celdas_preparadas: Dictionary = {}
var _cambios: Dictionary = {}
const SECTOR := 256.0
## Se reparten los pedidos, no se limita la cantidad de hormigas simuladas.
var limite_rutas_por_cuadro := 6
const PRESUPUESTO_RUTAS_USEC := 1200
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
var consultas_enlace := 0
var aciertos_cache_enlace := 0
var pruebas_enlace_max := 0
var _consulta_ocupacion := 0

func _ready() -> void:
	# Las alfombras conservan el detalle cercano sin vibrar en la vista del mapa.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	piezas = MaterialesCasa.piezas()
	for pieza in piezas:
		# La navegación usa el material visible, no el margen transparente del
		# sprite. Los perfiles son compartidos y se preparan una sola vez.
		var formas := SiluetaMueble.rectangulos(pieza)
		if pieza.has("componentes_id"):
			formas = ComponentesProyecto.formas_restantes(pieza, formas, Juego.componentes_proyecto_devorados)
		if formas.size() != 1 or formas[0] != pieza.rect:
			pieza.recortes = formas
		_cachear_limite_recortes(pieza)
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
						if pieza.recortes.is_empty():
							continue
						if pieza.has("_limite_recortes"):
							var limite: Rect2 = pieza._limite_recortes
							if not limite.intersects(rect, true):
								continue
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


func registrar_material_vivo(clave: String, material: MordiscosMaterial) -> void:
	if _obstaculos.has(clave) and material != null and material.configuracion_lista:
		_obstaculos[clave].material_vivo = material

func recortar_pieza(clave: String, rects: Array[Rect2], zona := Rect2()) -> void:
	if not _obstaculos.has(clave):
		return
	_obstaculos[clave].recortes = rects
	_cachear_limite_recortes(_obstaculos[clave])
	_encolar_cambio(zona if zona.has_area() else _obstaculos[clave].rect)


func _cachear_limite_recortes(pieza: Dictionary) -> void:
	if not pieza.has("recortes"):
		pieza.erase("_limite_recortes")
		return
	var recortes: Array = pieza.recortes
	var limite := Rect2()
	if not recortes.is_empty():
		limite = recortes[0]
		for i in range(1, recortes.size()):
			limite = limite.merge(recortes[i])
	# El caché vive con este descriptor; reemplazarlo por un fixture sin el
	# campo conserva el recorrido anterior y no reutiliza límites de otra pieza.
	pieza._limite_recortes = limite


func _encolar_cambio(rect: Rect2) -> void:
	version += 1
	# Sólo se quitan obstáculos: una ruta positiva anterior sigue siendo segura.
	# Las negativas sí pueden cambiar al abrir una puerta o romper una silla.
	_fallidas.clear()
	_destinos.clear()
	_enlaces_celda.clear()
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
	_consulta_ocupacion += 1
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			for clave in _sectores.get(Vector2i(x, y), []):
				if not _obstaculos.has(clave):
					continue
				var pieza: Dictionary = _obstaculos[clave]
				if volando and not pieza.pared:
					continue
				if pieza.get("_ultima_ocupacion", -1) == _consulta_ocupacion:
					continue
				pieza._ultima_ocupacion = _consulta_ocupacion
				if pieza.has("material_vivo"):
					# Un mismo objeto puede figurar en cuatro sectores. Podar y
					# consultar su árbol sólo una vez, incluso cuando resulta libre.
					var limite: Rect2 = pieza.get("_limite_recortes", pieza.rect)
					if not limite.has_area() or pos.x + margen < limite.position.x - MordiscosMaterial.PASO_MAXIMO or pos.x - margen > limite.end.x + MordiscosMaterial.PASO_MAXIMO or pos.y + margen < limite.position.y - MordiscosMaterial.PASO_MAXIMO or pos.y - margen > limite.end.y + MordiscosMaterial.PASO_MAXIMO:
						continue
					var material: MordiscosMaterial = pieza.material_vivo
					if material.intersecta_rect(Rect2(pos - Vector2.ONE * margen, Vector2.ONE * margen * 2.0)):
						return false
					continue
				if pieza.has("recortes"):
					if pieza.recortes.is_empty():
						continue
					if pieza.has("_limite_recortes"):
						var limite: Rect2 = pieza._limite_recortes
						if not limite.grow(margen).has_point(pos):
							continue
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
	var desde := Vector2i((area.position / SECTOR).floor())
	var hasta := Vector2i((area.end / SECTOR).floor())
	var vistos: Dictionary = {}
	for x in range(desde.x, hasta.x + 1):
		for y in range(desde.y, hasta.y + 1):
			for clave in _sectores.get(Vector2i(x, y), []):
				if vistos.has(clave) or not _obstaculos.has(clave):
					continue
				vistos[clave] = true
				var pieza: Dictionary = _obstaculos[clave]
				if volando and not pieza.pared:
					continue
				var limite: Rect2 = pieza.get("_limite_recortes", pieza.rect)
				if pieza.has("material_vivo"):
					# Rasterizar cubre el último píxel entero del perfil. La poda
					# también lo incluye; el árbol decide el contacto exacto.
					limite = limite.grow(MordiscosMaterial.PASO_MAXIMO)
				if not limite.has_area() or not limite.intersects(area, true):
					continue
				if pieza.has("material_vivo"):
					var material: MordiscosMaterial = pieza.material_vivo
					if material.intersecta_segmento(a, b, MARGEN):
						return false
				elif pieza.has("recortes"):
					for rect: Rect2 in pieza.recortes:
						if _corta_rect(a, b, rect.grow(MARGEN)):
							return false
				elif _corta_rect(a, b, pieza.rect.grow(MARGEN)):
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
	# Un enlace no puede conservar esquinas fuera de un territorio reducido,
	# aunque el cambio sea menor al umbral de reconstrucción de la rejilla.
	if radio != _radio_enlaces:
		_enlaces_celda.clear()
		_radio_enlaces = radio
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


func _celda_cercana(pos: Vector2, grid: AStarGrid2D, volando: bool, presupuesto: Dictionary = {}, limite_pruebas := 0) -> Vector2i:
	var centro := Vector2i(floori(pos.x / CELDA), floori(pos.y / CELDA))
	var mejor := Vector2i(100000, 100000)
	var distancia := INF
	var pruebas := 0
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
				if d < distancia:
					if limite_pruebas > 0 and pruebas >= limite_pruebas:
						return mejor
					if not presupuesto.is_empty():
						if presupuesto.restantes <= 0:
							return mejor
						presupuesto.restantes -= 1
					pruebas += 1
					if segmento_libre(pos, p, volando):
						mejor = id
						distancia = d
		if mejor.x != 100000:
			return mejor
	return mejor


## Un pasillo de 50–75 unidades puede ser transitable con margen 8, pero
## no contener ningún centro de celda con el certificado conservador de 30,72.
## Como máximo dos esquinas exteriores enlazan ese puesto con el mismo A*.
## No mueve hormigas, no reduce el margen y no ejecuta otra búsqueda A*.
func _enlazar_celda(pos: Vector2, grid: AStarGrid2D, volando: bool, radio: float) -> Dictionary:
	consultas_enlace += 1
	var clave := Vector3(pos.x, pos.y, 1.0 if volando else 0.0)
	if _enlaces_celda.has(clave):
		aciertos_cache_enlace += 1
		return _enlaces_celda[clave]
	if not libre(pos, MARGEN, volando):
		return {}
	var vertices := _esquinas_enlace(pos, radio, volando)
	if vertices.is_empty():
		return {}
	var presupuesto := {"restantes": MAX_PRUEBAS_ENLACE}
	var primeras: Array[Vector2] = []
	var segundas: Array[Vector2] = []
	# Primero se prefieren soluciones con una esquina. Las aristas se prueban
	# al necesitarlas: no construir una matriz de dieciséis por dieciséis.
	for vertice: Vector2 in vertices:
		if presupuesto.restantes <= 0:
			break
		presupuesto.restantes -= 1
		if not segmento_libre(pos, vertice, volando):
			segundas.append(vertice)
			continue
		var celda := _celda_cercana(vertice, grid, volando, presupuesto, MAX_PRUEBAS_ANCLA)
		if celda.x != 100000:
			return _guardar_enlace(clave, celda, PackedVector2Array([pos, vertice, grid.get_point_position(celda)]), presupuesto)
		primeras.append(vertice)
	# Si una esquina ya visible no tiene anclaje no sirve volver a visitarla
	# por otra. Sólo se ensayan las que estaban ocultas desde el puesto inicial.
	var sin_ancla: Dictionary = {}
	for primera: Vector2 in primeras:
		for segunda: Vector2 in segundas:
			if presupuesto.restantes <= 0:
				break
			if sin_ancla.has(segunda):
				continue
			presupuesto.restantes -= 1
			if not segmento_libre(primera, segunda, volando):
				continue
			var celda := _celda_cercana(segunda, grid, volando, presupuesto, MAX_PRUEBAS_ANCLA)
			if celda.x != 100000:
				return _guardar_enlace(clave, celda, PackedVector2Array([pos, primera, segunda, grid.get_point_position(celda)]), presupuesto)
			sin_ancla[segunda] = true
	pruebas_enlace_max = maxi(pruebas_enlace_max, MAX_PRUEBAS_ENLACE - int(presupuesto.restantes))
	return {}


func _guardar_enlace(clave: Vector3, celda: Vector2i, puntos: PackedVector2Array, presupuesto: Dictionary) -> Dictionary:
	pruebas_enlace_max = maxi(pruebas_enlace_max, MAX_PRUEBAS_ENLACE - int(presupuesto.restantes))
	if _enlaces_celda.size() >= MAX_CACHE_ENLACES:
		_enlaces_celda.clear()
	var enlace := {"celda": celda, "puntos": puntos}
	_enlaces_celda[clave] = enlace
	return enlace


## Hasta cuatro AABB próximos, no un recorrido de todos los muebles ni de
## todos sus píxeles. Las esquinas sólo son candidatas; cada enlace conserva
## la comprobación exacta contra las bandas vivas y las paredes vecinas.
func _esquinas_enlace(pos: Vector2, radio: float, volando: bool) -> Array[Vector2]:
	var alcance := MARGEN + CELDA * 2.0
	var a := Vector2i(((pos - Vector2.ONE * alcance) / SECTOR).floor())
	var b := Vector2i(((pos + Vector2.ONE * alcance) / SECTOR).floor())
	var vistos: Dictionary = {}
	var rectangulos: Array[Rect2] = []
	var distancias: Array[float] = []
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			for clave in _sectores.get(Vector2i(x, y), []):
				if vistos.has(clave) or not _obstaculos.has(clave):
					continue
				vistos[clave] = true
				var pieza: Dictionary = _obstaculos[clave]
				if volando and not pieza.pared:
					continue
				if pieza.has("recortes") and pieza.recortes.is_empty():
					continue
				var rect: Rect2 = pieza.get("_limite_recortes", pieza.rect)
				var distancia := pos.distance_squared_to(pos.clamp(rect.position, rect.end))
				if not rect.has_area() or distancia > alcance * alcance:
					continue
				var indice := 0
				while indice < distancias.size() and distancias[indice] <= distancia:
					indice += 1
				if indice >= MAX_OBSTACULOS_ENLACE:
					continue
				rectangulos.insert(indice, rect)
				distancias.insert(indice, distancia)
				if rectangulos.size() > MAX_OBSTACULOS_ENLACE:
					rectangulos.pop_back()
					distancias.pop_back()
	var vertices: Array[Vector2] = []
	var distancias_vertices: Array[float] = []
	var unicos: Dictionary = {}
	var limite := pow(maxf(0.0, radio - 6.0), 2)
	for rect: Rect2 in rectangulos:
		var exterior := rect.grow(MARGEN + 1.0)
		for punto: Vector2 in [exterior.position, Vector2(exterior.end.x, exterior.position.y), exterior.end, Vector2(exterior.position.x, exterior.end.y)]:
			if unicos.has(punto) or punto.length_squared() >= limite or not libre(punto, MARGEN, volando):
				continue
			unicos[punto] = true
			var distancia := pos.distance_squared_to(punto)
			var indice := 0
			while indice < distancias_vertices.size() and distancias_vertices[indice] <= distancia:
				indice += 1
			vertices.insert(indice, punto)
			distancias_vertices.insert(indice, distancia)
	return vertices


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
	var prefijo := PackedVector2Array([desde])
	var sufijo := PackedVector2Array([hasta])
	if a.x == 100000:
		var enlace := _enlazar_celda(desde, grid, volando, radio)
		if enlace.is_empty():
			return PackedVector2Array()
		a = enlace.celda
		prefijo = enlace.puntos
	if b.x == 100000:
		var enlace := _enlazar_celda(hasta, grid, volando, radio)
		if enlace.is_empty():
			return PackedVector2Array()
		b = enlace.celda
		sufijo = enlace.puntos
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
	var puntos := prefijo.duplicate()
	puntos.append_array(base)
	for i in range(sufijo.size() - 1, -1, -1):
		puntos.append(sufijo[i])
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
