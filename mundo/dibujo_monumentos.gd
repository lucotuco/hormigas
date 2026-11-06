class_name DibujoMonumentos
extends RefCounted
## Monumentos ilustrados para el atlas compartido. Los vanos quedan vacíos:
## la piedra y el hierro se recortan después a partir de este mismo material.


static func tiene(tipo: String) -> bool:
	return tipo in ["obelisco", "torre", "arco"]


static func dibujar(l: CanvasItem, m: Dictionary) -> void:
	match String(m.tipo):
		"obelisco": _obelisco(l, m.rect, m.color)
		"torre": _torre(l, m.rect, m.color)
		"arco": _arco(l, m.rect, m.color)


static func _punto(r: Rect2, x: float, y: float) -> Vector2:
	return r.position + r.size * Vector2(x, y)


static func _rect(r: Rect2, x: float, y: float, ancho: float, alto: float) -> Rect2:
	return Rect2(_punto(r, x, y), r.size * Vector2(ancho, alto))


static func _poligono(l: CanvasItem, r: Rect2, puntos: PackedVector2Array, color: Color) -> void:
	var cuerpo := PackedVector2Array()
	for punto in puntos:
		cuerpo.append(r.position + r.size * punto)
	l.draw_colored_polygon(cuerpo, color)
	l.draw_polyline(cuerpo + PackedVector2Array([cuerpo[0]]), color, 0.8, true)


static func _linea(l: CanvasItem, r: Rect2, desde: Vector2, hasta: Vector2, color: Color, ancho: float) -> void:
	l.draw_line(r.position + r.size * desde, r.position + r.size * hasta,
		color, maxf(0.8, minf(r.size.x, r.size.y) * ancho), true)


## Bézier continua; sólo se evalúa cuando se hornea el monumento.
static func _curva(desde: Vector2, control_a: Vector2, control_b: Vector2, hasta: Vector2, pasos := 24) -> PackedVector2Array:
	var puntos := PackedVector2Array()
	for i in pasos + 1:
		puntos.append(desde.bezier_interpolate(control_a, control_b, hasta, float(i) / pasos))
	return puntos


static func _trazo(l: CanvasItem, r: Rect2, puntos: PackedVector2Array, color: Color, ancho: float) -> void:
	var cuerpo := PackedVector2Array()
	for punto in puntos:
		cuerpo.append(r.position + r.size * punto)
	l.draw_polyline(cuerpo, color, maxf(0.8, minf(r.size.x, r.size.y) * ancho), true)


static func _obelisco(l: CanvasItem, r: Rect2, color: Color) -> void:
	var piedra := color.lerp(Color("e4dcc4"), 0.5)
	var sombra := piedra.darkened(0.25)
	var luz := piedra.lightened(0.15)
	DibujoCasa.ovalo(l, _rect(r, 0.12, 0.960, 0.78, 0.020), Color(0.21, 0.20, 0.15, 0.12))
	# Cara clara, arista continua y plano lateral mate. La punta no nace
	# en una esquina del rectángulo ni usa el perfil de bandas de navegación.
	_poligono(l, r, PackedVector2Array([
		Vector2(0.350, 0.090), Vector2(0.526, 0.015), Vector2(0.698, 0.090),
		Vector2(0.895, 0.945), Vector2(0.112, 0.945)]), piedra)
	_poligono(l, r, PackedVector2Array([
		Vector2(0.526, 0.015), Vector2(0.698, 0.090), Vector2(0.895, 0.945),
		Vector2(0.590, 0.945), Vector2(0.547, 0.090)]), sombra)
	_poligono(l, r, PackedVector2Array([
		Vector2(0.350, 0.090), Vector2(0.526, 0.015), Vector2(0.547, 0.090)]), luz)
	_poligono(l, r, PackedVector2Array([
		Vector2(0.350, 0.090), Vector2(0.368, 0.094), Vector2(0.137, 0.944),
		Vector2(0.112, 0.945)]), piedra.lightened(0.08))
	_linea(l, r, Vector2(0.547, 0.094), Vector2(0.590, 0.939), Color(luz, 0.35), 0.004)
	# Juntas grandes, tenues y dentro de las caras; no una textura de ruido.
	for i in 6:
		var y := 0.21 + i * 0.115
		var izquierda := lerpf(0.350, 0.112, (y - 0.09) / 0.855)
		var derecha := lerpf(0.547, 0.590, (y - 0.09) / 0.855)
		_linea(l, r, Vector2(izquierda + 0.016, y), Vector2(derecha - 0.008, y), Color(sombra, 0.16), 0.0025)
	DibujoCasa.caja(l, _rect(r, 0.434, 0.135, 0.030, 0.018), sombra.darkened(0.35), Color.TRANSPARENT, r.size.x * 0.004)
	DibujoCasa.caja(l, _rect(r, 0.392, 0.618, 0.115, 0.032), piedra.darkened(0.14), Color.TRANSPARENT, r.size.x * 0.003)
	_linea(l, r, Vector2(0.408, 0.628), Vector2(0.489, 0.628), Color(luz, 0.5), 0.002)
	# Entrada cerrada: la oscuridad es la puerta, no un hueco al piso.
	DibujoCasa.caja(l, _rect(r, 0.407, 0.848, 0.119, 0.092), piedra.darkened(0.30), Color.TRANSPARENT, r.size.x * 0.009)
	DibujoCasa.caja(l, _rect(r, 0.426, 0.861, 0.078, 0.079), Color("5e5e4b"), Color.TRANSPARENT, r.size.x * 0.004)
	_linea(l, r, Vector2(0.465, 0.865), Vector2(0.465, 0.934), Color("8e8b66"), 0.003)
	DibujoCasa.caja(l, _rect(r, 0.067, 0.945, 0.866, 0.017), piedra.darkened(0.17), Color.TRANSPARENT, r.size.x * 0.005)
	DibujoCasa.caja(l, _rect(r, 0.097, 0.962, 0.776, 0.012), piedra.darkened(0.27), Color.TRANSPARENT, r.size.x * 0.003)
	_linea(l, r, Vector2(0.082, 0.946), Vector2(0.915, 0.946), luz, 0.005)


static func _torre(l: CanvasItem, r: Rect2, color: Color) -> void:
	var hierro := color.lerp(Color("97816a"), 0.45)
	var oscuro := hierro.darkened(0.28)
	var claro := hierro.lightened(0.23)
	for x in [0.035, 0.735]:
		DibujoCasa.ovalo(l, _rect(r, x, 0.941, 0.23, 0.016), Color(0.19, 0.18, 0.14, 0.12))
	# El calado pertenece a la geometría: nunca una placa rectangular oscura
	# detrás del hierro. Dos largueros y pocas cruces legibles en la aguja.
	var cima_izquierda := Vector2(0.465, 0.170)
	var base_izquierda := Vector2(0.408, 0.490)
	var cima_derecha := Vector2(0.526, 0.170)
	var base_derecha := Vector2(0.583, 0.490)
	_linea(l, r, cima_izquierda, base_izquierda, oscuro, 0.019)
	_linea(l, r, cima_derecha, base_derecha, oscuro, 0.019)
	for i in 5:
		var t := float(i) / 5
		var siguiente := float(i + 1) / 5
		var izquierda := cima_izquierda.lerp(base_izquierda, t)
		var derecha := cima_derecha.lerp(base_derecha, t)
		var abajo_izquierda := cima_izquierda.lerp(base_izquierda, siguiente)
		var abajo_derecha := cima_derecha.lerp(base_derecha, siguiente)
		_linea(l, r, izquierda, derecha, hierro, 0.010)
		_linea(l, r, izquierda, abajo_derecha, hierro, 0.009)
		_linea(l, r, derecha, abajo_izquierda, claro, 0.006)
	_linea(l, r, cima_izquierda + Vector2(0.005, 0), base_izquierda + Vector2(0.005, 0), claro, 0.004)
	# Segundo tramo abierto entre las plataformas.
	for lado: float in [-1.0, 1.0]:
		var exterior := PackedVector2Array()
		var interior := PackedVector2Array()
		for punto in [Vector2(0.374, 0.535), Vector2(0.305, 0.670)]:
			exterior.append(Vector2(0.496 + (punto.x - 0.496) * -lado, punto.y))
		for punto in [Vector2(0.472, 0.535), Vector2(0.428, 0.670)]:
			interior.append(Vector2(0.496 + (punto.x - 0.496) * -lado, punto.y))
		_trazo(l, r, exterior, oscuro, 0.023)
		_trazo(l, r, interior, hierro, 0.020)
		for i in 3:
			var t := float(i) / 3
			var siguiente := float(i + 1) / 3
			_linea(l, r, exterior[0].lerp(exterior[1], t), interior[0].lerp(interior[1], siguiente), hierro, 0.010)
			_linea(l, r, interior[0].lerp(interior[1], t), exterior[0].lerp(exterior[1], siguiente), claro, 0.006)
		# Las curvas inferiores abren el gran arco hacia los pies. Sus huecos
		# siguen vacíos incluso al hornear sombras, travesaños y remaches.
		var curva_exterior := _curva(Vector2(0.244, 0.740), Vector2(0.194, 0.810), Vector2(0.109, 0.889), Vector2(0.056, 0.930))
		var curva_interior := _curva(Vector2(0.492, 0.740), Vector2(0.390, 0.750), Vector2(0.280, 0.820), Vector2(0.252, 0.930))
		for j in curva_exterior.size():
			curva_exterior[j].x = 0.496 + (curva_exterior[j].x - 0.496) * -lado
			curva_interior[j].x = 0.496 + (curva_interior[j].x - 0.496) * -lado
		_trazo(l, r, curva_exterior, oscuro, 0.028)
		_trazo(l, r, curva_interior, hierro, 0.025)
		for i in 4:
			var indice := i * 6
			_linea(l, r, curva_exterior[indice], curva_interior[indice + 6], hierro, 0.014)
			_linea(l, r, curva_interior[indice], curva_exterior[indice + 6], claro, 0.008)
			if i > 0:
				_linea(l, r, curva_exterior[indice], curva_interior[indice], oscuro, 0.010)
	# Tres plataformas con un bisel mate; pocas barandas grandes, no rejilla.
	_plataforma(l, r, Rect2(0.364, 0.490, 0.262, 0.045), hierro, claro, oscuro, 7)
	_plataforma(l, r, Rect2(0.254, 0.670, 0.485, 0.070), hierro, claro, oscuro, 11)
	DibujoCasa.caja(l, _rect(r, 0.028, 0.930, 0.228, 0.020), oscuro, Color.TRANSPARENT, r.size.x * 0.006)
	DibujoCasa.caja(l, _rect(r, 0.727, 0.930, 0.231, 0.020), oscuro, Color.TRANSPARENT, r.size.x * 0.006)
	_linea(l, r, Vector2(0.043, 0.932), Vector2(0.243, 0.932), claro, 0.006)
	_linea(l, r, Vector2(0.740, 0.932), Vector2(0.942, 0.932), claro, 0.006)
	DibujoCasa.caja(l, _rect(r, 0.451, 0.118, 0.087, 0.052), hierro, Color.TRANSPARENT, r.size.x * 0.005)
	DibujoCasa.caja(l, _rect(r, 0.459, 0.124, 0.071, 0.021), Color("625f50"), Color.TRANSPARENT, r.size.x * 0.003)
	_poligono(l, r, PackedVector2Array([
		Vector2(0.447, 0.118), Vector2(0.473, 0.090), Vector2(0.518, 0.090), Vector2(0.542, 0.118)]), claro)
	_linea(l, r, Vector2(0.493, 0.020), Vector2(0.493, 0.092), oscuro, 0.013)
	_linea(l, r, Vector2(0.490, 0.023), Vector2(0.490, 0.087), claro, 0.004)


static func _plataforma(l: CanvasItem, r: Rect2, zona: Rect2, hierro: Color, claro: Color, oscuro: Color, postes: int) -> void:
	var base := Rect2(r.position + zona.position * r.size, zona.size * r.size)
	DibujoCasa.caja(l, base, oscuro, Color.TRANSPARENT, r.size.x * 0.003)
	DibujoCasa.caja(l, Rect2(base.position, Vector2(base.size.x, base.size.y * 0.30)), claro, Color.TRANSPARENT, r.size.x * 0.002)
	DibujoCasa.caja(l, Rect2(base.position + Vector2(0, base.size.y * 0.35), Vector2(base.size.x, base.size.y * 0.43)), hierro, Color.TRANSPARENT, 0)
	for i in postes:
		var x := zona.position.x + zona.size.x * (i + 0.5) / postes
		_linea(l, r, Vector2(x, zona.position.y + zona.size.y * 0.39), Vector2(x, zona.position.y + zona.size.y * 0.71), Color(oscuro, 0.75), 0.004)


static func _arco(l: CanvasItem, r: Rect2, color: Color) -> void:
	var piedra := color.lerp(Color("ceb38c"), 0.40)
	var oscuro := piedra.darkened(0.24)
	var luz := piedra.lightened(0.22)
	for x in [0.035, 0.415, 0.715]:
		DibujoCasa.ovalo(l, _rect(r, x + 0.013, 0.918, 0.245 if x != 0.415 else 0.17, 0.027), Color(0.23, 0.18, 0.13, 0.12))
	# Cada pilar sigue el intradós del arco. Dibujar piedra alrededor del
	# vano, en vez de pintarlo oscuro sobre un bloque, conserva el piso real.
	var izquierdo := PackedVector2Array([
		Vector2(0.088, 0.290), Vector2(0.353, 0.290)])
	izquierdo.append_array(_curva(Vector2(0.353, 0.440), Vector2(0.300, 0.440), Vector2(0.267, 0.479), Vector2(0.267, 0.525)))
	izquierdo.append_array(PackedVector2Array([
		Vector2(0.267, 0.730), Vector2(0.284, 0.880), Vector2(0.293, 0.928),
		Vector2(0.034, 0.928), Vector2(0.049, 0.880), Vector2(0.081, 0.730)]))
	_poligono(l, r, izquierdo, piedra)
	var central := PackedVector2Array([
		Vector2(0.353, 0.290), Vector2(0.655, 0.290)])
	central.append_array(_curva(Vector2(0.655, 0.440), Vector2(0.603, 0.440), Vector2(0.564, 0.479), Vector2(0.564, 0.525)))
	central.append_array(PackedVector2Array([
		Vector2(0.564, 0.730), Vector2(0.572, 0.880), Vector2(0.584, 0.928),
		Vector2(0.416, 0.928), Vector2(0.430, 0.880), Vector2(0.438, 0.730)]))
	central.append_array(_curva(Vector2(0.438, 0.525), Vector2(0.438, 0.479), Vector2(0.403, 0.440), Vector2(0.353, 0.440)))
	_poligono(l, r, central, piedra)
	var derecho := PackedVector2Array([
		Vector2(0.655, 0.290), Vector2(0.919, 0.290), Vector2(0.925, 0.730),
		Vector2(0.951, 0.880), Vector2(0.963, 0.928), Vector2(0.716, 0.928),
		Vector2(0.729, 0.880), Vector2(0.741, 0.730)])
	derecho.append_array(_curva(Vector2(0.741, 0.525), Vector2(0.741, 0.479), Vector2(0.708, 0.440), Vector2(0.655, 0.440)))
	_poligono(l, r, derecho, piedra)
	# Semicolumnas, zócalos y juntas amplias dan escala arquitectónica.
	for datos: Vector3 in [Vector3(0.116, 0.244, 0.18), Vector3(0.463, 0.538, 0.12), Vector3(0.768, 0.893, 0.18)]:
		var ancho := datos.y - datos.x
		DibujoCasa.caja(l, _rect(r, datos.x, 0.400, ancho, 0.405), piedra.lightened(0.05), Color.TRANSPARENT, r.size.x * 0.004)
		DibujoCasa.caja(l, _rect(r, datos.y - ancho * 0.15, 0.400, ancho * 0.15, 0.405), oscuro, Color.TRANSPARENT, 0)
		_linea(l, r, Vector2(datos.x + ancho * 0.12, 0.416), Vector2(datos.x + ancho * 0.12, 0.790), Color(luz, 0.80), 0.003)
		for i in 3:
			var y := 0.49 + i * 0.105
			_linea(l, r, Vector2(datos.x + 0.010, y), Vector2(datos.y - 0.010, y), Color(oscuro, 0.23), 0.002)
		DibujoCasa.caja(l, _rect(r, datos.x - 0.010, 0.388, ancho + 0.020, 0.035), luz, Color.TRANSPARENT, r.size.x * 0.002)
		DibujoCasa.caja(l, _rect(r, datos.x - 0.016, 0.790, ancho + 0.032, 0.037), oscuro.lightened(0.08), Color.TRANSPARENT, r.size.x * 0.002)
	# Dovelas continuas: sólo la piedra del arco, sin borde fuera del vano.
	for centro_x in [0.353, 0.655]:
		var curva := _curva(Vector2(centro_x - 0.095, 0.525), Vector2(centro_x - 0.095, 0.383), Vector2(centro_x + 0.095, 0.383), Vector2(centro_x + 0.095, 0.525))
		_trazo(l, r, curva, piedra.lightened(0.14), 0.010)
		for i in 5:
			var angulo := PI + PI * (i + 0.5) / 5.0
			var interior := Vector2(centro_x + cos(angulo) * 0.085, 0.525 + sin(angulo) * 0.102)
			var exterior := Vector2(centro_x + cos(angulo) * 0.105, 0.525 + sin(angulo) * 0.128)
			_linea(l, r, interior, exterior, Color(oscuro, 0.38), 0.002)
	# Ático escalonado y molduras horizontales limpias.
	DibujoCasa.caja(l, _rect(r, 0.086, 0.095, 0.831, 0.125), piedra, Color.TRANSPARENT, r.size.x * 0.003)
	DibujoCasa.caja(l, _rect(r, 0.090, 0.040, 0.157, 0.055), piedra.lightened(0.08), Color.TRANSPARENT, r.size.x * 0.004)
	DibujoCasa.caja(l, _rect(r, 0.780, 0.040, 0.130, 0.055), piedra.lightened(0.08), Color.TRANSPARENT, r.size.x * 0.004)
	DibujoCasa.caja(l, _rect(r, 0.056, 0.220, 0.890, 0.070), oscuro, Color.TRANSPARENT, r.size.x * 0.004)
	DibujoCasa.caja(l, _rect(r, 0.056, 0.220, 0.890, 0.025), luz, Color.TRANSPARENT, r.size.x * 0.003)
	_linea(l, r, Vector2(0.101, 0.108), Vector2(0.901, 0.108), Color(luz, 0.90), 0.004)
	DibujoCasa.caja(l, _rect(r, 0.346, 0.126, 0.309, 0.061), piedra.darkened(0.14), Color.TRANSPARENT, r.size.x * 0.003)
	_linea(l, r, Vector2(0.375, 0.143), Vector2(0.625, 0.143), Color(luz, 0.6), 0.003)
	_linea(l, r, Vector2(0.405, 0.166), Vector2(0.598, 0.166), Color(luz, 0.4), 0.002)
	for datos: Vector3 in [Vector3(0.034, 0.259, 0.108), Vector3(0.416, 0.168, 0.443), Vector3(0.716, 0.247, 0.770)]:
		DibujoCasa.caja(l, _rect(r, datos.x, 0.880, datos.y, 0.048), oscuro, Color.TRANSPARENT, r.size.x * 0.004)
		_linea(l, r, Vector2(datos.x + 0.006, 0.883), Vector2(datos.x + datos.y - 0.006, 0.883), luz, 0.004)
		DibujoCasa.caja(l, _rect(r, datos.z, 0.928, 0.110 if datos.x == 0.416 else 0.122, 0.013), oscuro.darkened(0.08), Color.TRANSPARENT, r.size.x * 0.002)
