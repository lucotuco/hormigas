class_name DibujoCasa
extends RefCounted
## Ilustración cenital: materiales, volúmenes, tapizados y objetos domésticos.

static func caja(l: CanvasItem, r: Rect2, color: Color, borde := Color.TRANSPARENT, radio := 14.0) -> void:
	l.draw_style_box(Estilo.caja(color, int(radio), borde, 3 if borde.a > 0 else 0, 0), r)

static func ovalo(l: CanvasItem, r: Rect2, color: Color) -> void:
	l.draw_set_transform(r.get_center(), 0, r.size * 0.5)
	l.draw_circle(Vector2.ZERO, 1, color)
	l.draw_set_transform(Vector2.ZERO)

static func alfombra(l: CanvasItem, r: Rect2, color: Color) -> void:
	caja(l, Rect2(r.position + Vector2(12, 18), r.size), Color(0.1, 0.08, 0.06, 0.12), Color.TRANSPARENT, 28)
	caja(l, r, color, color.darkened(0.2), 24)
	l.draw_rect(r.grow(-24), color.lightened(0.23), false, 6)
	l.draw_rect(r.grow(-42), color.darkened(0.15), false, 3)
	# Bordado estático, sin texturas ni nodos adicionales.
	var centro := r.get_center()
	var radio := minf(r.size.x, r.size.y) * 0.24
	for escala in [1.0, 0.72]:
		var rombo := PackedVector2Array([centro + Vector2(0, -radio * escala), centro + Vector2(radio * escala, 0), centro + Vector2(0, radio * escala), centro + Vector2(-radio * escala, 0), centro + Vector2(0, -radio * escala)])
		l.draw_polyline(rombo, Color(color.lightened(0.35), 0.48), 9, true)
	for i in range(1, int(r.size.y / 75)):
		var y: float = r.position.y + i * 75
		l.draw_line(Vector2(r.position.x + 50, y), Vector2(r.end.x - 50, y), Color(1, 1, 1, 0.045), 3)
	for x in range(int(r.position.x) + 20, int(r.end.x), 28):
		l.draw_line(Vector2(x, r.position.y - 13), Vector2(x, r.position.y + 5), color.lightened(0.15), 5)
		l.draw_line(Vector2(x, r.end.y - 5), Vector2(x, r.end.y + 13), color.lightened(0.15), 5)

static func dibujar(l: CanvasItem, incluir_piezas := true) -> void:
	if Juego.lugar_actual != "casa":
		_destino(l)
		return
	# Umbrales y alfombras pertenecen al suelo y no bloquean el paso.
	_luz_ventanas(l)
	alfombra(l, Rect2(2320, -360, 1690, 1460), Color("9b6958"))
	alfombra(l, Rect2(4730, 70, 1530, 1210), Color("c3b392"))
	alfombra(l, Rect2(-750, 2350, 1810, 1800), Color("9a9daf"))
	alfombra(l, Rect2(4700, 3670, 770, 190), Color("8ba5a0"))
	var umbrales := [Rect2(1660, -100, 80, 450), Rect2(-100, 1310, 450, 80), Rect2(2750, 1310, 500, 80), Rect2(4250, 400, 100, 600), Rect2(200, 1990, 500, 100), Rect2(2600, 1990, 500, 100), Rect2(5200, 2490, 500, 100), Rect2(4250, 3450, 100, 500)]
	for r in umbrales:
		l.draw_rect(r, Color("b49e7c"))
		l.draw_rect(r.grow(-8), Color("cdb99a"), false, 3)
	# Nombres integrados al plano; no son mensajes superpuestos del HUD.
	for a in PlanoCasa.AMBIENTES:
		var r: Rect2 = a.rect
		var origen := r.position + Vector2(120, r.size.y - 110)
		l.draw_line(origen + Vector2(0, 25), origen + Vector2(250, 25), Color(0.25, 0.24, 0.21, 0.22), 3)
		l.draw_string(ThemeDB.fallback_font, origen, l.tr(a.nombre), HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color(0.25, 0.24, 0.21, 0.38))
	if incluir_piezas:
		for m in PlanoCasa.MUEBLES:
			mueble(l, m)
	# El gran banquete está caído junto a la mesa del comedor.
	var plato := PlanoCasa.BANQUETE
	l.draw_circle(plato + Vector2(14, 21), 154, Color(0.15, 0.1, 0.05, 0.18))
	l.draw_circle(plato, 150, Color("ece9d9"))
	l.draw_arc(plato, 136, 0, TAU, 72, Color("8aaba6"), 8, true)
	l.draw_circle(plato, 115, Color("dbded1"))
	# Servilleta y cubiertos, a escala del plato.
	l.draw_colored_polygon(PackedVector2Array([plato + Vector2(-380, -90), plato + Vector2(-240, -120), plato + Vector2(-200, 80), plato + Vector2(-345, 110)]), Color("eee8d3"))
	l.draw_line(plato + Vector2(-240, -150), plato + Vector2(-225, 160), Color("8e9b9b"), 12, true)
	for i in 4:
		l.draw_line(plato + Vector2(-257 + i * 11, -150), plato + Vector2(-257 + i * 11, -205), Color("a6b3b2"), 5, true)
	# Bordes elevados y sombra sur: paredes continuas salvo las puertas.
	if incluir_piezas:
		for rect in PlanoCasa.PAREDES:
			pared(l, rect)
	# Ventanas en los muros exteriores.
	for r in (PlanoCasa.VENTANAS if incluir_piezas else []):
		l.draw_rect(r.grow(8), Color("6f8889"))
		l.draw_rect(r, Color("bad8d7"))
		for i in 4:
			var x: float = r.position.x + r.size.x * i / 3
			l.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color("f2eee0"), 9)
	# Una hoja de puerta abierta y su arco de giro dejan clara la conexión.
	l.draw_arc(Vector2(1700, -100), 410, 0, PI * 0.5, 40, Color(0.37, 0.29, 0.2, 0.28), 4, true)
	l.draw_arc(Vector2(200, 2050), 460, 0, PI * 0.5, 40, Color(0.37, 0.29, 0.2, 0.22), 4, true)
	# Arcos de apertura, no hojas sólidas sin colisión.

static func pared(l: CanvasItem, rect: Rect2) -> void:
	l.draw_rect(Rect2(rect.position + Vector2(12, 22), rect.size + Vector2(5, 8)), Color(0.12, 0.12, 0.1, 0.18))
	l.draw_rect(rect, Color("857e6f"))
	l.draw_rect(rect.grow(-7), Color("ede7d6"))
	l.draw_line(rect.position + Vector2(4, 4), Vector2(rect.end.x - 4, rect.position.y + 4), Color("faf6e9"), 5)
	if rect.size.x > rect.size.y:
		l.draw_line(Vector2(rect.position.x, rect.end.y - 4), rect.end - Vector2(0, 4), Color("b4a58d"), 6)
	else:
		l.draw_line(Vector2(rect.end.x - 4, rect.position.y), rect.end - Vector2(4, 0), Color("b4a58d"), 6)

static func mueble(l: CanvasItem, m: Dictionary) -> void:
	var r: Rect2 = m.rect
	var c: Color = m.color
	var p := r.position
	var s := r.size
	if m.tipo in ["obelisco", "torre", "arco", "escultura", "vitrina"]:
		_monumento(l, m)
		return
	if m.tipo == "planta":
		_planta(l, r, c)
		return
	# Dos bandas de sombra horneadas; no hay luces dinámicas.
	caja(l, Rect2(p + Vector2(12, 22), s).grow(10), Color(0.16, 0.12, 0.08, 0.08), Color.TRANSPARENT, 26)
	caja(l, Rect2(p + Vector2(8, 14), s), Color(0.15, 0.1, 0.06, 0.19), Color.TRANSPARENT, 20)
	if m.tipo == "silla":
		_silla(l, m)
		return
	caja(l, r, c.darkened(0.28), c.darkened(0.42), 16)
	var tapa := Rect2(p - Vector2(0, 10), s)
	caja(l, tapa.grow(-5), c, c.lightened(0.26), 12)
	match m.tipo:
		"mesa", "mesa_comedor", "ratona", "escritorio", "mesita":
			for i in range(1, int(s.y / 65)):
				var y: float = p.y + i * 65
				l.draw_line(Vector2(p.x + 20, y), Vector2(r.end.x - 20, y), c.darkened(0.15), 3)
			for esquina in [p + Vector2(30, 30), p + Vector2(s.x - 30, 30), p + Vector2(30, s.y - 30), r.end - Vector2(30, 30)]:
				l.draw_circle(esquina, 9, c.darkened(0.22))
			if m.tipo == "mesa_comedor":
				caja(l, Rect2(p + Vector2(570, 110), Vector2(220, 550)), Color("b8b6a2"), Color.TRANSPARENT, 8)
			if m.tipo == "mesa":
				l.draw_circle(p + s * Vector2(0.72, 0.48), 74, Color("eee6d1"))
				l.draw_circle(p + s * Vector2(0.72, 0.48), 48, Color("9c7552"))
				l.draw_arc(p + s * Vector2(0.72, 0.48) + Vector2(55, 0), 23, -PI * 0.5, PI * 0.5, 18, Color("eee6d1"), 10, true)
			if m.tipo == "ratona":
				caja(l, Rect2(p + Vector2(65, 60), Vector2(230, 290)), Color("e4d9b9"), Color("ab9876"), 6)
				for i in 5:
					l.draw_line(p + Vector2(90, 100 + i * 38), p + Vector2(265, 100 + i * 38), Color("9f9c84"), 5)
				l.draw_circle(p + Vector2(590, 210), 77, Color("d9e0d2"))
			if m.tipo == "escritorio":
				caja(l, Rect2(p + Vector2(400, 80), Vector2(500, 300)), Color("4d5956"), Color("87938b"), 15)
				caja(l, Rect2(p + Vector2(430, 105), Vector2(440, 230)), Color("a1beb5"), Color.TRANSPARENT, 5)
				l.draw_rect(Rect2(p + Vector2(370, 395), Vector2(560, 85)), Color("d4d6c8"))
				for i in 3:
					l.draw_rect(Rect2(p + Vector2(70 + i * 12, 100 + i * 50), Vector2(200, 100)), [Color("b76b55"), Color("d4c395"), Color("8ba09b")][i])
			if m.tipo == "mesita":
				l.draw_circle(r.get_center(), 100, Color("d9caa3"))
				l.draw_circle(r.get_center(), 42, Color("b6aa89"))
		"sofa", "sillon":
			caja(l, r.grow(-28), c.darkened(0.08), c.lightened(0.15), 48)
			caja(l, Rect2(p + Vector2(30, 14), Vector2(s.x - 60, s.y * 0.27)), c.darkened(0.17), Color.TRANSPARENT, 35)
			var asientos := 3 if m.tipo == "sofa" else 1
			for i in asientos:
				var ancho := (s.x - 130) / asientos
				caja(l, Rect2(p + Vector2(65 + i * ancho, s.y * 0.36), Vector2(ancho - 12, s.y * 0.52)), c.lightened(0.08), c.darkened(0.17), 25)
			caja(l, Rect2(p + Vector2(10, 30), Vector2(60, s.y - 65)), c.lightened(0.02), Color.TRANSPARENT, 26)
			caja(l, Rect2(p + Vector2(s.x - 70, 30), Vector2(60, s.y - 65)), c.lightened(0.02), Color.TRANSPARENT, 26)
		"cama":
			caja(l, r.grow(-30), Color("ede7d9"), Color("c8b89d"), 48)
			caja(l, Rect2(p + Vector2(-20, -30), Vector2(s.x + 40, 120)), Color("9b8066"), Color("bfa185"), 22)
			for i in 2:
				caja(l, Rect2(p + Vector2(120 + i * 680, 140), Vector2(560, 260)), Color("f3eedf"), Color("d9d1bf"), 44)
			caja(l, Rect2(p + Vector2(45, 500), Vector2(s.x - 90, s.y - 550)), c, c.lightened(0.2), 32)
			l.draw_rect(Rect2(p + Vector2(45, 500), Vector2(s.x - 90, 170)), c.lightened(0.23))
			for i in range(1, 8):
				l.draw_line(p + Vector2(45, 670 + i * 95), p + Vector2(s.x - 45, 670 + i * 95), Color(1, 1, 1, 0.09), 3)
		"pileta", "lavabo":
			caja(l, r.grow(-45), Color("859b9c"), Color("d9e0d8"), 40)
			caja(l, r.grow(-70), Color("b6cdca"), Color("6e8e90"), 30)
			l.draw_circle(r.get_center() + Vector2(0, 22), 15, Color("738d8b"))
			l.draw_arc(r.get_center() + Vector2(0, -s.y * 0.27), 42, PI, TAU, 20, Color("e6e9df"), 14, true)
		"cocina":
			for i in 4:
				var centro := p + Vector2(140 + (i % 2) * 250, 64 + int(i / 2) * 110)
				l.draw_circle(centro, 45, Color("444e4a"))
				l.draw_arc(centro, 29, 0, TAU, 24, Color("79847b"), 5, true)
		"heladera":
			l.draw_line(p + Vector2(15, s.y * 0.32), p + Vector2(s.x - 15, s.y * 0.32), c.darkened(0.3), 8)
			for y in [s.y * 0.16, s.y * 0.53]:
				caja(l, Rect2(p + Vector2(s.x - 60, y), Vector2(20, 90)), Color("8b9d96"), Color.TRANSPARENT, 7)
			l.draw_rect(Rect2(p + Vector2(60, 290), Vector2(95, 120)), Color("e5bf77"))
		"television":
			caja(l, Rect2(p + Vector2(90, -80), Vector2(s.x - 180, s.y * 0.76)), Color("303d39"), Color("59675f"), 18)
			l.draw_line(p + Vector2(150, -35), p + Vector2(s.x - 160, 45), Color("50675d"), 5, true)
			l.draw_circle(p + Vector2(s.x - 100, s.y * 0.7), 7, Color("a2be8c"))
		"biblioteca", "ropero", "alacena", "aparador", "consola":
			var horizontal := s.x > s.y
			for i in 5:
				if horizontal:
					var x: float = p.x + s.x * i / 5
					l.draw_line(Vector2(x, p.y + 15), Vector2(x, r.end.y - 15), c.darkened(0.22), 5)
				else:
					var y: float = p.y + s.y * i / 5
					l.draw_line(Vector2(p.x + 15, y), Vector2(r.end.x - 15, y), c.darkened(0.22), 5)
			if m.tipo == "biblioteca":
				var colores := [Color("a66b57"), Color("8caaa2"), Color("d2bd86"), Color("a99ab0")]
				for i in 18:
					var rlibro := Rect2(p + Vector2(20 + i * (s.x - 40) / 18, 25), Vector2((s.x - 40) / 21, s.y - 55)) if horizontal else Rect2(p + Vector2(25, 20 + i * (s.y - 40) / 18), Vector2(s.x - 55, (s.y - 40) / 21))
					l.draw_rect(rlibro, colores[i % 4])
		"banera":
			caja(l, r.grow(-32), Color("f5f2e7"), Color("9aada7"), 90)
			caja(l, r.grow(-87), Color("accdca"), Color("d7e2d9"), 75)
			l.draw_circle(p + Vector2(s.x - 160, s.y * 0.5), 21, Color("6d9792"))
			l.draw_arc(p + Vector2(110, s.y * 0.5), 58, -PI * 0.5, PI * 0.5, 24, Color("d8e2d9"), 17, true)
		"inodoro":
			caja(l, Rect2(p + Vector2(15, 10), Vector2(s.x - 30, 190)), Color("f1f1e5"), Color("b4c4bc"), 22)
			ovalo(l, Rect2(p + Vector2(25, 160), Vector2(s.x - 50, s.y - 180)), Color("ebeee3"))
			ovalo(l, Rect2(p + Vector2(85, 235), Vector2(s.x - 170, s.y - 330)), Color("a5bfba"))
		"lavarropas":
			l.draw_line(p + Vector2(10, 90), p + Vector2(s.x - 10, 90), Color("92aaa3"), 6)
			l.draw_circle(r.get_center() + Vector2(0, 40), 178, Color("849f9c"))
			l.draw_circle(r.get_center() + Vector2(0, 40), 140, Color("b7d1ce"))
			l.draw_circle(r.get_center() + Vector2(0, 40), 105, Color("83aaa8"))
			l.draw_circle(p + Vector2(s.x - 65, 40), 25, Color("879e94"))

	_detalle_mueble(l, m)


static func _luz_ventanas(l: CanvasItem) -> void:
	for ventana in PlanoCasa.VENTANAS:
		var abajo: bool = ventana.position.y < 0
		var y: float = ventana.end.y if abajo else ventana.position.y
		var direccion := 1.0 if abajo else -1.0
		for i in 3:
			var x: float = ventana.position.x + i * ventana.size.x / 3.0
			var ancho: float = ventana.size.x / 3.0 - 16
			var luz := PackedVector2Array([Vector2(x, y), Vector2(x + ancho, y), Vector2(x + ancho + 170, y + direccion * 530), Vector2(x + 170, y + direccion * 530)])
			l.draw_colored_polygon(luz, Color(1.0, 0.95, 0.77, 0.15))


static func _planta(l: CanvasItem, r: Rect2, c: Color) -> void:
	var centro := r.get_center()
	var radio := minf(r.size.x, r.size.y)
	l.draw_circle(centro + Vector2(12, 18), radio * 0.46, Color(0.12, 0.14, 0.09, 0.17))
	l.draw_circle(centro, radio * 0.33, Color("a86e4d"))
	l.draw_arc(centro, radio * 0.32, 0, TAU, 32, Color("d4a17a"), 8, true)
	l.draw_circle(centro, radio * 0.25, Color("564333"))
	for i in 9:
		var a := i * 2.4
		var largo := radio * (0.39 if i < 5 else 0.27)
		var punta := centro + Vector2.from_angle(a) * largo
		var lateral := Vector2.from_angle(a + PI * 0.5) * largo * 0.36
		var medio := centro.lerp(punta, 0.56)
		l.draw_colored_polygon(PackedVector2Array([centro, medio + lateral, punta, medio - lateral]), c.darkened(0.12).lightened(i * 0.025))
		l.draw_line(centro, punta, Color(c.lightened(0.35), 0.55), 2, true)


static func _silla(l: CanvasItem, m: Dictionary) -> void:
	var r: Rect2 = m.rect
	var c: Color = m.color
	var s := r.size
	var p := r.position
	if m.get("acabado", "") == "carton":
		caja(l, r.grow(-6), Color("9c7045"), Color("735337"), 3)
		caja(l, Rect2(p + Vector2(4, -4), s - Vector2(8, 12)), Color("c3a06b"), Color("e0bd85"), 3)
		l.draw_line(p + Vector2(s.x * 0.5, 0), p + Vector2(s.x * 0.5, s.y - 15), Color("a38254"), 3)
		l.draw_rect(Rect2(p + s * Vector2(0.15, 0.35), s * Vector2(0.7, 0.18)), Color("ddc395"))
		for i in 5:
			l.draw_line(p + Vector2(15 + i * 18, s.y - 12), p + Vector2(15 + i * 18, s.y - 4), Color("c3a06b"), 3)
		return
	for uv in [Vector2(0.12, 0.12), Vector2(0.78, 0.12), Vector2(0.12, 0.78), Vector2(0.78, 0.78)]:
		caja(l, Rect2(p + s * uv, s * 0.12), Color("79563c"), Color("aa8056"), 5)
	caja(l, r.grow(-s.x * 0.13), Color("a27b52"), Color("684f39"), 10)
	var asiento := r.grow(-s.x * 0.20)
	caja(l, asiento, c, c.lightened(0.3), 16)
	caja(l, asiento.grow(-9), Color.TRANSPARENT, Color(c.darkened(0.35), 0.4), 10)
	l.draw_circle(asiento.get_center(), 3, c.darkened(0.25))
	var frente: String = m.get("frente", "sur")
	var respaldo := Rect2(p + s * Vector2(0.08, 0.06), s * Vector2(0.84, 0.18))
	if frente == "norte":
		respaldo.position.y = p.y + s.y * 0.76
	elif frente == "este" or frente == "oeste":
		respaldo = Rect2(p + s * Vector2(0.06 if frente == "este" else 0.76, 0.08), s * Vector2(0.18, 0.84))
	caja(l, respaldo, c.darkened(0.3), c.lightened(0.1), 9)


static func _plato(l: CanvasItem, pos: Vector2, radio: float) -> void:
	l.draw_circle(pos + Vector2(3, 5), radio, Color(0.15, 0.12, 0.08, 0.15))
	l.draw_circle(pos, radio, Color("f6efdf"))
	l.draw_arc(pos, radio * 0.82, 0, TAU, 32, Color("8eaaa2"), 3, true)
	l.draw_arc(pos, radio * 0.64, 0, TAU, 32, Color("e1d8c4"), 2, true)


static func _detalle_mueble(l: CanvasItem, m: Dictionary) -> void:
	# Los accesorios usan la misma máscara de destrucción que el mueble.
	var r: Rect2 = m.rect
	var p := r.position
	var s := r.size
	var c: Color = m.color
	match m.tipo:
		"banco":
			# Listones y apoyabrazos: un banco de plaza, no una alacena afuera.
			for i in 4:
				var tabla := Rect2(p + Vector2(18, 8 + i * (s.y - 30) / 4), Vector2(s.x - 36, (s.y - 30) / 4 - 6))
				caja(l, tabla, c.lightened(i * 0.025), c.darkened(0.25), 4)
			for x in [0.12, 0.86]:
				caja(l, Rect2(p + s * Vector2(x, 0.05), s * Vector2(0.035, 0.82)), Color("3d5350"), Color("71827b"), 7)
		"mesa", "mesa_comedor", "ratona", "escritorio", "mesita":
			for i in 7:
				var y := p.y + s.y * (0.12 + i * 0.12)
				var x := p.x + s.x * (0.08 + (i % 3) * 0.05)
				l.draw_line(Vector2(x, y), Vector2(x + s.x * 0.28, y + 2), Color(c.darkened(0.4), 0.15), 2, true)
			if m.tipo == "mesa_comedor":
				for uv in [Vector2(0.18, 0.24), Vector2(0.18, 0.74), Vector2(0.78, 0.24), Vector2(0.78, 0.74)]:
					var pos: Vector2 = p + s * uv
					_plato(l, pos, 102)
					l.draw_line(pos + Vector2(-125, -55), pos + Vector2(-125, 65), Color("cbd1c6"), 8, true)
					for d in [-6, 0, 6]:
						l.draw_line(pos + Vector2(-125 + d, -60), pos + Vector2(-125 + d, -85), Color("cbd1c6"), 3, true)
					l.draw_line(pos + Vector2(125, -65), pos + Vector2(125, 65), Color("cbd1c6"), 9, true)
					l.draw_circle(pos + Vector2(125, -112), 27, Color("c8d6c4"))
					l.draw_circle(pos + Vector2(125, -112), 19, Color("a0bbb4"))
				_planta(l, Rect2(p + s * Vector2(0.44, 0.36), s * Vector2(0.12, 0.25)), Color("667f58"))
			elif m.tipo == "mesa":
				caja(l, Rect2(p + s * Vector2(0.12, 0.18), s * Vector2(0.30, 0.60)), Color("e5d4ae"), Color("c6b28f"), 6)
				for i in 5:
					l.draw_line(p + s * Vector2(0.16, 0.3 + i * 0.08), p + s * Vector2(0.36, 0.3 + i * 0.08), Color("b6ab92"), 3)
			elif m.tipo == "escritorio":
				for fila in 3:
					for tecla in 12:
						l.draw_rect(Rect2(p + Vector2(385 + tecla * 43, 405 + fila * 21), Vector2(30, 12)), Color("a9b1a9"))
				l.draw_line(p + Vector2(455, 130), p + Vector2(750, 130), Color("d5e7cc"), 7)
				l.draw_line(p + Vector2(455, 160), p + Vector2(680, 160), Color("769890"), 5)
		"mesada":
			caja(l, r.grow(-25), Color("d7d4bf"), Color("eee7d2"), 7)
			var tabla := Rect2(p + s * Vector2(0.1, 0.2), s * Vector2(0.43, 0.62))
			caja(l, tabla, Color("b88c54"), Color("d1ad75"), 15)
			for i in 5:
				l.draw_line(tabla.position + Vector2(30 + i * 35, 15), tabla.position + Vector2(30 + i * 35, tabla.size.y - 15), Color("aa7c46"), 2)
			l.draw_line(tabla.get_center() - Vector2(20, 32), tabla.get_center() + Vector2(60, 15), Color("d9e1d8"), 14, true)
			l.draw_line(tabla.get_center() + Vector2(60, 15), tabla.get_center() + Vector2(95, 35), Color("5d5347"), 16, true)
			for i in 2:
				var pos := p + s * Vector2(0.7 + i * 0.15, 0.45)
				l.draw_circle(pos, 27, Color("e5dbc3"))
				l.draw_circle(pos, 17, Color("6f8970") if i == 0 else Color("b87551"))
		"alacena", "aparador", "consola", "ropero":
			var columnas := 3 if s.x > s.y * 2 else 2
			for i in columnas:
				var puerta := Rect2(p + Vector2(12 + i * (s.x - 24) / columnas, 8), Vector2((s.x - 24) / columnas - 8, s.y - 30))
				caja(l, puerta, c, c.darkened(0.22), 5)
				l.draw_rect(puerta.grow(-18), Color(c.lightened(0.25), 0.65), false, 3)
				var tirador := puerta.get_center() + Vector2(puerta.size.x * 0.28, 0)
				l.draw_line(tirador - Vector2(0, 18), tirador + Vector2(0, 18), Color("cfb47d"), 7, true)
			if m.tipo == "consola":
				_planta(l, Rect2(p + s * Vector2(0.08, 0.05), Vector2(170, 170)), Color("648467"))
				caja(l, Rect2(p + s * Vector2(0.7, 0.15), s * Vector2(0.18, 0.55)), Color("dfcba0"), Color("6e5d48"), 8)
		"sofa", "sillon":
			for uv in [Vector2(0.15, 0.40), Vector2(0.72, 0.42)]:
				var cojin := Rect2(p + s * uv, Vector2(minf(180, s.x * 0.22), s.y * 0.4))
				caja(l, cojin, Color("d7bc86"), Color("b8a077"), 20)
				l.draw_line(cojin.position + Vector2(14, 20), cojin.end - Vector2(14, 20), Color("ece0bf"), 5)
		"cama":
			for i in 2:
				var almohada := Rect2(p + Vector2(140 + i * 680, 160), Vector2(520, 220))
				caja(l, almohada.grow(-18), Color.TRANSPARENT, Color("ded5c2"), 28)
			for i in 5:
				var x := p.x + 140 + i * 280
				l.draw_line(Vector2(x, p.y + 760), Vector2(x, r.end.y - 65), Color(1, 1, 1, 0.12), 5)
		"heladera":
			l.draw_rect(Rect2(p + s * Vector2(0.1, 0.1), s * Vector2(0.55, 0.16)), Color(1, 1, 1, 0.12))
			l.draw_circle(p + Vector2(106, 282), 12, Color("a36b4b"))
			for i in 3:
				l.draw_line(p + Vector2(75, 322 + i * 20), p + Vector2(135, 322 + i * 20), Color("b5975e"), 3)
		"biblioteca":
			for i in 18:
				var horizontal := s.x > s.y
				var inicio := p + Vector2(24 + i * (s.x - 40) / 18, 48) if horizontal else p + Vector2(48, 24 + i * (s.y - 40) / 18)
				l.draw_line(inicio, inicio + (Vector2((s.x - 40) / 26, 0) if horizontal else Vector2(0, (s.y - 40) / 26)), Color("e1cda2"), 4)


static func _destino(l: CanvasItem) -> void:
	if Juego.lugar_actual == "restaurante":
		for m in PlanoCasa.muebles():
			if m.tipo == "mesa_comedor":
				var r: Rect2 = m.rect
				caja(l, r.grow(150), Color("927359"), Color("c3a077"), 24)
				l.draw_rect(r.grow(120), Color("b89870"), false, 5)
	elif Juego.lugar_actual == "museo":
		alfombra(l, Rect2(3350, 1220, 1450, 1650), Color("947764"))
		for m in PlanoCasa.muebles():
			if m.tipo == "vitrina":
				var r: Rect2 = m.rect
				l.draw_rect(r.grow(65), Color("b6a88f"), false, 7)
				l.draw_rect(Rect2(r.get_center() + Vector2(-70, r.size.y * 0.5 + 25), Vector2(140, 25)), Color("8c8068"))
	for a in PlanoCasa.ambientes():
		var r: Rect2 = a.rect
		l.draw_string(ThemeDB.fallback_font, r.position + Vector2(120, r.size.y - 120), l.tr(a.nombre), HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color(0.2, 0.2, 0.17, 0.35))
	if Juego.lugar_actual == "obelisco":
		for y in [-250, 2850]:
			l.draw_rect(Rect2(1750, y, 3200, 300), Color("8b8e82"))
			for x in range(1850, 4800, 310):
				l.draw_rect(Rect2(x, y + 35, 145, 230), Color("e8e2cb"))
		l.draw_arc(Vector2(3225, 1775), 1300, 0, TAU, 72, Color("ded7bf"), 35, true)
	elif Juego.lugar_actual == "coliseo":
		l.draw_set_transform(Vector2(3700, 1700), 0, Vector2(1.15, 1))
		for i in 4:
			l.draw_arc(Vector2.ZERO, 2050 - i * 160, 0, TAU, 96, Color("b59b75").lightened(i * 0.035), 58, true)
		l.draw_set_transform(Vector2.ZERO)
	elif Juego.lugar_actual == "eiffel":
		for x in [-650, 4700]:
			for y in [-600, 1700]:
				caja(l, Rect2(x, y, 1800, 1700), Color("77926c"), Color("c9c8ab"), 80)
		for y in [-300, 3400]:
			l.draw_rect(Rect2(1900, y, 2700, 180), Color("dfd4ba"))
	else:
		for a in PlanoCasa.ambientes():
			var r: Rect2 = a.rect
			l.draw_rect(r.grow(-70), Color(0.3, 0.24, 0.16, 0.12), false, 8)

static func _monumento(l: CanvasItem, m: Dictionary) -> void:
	var r: Rect2 = m.rect
	var p := r.position
	var s := r.size
	var c: Color = m.color
	caja(l, Rect2(p + Vector2(24, 34), s), Color(0.1, 0.09, 0.07, 0.2), Color.TRANSPARENT, 14)
	match m.tipo:
		"obelisco":
			caja(l, r, c.darkened(0.22), c.lightened(0.2), 8)
			var cuerpo := r.grow(-s.x * 0.18)
			l.draw_rect(cuerpo, c)
			l.draw_colored_polygon(PackedVector2Array([cuerpo.position, Vector2(cuerpo.get_center().x, p.y + 40), Vector2(cuerpo.end.x, cuerpo.position.y)]), c.lightened(0.25))
			l.draw_rect(Rect2(cuerpo.position.x + cuerpo.size.x * 0.5, cuerpo.position.y, cuerpo.size.x * 0.5, cuerpo.size.y), c.darkened(0.12))
			l.draw_rect(Rect2(p + s * Vector2(0.38, 0.65), s * Vector2(0.24, 0.12)), Color("a99877"))
		"torre":
			caja(l, r, Color("a99c80"), Color("d1c4a6"), 30)
			var cima := p + Vector2(s.x * 0.5, 35)
			for lado in [-1, 1]:
				var pie := p + Vector2(s.x * (0.5 + lado * 0.42), s.y - 70)
				l.draw_line(pie, cima, c.darkened(0.35), 95, true)
				l.draw_line(pie + Vector2(-lado * 70, 0), cima, c.lightened(0.1), 25, true)
			for i in range(1, 10):
				var t := i / 10.0
				var y := p.y + s.y * t
				var ancho := s.x * t * 0.42
				l.draw_line(Vector2(cima.x - ancho, y), Vector2(cima.x + ancho, y), c.darkened(0.3), 22, true)
				if i < 9:
					l.draw_line(Vector2(cima.x - ancho, y), Vector2(cima.x + ancho + 30, y + s.y * 0.1), c.darkened(0.3), 13, true)
			for t in [0.40, 0.72]:
				l.draw_rect(Rect2(p.x + s.x * (0.5 - t * 0.5), p.y + s.y * t, s.x * t, 65), c.lightened(0.2))
		"arco":
			caja(l, r, c, c.lightened(0.25), 18)
			for x in [0.22, 0.68]:
				caja(l, Rect2(p + Vector2(s.x * x, s.y * 0.32), Vector2(s.x * 0.18, s.y * 0.68)), c.darkened(0.5), Color.TRANSPARENT, 70)
			for i in 7:
				l.draw_line(p + Vector2(s.x * i / 7, 20), p + Vector2(s.x * i / 7, s.y * 0.3), c.darkened(0.2), 6)
		"escultura":
			caja(l, r, c.darkened(0.25), c.lightened(0.2), 25)
			caja(l, r.grow(-s.x * 0.12), c, c.lightened(0.2), 25)
			ovalo(l, Rect2(p + s * Vector2(0.3, 0.12), s * Vector2(0.4, 0.32)), c.lightened(0.2))
			l.draw_colored_polygon(PackedVector2Array([p + s * Vector2(0.32, 0.40), p + s * Vector2(0.7, 0.4), p + s * Vector2(0.82, 0.85), p + s * Vector2(0.18, 0.85)]), c.lightened(0.05))
		"vitrina":
			caja(l, r, c.darkened(0.3), c.lightened(0.3), 18)
			caja(l, r.grow(-35), c, Color("dbe9dc"), 12)
			for i in 3:
				l.draw_circle(p + Vector2(s.x * (i + 1) / 4, s.y * 0.5), s.y * 0.2, Color("cdbb89"))
			l.draw_line(p + Vector2(45, 45), r.end - Vector2(45, 45), Color(1, 1, 1, 0.35), 10, true)
