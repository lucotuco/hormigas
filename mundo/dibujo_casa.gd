class_name DibujoCasa
extends RefCounted
## Ilustración cenital: materiales, volúmenes, tapizados y objetos domésticos.

static func caja(l: CanvasItem, r: Rect2, color: Color, borde := Color.TRANSPARENT, radio := 14.0) -> void:
	if not r.has_area():
		return
	var radio_valido := int(minf(radio, minf(r.size.x, r.size.y) * 0.5))
	l.draw_style_box(Estilo.caja(color, radio_valido, borde, 3 if borde.a > 0 else 0, 0), r)

static func ovalo(l: CanvasItem, r: Rect2, color: Color) -> void:
	l.draw_set_transform(r.get_center(), 0, r.size * 0.5)
	l.draw_circle(Vector2.ZERO, 1, color)
	l.draw_set_transform(Vector2.ZERO)

static func alfombra(l: CanvasItem, r: Rect2, color: Color) -> void:
	caja(l, Rect2(r.position + Vector2(12, 18), r.size), Color(0.1, 0.08, 0.06, 0.12), Color.TRANSPARENT, 28)
	caja(l, r, color, color.darkened(0.2), 24)
	ArteCasa.alfombra(l, r.grow(-5), color)
	for x in range(int(r.position.x) + 20, int(r.end.x), 28):
		l.draw_line(Vector2(x, r.position.y - 13), Vector2(x, r.position.y + 5), color.lightened(0.15), 5)
		l.draw_line(Vector2(x, r.end.y - 5), Vector2(x, r.end.y + 13), color.lightened(0.15), 5)

static func dibujar(l: CanvasItem, incluir_piezas := true) -> void:
	EntornoMapa.dibujar(l)
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

static func pared(l: CanvasItem, rect: Rect2, con_sombra := true) -> void:
	if con_sombra:
		l.draw_rect(Rect2(rect.position + Vector2(12, 22), rect.size + Vector2(5, 8)), Color(0.12, 0.12, 0.1, 0.18))
	l.draw_rect(rect, Color("857e6f"))
	l.draw_rect(rect.grow(-7), Color("ede7d6"))
	l.draw_line(rect.position + Vector2(4, 4), Vector2(rect.end.x - 4, rect.position.y + 4), Color("faf6e9"), 5)
	if rect.size.x > rect.size.y:
		l.draw_line(Vector2(rect.position.x, rect.end.y - 4), rect.end - Vector2(0, 4), Color("b4a58d"), 6)
	else:
		l.draw_line(Vector2(rect.end.x - 4, rect.position.y), rect.end - Vector2(4, 0), Color("b4a58d"), 6)

static func mueble(l: CanvasItem, m: Dictionary) -> void:
	if ArteCasa.dibujar(l, m):
		return
	if m.get("acabado", "") == "carton":
		_silla(l, m)
	elif m.tipo in ArteCasa.ILUSTRADOS:
		_ilustrado(l, m)
	else:
		_monumento(l, m)


static func _volumen(l: CanvasItem, r: Rect2, color: Color, radio: float) -> void:
	# Luz de arriba a la izquierda y apoyo corto abajo a la derecha en todas
	# las piezas. Estas capas se hornean una sola vez, junto con los detalles.
	caja(l, Rect2(r.position + Vector2(9, 14), r.size).grow(3), Color(0.19, 0.16, 0.11, 0.10), Color.TRANSPARENT, radio + 3)
	caja(l, Rect2(r.position + Vector2(3, 6), r.size), color.darkened(0.30), Color.TRANSPARENT, radio)
	caja(l, r, color, color.darkened(0.25), radio)
	var margen := maxf(8, minf(r.size.x, r.size.y) * 0.035)
	l.draw_line(r.position + Vector2(radio, margen), Vector2(r.end.x - radio, r.position.y + margen), Color(color.lightened(0.28), 0.65), 3, true)


static func _veta_suave(l: CanvasItem, r: Rect2, color: Color) -> void:
	for i in 3:
		var y := r.position.y + r.size.y * (0.25 + i * 0.23)
		var x := r.position.x + r.size.x * (0.12 + (i % 2) * 0.11)
		l.draw_polyline(PackedVector2Array([Vector2(x, y), Vector2(x + r.size.x * 0.28, y - 3), Vector2(x + r.size.x * 0.55, y + 2)]), Color(color.darkened(0.32), 0.20), 2, true)


static func _taza_ilustrada(l: CanvasItem, centro: Vector2, radio: float) -> void:
	_plato(l, centro, radio * 1.3)
	l.draw_arc(centro + Vector2(radio * 0.8, 0), radio * 0.42, -PI * 0.55, PI * 0.55, 16, Color("e8dfc9"), radio * 0.20, true)
	l.draw_circle(centro, radio, Color("f1e8d5"))
	l.draw_circle(centro, radio * 0.73, Color("6e4f36"))
	l.draw_arc(centro, radio * 0.68, -2.8, -1.3, 12, Color("ad8155"), maxf(2, radio * 0.08), true)


static func _ilustrado(l: CanvasItem, m: Dictionary) -> void:
	var r: Rect2 = m.rect
	var p := r.position
	var s := r.size
	var menor := minf(s.x, s.y)
	var c: Color = m.color
	var madera := c.lerp(Color("b88f62"), 0.50)
	var loza := Color("e5dfcd")
	var metal := Color("899c94")
	match m.tipo:
		"canasto", "carrito", "kiosco", "colectivo", "taxi", "farol", "papelera", "cartel", "columna", "anfora", "fuente":
			_urbano(l, m)
		"silla", "planta", "inodoro":
			_perfil_ilustrado(l, m)
		"mesa", "mesa_comedor", "ratona", "escritorio", "mesita", "banco":
			_volumen(l, r.grow(-5), madera, menor * 0.07)
			_veta_suave(l, r, madera)
			if m.tipo == "mesa_comedor":
				caja(l, Rect2(p + s * Vector2(0.44, 0.08), s * Vector2(0.12, 0.84)), Color("b8b69a"), Color("d0ccb2"), 6)
				for uv in [Vector2(0.20, 0.25), Vector2(0.20, 0.75), Vector2(0.80, 0.25), Vector2(0.80, 0.75)]:
					var centro: Vector2 = p + s * uv
					_plato(l, centro, menor * 0.105)
					l.draw_line(centro + Vector2(-menor * 0.15, -menor * 0.09), centro + Vector2(-menor * 0.15, menor * 0.09), metal, 6, true)
					l.draw_line(centro + Vector2(menor * 0.15, -menor * 0.09), centro + Vector2(menor * 0.15, menor * 0.09), metal, 7, true)
				l.draw_circle(r.get_center(), menor * 0.075, Color("c4b58d"))
				for i in 3:
					l.draw_circle(r.get_center() + Vector2.from_angle(i * TAU / 3) * menor * 0.036, menor * 0.035, Color("b98757") if i == 0 else Color("95a16b"))
			elif m.tipo == "escritorio":
				var equipo := Rect2(p + s * Vector2(0.42, 0.14), s * Vector2(0.43, 0.69))
				caja(l, equipo, Color("78857d"), Color("56645d"), 12)
				caja(l, Rect2(equipo.position + equipo.size * Vector2(0.06, 0.05), equipo.size * Vector2(0.88, 0.55)), Color("a7bdb2"), Color("d1d8c8"), 6)
				for i in 3:
					l.draw_line(equipo.position + equipo.size * Vector2(0.12, 0.70 + i * 0.08), equipo.position + equipo.size * Vector2(0.88, 0.70 + i * 0.08), Color("bdc5b7"), 5)
				var libreta := Rect2(p + s * Vector2(0.10, 0.28), s * Vector2(0.22, 0.53))
				caja(l, libreta, Color("e4d8b8"), Color("9d8d69"), 5)
				for i in 3:
					l.draw_line(libreta.position + libreta.size * Vector2(0.15, 0.25 + i * 0.20), libreta.position + libreta.size * Vector2(0.80, 0.25 + i * 0.20), Color("b8ae91"), 3)
			elif m.tipo == "ratona":
				var libro := Rect2(p + s * Vector2(0.12, 0.17), s * Vector2(0.29, 0.64))
				caja(l, libro, Color("81968a"), Color("5d7267"), 7)
				l.draw_line(libro.position + Vector2(12, 8), Vector2(libro.position.x + 12, libro.end.y - 8), Color("c7ceb7"), 4)
				_taza_ilustrada(l, p + s * Vector2(0.73, 0.46), menor * 0.10)
			elif m.tipo == "mesa":
				caja(l, Rect2(p + s * Vector2(0.12, 0.19), s * Vector2(0.27, 0.58)), Color("ded4b7"), Color("c2b495"), 6)
				l.draw_line(p + s * Vector2(0.16, 0.27), p + s * Vector2(0.34, 0.27), Color("c5b99b"), 3)
				_taza_ilustrada(l, p + s * Vector2(0.70, 0.46), menor * 0.11)
			elif m.tipo == "mesita":
				l.draw_circle(p + s * Vector2(0.42, 0.40), menor * 0.19, Color("b9aa82"))
				l.draw_circle(p + s * Vector2(0.42, 0.40), menor * 0.14, Color("e3d3a6"))
				l.draw_arc(p + s * Vector2(0.42, 0.40), menor * 0.11, -2.8, -0.8, 18, Color("f0e3c3"), 4, true)
			elif m.tipo == "banco":
				for i in 3:
					l.draw_line(p + s * Vector2(0.03, 0.25 + i * 0.25), p + s * Vector2(0.97, 0.25 + i * 0.25), madera.darkened(0.23), 5)
				for x in [0.11, 0.87]:
					caja(l, Rect2(p + s * Vector2(x, 0.05), s * Vector2(0.025, 0.90)), Color("586c60"), Color("859687"), 5)
		"alacena", "aparador", "consola", "ropero", "biblioteca":
			_volumen(l, r.grow(-3), madera, menor * 0.045)
			if m.tipo == "biblioteca":
				var horizontal := s.x >= s.y
				caja(l, r.grow(-menor * 0.12), madera.darkened(0.35), Color.TRANSPARENT, 4)
				var colores := [Color("9d735a"), Color("899c90"), Color("c4b183"), Color("ac9a93"), Color("d0c6aa")]
				for i in 13:
					var libro := Rect2(p + s * Vector2(0.06 + i * 0.068, 0.20), s * Vector2(0.052, 0.61)) if horizontal else Rect2(p + s * Vector2(0.20, 0.06 + i * 0.068), s * Vector2(0.61, 0.052))
					caja(l, libro, colores[i % colores.size()], colores[i % colores.size()].darkened(0.18), 2)
			else:
				var columnas := 3 if s.x > s.y * 2 else 2
				for i in columnas:
					var puerta := Rect2(p + Vector2(s.x * (0.04 + i * 0.92 / columnas), s.y * 0.09), Vector2(s.x * 0.92 / columnas - s.x * 0.025, s.y * 0.79))
					caja(l, puerta, madera.lightened(0.035), madera.darkened(0.19), menor * 0.025)
					l.draw_line(puerta.position + puerta.size * Vector2(0.79, 0.39), puerta.position + puerta.size * Vector2(0.79, 0.62), Color("dbc18b"), maxf(5, menor * 0.023), true)
		"sofa", "sillon":
			_volumen(l, r.grow(-4), c.darkened(0.16), menor * 0.10)
			caja(l, Rect2(p + s * Vector2(0.04, 0.04), s * Vector2(0.92, 0.24)), c, c.lightened(0.17), menor * 0.08)
			var asientos := 3 if m.tipo == "sofa" else 1
			for i in asientos:
				var ancho := 0.78 / asientos
				var asiento := Rect2(p + s * Vector2(0.11 + i * ancho, 0.33), s * Vector2(ancho - 0.015, 0.58))
				caja(l, asiento, c.lightened(0.06), c.darkened(0.17), menor * 0.065)
				caja(l, asiento.grow(-menor * 0.025), Color.TRANSPARENT, Color(c.lightened(0.23), 0.4), menor * 0.045)
			for x in [0.025, 0.90]:
				caja(l, Rect2(p + s * Vector2(x, 0.16), s * Vector2(0.075, 0.76)), c.lightened(0.035), c.darkened(0.15), menor * 0.07)
			caja(l, Rect2(p + s * Vector2(0.13, 0.28), s * Vector2(0.17 if asientos == 3 else 0.40, 0.24)), Color("d6c79f"), Color("b6a883"), menor * 0.05)
		"cama":
			_volumen(l, r.grow(-8), Color("b29676"), menor * 0.035)
			caja(l, r.grow(-menor * 0.035), loza, Color("c4b89f"), menor * 0.055)
			caja(l, Rect2(p + s * Vector2(0.02, 0.015), s * Vector2(0.96, 0.065)), Color("a58461"), Color("c3a17a"), 14)
			for i in 2:
				var almohada := Rect2(p + s * Vector2(0.13 + i * 0.42, 0.13), s * Vector2(0.32, 0.19))
				caja(l, Rect2(almohada.position + Vector2(4, 7), almohada.size), Color("d2c8b0"), Color.TRANSPARENT, menor * 0.035)
				caja(l, almohada, Color("f0e8d5"), Color("d7cdb6"), menor * 0.035)
			caja(l, Rect2(p + s * Vector2(0.055, 0.38), s * Vector2(0.89, 0.57)), c, c.darkened(0.18), menor * 0.025)
			caja(l, Rect2(p + s * Vector2(0.055, 0.38), s * Vector2(0.89, 0.10)), c.lightened(0.18), Color.TRANSPARENT, 12)
			for i in 3:
				l.draw_line(p + s * Vector2(0.23 + i * 0.27, 0.51), p + s * Vector2(0.23 + i * 0.27, 0.91), Color(c.lightened(0.20), 0.22), 5, true)
		"pileta", "lavabo", "mesada", "cocina":
			_volumen(l, r.grow(-3), loza if m.tipo != "pileta" else Color("b9c4b9"), menor * 0.06)
			if m.tipo in ["pileta", "lavabo"]:
				var pileta := Rect2(p + s * Vector2(0.20, 0.20), s * Vector2(0.60, 0.65))
				caja(l, pileta, metal, Color("f0ead8"), menor * 0.13)
				caja(l, pileta.grow(-menor * 0.055), Color("b6c8bd"), Color("718b82"), menor * 0.09)
				l.draw_circle(pileta.get_center() + Vector2(0, menor * 0.07), menor * 0.035, Color("6c8478"))
				l.draw_arc(p + s * Vector2(0.51, 0.22), menor * 0.13, PI, TAU, 18, Color("84988e"), menor * 0.04, true)
			elif m.tipo == "cocina":
				for i in 4:
					var centro := p + s * Vector2(0.27 + (i % 2) * 0.46, 0.25 + (i / 2) * 0.40)
					l.draw_circle(centro, menor * 0.15, Color("48564d"))
					l.draw_arc(centro, menor * 0.10, 0, TAU, 20, Color("78897c"), 4, true)
				for i in 4:
					l.draw_circle(p + s * Vector2(0.30 + i * 0.135, 0.91), menor * 0.025, metal)
			else:
				var tabla := Rect2(p + s * Vector2(0.10, 0.16), s * Vector2(0.43, 0.67))
				_volumen(l, tabla, Color("c19b68"), 12)
				_veta_suave(l, tabla, Color("c19b68"))
				l.draw_line(tabla.position + tabla.size * Vector2(0.24, 0.35), tabla.position + tabla.size * Vector2(0.62, 0.65), Color("d9dec9"), menor * 0.045, true)
				l.draw_line(tabla.position + tabla.size * Vector2(0.62, 0.65), tabla.position + tabla.size * Vector2(0.81, 0.80), Color("655b47"), menor * 0.05, true)
				for i in 2:
					l.draw_circle(p + s * Vector2(0.70 + i * 0.14, 0.48), menor * 0.08, Color("b97b56") if i == 0 else Color("899768"))
		"heladera":
			_volumen(l, r.grow(-4), loza, menor * 0.06)
			l.draw_line(p + s * Vector2(0.05, 0.32), p + s * Vector2(0.95, 0.32), Color("b0b8a7"), 6)
			for y in [0.15, 0.52]:
				caja(l, Rect2(p + s * Vector2(0.82, y), s * Vector2(0.055, 0.15)), metal, Color("647d70"), 5)
			caja(l, Rect2(p + s * Vector2(0.14, 0.42), s * Vector2(0.29, 0.20)), Color("d7c396"), Color.TRANSPARENT, 3)
			l.draw_circle(p + s * Vector2(0.285, 0.43), menor * 0.025, Color("a56f56"))
		"television":
			_volumen(l, r.grow(-4), madera, menor * 0.07)
			var pantalla := Rect2(p + s * Vector2(0.11, 0.08), s * Vector2(0.78, 0.59))
			caja(l, pantalla, Color("344a40"), Color("5e7367"), 12)
			l.draw_line(pantalla.position + pantalla.size * Vector2(0.12, 0.20), pantalla.position + pantalla.size * Vector2(0.40, 0.20), Color("566d5d"), 5, true)
			l.draw_line(p + s * Vector2(0.43, 0.77), p + s * Vector2(0.57, 0.77), Color("566b5e"), 9, true)
		"banera":
			_volumen(l, r.grow(-menor * 0.025), loza, menor * 0.40)
			caja(l, r.grow(-menor * 0.12), Color("9ebeb4"), Color("f3ecdc"), menor * 0.30)
			caja(l, r.grow(-menor * 0.17), Color("b1cdc0"), Color("8daea2"), menor * 0.25)
			l.draw_circle(p + s * Vector2(0.76, 0.50), menor * 0.025, Color("7e9c8f"))
			l.draw_arc(p + s * Vector2(0.12, 0.50), menor * 0.065, -PI * 0.5, PI * 0.5, 18, metal, menor * 0.022, true)
		"lavarropas":
			_volumen(l, r.grow(-5), Color("d0dcd0"), menor * 0.055)
			l.draw_line(p + s * Vector2(0.04, 0.17), p + s * Vector2(0.96, 0.17), Color("abbfae"), 5)
			var centro := p + s * Vector2(0.50, 0.59)
			l.draw_circle(centro, menor * 0.28, metal)
			l.draw_circle(centro, menor * 0.23, Color("5e8278"))
			l.draw_circle(centro + Vector2(-menor * 0.015, -menor * 0.02), menor * 0.17, Color("9bbcb0"))
			l.draw_arc(centro, menor * 0.205, -2.7, -1.0, 18, Color("c5d8c4"), 5, true)
			l.draw_circle(p + s * Vector2(0.84, 0.09), menor * 0.035, metal)
		"vitrina":
			_volumen(l, r.grow(-3), madera, menor * 0.045)
			caja(l, r.grow(-menor * 0.07), Color("a3bbb0"), Color("d8dfcb"), menor * 0.035)
			for i in 3:
				var centro := p + s * Vector2(0.25 + i * 0.25, 0.53)
				l.draw_circle(centro, menor * 0.12, Color("c7b58a"))
				l.draw_arc(centro, menor * 0.085, -2.6, -0.6, 14, Color("e2d0a7"), 4, true)
			l.draw_line(p + s * Vector2(0.15, 0.16), p + s * Vector2(0.40, 0.16), Color("dce7d5"), 5, true)


static func _rect_frente(r: Rect2, frente: String) -> Rect2:
	match frente:
		"norte": return Rect2(Vector2.ONE - r.end, r.size)
		"este": return Rect2(Vector2(r.position.y, 1.0 - r.end.x), Vector2(r.size.y, r.size.x))
		"oeste": return Rect2(Vector2(1.0 - r.end.y, r.position.x), Vector2(r.size.y, r.size.x))
	return r


static func _perfil_ilustrado(l: CanvasItem, m: Dictionary) -> void:
	var r: Rect2 = m.rect
	var p := r.position
	var s := r.size
	var menor := minf(s.x, s.y)
	var c: Color = m.color
	var base := Color("897354") if m.tipo == "silla" else (Color("6c845d") if m.tipo == "planta" else Color("dedaca"))
	# El contorno de autoría es estable, no depende de la máscara exportada
	# desde este mismo dibujo. Así regenerar el atlas no deforma el mueble.
	var datos := m.duplicate()
	datos.rect = Rect2(0, 0, 1, 1)
	datos.frente = "sur"
	var bandas := SiluetaMueble.perfil_base(datos)
	var contorno := PackedVector2Array()
	contorno.append(Vector2(bandas[0].position.x, bandas[0].position.y))
	for banda in bandas:
		contorno.append(Vector2(banda.position.x, banda.get_center().y))
	contorno.append(Vector2(bandas.back().position.x, bandas.back().end.y))
	contorno.append(bandas.back().end)
	for i in range(bandas.size() - 1, -1, -1):
		contorno.append(Vector2(bandas[i].end.x, bandas[i].get_center().y))
	contorno.append(Vector2(bandas[0].end.x, bandas[0].position.y))
	var frente: String = m.get("frente", "sur") if m.tipo == "silla" else "sur"
	for i in contorno.size():
		var normalizado := _rect_frente(Rect2(contorno[i], Vector2.ZERO), frente).position
		contorno[i] = p + s * normalizado
	var sombra := PackedVector2Array()
	for punto in contorno:
		sombra.append(punto + Vector2(5, 8))
	l.draw_colored_polygon(sombra, Color(0.17, 0.15, 0.10, 0.14))
	l.draw_colored_polygon(contorno, base)
	l.draw_polyline(contorno + PackedVector2Array([contorno[0]]), base.darkened(0.18), 2, true)
	if m.tipo == "silla":
		for detalle in [{"rect": Rect2(0.13, 0.08, 0.56, 0.16), "color": c.darkened(0.20)}, {"rect": Rect2(0.14, 0.29, 0.53, 0.43), "color": c}, {"rect": Rect2(0.18, 0.33, 0.45, 0.35), "color": c.lightened(0.07)}]:
			var normalizado := _rect_frente(detalle.rect, frente)
			caja(l, Rect2(p + normalizado.position * s, normalizado.size * s), detalle.color, Color(base.lightened(0.20), 0.8), menor * 0.04)
	elif m.tipo == "inodoro":
		caja(l, Rect2(p + s * Vector2(0.13, 0.025), s * Vector2(0.56, 0.19)), Color("ece5d2"), Color("c5c5b4"), menor * 0.045)
		l.draw_circle(p + s * Vector2(0.57, 0.10), menor * 0.035, Color("98a99b"))
		ovalo(l, Rect2(p + s * Vector2(0.20, 0.35), s * Vector2(0.44, 0.45)), Color("f0e9d6"))
		ovalo(l, Rect2(p + s * Vector2(0.25, 0.40), s * Vector2(0.34, 0.34)), Color("c8d4c2"))
		ovalo(l, Rect2(p + s * Vector2(0.29, 0.44), s * Vector2(0.26, 0.25)), Color("b2c7b6"))
	else:
		# Grupos de hojas grandes, sin ruido fotográfico ni brillos puntuales.
		for hoja in [{"a": Vector2(0.42, 0.48), "b": Vector2(0.38, 0.07), "c": Vector2(0.50, 0.37)}, {"a": Vector2(0.42, 0.47), "b": Vector2(0.20, 0.15), "c": Vector2(0.35, 0.42)}, {"a": Vector2(0.44, 0.48), "b": Vector2(0.76, 0.18), "c": Vector2(0.58, 0.47)}, {"a": Vector2(0.42, 0.50), "b": Vector2(0.09, 0.39), "c": Vector2(0.30, 0.61)}, {"a": Vector2(0.45, 0.50), "b": Vector2(0.77, 0.49), "c": Vector2(0.57, 0.67)}, {"a": Vector2(0.43, 0.49), "b": Vector2(0.24, 0.70), "c": Vector2(0.39, 0.80)}, {"a": Vector2(0.44, 0.51), "b": Vector2(0.66, 0.69), "c": Vector2(0.48, 0.84)}]:
			l.draw_colored_polygon(PackedVector2Array([p + s * hoja.a, p + s * hoja.b, p + s * hoja.c]), c.lightened(0.07))
			l.draw_line(p + s * hoja.a, p + s * hoja.b, Color("a0b183"), 2, true)


static func _urbano(l: CanvasItem, m: Dictionary) -> void:
	# Estos tipos se comparten entre escenarios y se hornean por acabado,
	# nunca se agregan nodos para libros, ruedas, agua o accesorios.
	var r: Rect2 = m.rect
	var p := r.position
	var s := r.size
	var menor := minf(s.x, s.y)
	var c: Color = m.color
	match m.tipo:
		"canasto":
			_volumen(l, r.grow(-3), c.darkened(0.13), menor * 0.12)
			caja(l, r.grow(-menor * 0.07), c, c.lightened(0.24), menor * 0.10)
			for i in 4:
				l.draw_line(p + s * Vector2(0.10, 0.25 + i * 0.17), p + s * Vector2(0.90, 0.25 + i * 0.17), Color(c.darkened(0.3), 0.28), 4, true)
			for i in 3:
				caja(l, Rect2(p + s * Vector2(0.17 + i * 0.21, 0.20 + (i % 2) * 0.12), s * Vector2(0.25, 0.53)), [Color("dbd3b8"), Color("b4c0a9"), Color("d3bc95")][i], Color(c.darkened(0.3), 0.3), menor * 0.07)
		"carrito":
			for x in [0.10, 0.80]:
				for y in [0.04, 0.82]:
					caja(l, Rect2(p + s * Vector2(x, y), s * Vector2(0.10, 0.13)), Color("5a685b"), Color.TRANSPARENT, menor * 0.04)
			_volumen(l, r.grow(-menor * 0.06), c, menor * 0.06)
			caja(l, r.grow(-menor * 0.11), Color("c9bc99"), c.darkened(0.15), menor * 0.04)
			_plato(l, p + s * Vector2(0.32, 0.50), menor * 0.16)
			_taza_ilustrada(l, p + s * Vector2(0.69, 0.40), menor * 0.10)
			l.draw_line(p + s * Vector2(0.88, 0.22), p + s * Vector2(0.88, 0.76), Color("738676"), 7, true)
		"kiosco":
			_volumen(l, r.grow(-4), c.darkened(0.10), menor * 0.045)
			var libros: bool = m.get("acabado", "") == "libros"
			caja(l, Rect2(p + s * Vector2(0.03, 0.03), s * Vector2(0.94, 0.27)), c.darkened(0.15), c.lightened(0.23), menor * 0.045)
			var rotulo := l.tr("LIBROS") if libros else l.tr("DIARIOS")
			l.draw_string(ThemeDB.fallback_font, p + s * Vector2(0.17, 0.23), rotulo, HORIZONTAL_ALIGNMENT_CENTER, s.x * 0.66, int(menor * 0.13), Color("e2d6b5"))
			caja(l, Rect2(p + s * Vector2(0.07, 0.38), s * Vector2(0.86, 0.49)), Color("b3956c"), Color("d2bb92"), 5)
			var colores := [Color("e1d6ba"), Color("a5b29c"), Color("c49a7a"), Color("c8b784"), Color("9eaaa0")]
			for i in 5:
				var hoja := Rect2(p + s * Vector2(0.10 + i * 0.165, 0.43 + (i % 2) * 0.04), s * Vector2(0.13, 0.33))
				caja(l, hoja, colores[i] if libros else Color("e3dbc3"), Color("9e977e"), 3)
				l.draw_line(hoja.position + hoja.size * Vector2(0.15, 0.25), hoja.position + hoja.size * Vector2(0.85, 0.25), Color("939a82"), 3, true)
				if not libros:
					l.draw_line(hoja.position + hoja.size * Vector2(0.15, 0.45), hoja.position + hoja.size * Vector2(0.85, 0.45), Color("b0ad94"), 2, true)
		"colectivo", "taxi":
			for x in [0.12, 0.76]:
				for y in [0.0, 0.82]:
					caja(l, Rect2(p + s * Vector2(x, y), s * Vector2(0.10, 0.18)), Color("444c41"), Color.TRANSPARENT, menor * 0.055)
			_volumen(l, Rect2(p + s * Vector2(0.015, 0.06), s * Vector2(0.97, 0.88)), c, menor * 0.18)
			if m.tipo == "colectivo":
				caja(l, Rect2(p + s * Vector2(0.07, 0.23), s * Vector2(0.77, 0.54)), Color("d4bb86"), Color("b99065"), menor * 0.09)
				for i in 5:
					caja(l, Rect2(p + s * Vector2(0.10 + i * 0.145, 0.27), s * Vector2(0.12, 0.44)), Color("92aca0"), Color("d6dbc0"), menor * 0.035)
				caja(l, Rect2(p + s * Vector2(0.88, 0.18), s * Vector2(0.065, 0.64)), Color("869e91"), Color("c5ceba"), 5)
			else:
				caja(l, Rect2(p + s * Vector2(0.33, 0.18), s * Vector2(0.37, 0.64)), Color("d2b56e"), Color("e2c989"), menor * 0.11)
				for x in [0.18, 0.73]:
					caja(l, Rect2(p + s * Vector2(x, 0.20), s * Vector2(0.12, 0.60)), Color("9fb5a6"), Color("b7c4ae"), menor * 0.05)
				l.draw_string(ThemeDB.fallback_font, p + s * Vector2(0.39, 0.58), l.tr("TAXI"), HORIZONTAL_ALIGNMENT_CENTER, s.x * 0.24, int(menor * 0.16), Color("4e5c49"))
		"papelera":
			_volumen(l, r.grow(-5), c, menor * 0.15)
			ovalo(l, Rect2(p + s * Vector2(0.12, 0.08), s * Vector2(0.76, 0.27)), Color("4f624f"))
			for i in 4:
				l.draw_line(p + s * Vector2(0.20 + i * 0.20, 0.42), p + s * Vector2(0.20 + i * 0.20, 0.85), Color(c.lightened(0.18), 0.8), 4, true)
		"farol", "cartel":
			caja(l, Rect2(p + s * Vector2(0.28, 0.90), s * Vector2(0.44, 0.08)), c.darkened(0.16), c.lightened(0.08), 4)
			caja(l, Rect2(p + s * Vector2(0.44, 0.30), s * Vector2(0.12, 0.62)), c, Color.TRANSPARENT, 3)
			if m.tipo == "farol":
				caja(l, Rect2(p + s * Vector2(0.20, 0.03), s * Vector2(0.60, 0.29)), c.darkened(0.16), c.lightened(0.18), 6)
				caja(l, Rect2(p + s * Vector2(0.31, 0.07), s * Vector2(0.38, 0.21)), Color("d9c895"), Color("aab08b"), 4)
				l.draw_line(p + s * Vector2(0.50, 0.08), p + s * Vector2(0.50, 0.27), c, 3)
			else:
				caja(l, Rect2(p + s * Vector2(0.02, 0.03), s * Vector2(0.96, 0.33)), c, Color("c6d0b6"), 6)
				l.draw_string(ThemeDB.fallback_font, p + s * Vector2(0.08, 0.25), l.tr("9 DE JULIO"), HORIZONTAL_ALIGNMENT_CENTER, s.x * 0.84, int(s.y * 0.105), Color("e4e1cb"))
		"columna", "fuente":
			ovalo(l, Rect2(p + s * Vector2(0.03, 0.03) + Vector2(7, 10), s * 0.94), Color(0.18, 0.16, 0.11, 0.14))
			ovalo(l, Rect2(p + s * Vector2(0.03, 0.03), s * 0.94), c.darkened(0.19))
			ovalo(l, Rect2(p + s * Vector2(0.07, 0.07), s * 0.86), c.lightened(0.12))
			if m.tipo == "fuente":
				ovalo(l, Rect2(p + s * Vector2(0.14, 0.14), s * 0.72), Color("8da99b"))
				ovalo(l, Rect2(p + s * Vector2(0.18, 0.18), s * 0.64), Color("b1c8b5"))
				for i in 2:
					l.draw_arc(r.get_center(), menor * (0.20 + i * 0.08), -2.7, -0.7, 24, Color("cad8c0"), 4, true)
				l.draw_circle(r.get_center(), menor * 0.09, c.darkened(0.10))
				l.draw_circle(r.get_center() - Vector2(2, 3), menor * 0.055, c.lightened(0.22))
			else:
				l.draw_circle(r.get_center(), menor * 0.32, c)
				for i in 8:
					var dir := Vector2.from_angle(TAU * i / 8)
					l.draw_line(r.get_center() + dir * menor * 0.33, r.get_center() + dir * menor * 0.40, c.darkened(0.18), 5, true)
				if m.get("acabado", "") == "rota":
					l.draw_polyline(PackedVector2Array([p + s * Vector2(0.27, 0.24), p + s * Vector2(0.54, 0.51), p + s * Vector2(0.38, 0.72)]), c.darkened(0.28), 8, true)
		"anfora":
			ovalo(l, Rect2(p + s * Vector2(0.17, 0.26) + Vector2(5, 8), s * Vector2(0.66, 0.67)), Color(0.18, 0.14, 0.10, 0.14))
			for x in [0.17, 0.83]:
				l.draw_arc(p + s * Vector2(x, 0.47), menor * 0.12, 0, TAU, 20, c.darkened(0.19), menor * 0.06, true)
			ovalo(l, Rect2(p + s * Vector2(0.18, 0.24), s * Vector2(0.64, 0.68)), c.darkened(0.18))
			ovalo(l, Rect2(p + s * Vector2(0.23, 0.25), s * Vector2(0.54, 0.62)), c)
			caja(l, Rect2(p + s * Vector2(0.32, 0.08), s * Vector2(0.36, 0.25)), c.lightened(0.08), c.darkened(0.15), menor * 0.04)
			ovalo(l, Rect2(p + s * Vector2(0.33, 0.07), s * Vector2(0.34, 0.12)), Color("785c43"))
			l.draw_arc(p + s * Vector2(0.50, 0.57), menor * 0.24, 0.25, 2.85, 18, Color("d8b68a"), 5, true)


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




static func _silla(l: CanvasItem, m: Dictionary) -> void:
	# Banquito de práctica: cartón corrugado, pliegue y cinta de papel.
	var r: Rect2 = m.rect
	var p := r.position
	var s := r.size
	caja(l, Rect2(p + Vector2(5, 8), s), Color(0.19, 0.16, 0.11, 0.14), Color.TRANSPARENT, 4)
	caja(l, r.grow(-6), Color("9c7045"), Color("735337"), 3)
	caja(l, Rect2(p + Vector2(4, -4), s - Vector2(8, 12)), Color("c3a06b"), Color("e0bd85"), 3)
	l.draw_line(p + Vector2(s.x * 0.5, 2), p + Vector2(s.x * 0.5, s.y - 18), Color("b18b59"), 3)
	l.draw_rect(Rect2(p + Vector2(6, s.y * 0.35), Vector2(s.x - 12, s.y * 0.18)), Color("d1b17e"))
	for i in 5:
		l.draw_line(p + Vector2(15 + i * 18, s.y - 12), p + Vector2(15 + i * 18, s.y - 4), Color("c3a06b"), 3)


static func _plato(l: CanvasItem, pos: Vector2, radio: float) -> void:
	l.draw_circle(pos + Vector2(3, 5), radio, Color(0.15, 0.12, 0.08, 0.15))
	l.draw_circle(pos, radio, Color("f6efdf"))
	l.draw_arc(pos, radio * 0.82, 0, TAU, 32, Color("8eaaa2"), 3, true)
	l.draw_arc(pos, radio * 0.64, 0, TAU, 32, Color("e1d8c4"), 2, true)




static func _destino(l: CanvasItem) -> void:
	if Juego.lugar_actual == "restaurante":
		for m in PlanoCasa.muebles():
			if m.tipo == "mesa_comedor":
				var r: Rect2 = m.rect
				caja(l, r.grow(150), Color("a78868"), Color("bda17d"), 24)
				l.draw_rect(r.grow(120), Color("b89a76"), false, 2)
	elif Juego.lugar_actual == "museo":
		alfombra(l, Rect2(3350, 1220, 1450, 1650), Color("947764"))
		for m in PlanoCasa.muebles():
			if m.tipo == "vitrina":
				var r: Rect2 = m.rect
				l.draw_rect(r.grow(65), Color("b6a88f"), false, 3)
				l.draw_rect(Rect2(r.get_center() + Vector2(-70, r.size.y * 0.5 + 25), Vector2(140, 25)), Color("8c8068"))
	for a in PlanoCasa.ambientes():
		var r: Rect2 = a.rect
		l.draw_string(ThemeDB.fallback_font, r.position + Vector2(120, r.size.y - 120), l.tr(a.nombre), HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color(0.2, 0.2, 0.17, 0.35))
	if Juego.lugar_actual == "obelisco":
		# Una explanada de piedra integra el monumento con la avenida.
		# El bordillo es bajo: todo este dibujo sigue siendo suelo transitable.
		var centro := Vector2(3225, 1775)
		l.draw_circle(centro + Vector2(0, 8), 1164, Color(0.28, 0.26, 0.20, 0.07))
		l.draw_circle(centro, 1160, Color("b5b09d"))
		l.draw_circle(centro, 1150, Color("cbc5b2"))
		l.draw_arc(centro, 1135, 0, TAU, 96, Color("d4cebc"), 3, true)
		# Aceras y cruces comparten la misma piedra; la pintura acompaña,
		# sin competir con las hormigas ni parecer barreras del mapa.
		for y in [-250, 2750]:
			l.draw_rect(Rect2(-900, y - 60, 7800, 440), Color("c9c2ae"))
			l.draw_rect(Rect2(-900, y, 7800, 320), Color("73766d"))
			l.draw_line(Vector2(-900, y + 3), Vector2(6900, y + 3), Color("aaa994"), 4)
			l.draw_line(Vector2(-900, y + 317), Vector2(6900, y + 317), Color("dbd2bb"), 4)
			for x in range(-800, 6800, 400):
				l.draw_rect(Rect2(x, y + 158, 160, 4), Color("bdbba2"))
			for x in [1800, 4800]:
				for i in 6:
					l.draw_rect(Rect2(x, y + 24 + i * 48, 230, 24), Color("d2cbb7"))
	elif Juego.lugar_actual == "coliseo":
		l.draw_set_transform(Vector2(3700, 1700), 0, Vector2(1.15, 1))
		# Arena, paseo de piedra y borde exterior: tres superficies amplias,
		# no una sucesión de aros gruesos detrás de las arcadas comestibles.
		l.draw_circle(Vector2.ZERO, 2090, Color("bfa885"))
		l.draw_circle(Vector2.ZERO, 1900, Color("d3bb94"))
		l.draw_circle(Vector2.ZERO, 1740, Color("d6bc91"))
		l.draw_arc(Vector2.ZERO, 2080, 0, TAU, 96, Color("cdbb9c"), 6, true)
		l.draw_arc(Vector2.ZERO, 1900, 0, TAU, 96, Color("bca784"), 4, true)
		l.draw_set_transform(Vector2.ZERO)
	elif Juego.lugar_actual == "eiffel":
		# Parterres bajos y senderos de grava: decoración caminable,
		# alineada con la esplanada y con los muebles que ya tiene el plano.
		for x in [-650, 4700]:
			for y in [-600, 1700]:
				caja(l, Rect2(x, y, 1800, 1700), Color("94a17e"), Color("b8b79a"), 65)
				l.draw_line(Vector2(x + 60, y + 70), Vector2(x + 1740, y + 70), Color("a8b18d"), 4, true)
				l.draw_line(Vector2(x + 60, y + 1630), Vector2(x + 1740, y + 1630), Color("87966f"), 4, true)
		for y in [-300, 3400]:
			l.draw_rect(Rect2(1900, y, 2700, 180), Color("d3c9b0"))
			l.draw_line(Vector2(1900, y + 5), Vector2(4600, y + 5), Color("e0d6be"), 3)
			l.draw_line(Vector2(1900, y + 175), Vector2(4600, y + 175), Color("bcb69b"), 3)
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
