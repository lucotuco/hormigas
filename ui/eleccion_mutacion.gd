class_name EleccionMutacion
extends Control
## Pantalla de "subiste de nivel": tres cartas de mutación con rareza. La run
## queda en pausa (EvolucionRun) y esta pantalla procesa igual. Se elige con
## clic o con 1, 2 y 3; R revuelve una vez por run. Al elegir, la carta
## destella y la pantalla se va enseguida: la acción vuelve rápido.

const ANCHO_CARTA := 250.0
const ALTO_CARTA := 330.0
const NOMBRES_RAREZA := {"comun": "COMÚN", "rara": "RARA", "epica": "ÉPICA", "legendaria": "LEGENDARIA"}

var evolucion: EvolucionRun
var _fondo: ColorRect
var _titulo: Label
var _subtitulo: Label
var _fila: HBoxContainer
var _boton_revolver: Button
var _inventario: Label
var _cartas: Array[Carta] = []
var _bloqueada := false


class Carta:
	extends Control
	signal elegida(indice: int)

	var indice := 0
	var datos: Dictionary
	var color := Color.WHITE
	var _hover := 0.0
	var _hover_objetivo := 0.0
	var _brillo := 0.0
	var _elegida := false
	var _fuente: Font

	func _init(d: Dictionary, i: int) -> void:
		datos = d
		indice = i
		color = EvolucionRun.COLORES_RAREZA.get(d.rareza, Color.WHITE)
		custom_minimum_size = Vector2(EleccionMutacion.ANCHO_CARTA, EleccionMutacion.ALTO_CARTA)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		focus_mode = Control.FOCUS_ALL
		mouse_entered.connect(func() -> void: _hover_objetivo = 1.0)
		mouse_exited.connect(func() -> void: _hover_objetivo = 0.0)

	func _ready() -> void:
		_fuente = get_theme_default_font()
		pivot_offset = custom_minimum_size * 0.5

	func destacar() -> void:
		_elegida = true
		_brillo = 1.0

	func _process(delta: float) -> void:
		var antes := _hover
		_hover = move_toward(_hover, _hover_objetivo if not _elegida else 1.0, delta * 7.0)
		_brillo = maxf(0.0, _brillo - delta * 2.5)
		if antes != _hover or _brillo > 0.0 or datos.rareza in ["epica", "legendaria"]:
			position.y = -10.0 * _hover
			queue_redraw()

	func _gui_input(evento: InputEvent) -> void:
		var clic := evento as InputEventMouseButton
		if clic and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			elegida.emit(indice)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var t := Time.get_ticks_msec() * 0.001
		# Aura de la rareza: las altas laten, la legendaria también gira su brillo.
		var aura := 0.0
		if datos.rareza == "epica":
			aura = 0.35 + 0.15 * sin(t * 3.0)
		elif datos.rareza == "legendaria":
			aura = 0.6 + 0.25 * sin(t * 4.0)
		aura = maxf(aura, _hover * 0.5)
		if aura > 0.0:
			for i in 3:
				var g := 4.0 + i * 5.0
				draw_style_box(Estilo.caja(Color(color, aura * (0.22 - i * 0.06)), 18 + int(g), Color.TRANSPARENT, 0, 0), r.grow(g))
		var fondo := Color("1b1f1c").lerp(color, 0.08 + 0.06 * _hover)
		draw_style_box(Estilo.caja(fondo, 16, color.darkened(0.15 - 0.15 * _hover), 3, 0), r)
		# Franja de rareza.
		draw_style_box(Estilo.caja(Color(color, 0.92), 16, Color.TRANSPARENT, 0, 0), Rect2(Vector2(0, 0), Vector2(size.x, 34)))
		draw_rect(Rect2(Vector2(0, 18), Vector2(size.x, 16)), Color(color, 0.92))
		_texto_centrado(tr(EleccionMutacion.NOMBRES_RAREZA.get(datos.rareza, "")), 24, 14, Color(0.09, 0.07, 0.06))
		draw_string(_fuente, Vector2(12, 24), "%d" % (indice + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.09, 0.07, 0.06, 0.75))
		# Sello hexagonal con el valor grande: lo primero que se lee.
		var centro := Vector2(size.x * 0.5, 118)
		var hexagono := PackedVector2Array()
		for i in 6:
			hexagono.append(centro + Vector2.from_angle(TAU * i / 6.0) * 70.0)
		draw_colored_polygon(hexagono, Color(color, 0.16))
		hexagono.append(hexagono[0])
		draw_polyline(hexagono, Color(color, 0.85), 2.5, true)
		var valor := _valor_grande()
		var tamano_valor := 36 if valor.length() <= 4 else 30
		_texto_centrado(valor, centro.y + tamano_valor * 0.36, tamano_valor, color.lightened(0.25), 6)
		# Nombre y descripción.
		_texto_centrado(tr(datos.nombre), 212, 19, Estilo.TEXTO, 4)
		var descripcion := EvolucionRun.descripcion_carta(datos)
		var lineas := _partir(descripcion, size.x - 36, 14)
		for i in lineas.size():
			_texto_centrado(lineas[i], 242 + i * 19, 14, Estilo.TEXTO_SUAVE)
		if int(datos.veces) > 0:
			_texto_centrado(tr("Ya tenés ×%d") % int(datos.veces), size.y - 16, 13, Color(color, 0.95))
		if _brillo > 0.0:
			draw_style_box(Estilo.caja(Color(1, 1, 1, _brillo * 0.55), 16, Color.TRANSPARENT, 0, 0), r)

	func _valor_grande() -> String:
		var v := EvolucionRun.texto_valor(datos)
		match datos.efecto:
			"critico_mult": return "+%s×" % v
			"capacidad", "cria": return "+%s" % v
			"tiempo": return "+%s s" % v
			_: return "+%s%%" % v

	func _texto_centrado(texto: String, y: float, tamano: int, tinta: Color, contorno := 0) -> void:
		var ancho := _fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
		var pos := Vector2((size.x - ancho) * 0.5, y)
		if contorno > 0:
			draw_string_outline(_fuente, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, contorno, Color(0.05, 0.04, 0.03, 0.85))
		draw_string(_fuente, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, tinta)

	func _partir(texto: String, ancho_max: float, tamano: int) -> PackedStringArray:
		var lineas := PackedStringArray()
		var actual := ""
		for palabra in texto.split(" "):
			var prueba := palabra if actual == "" else actual + " " + palabra
			if _fuente.get_string_size(prueba, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x > ancho_max and actual != "":
				lineas.append(actual)
				actual = palabra
			else:
				actual = prueba
		if actual != "":
			lineas.append(actual)
		return lineas


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 90
	visible = false
	_fondo = ColorRect.new()
	_fondo.color = Color(0.03, 0.025, 0.05, 0.74)
	_fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	var columna := VBoxContainer.new()
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	columna.add_theme_constant_override("separation", 14)
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(columna)
	_titulo = Estilo.etiqueta("", 52, EvolucionRun.COLORES_RAREZA.legendaria, 2)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(_titulo)
	_subtitulo = Estilo.etiqueta("", 17, Estilo.TEXTO)
	_subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(_subtitulo)
	var espacio := Control.new()
	espacio.custom_minimum_size.y = 14
	espacio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(espacio)
	_fila = HBoxContainer.new()
	_fila.alignment = BoxContainer.ALIGNMENT_CENTER
	_fila.add_theme_constant_override("separation", 26)
	_fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(_fila)
	var pie := HBoxContainer.new()
	pie.alignment = BoxContainer.ALIGNMENT_CENTER
	pie.add_theme_constant_override("separation", 18)
	pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(pie)
	_boton_revolver = Estilo.boton("", 15, Color("2b2638"), Color("8c5cff"))
	_boton_revolver.custom_minimum_size = Vector2(200, 40)
	_boton_revolver.focus_mode = Control.FOCUS_NONE
	_boton_revolver.pressed.connect(_revolver)
	pie.add_child(_boton_revolver)
	_inventario = Estilo.etiqueta("", 13, Estilo.TEXTO_SUAVE)
	_inventario.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inventario.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inventario.custom_minimum_size.x = 820
	columna.add_child(_inventario)


func mostrar(oferta: Array[Dictionary]) -> void:
	_bloqueada = false
	visible = true
	_titulo.text = tr("¡COFRE DORADO!") if evolucion.oferta_cofre else tr("¡NIVEL %d!") % evolucion.nivel
	var extra := ""
	if evolucion.pendientes > 1:
		extra = "  ·  " + tr("%d niveles por elegir") % evolucion.pendientes
	_subtitulo.text = tr("Elegí una mutación para esta expedición  ·  1 · 2 · 3") + extra
	_actualizar_revolver()
	_actualizar_inventario()
	_armar(oferta)
	modulate.a = 0.0
	var aparecer := create_tween()
	aparecer.tween_property(self, "modulate:a", 1.0, 0.12)
	_titulo.pivot_offset = _titulo.size * 0.5
	_titulo.scale = Vector2.ONE * 1.6
	create_tween().tween_property(_titulo, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _armar(oferta: Array[Dictionary]) -> void:
	for c in _cartas:
		c.queue_free()
	_cartas.clear()
	var mejor := 0
	for i in oferta.size():
		var carta := Carta.new(oferta[i], i)
		carta.elegida.connect(_elegir)
		_fila.add_child(carta)
		_cartas.append(carta)
		mejor = maxi(mejor, Juego.RAREZAS.find(oferta[i].rareza))
		carta.modulate.a = 0.0
		carta.scale = Vector2.ONE * 0.7
		var tween := carta.create_tween().set_parallel(true)
		tween.tween_property(carta, "modulate:a", 1.0, 0.16).set_delay(0.06 + i * 0.08)
		tween.tween_property(carta, "scale", Vector2.ONE, 0.3).set_delay(0.06 + i * 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if mejor >= 3:
		Sonido.tocar("legendaria", 1.0, 0.0)
	elif mejor >= 2:
		Sonido.tocar("carta", 1.25, 0.0)
	else:
		Sonido.tocar("carta", 1.0, 0.0)


func _actualizar_revolver() -> void:
	_boton_revolver.text = tr("Revolver (R) · %d") % evolucion.revolver_restante
	_boton_revolver.disabled = evolucion.revolver_restante <= 0


func _actualizar_inventario() -> void:
	if evolucion.elegidas.is_empty():
		_inventario.text = ""
		return
	var partes := PackedStringArray()
	for id in evolucion.elegidas:
		var m: Dictionary = Juego.mutaciones_por_id.get(id, {})
		if not m.is_empty():
			partes.append("%s ×%d" % [tr(m.nombre), int(evolucion.elegidas[id])])
	_inventario.text = tr("En esta expedición: %s") % "  ·  ".join(partes)


func _revolver() -> void:
	if _bloqueada or not evolucion.revolver():
		return
	_actualizar_revolver()
	_armar(evolucion.oferta)


func _elegir(indice: int) -> void:
	if _bloqueada or indice < 0 or indice >= _cartas.size():
		return
	_bloqueada = true
	var carta := _cartas[indice]
	carta.destacar()
	for c in _cartas:
		if c != carta:
			c.create_tween().tween_property(c, "modulate:a", 0.15, 0.12)
	var tween := carta.create_tween()
	tween.tween_property(carta, "scale", Vector2.ONE * 1.1, 0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.12)
	tween.tween_callback(func() -> void: evolucion.elegir(indice))


## Lo llama EvolucionRun al quedar sin niveles pendientes.
func ocultar() -> void:
	if not visible:
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func() -> void: visible = false)


func _unhandled_input(evento: InputEvent) -> void:
	if not visible or _bloqueada:
		return
	var tecla := evento as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	match tecla.keycode:
		KEY_1, KEY_KP_1: _elegir(0)
		KEY_2, KEY_KP_2: _elegir(1)
		KEY_3, KEY_KP_3: _elegir(2)
		KEY_R: _revolver()
		_: return
	get_viewport().set_input_as_handled()
