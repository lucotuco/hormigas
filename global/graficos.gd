extends Node
## Un atlas compartido: el arte procedural se dibuja una vez, no por hormiga/cuadro.
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
		elif tipo == "resto":
			var c: Color = datos.color
			for i in 3:
				var p := Vector2(-5 + i * 5, (i % 2) * 5 - 2)
				draw_colored_polygon(PackedVector2Array([p + Vector2(-3, 0), p + Vector2(0, -5), p + Vector2(5, -2), p + Vector2(2, 4)]), c.lightened(i * 0.1))
		else:
			draw_circle(Vector2.ZERO, 3, Color.WHITE)

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
		comida.configurar(tipo, 123)
		comida.rotation = 0
		var r: float = tipo.radio + 5
		_agregar("comida:" + tipo.id, comida, Rect2(-r, -r, r * 2, r * 2), 2)
	var catalogo := PlanoCasa.MUEBLES + Mundos.ESPECIALES
	for i in catalogo.size():
		var p := Pintura.new()
		p.tipo = "mueble"
		p.datos = catalogo[i].duplicate()
		var r: Rect2 = p.datos.rect
		p.datos.rect = Rect2(Vector2.ZERO, r.size)
		var escala := minf(0.8, 512.0 / maxf(r.size.x + 75, r.size.y + 150))
		_agregar("mueble:%d" % i, p, Rect2(-35, -100, r.size.x + 75, r.size.y + 150), escala)
		var id := str(p.datos.tipo) + ":" + str(p.datos.get("frente", "sur"))
		if not _mueble_claves.has(id):
			_mueble_claves[id] = "mueble:%d" % i
			_mueble_medidas[id] = r.size
	for material_id in 4:
		var resto := Pintura.new()
		resto.tipo = "resto"
		resto.datos = {"color": [Color("e7c77d"), Color("bc9364"), Color("9cb5ac"), Color("c8bba2")][material_id]}
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

func dibujar_mueble(lienzo: CanvasItem, datos: Dictionary) -> void:
	var id := str(datos.tipo) + ":" + str(datos.get("frente", "sur"))
	if not _mueble_claves.has(id):
		return
	var clave: String = _mueble_claves[id]
	var r: Rect2 = datos.rect
	var escala: Vector2 = r.size / _mueble_medidas[id]
	var original: Rect2 = tamanos[clave]
	var destino := Rect2(r.position + original.position * escala, original.size * escala)
	lienzo.draw_texture_rect_region(textura, destino, regiones[clave])
