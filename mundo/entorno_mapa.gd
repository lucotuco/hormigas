class_name EntornoMapa
extends RefCounted
## Paisaje retenido por Cocina: ningún nodo, ruta, colisión ni _process extra.
## El borde cercano tiene muebles auténticos en Mundos. Casas, árboles grandes
## y fachadas de este segundo cinturón quedan siempre fuera del juego.

static func dibujar(l: CanvasItem) -> void:
	var destino := Juego.lugar_actual
	if destino in ["casa", "restaurante", "museo"]:
		_patio(l, destino)
	elif destino == "obelisco":
		_avenida(l)
	elif destino == "coliseo":
		_parque_arqueologico(l)
	else:
		_jardines(l)
	_barrio(l, destino)


static func _sendero(l: CanvasItem, r: Rect2, color := Color("c7bea5")) -> void:
	l.draw_rect(r, color.darkened(0.13))
	l.draw_rect(r.grow(-10), color)
	var horizontal := r.size.x > r.size.y
	var largo := r.size.x if horizontal else r.size.y
	for i in range(1, floori(largo / 360.0)):
		var a := r.position + (Vector2(i * 360, 10) if horizontal else Vector2(10, i * 360))
		var b := a + (Vector2(0, r.size.y - 20) if horizontal else Vector2(r.size.x - 20, 0))
		l.draw_line(a, b, color.darkened(0.10), 3)


static func _patio(l: CanvasItem, destino: String) -> void:
	# Camino perimetral y cuatro pasos a través de las puertas de los edificios.
	# El piso dibujado y la navegación comparten el mismo ancho de abertura.
	var color := Color("c8bfaa") if destino == "museo" else Color("c5b497")
	_sendero(l, Rect2(-1220, -1260, 8400, 260), color)
	_sendero(l, Rect2(-1220, 4600, 8400, 240), color)
	_sendero(l, Rect2(-1220, -1000, 270, 5600), color)
	_sendero(l, Rect2(6950, -1000, 230, 5600), color)
	for r in [Rect2(-2150, 1450, 1250, 450), Rect2(6900, 1850, 1250, 500), Rect2(3500, -1900, 450, 950), Rect2(900, 4550, 500, 950)]:
		_sendero(l, r, color)
	# Zonas de uso del patio, discretas debajo de sus objetos comestibles.
	for r in [Rect2(-2050, 650, 950, 510), Rect2(3500, -1860, 1100, 750), Rect2(7150, 2750, 850, 500), Rect2(3800, 4770, 1200, 510)]:
		DibujoCasa.caja(l, r, Color("bcb290") if destino == "casa" else color, color.darkened(0.11), 25)
	# Canteros bajos: se pueden atravesar, no prometen colisiones inexistentes.
	for r in [Rect2(-2000, -1700, 1200, 250), Rect2(4700, -1650, 1700, 210), Rect2(100, 5050, 600, 220), Rect2(5100, 5080, 800, 160)]:
		_cantero(l, r, Color("7f926b"))
	_borde_parcela(l)


static func _avenida(l: CanvasItem) -> void:
	var v := PlanoCasa.limites_visuales()
	# La 9 de Julio continúa a izquierda y derecha del recorte anterior.
	for y in [-250, 2750]:
		l.draw_rect(Rect2(v.position.x, y - 60, v.size.x, 440), Color("c9c2ae"))
		l.draw_rect(Rect2(v.position.x, y, v.size.x, 320), Color("73766d"))
		for x in range(int(v.position.x) + 100, int(v.end.x), 400):
			l.draw_rect(Rect2(x, y + 158, 160, 4), Color("bdbba2"))
	for x in [-1950, 7330]:
		_sendero(l, Rect2(x, -1750, 280, 6900), Color("c8c2b0"))
	for r in [Rect2(-1950, -1600, 2400, 230), Rect2(4700, -1650, 2900, 260), Rect2(-1700, 4850, 3000, 250), Rect2(5000, 4850, 2800, 250)]:
		_cantero(l, r, Color("879477"))


static func _parque_arqueologico(l: CanvasItem) -> void:
	for r in [Rect2(-1950, -1660, 9800, 260), Rect2(-1950, 4750, 9800, 280), Rect2(-1950, -1660, 280, 6670), Rect2(7470, -1660, 280, 6670)]:
		_sendero(l, r, Color("c8b592"))
	for i in 14:
		var x := -1700.0 + i * 640.0
		# Piedras a ras del suelo, no copias falsas de los arcos comestibles.
		l.draw_rect(Rect2(x, -1300 + (i % 3) * 34, 210, 80), Color("b1a080"))
		l.draw_rect(Rect2(x + 110, 5150 - (i % 4) * 30, 160, 70), Color("b9a584"))


static func _jardines(l: CanvasItem) -> void:
	for r in [Rect2(-1950, -1650, 9800, 250), Rect2(-1950, 4800, 9800, 260), Rect2(-1950, -1650, 270, 6710), Rect2(7470, -1650, 280, 6710)]:
		_sendero(l, r, Color("d0c6ad"))
	for r in [Rect2(-1950, 1100, 1000, 180), Rect2(6900, 2000, 1100, 180), Rect2(900, 4550, 200, 900), Rect2(3500, -1900, 200, 950)]:
		_sendero(l, r, Color("d0c6ad"))
	for x in [-1300, 5700]:
		for y in [-1550, 4900]:
			_cantero(l, Rect2(x, y, 1100, 260), Color("82916b"))
	_borde_parcela(l)


static func _cantero(l: CanvasItem, r: Rect2, color: Color) -> void:
	DibujoCasa.caja(l, r, color.darkened(0.12), Color("b4b08d"), 55)
	DibujoCasa.caja(l, r.grow(-22), color, Color.TRANSPARENT, 40)
	for i in 5:
		var pos := r.position + r.size * Vector2(0.12 + i * 0.19, 0.45 + (i % 2) * 0.16)
		l.draw_circle(pos, minf(r.size.y * 0.09, 19), Color("bcab7e") if i % 2 == 0 else Color("9eab88"))


static func _borde_parcela(l: CanvasItem) -> void:
	# Cerco bajo en el límite del terreno: detrás sólo hay contexto visual.
	var r := PlanoCasa.limites()
	var tinta := Color("718261")
	for y in [r.position.y - 30, r.end.y + 30]:
		l.draw_line(Vector2(r.position.x - 30, y), Vector2(r.end.x + 30, y), tinta, 10)
		for x in range(int(r.position.x), int(r.end.x), 280):
			l.draw_rect(Rect2(x, y - 35, 12, 70), tinta.darkened(0.13))
	for x in [r.position.x - 30, r.end.x + 30]:
		l.draw_line(Vector2(x, r.position.y - 30), Vector2(x, r.end.y + 30), tinta, 10)
		for y in range(int(r.position.y), int(r.end.y), 280):
			l.draw_rect(Rect2(x - 35, y, 70, 12), tinta.darkened(0.13))


static func _barrio(l: CanvasItem, destino: String) -> void:
	# Siluetas serenas, no versiones de los objetos que se pueden comer.
	var urbano := destino in ["restaurante", "museo", "obelisco"]
	var color := Color("9a9882") if urbano else Color("88916f")
	for i in 8:
		var x := -4300.0 + i * 1900.0
		if urbano or destino == "casa":
			_techo(l, Rect2(x, -2600, 1350, 500), Color("9f8b76") if destino == "casa" else Color("999889"))
			_techo(l, Rect2(x + 130, 5740, 1180, 500), Color("a48f78") if destino == "casa" else Color("a3a08e"))
		else:
			_arbol(l, Vector2(x + 450, -2350), 180, color)
			_arbol(l, Vector2(x + 350, 5920), 185, color)
	for lado in [-1, 1]:
		var x := -3400.0 if lado < 0 else 9400.0
		for i in 7:
			var pos := Vector2(x + (i % 2) * 170, -1600 + i * 1070)
			_arbol(l, pos, 170 + (i % 3) * 22, color)
		if urbano:
			for y in [-1950, 3700]:
				_techo(l, Rect2(x - 650, y, 580, 1500), Color("929386"))


static func _techo(l: CanvasItem, r: Rect2, color: Color) -> void:
	l.draw_rect(Rect2(r.position + Vector2(20, 35), r.size), Color(0.19, 0.22, 0.15, 0.10))
	DibujoCasa.caja(l, r, color.darkened(0.12), color.darkened(0.2), 12)
	var horizontal := r.size.x > r.size.y
	var a := r.position + (Vector2(30, r.size.y * 0.5) if horizontal else Vector2(r.size.x * 0.5, 30))
	var b := r.end - (Vector2(30, r.size.y * 0.5) if horizontal else Vector2(r.size.x * 0.5, 30))
	l.draw_line(a, b, color.lightened(0.15), 13)
	for i in 3:
		var caja := Rect2(r.position + r.size * Vector2(0.15 + i * 0.28, 0.16), r.size * Vector2(0.10, 0.16))
		l.draw_rect(caja, color.darkened(0.20))


static func _arbol(l: CanvasItem, pos: Vector2, radio: float, color: Color) -> void:
	l.draw_circle(pos + Vector2(25, 35), radio, Color(0.20, 0.25, 0.15, 0.10))
	for i in 5:
		var centro := pos + Vector2.from_angle(i * TAU / 5) * radio * 0.35
		l.draw_circle(centro, radio * 0.62, color.darkened(0.09 if i % 2 else 0.03))
	l.draw_circle(pos - Vector2(radio * 0.12, radio * 0.13), radio * 0.47, color.lightened(0.045))
