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
	for i in range(1, int(r.size.y / 75)):
		var y: float = r.position.y + i * 75
		l.draw_line(Vector2(r.position.x + 50, y), Vector2(r.end.x - 50, y), Color(1, 1, 1, 0.045), 3)
	for x in range(int(r.position.x) + 20, int(r.end.x), 28):
		l.draw_line(Vector2(x, r.position.y - 13), Vector2(x, r.position.y + 5), color.lightened(0.15), 5)
		l.draw_line(Vector2(x, r.end.y - 5), Vector2(x, r.end.y + 13), color.lightened(0.15), 5)

static func dibujar(l: CanvasItem) -> void:
	# Umbrales y alfombras pertenecen al suelo y no bloquean el paso.
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
		l.draw_string(ThemeDB.fallback_font, r.position + Vector2(120, r.size.y - 110), a.nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 68, Color(0.25, 0.24, 0.21, 0.38))
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
	for pared in PlanoCasa.PAREDES:
		l.draw_rect(Rect2(pared.position + Vector2(12, 22), pared.size + Vector2(5, 8)), Color(0.12, 0.12, 0.1, 0.18))
		l.draw_rect(pared, Color("857e6f"))
		l.draw_rect(pared.grow(-7), Color("ede7d6"))
		l.draw_line(pared.position + Vector2(4, 4), Vector2(pared.end.x - 4, pared.position.y + 4), Color("faf6e9"), 5)
	# Ventanas en los muros exteriores.
	for r in [Rect2(-650, -1010, 840, 65), Rect2(5000, -1010, 1060, 65), Rect2(-400, 4530, 960, 65), Rect2(5700, 4530, 780, 65)]:
		l.draw_rect(r.grow(8), Color("6f8889"))
		l.draw_rect(r, Color("bad8d7"))
		for i in 4:
			var x: float = r.position.x + r.size.x * i / 3
			l.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color("f2eee0"), 9)
	# Una hoja de puerta abierta y su arco de giro dejan clara la conexión.
	l.draw_arc(Vector2(1700, -100), 410, 0, PI * 0.5, 40, Color(0.37, 0.29, 0.2, 0.28), 4, true)
	l.draw_line(Vector2(1700, -100), Vector2(2100, -100), Color("a78660"), 19, true)
	l.draw_arc(Vector2(200, 2050), 460, 0, PI * 0.5, 40, Color(0.37, 0.29, 0.2, 0.22), 4, true)
	l.draw_line(Vector2(200, 2050), Vector2(200, 2500), Color("b49371"), 18, true)

static func mueble(l: CanvasItem, m: Dictionary) -> void:
	var r: Rect2 = m.rect
	var c: Color = m.color
	var p := r.position
	var s := r.size
	caja(l, Rect2(p + Vector2(14, 23), s), Color(0.15, 0.1, 0.06, 0.23), Color.TRANSPARENT, 20)
	caja(l, r, c.darkened(0.25), c.darkened(0.4), 18)
	var tapa := Rect2(p - Vector2(0, 10), s)
	caja(l, tapa.grow(-5), c, c.lightened(0.16), 14)
	match m.tipo:
		"mesa", "mesa_comedor", "ratona", "escritorio", "mesita":
			for i in range(1, int(s.y / 65)):
				var y: float = p.y + i * 65
				l.draw_line(Vector2(p.x + 20, y), Vector2(r.end.x - 20, y), c.darkened(0.15), 3)
			for esquina in [p + Vector2(30, 30), p + Vector2(s.x - 30, 30), p + Vector2(30, s.y - 30), r.end - Vector2(30, 30)]:
				l.draw_circle(esquina, 9, c.darkened(0.22))
			if m.tipo == "mesa_comedor":
				for pos in [Vector2(240, 190), Vector2(240, 580), Vector2(1050, 190), Vector2(1050, 580)]:
					l.draw_circle(p + pos, 107, Color("eeead7"))
					l.draw_arc(p + pos, 87, 0, TAU, 40, Color("a1b3a5"), 5, true)
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
		"silla":
			caja(l, r.grow(-18), c.darkened(0.15), c.lightened(0.15), 18)
			var respaldo := Rect2(p + Vector2(16, 12), Vector2(s.x - 32, s.y * 0.26))
			var asiento := Rect2(p + Vector2(25, s.y * 0.37), Vector2(s.x - 50, s.y * 0.48))
			match m.get("frente", "sur"):
				"norte":
					respaldo = Rect2(p + Vector2(16, s.y * 0.74), Vector2(s.x - 32, s.y * 0.20))
					asiento = Rect2(p + Vector2(25, s.y * 0.12), Vector2(s.x - 50, s.y * 0.48))
				"este":
					respaldo = Rect2(p + Vector2(12, 16), Vector2(s.x * 0.24, s.y - 32))
					asiento = Rect2(p + Vector2(s.x * 0.37, 25), Vector2(s.x * 0.48, s.y - 50))
				"oeste":
					respaldo = Rect2(p + Vector2(s.x * 0.74, 16), Vector2(s.x * 0.20, s.y - 32))
					asiento = Rect2(p + Vector2(s.x * 0.12, 25), Vector2(s.x * 0.48, s.y - 50))
			caja(l, respaldo, c.darkened(0.3), Color.TRANSPARENT, 13)
			caja(l, asiento, c.lightened(0.1), c.darkened(0.15), 18)
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
		"planta":
			ovalo(l, r.grow(-25), Color("9a7257"))
			for i in 8:
				var centro := r.get_center() + Vector2.from_angle(i * TAU / 8) * s.x * 0.23
				ovalo(l, Rect2(centro - Vector2(48, 65), Vector2(96, 130)), c.lightened((i % 3) * 0.06))
			l.draw_circle(r.get_center(), 45, c.darkened(0.25))
