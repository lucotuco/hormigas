class_name ArbolHormiguero
extends Control
## Corte retenido del nido. Geometría y rutas se construyen al redimensionar;
## los niveles sólo cambian la excavación y los objetos dibujados de cada cámara.
const POSICIONES := {
	"mas_obreras": Vector2(.20, .23), "patas_largas": Vector2(.075, .23), "cria_acelerada": Vector2(.20, .10),
	"restauradoras": Vector2(.075, .38), "portenas": Vector2(.20, .38), "mirador": Vector2(.075, .53),
	"mandibulas": Vector2(.70, .13), "mordida_rapida": Vector2(.81, .22), "mandibulas_acero": Vector2(.93, .22),
	"mordida_madera": Vector2(.80, .37), "mordida_resistente": Vector2(.92, .37), "mordida_muros": Vector2(.94, .52),
	"pisada": Vector2(.57, .27), "pisada_auto": Vector2(.61, .48), "titanio": Vector2(.70, .44),
	"mate": Vector2(.92, .67), "legion": Vector2(.81, .53),
	"buche": Vector2(.20, .55), "recoleccion_eficiente": Vector2(.075, .68), "huevos_dorados": Vector2(.20, .73),
	"bandeja": Vector2(.075, .84), "haute": Vector2(.20, .89),
	"rastro_persistente": Vector2(.77, .70), "antenas": Vector2(.68, .80), "pisoton": Vector2(.91, .83), "curadora": Vector2(.80, .91),
	"reservas": Vector2(.34, .66), "segundo_aire": Vector2(.32, .91), "cuadrigas": Vector2(.44, .92),
	"excavar": Vector2(.54, .60), "entradas": Vector2(.55, .92),
}
var rutas: Array[Curve2D] = []
var caminos: Array[Dictionary] = []
var estados: Dictionary = {}
var salas: Dictionary = {}
var secciones: Dictionary = {}
var mejoras: Array = []
var seleccion := ""
var seccion := "hogar"
var dimensiones := Vector2.ZERO
var niveles_totales := 0

func configurar(camaras: Dictionary, accesos: Dictionary) -> void:
	salas = camaras
	secciones = accesos
	mejoras = Juego.mejoras
	reconstruir()

func posicion_mejora(id: String) -> Vector2:
	if POSICIONES.has(id):
		return POSICIONES[id]
	# Las filas futuras conservan un lugar sin cambiar datos de balance.
	var m: Dictionary = Juego.mejoras_por_id[id]
	var base: Vector2 = salas[m.rama].pos
	return (base + Vector2(.07, .09)).clamp(Vector2(.06, .10), Vector2(.94, .92))

func reconstruir() -> void:
	if size.x < 1 or size.y < 90 or salas.is_empty():
		return
	dimensiones = size
	rutas.clear()
	caminos.clear()
	var centro: Vector2 = secciones.hogar.pos * size
	_agregar_camino(Vector2(size.x * .5, 31), secciones.legado.pos * size, "", 23)
	for id in secciones:
		if id != "hogar":
			_agregar_camino(centro, secciones[id].pos * size, "", 22)
	for rama in salas:
		_agregar_camino(centro, salas[rama].pos * size, "", 25)
	for m in mejoras:
		var destino := posicion_mejora(m.id) * size
		var origen: Vector2 = salas[m.rama].pos * size
		if m.requiere_id != "" and Juego.mejoras_por_id.has(m.requiere_id):
			origen = posicion_mejora(m.requiere_id) * size
		_agregar_camino(origen, destino, m.id, 13)
	queue_redraw()

func _agregar_camino(a: Vector2, b: Vector2, id: String, ancho: float) -> void:
	var diferencia := b - a
	var normal := diferencia.orthogonal().normalized() * minf(50, diferencia.length() * .15)
	var puntos := PackedVector2Array()
	for i in 25:
		puntos.append(a.bezier_interpolate(a + diferencia * .36 + normal, b - diferencia * .30 + normal, b, i / 24.0))
	caminos.append({"puntos": puntos, "id": id, "ancho": ancho})
	var ruta := Curve2D.new()
	ruta.bake_interval = 8
	for punto in puntos:
		ruta.add_point(punto)
	rutas.append(ruta)

func actualizar(datos: Dictionary, elegida: String, activa: String) -> void:
	estados = datos
	seleccion = elegida
	seccion = activa
	niveles_totales = 0
	for dato in estados.values():
		niveles_totales += int(dato.nivel)
	queue_redraw()

func _camara(centro: Vector2, radio: Vector2, fase: float, acento: Color, construida: bool, elegida := false) -> void:
	var borde := PackedVector2Array()
	for i in 48:
		var angulo := TAU * i / 48.0
		var onda := 1 + sin(angulo * 3 + fase) * .065 + cos(angulo * 5 + fase) * .035
		borde.append(centro + Vector2.from_angle(angulo) * radio * onda)
	draw_colored_polygon(borde, Color("2e2119") if construida else Color("493323"))
	borde.append(borde[0])
	draw_polyline(borde, Color("241a14"), 10, true)
	draw_polyline(borde, Color("92704b") if construida else Color("6d5037"), 5, true)
	draw_polyline(borde, Color(acento, .85 if elegida else (.36 if construida else .13)), 2, true)

func _decorar(centro: Vector2, rama: String, nivel: int, color: Color, grande := false) -> void:
	var cantidad := mini(12, 2 + ceili(sqrt(nivel))) if nivel > 0 else 0
	for i in cantidad:
		var p := centro + Vector2(-25 + (i % 6) * 10, 17 + int(i / 6) * 7)
		if grande:
			p = centro + Vector2(-48 + (i % 6) * 18, 25 + int(i / 6) * 12)
		match rama:
			"Colonia":
				draw_set_transform(p, -.25, Vector2(.75, 1.15))
				draw_circle(Vector2.ZERO, 4 if grande else 2.7, color.lightened(.15))
			"Recolección":
				draw_set_transform(p, i * .73, Vector2(1.2, .7))
				draw_circle(Vector2.ZERO, 4 if grande else 2.7, color)
			"Mandíbulas":
				draw_line(p, p + Vector2(7, -7), color.darkened(.12), 2.5 if grande else 1.8, true)
				draw_line(p + Vector2(3, -6), p + Vector2(8, -3), color, 2, true)
			"Feromonas":
				draw_circle(p + Vector2(0, sin(i * .9) * 3), 2.7 if grande else 1.8, Color(color, .5 + i % 3 * .15))
			"Tiempo":
				draw_line(p, p + Vector2(5, -5), color, 2, true)
				draw_line(p + Vector2(5, -5), p + Vector2(8, -1), color.darkened(.3), 2, true)
			"Territorio":
				draw_colored_polygon(PackedVector2Array([p, p + Vector2(6, -5), p + Vector2(9, 2), p + Vector2(2, 5)]), color.darkened(i % 3 * .1))
		draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if size.x < 1 or salas.is_empty():
		return
	if dimensiones != size:
		reconstruir()
	draw_rect(Rect2(Vector2.ZERO, size), Color("513b29"))
	for capa in 7:
		var franja := PackedVector2Array()
		for i in 33:
			franja.append(Vector2(size.x * i / 32.0, 44 + capa * size.y * .145 + sin(i * .29 + capa) * 16))
		franja.append(Vector2(size.x, size.y))
		franja.append(Vector2(0, size.y))
		draw_colored_polygon(franja, Color("62452d").darkened(capa * .068))
	var rng := RandomNumberGenerator.new()
	rng.seed = 74
	for i in 320:
		draw_circle(Vector2(rng.randf() * size.x, rng.randf_range(48, maxf(49, size.y))), rng.randf_range(.7, 2.2), Color(.87, .68, .43, .13))
	for lado in [.035, .27, .73, .97]:
		var inicio := Vector2(size.x * lado, 38)
		var raiz := PackedVector2Array()
		for i in 10:
			raiz.append(inicio + Vector2(sin(i * .6 + lado * 8) * 15, i * 14))
		draw_polyline(raiz, Color("9b794d"), 2.5, true)
		for i in [3, 6]:
			draw_line(raiz[i], raiz[i] + Vector2(18 if i == 3 else -18, 24), Color("9b794d"), 1, true)
	# Bordes y excavación se pintan en pasadas: las bifurcaciones quedan abiertas.
	for capa in 3:
		for camino in caminos:
			var estado: Dictionary = estados.get(camino.id, {})
			if not estado.get("visible", true):
				continue
			var construido: bool = camino.id == "" or estado.get("nivel", 0) > 0
			var ancho: float = camino.ancho + minf(5, sqrt(estado.get("nivel", 0)))
			var tinta: Color = [Color("84613e"), Color("251a13"), Color("2e2119")][capa]
			if not construido:
				tinta = [Color("6e5035"), Color("39281c"), Color("443020")][capa]
			draw_polyline(camino.puntos, tinta, ancho + [9, 4, 0][capa], true)
	for id in secciones:
		var dato: Dictionary = secciones[id]
		var central: bool = id == "hogar"
		var radio := Vector2(119, 65) if central else Vector2(127, 54)
		if central:
			radio += Vector2.ONE * minf(17, sqrt(niveles_totales) * 1.2)
		_camara(dato.pos * size, radio, dato.pos.x * 9, dato.color, true, id == seccion)
		_decorar(dato.pos * size + Vector2(0, 4), "Colonia" if id in ["hogar", "castas"] else "Recolección", maxi(1, niveles_totales), dato.color, true)
	for rama in salas:
		var nivel := 0
		for m in mejoras:
			if m.rama == rama:
				nivel += int(estados.get(m.id, {}).get("nivel", 0))
		var dato: Dictionary = salas[rama]
		_camara(dato.pos * size, Vector2(84, 47) + Vector2.ONE * minf(11, sqrt(nivel)), dato.pos.y * 7, dato.color, true)
		_decorar(dato.pos * size + Vector2(0, -13), rama, nivel, dato.color, true)
	for m in mejoras:
		var estado: Dictionary = estados.get(m.id, {})
		if not estado.get("visible", true):
			continue
		var nivel: int = estado.get("nivel", 0)
		var p := posicion_mejora(m.id) * size
		var color: Color = salas[m.rama].color
		var crecimiento := minf(10, sqrt(nivel) * 2)
		_camara(p, Vector2(36, 25) + Vector2(crecimiento, crecimiento * .7), m.id.hash() % 19, color, nivel > 0, m.id == seleccion)
		_decorar(p, m.rama, nivel, color)
		if estado.get("puede", false):
			draw_circle(p + Vector2(29 + crecimiento, -19), 4.5, Color("b8d891"))
	# El horizonte y la boca unen la pantalla a una única colonia subterránea.
	draw_rect(Rect2(0, 0, size.x, 35), Color("252c22"))
	draw_polyline(PackedVector2Array([Vector2(0, 37), Vector2(size.x * .44, 37), Vector2(size.x * .485, 20), Vector2(size.x * .515, 20), Vector2(size.x * .56, 37), Vector2(size.x, 37)]), Color("967448"), 5, true)
	draw_set_transform(Vector2(size.x * .5, 25), 0, Vector2(1, .4))
	draw_circle(Vector2.ZERO, 16, Color("211a13"))
	draw_set_transform(Vector2.ZERO)
