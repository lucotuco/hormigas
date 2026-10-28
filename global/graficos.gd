extends Node
## Un atlas compartido: sprites preiluminados y arte procedural horneados una vez.
signal preparado
const CUADROS := 8
var listo := false
var textura: Texture2D
var regiones: Dictionary = {}
var tamanos: Dictionary = {}
var _viewport: SubViewport
var _x := 4
var _y := 4
var _alto_fila := 0
var _pendientes: Array[Dictionary] = []
var _mueble_claves: Dictionary = {}
var _mueble_medidas: Dictionary = {}
var _alturas := PackedInt32Array()
var _alto_atlas := 4
var _animaciones: Dictionary = {}

func animacion(tipo: String, evolucion: int) -> Array[Rect2]:
	var clave := "%s:%d" % [tipo, evolucion]
	if not _animaciones.has(clave):
		var cuadros: Array[Rect2] = []
		for i in CUADROS:
			cuadros.append(regiones["hormiga:%s:%d:%d" % [tipo, evolucion, i]])
		_animaciones[clave] = cuadros
	return _animaciones[clave]

class Pintura extends Node2D:
	var tipo := ""
	var datos: Dictionary
	var fase := 0.0
	var evolucion := 0
	func _draw() -> void:
		if tipo == "hormiga":
			AspectoHormiga.dibujar(self, datos.id, datos.color, fase, false, Color.WHITE, evolucion)
		elif tipo == "mueble":
			DibujoCasa.mueble(self, datos)
		elif tipo == "reposteria":
			_dulce()
		elif tipo == "resto":
			var c: Color = datos.color
			for i in 3:
				var p := Vector2(-5 + i * 5, (i % 2) * 5 - 2)
				draw_colored_polygon(PackedVector2Array([p + Vector2(-3, 0), p + Vector2(0, -5), p + Vector2(5, -2), p + Vector2(2, 4)]), c.lightened(i * 0.1))
		else:
			draw_circle(Vector2.ZERO, 3, Color.WHITE)
	func _dulce() -> void:
		var r: float = datos.radio
		var c: Color = datos.color
		if datos.forma == "aro":
			draw_arc(Vector2(1.5, 2.5), r * 0.65, 0, TAU, 48, Color(0.22, 0.16, 0.09, 0.18), r * 0.66, true)
			draw_arc(Vector2.ZERO, r * 0.65, 0, TAU, 48, Color("b88b59"), r * 0.68, true)
			draw_arc(Vector2(0, -r * 0.035), r * 0.65, 0, TAU, 48, c, r * 0.48, true)
			for i in 8:
				var a := i * TAU / 8 + 0.2
				var punto := Vector2.from_angle(a) * r * 0.65
				draw_line(punto, punto + Vector2.from_angle(a + 0.7) * r * 0.08, Color("e8d9b8") if i % 2 else Color("a77262"), maxf(1, r * 0.035), true)
		else:
			draw_circle(Vector2(1.5, 2.5), r * 0.98, Color(0.22, 0.16, 0.09, 0.18))
			var pisos := 3 if datos.forma == "torta_pisos" else 1
			for piso in pisos:
				var radio := r * (1.0 - piso * 0.28)
				var centro := Vector2(0, -piso * r * 0.045)
				draw_circle(centro, radio, c.darkened(0.22))
				draw_circle(centro - Vector2(0, radio * 0.04), radio * 0.93, c)
				draw_arc(centro, radio * 0.80, 0, TAU, 40, Color("ebdfc8"), maxf(1, radio * 0.065), true)
				for i in 6:
					var punto := centro + Vector2.from_angle(TAU * i / 6 + 0.2) * radio * 0.68
					draw_circle(punto, radio * 0.09, Color("f1e8d3"))
					draw_circle(punto + Vector2(0, -radio * 0.02), radio * 0.055, Color("b06f59"))
				draw_arc(centro, radio * 0.88, -2.8, -1.0, 16, c.lightened(0.16), maxf(1, radio * 0.035), true)

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(2, 2)
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.world_2d = World2D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	for c in Juego.castas:
		for evolucion in 3:
			for cuadro in CUADROS:
				var p := Pintura.new()
				p.tipo = "hormiga"
				p.datos = c
				p.evolucion = evolucion
				p.fase = TAU * cuadro / CUADROS
				_agregar("hormiga:%s:%d:%d" % [c.id, evolucion, cuadro], p, Rect2(-12, -12, 24, 24), 3)
	for tipo in Juego.comidas:
		var comida := Comida.new()
		comida._usar_cache = false
		var ilustracion: Dictionary = tipo.duplicate()
		var tono: Color = tipo.color
		# Colores de pastel/pan y acentos de fruta comparten la misma paleta
		# mate del mobiliario. Sólo cambia la copia usada para hornear el arte.
		ilustracion.color = Color.from_hsv(tono.h, tono.s * 0.82, minf(tono.v, 0.92)).lerp(Color("ead8b0"), 0.025)
		comida.configurar(ilustracion, 123)
		comida.rotation = 0
		var r: float = tipo.radio + 5
		if tipo.forma in ["torta", "torta_pisos"] or (tipo.forma == "aro" and tipo.radio > 12):
			var dulce := Pintura.new()
			dulce.tipo = "reposteria"
			dulce.datos = ilustracion
			_agregar("comida:" + tipo.id, dulce, Rect2(-r, -r, r * 2, r * 2), 2)
			comida.free()
		else:
			_agregar("comida:" + tipo.id, comida, Rect2(-r, -r, r * 2, r * 2), 2)
	var catalogo := catalogo_muebles()
	for i in catalogo.size():
		var id := clave_mueble(catalogo[i])
		if _mueble_claves.has(id):
			continue # una textura por acabado y orientación, no por instancia
		var p := Pintura.new()
		p.tipo = "mueble"
		p.datos = catalogo[i].duplicate()
		var r: Rect2 = p.datos.rect
		p.datos.rect = Rect2(Vector2.ZERO, r.size)
		# El dibujo mate conserva líneas amplias a448px; los monumentos guardan
		# su resolución anterior. Más tipos no implican otra textura por pieza.
		var resolucion := 448.0 if p.datos.tipo in ArteCasa.ILUSTRADOS else 512.0
		var escala := minf(0.8, resolucion / maxf(r.size.x + 75, r.size.y + 150))
		_agregar("mueble:%d" % i, p, Rect2(-35, -100, r.size.x + 75, r.size.y + 150), escala)
		_mueble_claves[id] = "mueble:%d" % i
		_mueble_medidas[id] = r.size
	for material_id in 4:
		var resto := Pintura.new()
		resto.tipo = "resto"
		resto.datos = {"color": [Color("d9bb80"), Color("b58d61"), Color("95afa0"), Color("c8bba2")][material_id]}
		_agregar("resto:%d" % material_id, resto, Rect2(-12, -12, 24, 24), 3)
	var carga := Pintura.new()
	_agregar("carga", carga, Rect2(-4, -4, 8, 8), 4)
	# Orden por altura: las camas y bibliotecas no dejan filas casi vacías.
	_pendientes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.rect.size.y * a.escala > b.rect.size.y * b.escala)
	_alturas.resize(127)
	_alturas.fill(4)
	for pendiente in _pendientes:
		_montar(pendiente.clave, pendiente.dibujo, pendiente.rect, pendiente.escala)
	_pendientes.clear()
	_viewport.size = Vector2i(2048, ceili((_alto_atlas + 4) / 64.0) * 64)
	textura = _viewport.get_texture()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	# Congelar el atlas; no agrega un segundo render por cuadro.
	listo = true
	preparado.emit()

func _agregar(clave: String, dibujo: Node2D, rect: Rect2, escala: float) -> void:
	_pendientes.append({"clave": clave, "dibujo": dibujo, "rect": rect, "escala": escala})

func _montar(clave: String, dibujo: Node2D, rect: Rect2, escala: float) -> void:
	var tam := Vector2i((rect.size * escala).ceil())
	# Skyline de 16 px: rellena huecos sin reservar filas enteras para piezas altas.
	var columnas := ceili((tam.x + 8) / 16.0)
	var mejor := 0
	var nivel := 8192
	for inicio in range(_alturas.size() - columnas + 1):
		var altura := 4
		for j in range(inicio, inicio + columnas):
			altura = maxi(altura, _alturas[j])
			if altura >= nivel:
				break
		if altura < nivel:
			nivel = altura
			mejor = inicio
	_x = 4 + mejor * 16
	_y = nivel
	assert(_y + tam.y < 8192, "El atlas necesita más espacio")
	regiones[clave] = Rect2(_x, _y, tam.x, tam.y)
	tamanos[clave] = rect
	dibujo.position = Vector2(_x, _y) - rect.position * escala
	dibujo.scale = Vector2.ONE * escala
	_viewport.add_child(dibujo)
	for j in range(mejor, mejor + columnas):
		_alturas[j] = _y + tam.y + 8
	_alto_atlas = maxi(_alto_atlas, _y + tam.y)

func dibujar(lienzo: CanvasItem, clave: String, desplazamiento := Vector2.ZERO, color := Color.WHITE) -> void:
	if regiones.has(clave):
		var rect: Rect2 = tamanos[clave]
		rect.position += desplazamiento
		lienzo.draw_texture_rect_region(textura, rect, regiones[clave], color)

func catalogo_muebles() -> Array:
	# Incluir las orientaciones/acabados efectivamente usados en cada destino.
	# El deduplicado del horneado sigue produciendo una sola región por clave.
	var catalogo := PlanoCasa.MUEBLES + Mundos.ESPECIALES
	for destino in Mundos.ORDEN:
		catalogo.append_array(Mundos.plano(destino).muebles)
	return catalogo

func clave_mueble(datos: Dictionary) -> String:
	var color: Color = datos.color
	var eje := "vertical" if datos.tipo == "biblioteca" and datos.rect.size.y > datos.rect.size.x else "horizontal"
	return "%s:%s:%s:%s:%s" % [datos.tipo, datos.get("frente", "sur"), color.to_html(), datos.get("acabado", "normal"), eje]

func dibujar_mueble(lienzo: CanvasItem, datos: Dictionary) -> void:
	var id := clave_mueble(datos)
	if not _mueble_claves.has(id):
		return
	var clave: String = _mueble_claves[id]
	var r: Rect2 = datos.rect
	var escala: Vector2 = r.size / _mueble_medidas[id]
	var original: Rect2 = tamanos[clave]
	var destino := Rect2(r.position + original.position * escala, original.size * escala)
	lienzo.draw_texture_rect_region(textura, destino, regiones[clave])
