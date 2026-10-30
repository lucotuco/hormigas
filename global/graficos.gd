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
var _regiones_muebles_crudas: Dictionary = {}
var _rects_muebles_crudos: Dictionary = {}
var _alturas := PackedInt32Array()
var _alto_atlas := 4
var _animaciones: Dictionary = {}
## Geometría del arte prehorneada: idéntica en juego y simulación headless.
## Nunca se lee la GPU para decidir cuánto material o dinero se extrae.
var _formas_alimentos: Dictionary = {}
var tiempo_lectura_siluetas_usec := 0
var tiempo_cpu_siluetas_usec := 0
var pixeles_siluetas_revisados := 0
var pixeles_lectura_atlas := 0
const GRILLA_SILUETA_ALIMENTO := 8
const ALPHA_MATERIAL_ALIMENTO := 0.55

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
		elif tipo == "pared":
			DibujoCasa.pared(self, Rect2(0, 0, 96, 64))
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
	_cargar_siluetas_alimentos()
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
	var pared := Pintura.new()
	pared.tipo = "pared"
	_agregar("material:pared", pared, Rect2(0, 0, 96, 64), 1)
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
	await _separar_material()
	_ajustar_cuerpos()
	# Congelar el atlas; no agrega un segundo render por cuadro.
	listo = true
	preparado.emit()


func _separar_material() -> void:
	# Segundo pase GPU de arranque: el cutoff ve la alpha del sprite COMPLETO,
	# no de cada pincelada. El atlas crudo se libera; no quedan dos atlas vivos.
	var crudo := _viewport
	var limpio := SubViewport.new()
	limpio.size = crudo.size
	limpio.transparent_bg = true
	limpio.disable_3d = true
	limpio.world_2d = World2D.new()
	limpio.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(limpio)
	var recorte := ShaderMaterial.new()
	recorte.shader = preload("res://mundo/atlas_material.gdshader")
	for clave: String in regiones:
		var copia := Sprite2D.new()
		copia.texture = textura
		copia.region_enabled = true
		copia.region_filter_clip_enabled = true
		copia.region_rect = regiones[clave]
		copia.centered = false
		copia.position = regiones[clave].position
		if clave.begins_with("mueble:") or clave == "material:pared":
			copia.material = recorte
		limpio.add_child(copia)
	limpio.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	limpio.render_target_update_mode = SubViewport.UPDATE_DISABLED
	textura = limpio.get_texture()
	_viewport = limpio
	for copia in limpio.get_children():
		copia.queue_free()
	crudo.queue_free()


func _ajustar_cuerpos() -> void:
	for datos: Dictionary in catalogo_muebles():
		var id := clave_mueble(datos)
		if not _mueble_claves.has(id):
			continue
		var clave: String = _mueble_claves[id]
		if _regiones_muebles_crudas.has(clave):
			continue
		_regiones_muebles_crudas[clave] = regiones[clave]
		_rects_muebles_crudos[clave] = tamanos[clave]
		var cuerpo := SiluetaMueble.datos_material(datos)
		if cuerpo.is_empty():
			continue
		var base: Vector2 = _mueble_medidas[id]
		var b: Array = cuerpo.limites
		var ocupado := Rect2(Vector2(b[0], b[1]) * base, Vector2(b[2], b[3]) * base)
		var original: Rect2 = tamanos[clave]
		var atlas: Rect2 = regiones[clave]
		var escala := atlas.size / original.size
		regiones[clave] = Rect2(atlas.position + (ocupado.position - original.position) * escala, ocupado.size * escala)
		# El cuerpo completo se ajusta al mismo rect físico, sin perder sus
		# salientes ni dejar una tira visible fuera de la máscara comestible.
		tamanos[clave] = Rect2(Vector2.ZERO, base)


func configurar_sombra(material_cuerpo: ShaderMaterial, datos: Dictionary) -> void:
	var id := clave_mueble(datos)
	if not listo or not _mueble_claves.has(id):
		return
	var clave: String = _mueble_claves[id]
	var region: Rect2 = regiones[clave]
	var rect: Rect2 = datos.rect
	var inv_atlas := Vector2.ONE / Vector2(textura.get_width(), textura.get_height())
	material_cuerpo.set_shader_parameter("sombra_activa", true)
	material_cuerpo.set_shader_parameter("region_cuerpo", Vector4(region.position.x * inv_atlas.x, region.position.y * inv_atlas.y, region.end.x * inv_atlas.x, region.end.y * inv_atlas.y))
	material_cuerpo.set_shader_parameter("uv_por_unidad", region.size * inv_atlas / rect.size)

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

func dibujar_mueble(lienzo: CanvasItem, datos: Dictionary, con_sombra := false) -> void:
	var id := clave_mueble(datos)
	if not _mueble_claves.has(id):
		return
	var clave: String = _mueble_claves[id]
	var r: Rect2 = datos.rect
	var escala: Vector2 = r.size / _mueble_medidas[id]
	var original: Rect2 = tamanos[clave]
	var destino := Rect2(r.position + original.position * escala, original.size * escala)
	var fuente: Rect2 = regiones[clave]
	if con_sombra:
		var margen := Vector2.ONE * 12
		var relacion := fuente.size / destino.size
		destino = destino.grow(12)
		fuente = Rect2(fuente.position - margen * relacion, fuente.size + margen * relacion * 2)
	lienzo.draw_texture_rect_region(textura, destino, fuente)


## El retazo usa el mismo atlas y la misma transformación que el objeto.
## No se lee la GPU ni se crea una textura al arrancar un bocado.
func region_porcion(clave: String, porcion: Rect2, dibujo: Rect2) -> Rect2:
	if not listo or not regiones.has(clave) or not dibujo.has_area():
		return Rect2()
	var recorte := porcion.intersection(dibujo)
	if not recorte.has_area():
		return Rect2()
	var atlas: Rect2 = regiones[clave]
	var escala := atlas.size / dibujo.size
	return Rect2(atlas.position + (recorte.position - dibujo.position) * escala, recorte.size * escala)


func region_porcion_mueble(datos: Dictionary, porcion_mundo: Rect2) -> Rect2:
	var id := clave_mueble(datos)
	if not listo or not _mueble_claves.has(id):
		return Rect2()
	var clave: String = _mueble_claves[id]
	var rect: Rect2 = datos.rect
	var escala: Vector2 = rect.size / _mueble_medidas[id]
	var original: Rect2 = tamanos[clave]
	var dibujo := Rect2(rect.position + original.position * escala, original.size * escala)
	return region_porcion(clave, porcion_mundo, dibujo)


## Vista retenida, sólo lectura. Cajas ocupadas de una grilla 8×8, en
## coordenadas locales del alimento; se omiten las zonas completamente vacías.
## El recurso incluido también está disponible sin renderer.
func formas_alimento(id: String) -> Array[Rect2]:
	if not _formas_alimentos.has(id):
		return []
	return _formas_alimentos[id]


func _cargar_siluetas_alimentos() -> void:
	var datos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://datos/siluetas_comidas.json"))
	for id: String in datos:
		var zonas: Array[Rect2] = []
		for r: Array in datos[id]:
			zonas.append(Rect2(r[0], r[1], r[2], r[3]))
		_formas_alimentos[id] = zonas


func _preparar_siluetas_alimentos() -> void:
	_formas_alimentos.clear()
	pixeles_siluetas_revisados = 0
	var inicio_lectura := Time.get_ticks_usec()
	var imagen := textura.get_image()
	tiempo_lectura_siluetas_usec = Time.get_ticks_usec() - inicio_lectura
	if imagen == null or imagen.is_empty():
		return
	pixeles_lectura_atlas = imagen.get_width() * imagen.get_height()
	var inicio_cpu := Time.get_ticks_usec()
	for tipo in Juego.comidas:
		var clave := "comida:" + String(tipo.id)
		if not regiones.has(clave) or not tamanos.has(clave):
			continue
		var radio: float = tipo.radio
		var cuerpo := Rect2(Vector2.ONE * -radio, Vector2.ONE * radio * 2.0)
		_formas_alimentos[tipo.id] = _formas_desde_alpha(imagen, regiones[clave], tamanos[clave], cuerpo)
	tiempo_cpu_siluetas_usec = Time.get_ticks_usec() - inicio_cpu
	# La única copia CPU del atlas sale de alcance aquí; las cajas no la referencian.
	imagen = null
	print("[Graficos] Siluetas de %d alimentos: lectura %.2f ms; CPU %.2f ms; %d píxeles revisados; atlas RGBA8 aprox. %.2f MiB temporales." % [
		_formas_alimentos.size(), tiempo_lectura_siluetas_usec / 1000.0, tiempo_cpu_siluetas_usec / 1000.0,
		pixeles_siluetas_revisados, pixeles_lectura_atlas * 4.0 / 1048576.0])


func _formas_desde_alpha(imagen: Image, atlas: Rect2, dibujo: Rect2, cuerpo: Rect2) -> Array[Rect2]:
	var formas: Array[Rect2] = []
	if not dibujo.has_area() or not atlas.has_area() or not cuerpo.has_area():
		return formas
	var escala := atlas.size / dibujo.size
	# Misma transformación dibujo→atlas que region_porcion, antes de listo.
	var origen_pixel := atlas.position + (cuerpo.position - dibujo.position) * escala
	var fin_pixel := atlas.position + (cuerpo.end - dibujo.position) * escala
	var minimo_x := clampi(floori(origen_pixel.x), 0, imagen.get_width())
	var minimo_y := clampi(floori(origen_pixel.y), 0, imagen.get_height())
	var maximo_x := clampi(ceili(fin_pixel.x), 0, imagen.get_width())
	var maximo_y := clampi(ceili(fin_pixel.y), 0, imagen.get_height())
	var cantidad := GRILLA_SILUETA_ALIMENTO * GRILLA_SILUETA_ALIMENTO
	var izquierda := PackedInt32Array()
	var arriba := PackedInt32Array()
	var derecha := PackedInt32Array()
	var abajo := PackedInt32Array()
	izquierda.resize(cantidad)
	izquierda.fill(maximo_x)
	arriba.resize(cantidad)
	arriba.fill(maximo_y)
	derecha.resize(cantidad)
	derecha.fill(minimo_x - 1)
	abajo.resize(cantidad)
	abajo.fill(minimo_y - 1)
	for y in range(minimo_y, maximo_y):
		var local_y := dibujo.position.y + (y + 0.5 - atlas.position.y) / escala.y
		if local_y < cuerpo.position.y or local_y >= cuerpo.end.y:
			continue
		var fila := clampi(floori((local_y - cuerpo.position.y) / cuerpo.size.y * GRILLA_SILUETA_ALIMENTO), 0, GRILLA_SILUETA_ALIMENTO - 1)
		for x in range(minimo_x, maximo_x):
			var local_x := dibujo.position.x + (x + 0.5 - atlas.position.x) / escala.x
			if local_x < cuerpo.position.x or local_x >= cuerpo.end.x:
				continue
			pixeles_siluetas_revisados += 1
			if imagen.get_pixel(x, y).a <= ALPHA_MATERIAL_ALIMENTO:
				continue
			var columna := clampi(floori((local_x - cuerpo.position.x) / cuerpo.size.x * GRILLA_SILUETA_ALIMENTO), 0, GRILLA_SILUETA_ALIMENTO - 1)
			var id := fila * GRILLA_SILUETA_ALIMENTO + columna
			izquierda[id] = mini(izquierda[id], x)
			arriba[id] = mini(arriba[id], y)
			derecha[id] = maxi(derecha[id], x)
			abajo[id] = maxi(abajo[id], y)
	for id in cantidad:
		if derecha[id] < izquierda[id] or abajo[id] < arriba[id]:
			continue
		var minimo := dibujo.position + (Vector2(izquierda[id], arriba[id]) - atlas.position) / escala
		var maximo := dibujo.position + (Vector2(derecha[id] + 1, abajo[id] + 1) - atlas.position) / escala
		var tamano_zona := cuerpo.size / float(GRILLA_SILUETA_ALIMENTO)
		var zona := Rect2(cuerpo.position + Vector2(id % GRILLA_SILUETA_ALIMENTO, id / GRILLA_SILUETA_ALIMENTO as int) * tamano_zona, tamano_zona)
		var ocupado := Rect2(minimo, maximo - minimo).intersection(zona).intersection(cuerpo)
		if ocupado.has_area():
			formas.append(ocupado)
	return formas
