class_name ArteCamara
extends RefCounted
## Cómo se ve cada cámara del hormiguero según su rama: la forma (como un
## border-radius de CSS), lo que guarda adentro (crece con el nivel) y el
## rastro que deja en sus túneles. Es el mismo kit del lienzo de diseño:
## graneros planos, nidos redondos, talleres tallados, cámaras redondas con
## gotas, cámaras altas con reservas colgando y galerías largas y bajas.
## Todo se dibuja en un CanvasItem retenido: no hay nodos por cámara.

## Radios de las esquinas en % del ancho (sup. izq., sup. der., inf. der., inf. izq.)
## y del alto (en el mismo orden).
const FORMAS := {
	"castas": [46, 54, 52, 48, 52, 46, 54, 48],
	"colonia": [50, 50, 48, 52, 56, 54, 46, 44],
	"recoleccion": [50, 50, 20, 20, 76, 76, 24, 24],
	"mandibulas": [22, 30, 18, 26, 30, 22, 34, 24],
	"feromonas": [50, 50, 50, 50, 50, 50, 50, 50],
	"tiempo": [50, 50, 46, 46, 64, 64, 36, 36],
	"territorio": [58, 42, 62, 38, 64, 48, 52, 36],
	"comun": [52, 48, 50, 50, 50, 52, 48, 50],
	"reina": [50, 50, 48, 52, 54, 54, 46, 46],
	"viajes": [40, 60, 45, 55, 60, 50, 50, 40],
}
const COLORES := {
	"castas": Color("e5879a"), "colonia": Color("b8cd91"), "recoleccion": Color("e8cc86"),
	"mandibulas": Color("e7ac7d"), "feromonas": Color("8dc3bc"), "tiempo": Color("c3add4"),
	"territorio": Color("c9b48c"), "reina": Color("ebc67d"), "viajes": Color("d8c49a"),
	"comun": Color("ebc67d"),
}
## Rastro en los túneles de la rama: color, ancho, separación entre puntos, opacidad.
const RASTROS := {
	"recoleccion": {"color": Color("e2bd72"), "ancho": 3.2, "paso": 15.0, "alfa": 0.9},
	"feromonas": {"color": Color("a8e6dc"), "ancho": 2.6, "paso": 9.0, "alfa": 0.95, "halo": Color(0.553, 0.765, 0.737, 0.16)},
	"tiempo": {"color": Color("d8b4e8"), "ancho": 3.0, "paso": 22.0, "alfa": 0.8},
}
## Estilos de las piezas de adentro: relleno, trazo, grosor.
const ESTILOS := {
	"huevo": [Color("efe6cf"), null, 0.0], "larva": [null, Color("e6dcc0"), 2.4],
	"monton": [Color("c99a52"), Color("7a5a2e"), 1.0], "miga": [Color("e2bd72"), null, 0.0],
	"astilla": [Color("b9824c"), Color("6e4a26"), 0.8], "metal": [Color("a9aba5"), Color("5d5f5a"), 0.8],
	"halo": [Color(0.553, 0.765, 0.737, 0.22), null, 0.0], "gota": [Color("a8e6dc"), null, 0.0],
	"hilo": [null, Color("9a84ab"), 1.2], "reserva": [Color("d8b4e8"), Color("8f6aa3"), 1.0],
	"piedra": [Color("8d847a"), Color("5b544c"), 0.8], "tierra": [Color("6e5236"), null, 0.0],
	"raiz": [null, Color("9a7a52"), 1.4], "obrera": [Color("e7b3bf"), null, 0.0],
	"patas": [null, Color("e7b3bf"), 1.0], "reina": [Color("c9a8de"), null, 0.0],
	"patas_reina": [null, Color("b496c7"), 1.6], "bandera": [Color("ebc67d"), null, 0.0],
	"palito": [null, Color("cdb08a"), 1.4], "hoja": [Color("8fae5e"), Color("5c7a36"), 0.8],
	# La reina: brillo de jalea, alas de la reina joven, franjas del abdomen,
	# corona y las ofrendas de cada destino conquistado.
	"brillo": [Color(0.922, 0.776, 0.49, 0.16), null, 0.0], "ala": [Color(0.94, 0.94, 0.98, 0.42), Color(0.97, 0.97, 1.0, 0.8), 1.4],
	"franja": [null, Color(0.18, 0.12, 0.1, 0.45), 1.6], "corona": [Color("f0cf7a"), Color("9a7a3a"), 0.8],
	"jalea": [Color("f3d58c"), null, 0.0], "trofeo": [Color("d9c08a"), Color("7d6440"), 0.8],
	"suelo": [Color(0.478, 0.353, 0.227, 0.42), null, 0.0], "aserrin": [Color("9c6e43"), null, 0.0],
}
const ORDEN_CAPAS := ["suelo", "halo", "aserrin", "tierra", "monton", "raiz", "hilo", "reserva", "piedra",
	"astilla", "metal", "huevo", "larva", "miga", "gota", "brillo", "jalea", "patas", "obrera", "patas_reina", "reina", "ala",
	"franja", "corona", "palito", "bandera", "hoja", "trofeo"]
## El color de la reina sigue el decreto con que se fundó la colonia.
const COLOR_REINA := {"": Color("c9a8de"), "numerosa": Color("e3b28c"), "guerrera": Color("d98b7c"),
	"recolectora": Color("e6c97f"), "exploradora": Color("a9cf9b")}
const BORDE := Color("7d5c40")
const CERRADO := Color("5a4230")
const RELLENO := Color("2e2119")
const SOMBRA := Color("241a14")
static func kit_de(rama: String) -> String:
	if "|" in rama or rama == "Fondo":
		return "comun"
	return {"Colonia": "colonia", "Mandíbulas": "mandibulas", "Recolección": "recoleccion",
		"Feromonas": "feromonas", "Tiempo": "tiempo", "Territorio": "territorio", "Castas": "castas"}.get(rama, "comun")


## Las dos ramas que mezcla una cámara compartida.
static func mezcla_de(rama: String) -> Array[String]:
	var mezcla: Array[String] = []
	if rama == "Fondo":
		mezcla.assign(["recoleccion", "mandibulas"])
	else:
		for parte in rama.split("|"):
			mezcla.append(kit_de(parte))
	return mezcla


static func color_de(rama: String) -> Color:
	return COLORES.get(kit_de(rama), COLORES.comun)


## Contorno de una cámara centrada en (0, 0), como un border-radius de CSS.
static func forma(kit: String, tamano: Vector2, pasos := 9) -> PackedVector2Array:
	var r: Array = FORMAS.get(kit, FORMAS.comun)
	var w := tamano.x
	var h := tamano.y
	var radios := [Vector2(r[0], r[4]), Vector2(r[1], r[5]), Vector2(r[2], r[6]), Vector2(r[3], r[7])]
	for i in 4:
		radios[i] = Vector2(radios[i].x * w / 100.0, radios[i].y * h / 100.0)
	var centros := [Vector2(radios[0].x, radios[0].y), Vector2(w - radios[1].x, radios[1].y),
		Vector2(w - radios[2].x, h - radios[2].y), Vector2(radios[3].x, h - radios[3].y)]
	var inicios := [PI, PI * 1.5, 0.0, PI * 0.5]
	var puntos := PackedVector2Array()
	for i in 4:
		for j in pasos + 1:
			var angulo: float = inicios[i] + PI * 0.5 * j / pasos
			var p: Vector2 = centros[i] + Vector2(cos(angulo) * radios[i].x, sin(angulo) * radios[i].y) - tamano * 0.5
			# Dos esquinas que se tocan comparten un punto: no repetirlo.
			if puntos.is_empty() or p.distance_squared_to(puntos[puntos.size() - 1]) > 0.01:
				puntos.append(p)
	if puntos.size() > 2 and puntos[0].distance_squared_to(puntos[puntos.size() - 1]) <= 0.01:
		puntos.remove_at(puntos.size() - 1)
	return puntos


## La cámara: sombra, aro del color de la rama y fondo de tierra cavada.
## brillo (0 a 1) tiñe el fondo con el color de la rama.
static func caparazon(ci: CanvasItem, kit: String, centro: Vector2, tamano: Vector2, aro: Color, grosor: float, brillo: float, opacidad := 1.0) -> void:
	var exterior := forma(kit, tamano + Vector2.ONE * 3.0)
	var anillo := forma(kit, tamano)
	var interior := forma(kit, tamano - Vector2.ONE * grosor * 2.0)
	ci.draw_colored_polygon(_mover(exterior, centro), Color(SOMBRA, opacidad))
	ci.draw_colored_polygon(_mover(anillo, centro), Color(aro, opacidad))
	ci.draw_colored_polygon(_mover(interior, centro), Color(RELLENO, opacidad))
	if brillo > 0.0:
		var color := COLORES.get(kit, aro) as Color
		var foco := centro + Vector2(0, -tamano.y * 0.1)
		var fondo := Color(color, 0.0)
		var luz := Color(color, 0.2 * brillo * opacidad)
		for i in interior.size():
			var a := centro + (interior[i] - Vector2(0, 0)) * 0.98
			var b := centro + interior[(i + 1) % interior.size()] * 0.98
			ci.draw_primitive(PackedVector2Array([foco, a, b]), PackedColorArray([luz, fondo, fondo]), PackedVector2Array())
	var linea := _mover(interior, centro)
	linea.append(linea[0])
	ci.draw_polyline(linea, Color(SOMBRA, opacidad), 1.5, true)


## Borde punteado de las cámaras que piden dos ramas.
static func punteado(ci: CanvasItem, kit: String, centro: Vector2, tamano: Vector2, color: Color) -> void:
	var contorno := _mover(forma(kit, tamano + Vector2.ONE * 8.0, 12), centro)
	contorno.append(contorno[0])
	var largo := 0.0
	for i in contorno.size() - 1:
		var a := contorno[i]
		var b := contorno[i + 1]
		var tramo := a.distance_to(b)
		var t := 0.0
		while t < tramo:
			var fase := fmod(largo + t, 7.0)
			if fase < 4.0:
				var fin := minf(tramo, t + 4.0 - fase)
				ci.draw_line(a.lerp(b, t / tramo), a.lerp(b, fin / tramo), color, 1.5, true)
				t = fin
			else:
				t += 7.0 - fase
		largo += tramo


## Lo que guarda la cámara. lleno va de 0 (vacía) a 1 (completa).
static func contenido(ci: CanvasItem, kit: String, centro: Vector2, tamano: Vector2, lleno: float, semilla: int, mezcla: Array = [], extra := 0) -> void:
	var piezas := piezas_de(kit, centro, tamano, lleno, semilla, mezcla, extra)
	for capa in ORDEN_CAPAS:
		for p in piezas:
			if p.capa == capa:
				_pintar(ci, p)


## Piezas {capa, tipo, puntos} de una cámara. Mismo azar que el lienzo.
static func piezas_de(kit: String, c: Vector2, tamano: Vector2, f: float, semilla: int, mezcla: Array = [], extra := 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if f <= 0.0:
		return out
	var w := tamano.x
	var h := tamano.y
	var azar := [semilla * 7919 + 13]
	var az := func() -> float:
		azar[0] = (azar[0] * 9301 + 49297) % 233280
		return azar[0] / 233280.0
	var k := clampf(minf(w / 74.0, h / 50.0), 0.75, 1.9)
	var piso := c.y + h * 0.5 - 8.0 * k
	var techo := c.y - h * 0.5 + 8.0 * k
	var util := w - 22.0 * k
	if kit == "comun":
		if mezcla.size() >= 2:
			out.append_array(piezas_de(mezcla[0], c + Vector2(-w * 0.22, 0), Vector2(w * 0.5, h), f * 0.85, semilla + 1))
			out.append_array(piezas_de(mezcla[1], c + Vector2(w * 0.22, 0), Vector2(w * 0.5, h), f * 0.85, semilla + 2))
		return out
	if kit != "reina":
		out.append(_elipse("suelo", Vector2(c.x, piso + 2.5 * k), util * 0.5, 4.2 * k))
	match kit:
		"colonia":
			var lugares := [Vector2(0, 0), Vector2(-8, 0.6), Vector2(8, 0.6), Vector2(-4, -7), Vector2(4, -7), Vector2(-16, 1), Vector2(16, 1), Vector2(0, -14), Vector2(-12, -6.4), Vector2(12, -6.4)]
			var n := maxi(1, roundi(f * 10))
			var base := Vector2(c.x + (az.call() - 0.5) * util * 0.12 - util * 0.08, piso - 5.0 * k)
			for i in n:
				out.append(_elipse("huevo", base + lugares[i] * k, 3.6 * k, 4.6 * k))
			if f >= 0.5:
				var lx := c.x + util * 0.32
				var r := 4.6 * k
				out.append(_arco("larva", Vector2(lx, piso - 3.0 * k), r, PI, TAU))
				if f >= 0.9:
					out.append(_arco("larva", Vector2(lx + r * 0.25, piso - 13.0 * k), r * 0.9, 0.0, PI))
		"recoleccion":
			var pilas := 2 if f >= 0.6 else 1
			for i in pilas:
				var pw := util * (0.46 if pilas == 2 else 0.6) * (0.7 + 0.3 * f)
				var ph := (h * 0.12 + h * 0.2 * f) * (1.0 if i == 0 else 0.78)
				var x0 := c.x - pw * 0.5
				if pilas == 2:
					x0 = c.x - util * 0.48 if i == 0 else c.x + util * 0.06
				out.append(_cuadratica("monton", Vector2(x0, piso), Vector2(x0 + pw * 0.5, piso - 2.0 * ph), Vector2(x0 + pw, piso)))
			for i in roundi(f * 9):
				out.append(_elipse("miga", Vector2(c.x + (az.call() - 0.5) * util * 0.95, piso - 1.0 - az.call() * 3.0 * k), 1.9 * k, 1.6 * k))
		"mandibulas":
			if f >= 0.5:
				out.append(_cuadratica("aserrin", Vector2(c.x - util * 0.45, piso), Vector2(c.x - util * 0.2, piso - h * 0.22 * f), Vector2(c.x + util * 0.05, piso)))
			var n := roundi(f * 8) + 1
			for i in n:
				var x: float = c.x - util * 0.5 + util * (i + 0.5) / n + (az.call() - 0.5) * 4.0 * k
				var y: float = piso - 3.0 * k - az.call() * h * 0.22
				var angulo: float = (az.call() - 0.5) * 1.8
				if i % 3 == 2:
					out.append(_poligono("metal", Vector2(x, y), angulo, k, [Vector2(-4.6, 2.8), Vector2(4.6, 3.3), Vector2(0, -4.6)]))
				else:
					out.append(_poligono("astilla", Vector2(x, y), angulo, k, [Vector2(-6.5, -1.6), Vector2(6.5, -1.2), Vector2(6.5, 1.6), Vector2(-6.5, 1.3)]))
		"feromonas":
			var n := maxi(1, roundi(f * 6))
			for i in n:
				var angulo: float = float(i) / n * TAU + az.call()
				var r := 0.0 if n == 1 else (0.55 if i % 2 else 0.32)
				var p := c + Vector2(cos(angulo) * (w * 0.5 - 12.0 * k), sin(angulo) * (h * 0.5 - 11.0 * k)) * r
				out.append(_elipse("halo", p, 7.5 * k, 7.5 * k))
				out.append(_elipse("gota", p, 3.1 * k, 3.1 * k))
		"tiempo":
			var n := maxi(1, roundi(f * 4))
			for i in n:
				var x := c.x - util * 0.4 + util * 0.8 * (i + 0.5) / n
				var largo: float = (4.0 + az.call() * 5.0) * k
				var r: float = (4.6 + f * 2.2 + az.call()) * k
				out.append(_linea("hilo", [Vector2(x, techo - 2.0), Vector2(x, techo + largo)]))
				out.append(_elipse("reserva", Vector2(x, techo + largo + r), r, r * 1.05))
		"territorio":
			var lado := -1.0 if az.call() < 0.5 else 1.0
			var tw := util * (0.34 + 0.24 * f)
			var th := h * (0.1 + 0.2 * f)
			var tx := c.x + lado * util * 0.24
			out.append(_cuadratica("tierra", Vector2(tx - tw * 0.5, piso), Vector2(tx, piso - 2.0 * th), Vector2(tx + tw * 0.5, piso)))
			var n := roundi(f * 5) + 1
			for i in n:
				out.append(_elipse("piedra", Vector2(c.x - lado * util * 0.14 + (i - n * 0.5) * 8.5 * k + az.call() * 3.0, piso - 2.8 * k - az.call() * 2.0 * k), (3.8 + az.call() * 1.6) * k, (2.7 + az.call()) * k))
			if f >= 0.5:
				var raiz := PackedVector2Array()
				var a := Vector2(c.x - util * 0.42, techo - 4.0)
				for j in 13:
					raiz.append(a.bezier_interpolate(Vector2(c.x - util * 0.1, techo + 9.0 * k), Vector2(c.x + util * 0.1, techo), Vector2(c.x + util * 0.38, techo + 8.0 * k), j / 12.0))
				out.append({"capa": "raiz", "tipo": "linea", "puntos": raiz})
				out.append(_linea("raiz", [Vector2(c.x - util * 0.05, techo + 3.0 * k), Vector2(c.x - util * 0.05 + 3.0 * k, techo + 10.0 * k)]))
		"castas":
			var n := maxi(1, roundi(f * 3))
			for i in n:
				var x := c.x - util * 0.4 + util * 0.8 * (i + 0.5) / n + (3.0 if i % 2 else -3.0) * k
				var y := piso - 6.0 * k - (i % 2) * 9.0 * k
				var e: float = (0.95 + az.call() * 0.15) * k
				out.append_array(_hormiga("obrera", "patas", Vector2(x, y), e, i == 0))
		"reina":
			out.append_array(_reina(c, tamano, k, extra, Juego.decreto, Juego.lugares_completados.keys()))
		"viajes":
			# Una bandera por destino conquistado (al menos la de casa en el lienzo).
			var banderas := clampi(extra, 0, 6)
			for i in banderas:
				var x := c.x + (-0.42 + i * 0.075) * w
				out.append(_linea("palito", [Vector2(x, piso + 1), Vector2(x, piso - 20)]))
				out.append({"capa": "bandera", "tipo": "relleno", "puntos": PackedVector2Array([Vector2(x, piso - 20), Vector2(x + 11, piso - 16.5 + i % 2), Vector2(x, piso - 13)])})
			var hoja := PackedVector2Array()
			for j in 9:
				hoja.append(Vector2(c.x + w * 0.16, piso).bezier_interpolate(Vector2(c.x + w * 0.21, piso - 9.3), Vector2(c.x + w * 0.27, piso - 9.3), Vector2(c.x + w * 0.33, piso - 2), j / 8.0))
			for j in range(1, 8):
				hoja.append(Vector2(c.x + w * 0.33, piso - 2).bezier_interpolate(Vector2(c.x + w * 0.27, piso + 0.7), Vector2(c.x + w * 0.21, piso + 1.3), Vector2(c.x + w * 0.16, piso), j / 8.0))
			out.append({"capa": "hoja", "tipo": "relleno", "puntos": hoja})
			out.append(_elipse("miga", Vector2(c.x + w * 0.05, piso - 3), 4, 3))
			out.append(_elipse("miga", Vector2(c.x - w * 0.02, piso - 2), 2.5, 2))
	return out


## Rastro punteado de una rama a lo largo de un túnel.
static func rastro(ci: CanvasItem, kit: String, puntos: PackedVector2Array) -> void:
	if not RASTROS.has(kit) or puntos.size() < 2:
		return
	var datos: Dictionary = RASTROS[kit]
	if datos.has("halo"):
		ci.draw_polyline(puntos, datos.halo, 10.0, true)
	var color := Color(datos.color, datos.alfa)
	var resto := 0.0
	for i in puntos.size() - 1:
		var a := puntos[i]
		var b := puntos[i + 1]
		var tramo := a.distance_to(b)
		var t := resto
		while t <= tramo:
			ci.draw_circle(a.lerp(b, t / maxf(tramo, 0.001)), datos.ancho * 0.5, color)
			t += datos.paso
		resto = t - tramo


static func _pintar(ci: CanvasItem, p: Dictionary) -> void:
	var estilo: Array = ESTILOS[p.capa]
	var puntos: PackedVector2Array = p.puntos
	if p.tipo == "linea":
		if estilo[1] != null:
			ci.draw_polyline(puntos, p.get("color", estilo[1]), estilo[2], true)
		return
	if estilo[0] != null and puntos.size() >= 3:
		ci.draw_colored_polygon(puntos, p.get("color", estilo[0]))
	if estilo[1] != null and estilo[2] > 0:
		var cerrado := puntos.duplicate()
		cerrado.append(puntos[0])
		ci.draw_polyline(cerrado, estilo[1], estilo[2], true)


static func _elipse(capa: String, c: Vector2, rx: float, ry: float) -> Dictionary:
	var puntos := PackedVector2Array()
	var lados := clampi(int(maxf(rx, ry) * 2.2), 8, 22)
	for i in lados:
		var a := TAU * i / lados
		puntos.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return {"capa": capa, "tipo": "relleno", "puntos": puntos}


static func _arco(capa: String, c: Vector2, r: float, desde: float, hasta: float) -> Dictionary:
	var puntos := PackedVector2Array()
	for i in 11:
		var a := lerpf(desde, hasta, i / 10.0)
		puntos.append(c + Vector2(cos(a), sin(a)) * r)
	return {"capa": capa, "tipo": "linea", "puntos": puntos}


static func _cuadratica(capa: String, a: Vector2, control: Vector2, b: Vector2) -> Dictionary:
	var puntos := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		puntos.append(a.lerp(control, t).lerp(control.lerp(b, t), t))
	return {"capa": capa, "tipo": "relleno", "puntos": puntos}


static func _poligono(capa: String, c: Vector2, angulo: float, escala: float, vertices: Array) -> Dictionary:
	var puntos := PackedVector2Array()
	for v in vertices:
		puntos.append(c + (v * escala).rotated(angulo))
	return {"capa": capa, "tipo": "relleno", "puntos": puntos}


static func _linea(capa: String, puntos: Array) -> Dictionary:
	return {"capa": capa, "tipo": "linea", "puntos": PackedVector2Array(puntos)}


static func _hormiga(capa: String, capa_patas: String, p: Vector2, e: float, cabezona: bool) -> Array[Dictionary]:
	var partes: Array[Dictionary] = [
		_elipse(capa, p + Vector2(-7, 0) * e, 5.5 * e, 3.8 * e),
		_elipse(capa, p, 2.6 * e, 2.2 * e),
		_elipse(capa, p + Vector2(5.5, -0.4) * e, (4.4 if cabezona else 3.0) * e, (3.6 if cabezona else 2.6) * e),
	]
	for pata in [[Vector2(-2, 1.5), Vector2(-4, 5)], [Vector2(0, 2), Vector2(0, 5.5)], [Vector2(2, 1.5), Vector2(4, 5)]]:
		partes.append(_linea(capa_patas, [p + pata[0] * e, p + pata[1] * e]))
	return partes


## La reina cambia con cada fundación (0 a 6):
##   0   reina joven, delgada y con alas: todavía no hizo su vuelo.
##   1   se arrancó las alas al fundar; el abdomen empieza a crecer.
##   2-3 abdomen con franjas y obreras que la cuidan.
##   4-5 brillo de jalea, corona y más cuidadoras.
##   6   reina enorme con su cortejo completo.
## El color sigue el decreto y cada destino conquistado deja una ofrenda
## colgando del techo. Son piezas retenidas: no hay animación por cuadro.
static func _reina(c: Vector2, tamano: Vector2, k: float, fundaciones: int, decreto: String, conquistas: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var etapa := clampi(fundaciones, 0, 6)
	var color: Color = COLOR_REINA.get(decreto, COLOR_REINA[""])
	var e := 3.6 + 0.12 * etapa
	var p := c + Vector2(6, 6)
	if etapa >= 4:
		out.append(_elipse("brillo", p + Vector2(-6, 0) * e, (16.0 + etapa) * e * 0.5, 9.0 * e * 0.5))
	# Abdomen: crece con cada colonia, como el de una reina que pone sin parar.
	var abdomen := Vector2(5.5 * (1.0 + 0.16 * etapa), 3.8 * (1.0 + 0.12 * etapa))
	var centro_abdomen := p + Vector2(-4.2 - abdomen.x, 0) * e
	var cuerpo: Array[Dictionary] = [
		_elipse("reina", centro_abdomen, abdomen.x * e, abdomen.y * e),
		_elipse("reina", p, 2.8 * e, 2.3 * e),
		_elipse("reina", p + Vector2(5.4, -0.4) * e, 3.0 * e, 2.6 * e),
	]
	for pieza in cuerpo:
		pieza.color = color
	out.append_array(cuerpo)
	var tono_patas := color.darkened(0.25)
	for pata in [[Vector2(-2, 1.5), Vector2(-4.5, 5.5)], [Vector2(0, 2), Vector2(0, 6)], [Vector2(2, 1.5), Vector2(4.5, 5.5)]]:
		var linea := _linea("patas_reina", [p + pata[0] * e, p + pata[1] * e])
		linea.color = tono_patas
		out.append(linea)
	if etapa == 0:
		# Alas de la reina joven, apoyadas sobre el abdomen.
		out.append(_poligono("ala", p + Vector2(0, -1.2) * e, -0.32, e, [Vector2(0, 0), Vector2(-11, -4.2), Vector2(-15, -1.8), Vector2(-10, 0.6)]))
		out.append(_poligono("ala", p + Vector2(0, -0.8) * e, -0.08, e, [Vector2(0, 0), Vector2(-12, -1.6), Vector2(-15.5, 0.8), Vector2(-9, 1.6)]))
	else:
		for i in mini(etapa + 1, 6):
			var x := centro_abdomen.x + abdomen.x * e * (0.55 - i * 0.22)
			out.append(_arco("franja", Vector2(x, centro_abdomen.y), abdomen.y * e * 0.98, -PI * 0.5 + 0.35, PI * 0.5 - 0.35))
	if etapa >= 4:
		var cabeza := p + Vector2(5.6, -3.0) * e
		out.append(_poligono("corona", cabeza, 0.0, e, [Vector2(-2.2, 0), Vector2(-2.2, -2.2), Vector2(-1.1, -1.1), Vector2(0, -2.6), Vector2(1.1, -1.1), Vector2(2.2, -2.2), Vector2(2.2, 0)]))
	# Cuidadoras: obreras que la miran desde los costados.
	var lugares := [Vector2(0.36, 0.14), Vector2(-0.4, 0.2), Vector2(0.4, -0.12), Vector2(-0.43, -0.08)]
	for i in clampi(etapa - 1, 0, 4):
		var lugar: Vector2 = lugares[i]
		var obrera := _hormiga("obrera", "patas", c + lugar * tamano, 0.95 * k, false)
		if lugar.x > 0:
			for pieza in obrera:
				pieza.puntos = _espejar(pieza.puntos, (c + lugar * tamano).x)
		out.append_array(obrera)
	# Huevos y, desde la cuarta colonia, gotas de jalea real.
	var huevos := [Vector2(-0.3, 0.3), Vector2(-0.24, 0.34), Vector2(-0.18, 0.31), Vector2(0.17, 0.32), Vector2(0.23, 0.34), Vector2(0.29, 0.3), Vector2(-0.12, 0.35), Vector2(0.11, 0.35)]
	for i in mini(4 + etapa, huevos.size()):
		out.append(_elipse("huevo", c + huevos[i] * tamano, 3.2 * k, 4.0 * k))
	if etapa >= 4:
		for i in etapa - 3:
			out.append(_elipse("jalea", c + Vector2(-0.06 + i * 0.05, 0.36) * tamano, 2.6 * k, 2.2 * k))
	# Una ofrenda por destino conquistado, colgando del techo.
	var techo := c.y - tamano.y * 0.5 + 9.0 * k
	var ofrendas := ["casa", "restaurante", "museo", "obelisco", "coliseo", "eiffel"]
	for i in ofrendas.size():
		if not conquistas.has(ofrendas[i]):
			continue
		var x := c.x + (-0.3 + i * 0.12) * tamano.x
		var largo := (5.0 + (i % 2) * 4.0) * k
		out.append(_linea("hilo", [Vector2(x, techo - 6.0 * k), Vector2(x, techo + largo)]))
		out.append_array(_ofrenda(ofrendas[i], Vector2(x, techo + largo + 4.0 * k), k))
	return out


## Siluetas chicas de cada destino: una miga, un ravioles, una columna, el
## Obelisco, un arco y la Torre. Mismo estilo dorado para todas.
static func _ofrenda(destino: String, p: Vector2, k: float) -> Array[Dictionary]:
	match destino:
		"casa":
			return [_elipse("trofeo", p, 3.4 * k, 2.8 * k)]
		"restaurante":
			return [_poligono("trofeo", p, PI * 0.25, k, [Vector2(-3.2, -3.2), Vector2(3.2, -3.2), Vector2(3.2, 3.2), Vector2(-3.2, 3.2)])]
		"museo":
			return [_poligono("trofeo", p, 0.0, k, [Vector2(-2, -4), Vector2(2, -4), Vector2(2, 4), Vector2(-2, 4)]),
				_poligono("trofeo", p + Vector2(0, -4.5) * k, 0.0, k, [Vector2(-3.2, -1), Vector2(3.2, -1), Vector2(3.2, 0.6), Vector2(-3.2, 0.6)])]
		"obelisco":
			return [_poligono("trofeo", p, 0.0, k, [Vector2(-1.8, 5), Vector2(-1.2, -4), Vector2(0, -6), Vector2(1.2, -4), Vector2(1.8, 5)])]
		"coliseo":
			return [_poligono("trofeo", p, 0.0, k, [Vector2(-4, 4), Vector2(-4, -1), Vector2(-2.4, -3.6), Vector2(2.4, -3.6), Vector2(4, -1), Vector2(4, 4), Vector2(2, 4), Vector2(2, 0), Vector2(-2, 0), Vector2(-2, 4)])]
		"eiffel":
			return [_poligono("trofeo", p, 0.0, k, [Vector2(-4, 5), Vector2(-0.6, -6), Vector2(0.6, -6), Vector2(4, 5), Vector2(1.6, 5), Vector2(0, 1.5), Vector2(-1.6, 5)])]
	return []


static func _espejar(puntos: PackedVector2Array, eje: float) -> PackedVector2Array:
	var salida := PackedVector2Array()
	for p in puntos:
		salida.append(Vector2(2.0 * eje - p.x, p.y))
	return salida


static func _mover(puntos: PackedVector2Array, desplazamiento: Vector2) -> PackedVector2Array:
	var salida := PackedVector2Array()
	salida.resize(puntos.size())
	for i in puntos.size():
		salida[i] = puntos[i] + desplazamiento
	return salida
