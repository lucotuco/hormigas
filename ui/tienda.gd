extends Control
## El hormiguero es el árbol: cada mejora excava su propia cámara visible.
const ESCENA_RUN := "res://mundo/run.tscn"
const SALAS := {
	"Colonia": {"titulo": "El criadero", "detalle": "Una familia cada vez más grande.", "color": Color("b8cd91"), "pos": Vector2(.32, .27)},
	"Mandíbulas": {"titulo": "El taller", "detalle": "Comida → madera y telas → materiales resistentes → paredes.", "color": Color("e7ac7d"), "pos": Vector2(.68, .29)},
	"Recolección": {"titulo": "La despensa", "detalle": "Pequeños viajes, grandes tesoros.", "color": Color("e8cc86"), "pos": Vector2(.32, .53)},
	"Feromonas": {"titulo": "El observatorio", "detalle": "Todos los caminos llevan a casa.", "color": Color("8dc3bc"), "pos": Vector2(.69, .63)},
	"Tiempo": {"titulo": "El refugio", "detalle": "Siempre hay tiempo para otro bocado.", "color": Color("c3add4"), "pos": Vector2(.41, .77)},
	"Territorio": {"titulo": "La excavación", "detalle": "La cocina es solo el comienzo.", "color": Color("c9b48c"), "pos": Vector2(.58, .77)},
}
const SECCIONES := {
	"hogar": {"pos": Vector2(.50, .44), "color": Color("b8cd91")},
	"castas": {"pos": Vector2(.085, .10), "color": Color("e7ac7d")},
	"viajes": {"pos": Vector2(.915, .10), "color": Color("8dc3bc")},
	"legado": {"pos": Vector2(.50, .13), "color": Color("d9b5e7")},
}
var _tarjetas: Dictionary = {}
var _salas: Dictionary = {}
var _rama := "Colonia"
var _lbl_migas: Label
var _lbl_proxima: Label
var _lbl_sala: Label
var _lbl_detalle: Label
var _lbl_estado: Label
var _lista: VBoxContainer
var _boton_run: Button
var _migas_mostradas := 0.0
var _tween_compra: Tween
var _ventana: VentanaModal
var _cuerpo_mejoras: Control
var _panel_castas: PanelCastas
var _pestanas: Dictionary = {}
var _cantidades: Dictionary = {}
var _panel_viajes: PanelCampana
var _panel_legado: PanelCampana
var _lbl_comprar: Label
var _mapa_hormiguero: Control
var _corte_tierra: ArbolHormiguero
var _animacion_hormiguero: TransitoNido
var _seccion := "hogar"
var _nodos_mejoras: Dictionary = {}
var _secciones_por_descubrir: Dictionary = {}
var _mejora_seleccionada := ""
var _ficha_mejoras: PanelContainer
var _panel_seccion: PanelContainer
var _titulo_seccion: Label
var _boton_volver: Button
var _area_nido: Control
const NOMBRES_PESTANAS := {"hogar": "Mejoras", "castas": "Castas", "viajes": "Viajes", "legado": "Jalea real"}


class SelloMejora extends Control:
	var stat := "dano"
	var color := Color.WHITE
	var abierta := false
	var nivel := 0

	func _draw() -> void:
		var tinta := color if abierta or nivel > 0 else color.darkened(.55)
		draw_set_transform(size * .5)
		match stat:
			"hormigas_iniciales", "cria":
				for i in 3:
					draw_set_transform(size * .5 + Vector2((i - 1) * 10, (i % 2) * 5 - 2), -.25, Vector2(.7, 1.1))
					draw_circle(Vector2.ZERO, 6, tinta)
			"materiales", "entradas", "radio_territorio":
				draw_polyline(PackedVector2Array([Vector2(-12, 11), Vector2(-12, -2), Vector2.ZERO + Vector2(0, -12), Vector2(12, -2), Vector2(12, 11)]), tinta, 2.4, true)
				for i in 3:
					draw_line(Vector2(-8, -2 + i * 5), Vector2(8, -2 + i * 5), Color(tinta, .6), 1.4, true)
			"capacidad", "multiplicador_migas":
				for i in 3:
					draw_circle(Vector2(-9 + i * 9, 4 - (i % 2) * 10), 5.5, tinta)
				draw_line(Vector2(-15, 13), Vector2(15, 13), tinta, 2, true)
			"duracion_run", "intervalo_mordida":
				draw_arc(Vector2.ZERO, 12, 0, TAU, 24, tinta, 2, true)
				draw_polyline(PackedVector2Array([Vector2(0, -8), Vector2.ZERO, Vector2(7, 4)]), tinta, 2, true)
			"olfato", "feromona_cantidad":
				for i in 5:
					draw_circle(Vector2(-13 + i * 6, sin(i) * 9), 2 + i * .3, Color(tinta, .4 + i * .14))
			"velocidad":
				for i in [-1, 1]:
					draw_polyline(PackedVector2Array([Vector2(-10, i * 9), Vector2(3, i * 9), Vector2(10, 0)]), tinta, 2.5, true)
			_:
				for lado in [-1, 1]:
					draw_polyline(PackedVector2Array([Vector2(lado * 9, 10), Vector2(lado * 12, -3), Vector2(lado * 5, -12), Vector2(lado * 2, -5)]), tinta, 3, true)
		if not abierta and nivel == 0:
			draw_circle(Vector2(14, -13), 5, Color("30271e"))
			draw_arc(Vector2(14, -14), 3, PI, TAU, 8, Color("9c8e76"), 1, true)
			draw_rect(Rect2(10, -14, 8, 6), Color("9c8e76"))
		draw_set_transform(Vector2.ZERO)


class CerrojoCamara extends Control:
	func _draw() -> void:
		draw_arc(Vector2(8, 7), 5, PI, TAU, 14, Color("a3947b"), 2, true)
		draw_rect(Rect2(1, 7, 14, 11), Color("a3947b"))
		draw_circle(Vector2(8, 12), 1.5, Color("382a20"))


class IconoSala extends Control:
	var rama := "Colonia"
	var color := Color.WHITE
	var nivel := 0
	var seleccionada := false
	var disponibles := 0
	var reloj := 0.0
	var proximo_dibujo := 0.0

	func _process(delta: float) -> void:
		reloj += delta
		if seleccionada and is_visible_in_tree() and reloj >= proximo_dibujo:
			proximo_dibujo = reloj + 0.1
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		# La cámara pertenece al corte de tierra; el símbolo conserva su lectura.
		if seleccionada:
			draw_circle(c, 39 + sin(reloj * 2) * 2, Color(color, 0.07))
		draw_circle(c + Vector2(0, 3), 31, Color(0, 0, 0, 0.2))
		draw_circle(c, 30, Color("302a22"))
		draw_arc(c, 30, 0, TAU, 60, Color(color, 0.9 if seleccionada else 0.35), 2, true)
		var tinta := color if nivel > 0 or seleccionada else color.darkened(0.3)
		draw_set_transform(c)
		match rama:
			"Colonia":
				for p in [Vector2(-10, 3), Vector2(9, 4), Vector2(0, -10)]:
					draw_set_transform(c + p, -0.3, Vector2(0.8, 1.1))
					draw_circle(Vector2.ZERO, 7, tinta)
					draw_arc(Vector2.ZERO, 4, -2.8, -1.3, 12, tinta.lightened(0.4), 1.5, true)
			"Mandíbulas":
				for lado in [-1, 1]:
					draw_colored_polygon(PackedVector2Array([Vector2(lado * 14, 12), Vector2(lado * 18, -4), Vector2(lado * 8, -15), Vector2(lado * 3, -7), Vector2(lado * 10, -5), Vector2(lado * 6, 8)]), tinta)
			"Recolección":
				for i in 3:
					draw_circle(Vector2(-10 + i * 10, 9 - (i % 2) * 12), 7, tinta.darkened(i * 0.06))
				draw_line(Vector2(-19, 20), Vector2(19, 20), tinta, 2, true)
			"Feromonas":
				for i in 6:
					draw_circle(Vector2(-17 + i * 7, sin(i * 0.9) * 11), 2 + i * 0.35, Color(tinta, 0.35 + i * 0.12))
			"Tiempo":
				draw_arc(Vector2.ZERO, 18, 0, TAU, 40, tinta, 2, true)
				draw_polyline(PackedVector2Array([Vector2(0, -12), Vector2.ZERO, Vector2(9, 5)]), tinta, 2.5, true)
				draw_circle(Vector2.ZERO, 3, tinta)
			"Territorio":
				for i in 3:
					draw_arc(Vector2(-12, 12), 10 + i * 10, -PI * 0.5, 0, 24, Color(tinta, 1.0 - i * 0.2), 2, true)
		draw_set_transform(Vector2.ZERO)
		for i in mini(nivel, 8):
			draw_circle(c + Vector2.from_angle(PI * 0.2 + i * PI * 0.085) * 36, 2, color)
		if disponibles > 0:
			draw_circle(c + Vector2(27, -23), 7, Color("b8d891"))
			draw_circle(c + Vector2(27, -23), 10, Color(0.7, 0.9, 0.5, 0.12))


class EscenaSeccion extends Control:
	var seccion := "hogar"
	var tinta := Color.WHITE

	func _draw() -> void:
		match seccion:
			"hogar":
				# Huevos y larvas sobre una cama de fibras.
				for i in 9:
					draw_line(Vector2(12 + i * 6, 64), Vector2(20 + i * 5, 48), Color("87744d"), 2, true)
				for i in 6:
					draw_set_transform(Vector2(22 + (i % 3) * 17, 48 - (i / 3) * 20), -0.25, Vector2(0.75, 1.0))
					draw_circle(Vector2.ZERO, 9, tinta)
					draw_arc(Vector2.ZERO, 5, -2.5, -0.7, 10, tinta.lightened(0.3), 2, true)
			"castas", "legado":
				var reina := seccion == "legado"
				for lado in [-1, 1]:
					for i in 3:
						draw_polyline(PackedVector2Array([Vector2(38, 36 + i * 6), Vector2(38 + lado * 15, 26 + i * 13), Vector2(38 + lado * 23, 20 + i * 19)]), tinta.darkened(0.25), 2, true)
					draw_polyline(PackedVector2Array([Vector2(38 + lado * 5, 24), Vector2(38 + lado * 12, 13), Vector2(38 + lado * 18, 16)]), tinta, 1.5, true)
				draw_set_transform(Vector2(38, 58), 0, Vector2(1, 1.3))
				draw_circle(Vector2.ZERO, 14 if reina else 10, tinta.darkened(0.22))
				draw_set_transform(Vector2.ZERO)
				draw_circle(Vector2(38, 39), 8, tinta)
				draw_circle(Vector2(38, 25), 10, tinta.lightened(0.1))
				if reina:
					draw_colored_polygon(PackedVector2Array([Vector2(27, 12), Vector2(25, 1), Vector2(34, 7), Vector2(38, -1), Vector2(43, 7), Vector2(51, 1), Vector2(49, 12)]), Color("e5c379"))
			"viajes":
				draw_colored_polygon(PackedVector2Array([Vector2(8, 20), Vector2(29, 13), Vector2(51, 21), Vector2(73, 13), Vector2(73, 64), Vector2(51, 72), Vector2(29, 63), Vector2(8, 70)]), Color("b9a77b"))
				draw_line(Vector2(29, 13), Vector2(29, 63), Color("786648"), 1, true)
				draw_line(Vector2(51, 21), Vector2(51, 72), Color("786648"), 1, true)
				for i in 7:
					draw_circle(Vector2(18 + i * 7, 48 + sin(i) * 8), 2, Color("4b6258"))
				draw_circle(Vector2(62, 37), 5, tinta.darkened(0.45))
		draw_set_transform(Vector2.ZERO)


class TransitoNido extends Control:
	## 22 siluetas como máximo en un solo CanvasItem, sin nodos ni IA por hormiga.
	## Sólo esta capa se redibuja a 30 Hz; el suelo y las cámaras quedan retenidos.
	var rutas: Array[Curve2D] = []
	var indices_rutas: Array[int] = []
	var reloj := 0.0
	var acumulado := 0.0
	var actualizaciones := 0

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		reloj += delta
		acumulado += delta
		if acumulado >= 1.0 / 30.0:
			acumulado = fmod(acumulado, 1.0 / 30.0)
			actualizaciones += 1
			queue_redraw()

	func posicion(ruta: Curve2D, indice: int, tiempo: float) -> Vector2:
		var largo := ruta.get_baked_length()
		var recorrido := fposmod(tiempo * (22 + indice % 3 * 5) + indice * 83, largo * 2)
		return ruta.sample_baked(largo - absf(largo - recorrido))

	func _draw() -> void:
		if indices_rutas.is_empty():
			return
		for indice in mini(22, indices_rutas.size() * 2):
			var ruta := rutas[indices_rutas[(indice * 7) % indices_rutas.size()]]
			if ruta.get_baked_length() < 1:
				continue
			var p := posicion(ruta, indice, reloj)
			var rumbo := (posicion(ruta, indice, reloj + 0.08) - p).angle()
			draw_set_transform(p, rumbo)
			var tinta := Color("c3a176") if indice % 2 == 0 else Color("a38b6c")
			for pata in 3:
				var paso := sin(reloj * 11 + pata * 2 + indice) * 1.5
				for lado in [-1, 1]:
					draw_line(Vector2(-2 + pata * 2, lado), Vector2(-4 + pata * 3 + paso * lado, lado * 4), tinta, 1, true)
			draw_circle(Vector2(-4, 0), 3.0, tinta.darkened(.18))
			draw_circle(Vector2.ZERO, 2, tinta)
			draw_circle(Vector2(4, 0), 2.3, tinta)
			draw_line(Vector2(5, -1), Vector2(8, -3), tinta, 1, true)
			draw_line(Vector2(5, 1), Vector2(8, 3), tinta, 1, true)
			if indice % 4 == 0:
				draw_circle(Vector2(8, 0), 2.8, Color("dfc273"))
		draw_set_transform(Vector2.ZERO)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fondo := ColorRect.new()
	fondo.color = Color("171b18")
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 18)
	add_child(margen)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 9)
	margen.add_child(columna)
	columna.add_child(_encabezado())
	_area_nido = Control.new()
	_area_nido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(_area_nido)
	_mapa_hormiguero = _crear_mapa()
	_mapa_hormiguero.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area_nido.add_child(_mapa_hormiguero)
	_cuerpo_mejoras = Control.new()
	_cuerpo_mejoras.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cuerpo_mejoras.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area_nido.add_child(_cuerpo_mejoras)
	_ficha_mejoras = _crear_detalles()
	_ficha_mejoras.hide()
	_cuerpo_mejoras.add_child(_ficha_mejoras)
	_panel_seccion = PanelContainer.new()
	_panel_seccion.add_theme_stylebox_override("panel", Estilo.caja(Color("182019"), 24, Color("8d7751"), 2, 20))
	_panel_seccion.hide()
	_area_nido.add_child(_panel_seccion)
	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 14)
	_panel_seccion.add_child(contenido)
	var barra := HBoxContainer.new()
	contenido.add_child(barra)
	_titulo_seccion = Estilo.etiqueta("", 27, Estilo.ACENTO)
	_titulo_seccion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.add_child(_titulo_seccion)
	var cerrar := Estilo.boton(tr("Volver al hormiguero") + "  ×", 15, Color("283126"), Color("697652"))
	_boton_volver = cerrar
	cerrar.pressed.connect(_cambiar_pestana.bind("hogar"))
	barra.add_child(cerrar)
	_panel_castas = PanelCastas.new()
	_panel_castas.visible = false
	contenido.add_child(_panel_castas)
	_panel_viajes = PanelCampana.new()
	_panel_viajes.modo = "viajes"
	_panel_viajes.visible = false
	contenido.add_child(_panel_viajes)
	_panel_legado = PanelCampana.new()
	_panel_legado.modo = "legado"
	_panel_legado.visible = false
	contenido.add_child(_panel_legado)
	var pie := HBoxContainer.new()
	pie.add_theme_constant_override("separation", 20)
	pie.add_child(_crear_compra_lotes())
	var ayuda := Estilo.etiqueta(tr("Elegí una mejora para ver qué cambia."), 14, Estilo.TEXTO_SUAVE)
	ayuda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pie.add_child(ayuda)
	pie.add_child(_pie())
	columna.add_child(pie)
	_area_nido.resized.connect(_acomodar_paneles)
	Juego.migas_cambiaron.connect(_on_migas_cambiaron)
	Juego.partida_borrada.connect(_refrescar)
	Juego.modo_compra_cambio.connect(_refrescar)
	Juego.progreso_cambio.connect(_refrescar)
	_migas_mostradas = Juego.migas
	_refrescar()
	_cambiar_pestana("hogar")
	_boton_run.grab_focus()
	_acomodar_paneles.call_deferred()


func _acomodar_paneles() -> void:
	if not is_instance_valid(_panel_seccion):
		return
	var tam := _area_nido.size
	_panel_seccion.position = Vector2(tam.x * .16, tam.y * .20)
	_panel_seccion.size = Vector2(tam.x * .68, tam.y * .74)
	_ficha_mejoras.size = Vector2(420, minf(425, tam.y - 70))
	if _ficha_mejoras.visible:
		_posicionar_ficha()


func _posicionar_ficha() -> void:
	_ficha_mejoras.size = Vector2(420, minf(425, _area_nido.size.y - 70))
	var pos: Vector2 = _corte_tierra.posicion_mejora(_mejora_seleccionada) if _mejora_seleccionada != "" else SALAS[_rama].pos
	var punto := pos * _area_nido.size
	var x := punto.x + 92 if pos.x < .52 else punto.x - _ficha_mejoras.size.x - 92
	_ficha_mejoras.position = Vector2(clampf(x, 12, _area_nido.size.x - _ficha_mejoras.size.x - 12), clampf(punto.y - 65, 45, _area_nido.size.y - _ficha_mejoras.size.y - 12))


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel") and not is_instance_valid(_ventana):
		if _seccion != "hogar":
			_cambiar_pestana("hogar")
		else:
			_ficha_mejoras.hide()
			_mejora_seleccionada = ""
			_refrescar()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_migas_mostradas = lerpf(_migas_mostradas, Juego.migas, 1.0 - exp(-10.0 * delta))
	_lbl_migas.text = tr("%s migas") % Juego.formatear(_migas_mostradas)


func _encabezado() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 24)
	var titulos := VBoxContainer.new()
	titulos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulos.add_child(Estilo.etiqueta(tr("ENTRE RAÍCES Y MIGAS"), 11, Color("9db196")))
	titulos.add_child(Estilo.etiqueta(tr("Un hogar que crece"), 28, Estilo.TEXTO))
	_lbl_proxima = Estilo.etiqueta("", 13, Estilo.TEXTO_SUAVE)
	titulos.add_child(_lbl_proxima)
	fila.add_child(titulos)
	var caja := VBoxContainer.new()
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_child(Estilo.etiqueta(tr("EN LA DESPENSA"), 11, Estilo.TEXTO_SUAVE))
	_lbl_migas = Estilo.etiqueta("", 26, Estilo.ACENTO)
	caja.add_child(_lbl_migas)
	fila.add_child(caja)
	_boton_run = Estilo.boton(tr("Explorar") + "  →", 18, Color("46593e"), Color("94b47e"))
	_boton_run.custom_minimum_size = Vector2(210, 52)
	_boton_run.pressed.connect(_nueva_run)
	fila.add_child(_boton_run)
	return fila


func _crear_mapa() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Estilo.caja(Color("211e19"), 18, Color("6f563b"), 1, 0))
	var base := Control.new()
	base.clip_contents = true
	panel.add_child(base)
	_corte_tierra = ArbolHormiguero.new()
	_corte_tierra.set_anchors_preset(Control.PRESET_FULL_RECT)
	_corte_tierra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_child(_corte_tierra)
	_corte_tierra.configurar(SALAS, SECCIONES)
	_animacion_hormiguero = TransitoNido.new()
	_animacion_hormiguero.set_anchors_preset(Control.PRESET_FULL_RECT)
	_animacion_hormiguero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_child(_animacion_hormiguero)
	_corte_tierra.resized.connect(func() -> void:
		_corte_tierra.reconstruir()
		_animacion_hormiguero.rutas = _corte_tierra.rutas
		_actualizar_transito()
	)
	for id in SECCIONES:
		var datos: Dictionary = SECCIONES[id]
		var boton := Button.new()
		boton.text = tr(NOMBRES_PESTANAS[id])
		boton.add_theme_font_size_override("font_size", 23)
		boton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_anclar(boton, datos.pos, Vector2(236, 92), Vector2.ZERO)
		for estado in ["normal", "hover", "pressed", "focus"]:
			var caja := Estilo.caja(Color(datos.color, .07 if estado != "normal" else 0), 35, Color(datos.color, .4 if estado != "normal" else 0), 1, 10)
			caja.content_margin_left = 75
			boton.add_theme_stylebox_override(estado, caja)
		boton.pressed.connect(_cambiar_pestana.bind(id))
		if id != "hogar":
			var cerrada := Control.new()
			_anclar(cerrada, datos.pos, Vector2(236, 92), Vector2.ZERO)
			cerrada.tooltip_text = tr("Cámara por desarrollar")
			base.add_child(cerrada)
			var nombre := Estilo.etiqueta(tr(NOMBRES_PESTANAS[id]), 21, Color("aa9b84"))
			nombre.position = Vector2(81, 32)
			nombre.size.x = 143
			nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cerrada.add_child(nombre)
			var futuro := EscenaSeccion.new()
			futuro.seccion = id
			futuro.tinta = datos.color.darkened(.45)
			futuro.position = Vector2(10, 14)
			futuro.scale = Vector2.ONE * .7
			futuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cerrada.add_child(futuro)
			var cerrojo := CerrojoCamara.new()
			cerrojo.position = Vector2(211, 7)
			cerrojo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cerrada.add_child(cerrojo)
			_secciones_por_descubrir[id] = cerrada
		base.add_child(boton)
		var escena := EscenaSeccion.new()
		escena.seccion = id
		escena.tinta = datos.color
		escena.position = Vector2(10, 14)
		escena.size = Vector2(80, 80)
		escena.scale = Vector2.ONE * .7
		escena.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boton.add_child(escena)
		_pestanas[id] = boton
	for rama in SALAS:
		var datos: Dictionary = SALAS[rama]
		var boton := Button.new()
		_anclar(boton, datos.pos, Vector2(162, 112), Vector2(0, 17))
		boton.tooltip_text = tr(datos.titulo) + ": " + tr(datos.detalle)
		for estado in ["normal", "hover", "pressed", "focus"]:
			boton.add_theme_stylebox_override(estado, StyleBoxEmpty.new() if estado == "normal" else Estilo.caja(Color(datos.color, .05), 30, Color(datos.color, .2), 1, 0))
		boton.pressed.connect(_seleccionar.bind(rama))
		base.add_child(boton)
		var icono := IconoSala.new()
		icono.rama = rama
		icono.color = datos.color
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icono.position = Vector2(51, 4)
		icono.size = Vector2(80, 80)
		icono.scale = Vector2.ONE * .75
		boton.add_child(icono)
		var etiqueta := Estilo.etiqueta(tr(datos.titulo), 18, datos.color)
		etiqueta.position = Vector2(0, 69)
		etiqueta.size.x = 162
		etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boton.add_child(etiqueta)
		var aviso := Estilo.etiqueta("", 12, Color("b8d891"))
		aviso.position = Vector2(0, 92)
		aviso.size.x = 162
		aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boton.add_child(aviso)
		_salas[rama] = {"boton": boton, "icono": icono, "aviso": aviso}
	for m in Juego.mejoras:
		var boton := Button.new()
		_anclar(boton, _corte_tierra.posicion_mejora(m.id), Vector2(170, 96), Vector2(0, 20))
		for estado in ["normal", "hover", "pressed", "focus"]:
			boton.add_theme_stylebox_override(estado, StyleBoxEmpty.new() if estado == "normal" else Estilo.caja(Color(SALAS[m.rama].color, .05), 28, Color(SALAS[m.rama].color, .32), 1, 0))
		boton.pressed.connect(_seleccionar_mejora.bind(m.id))
		base.add_child(boton)
		var simbolo := SelloMejora.new()
		simbolo.stat = m.stat
		simbolo.color = SALAS[m.rama].color
		simbolo.position = Vector2(65, 10)
		simbolo.size = Vector2(40, 40)
		simbolo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boton.add_child(simbolo)
		var nombre := Estilo.etiqueta(tr(m.nombre), 16, Estilo.TEXTO)
		nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nombre.position = Vector2(0, 57)
		nombre.size = Vector2(170, 42)
		nombre.max_lines_visible = 2
		nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nombre.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		boton.add_child(nombre)
		var nivel := Estilo.etiqueta("", 12, Estilo.TEXTO_SUAVE)
		nivel.position = Vector2(111, 18)
		boton.add_child(nivel)
		_nodos_mejoras[m.id] = {"boton": boton, "icono": simbolo, "nivel": nivel, "nombre": nombre}
	return panel


func _anclar(control: Control, pos: Vector2, tamano: Vector2, desplazamiento: Vector2) -> void:
	control.anchor_left = pos.x
	control.anchor_right = pos.x
	control.anchor_top = pos.y
	control.anchor_bottom = pos.y
	control.offset_left = -tamano.x * .5 + desplazamiento.x
	control.offset_right = tamano.x * .5 + desplazamiento.x
	control.offset_top = -tamano.y * .5 + desplazamiento.y
	control.offset_bottom = tamano.y * .5 + desplazamiento.y

func _crear_compra_lotes() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	var texto := Estilo.etiqueta(tr("COMPRAR"), 11, Estilo.TEXTO_SUAVE)
	texto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(texto)
	_lbl_comprar = texto
	for cantidad in [1, 10, 0]:
		var boton := Estilo.boton(tr("Máx") if cantidad == 0 else "×%d" % cantidad, 15, Color("282f26"), Color("52634a"))
		boton.custom_minimum_size.x = 64
		boton.pressed.connect(Juego.cambiar_cantidad_compra.bind(cantidad))
		boton.tooltip_text = tr("Todo lo que alcance") if cantidad == 0 else tr("Compra hasta el límite de nivel; requiere pagar el lote completo.")
		fila.add_child(boton)
		_cantidades[cantidad] = boton
	return fila


func _cambiar_pestana(id: String) -> void:
	_seccion = id
	Juego.marcar_visto(id)
	_cuerpo_mejoras.visible = id == "hogar"
	_panel_seccion.visible = id != "hogar"
	_titulo_seccion.text = tr(NOMBRES_PESTANAS[id])
	_ficha_mejoras.hide()
	_panel_castas.visible = id == "castas"
	_panel_viajes.visible = id == "viajes"
	_panel_legado.visible = id == "legado"
	if id == "viajes":
		_panel_viajes.refrescar()
	elif id == "legado":
		_panel_legado.refrescar()
	for clave in _pestanas:
		var color: Color = SECCIONES[clave].color
		var caja := Estilo.caja(Color.TRANSPARENT, 48, Color.TRANSPARENT, 0, 12)
		caja.content_margin_left = 75
		_pestanas[clave].add_theme_stylebox_override("normal", caja)
		_pestanas[clave].add_theme_color_override("font_color", color if clave == id else Estilo.TEXTO)
	_corte_tierra.seccion = id
	_corte_tierra.queue_redraw()
	for rama in _salas:
		_salas[rama].icono.seleccionada = id == "hogar" and rama == _rama
		_salas[rama].icono.queue_redraw()


func _crear_detalles() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 340)
	panel.size = Vector2(420, 425)
	panel.add_theme_stylebox_override("panel", Estilo.caja(Color("1e271f"), 20, Color("8d9573"), 2, 16))
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	panel.add_child(columna)
	var fila := HBoxContainer.new()
	columna.add_child(fila)
	_lbl_sala = Estilo.etiqueta("", 25)
	_lbl_sala.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(_lbl_sala)
	var cerrar := Estilo.boton("×", 22, Color("293226"), Color("4d5d45"))
	cerrar.tooltip_text = tr("Volver al hormiguero")
	cerrar.pressed.connect(_cerrar_ficha)
	fila.add_child(cerrar)
	_lbl_detalle = Estilo.etiqueta("", 14, Estilo.TEXTO_SUAVE)
	_lbl_detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_lbl_detalle)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 196
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columna.add_child(scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 10)
	scroll.add_child(_lista)
	for m in Juego.mejoras:
		_crear_tarjeta(m)
	_lbl_estado = Estilo.etiqueta(tr("Las mejoras se guardan al comprar."), 12, Estilo.TEXTO_SUAVE)
	_lbl_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_lbl_estado)
	return panel


func _crear_tarjeta(m: Dictionary) -> void:
	var boton := Button.new()
	boton.custom_minimum_size.y = 218
	boton.pressed.connect(_comprar.bind(m.id))
	_lista.add_child(boton)
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 13)
	boton.add_child(margen)
	var contenido := VBoxContainer.new()
	contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido.add_theme_constant_override("separation", 5)
	margen.add_child(contenido)
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido.add_child(fila)
	# Las mejoras de destino llevan una estrella: se traen de un viaje.
	var nombre := Estilo.etiqueta(("✦ " if m.destino != "" else "") + tr(m.nombre), 19)
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fila.add_child(nombre)
	var nivel := Estilo.etiqueta("", 16, Estilo.TEXTO_SUAVE)
	fila.add_child(nivel)
	var descripcion := Estilo.etiqueta(tr(m.descripcion), 14, Estilo.TEXTO_SUAVE)
	descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenido.add_child(descripcion)
	var cambio := Estilo.etiqueta("", 16, Estilo.VERDE)
	cambio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenido.add_child(cambio)
	var costo := Estilo.etiqueta("", 15, Estilo.ACENTO)
	costo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenido.add_child(costo)
	_tarjetas[m.id] = {"boton": boton, "nivel": nivel, "cambio": cambio, "costo": costo}


func _pie() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	for opcion in [[tr("Estadísticas"), abrir_estadisticas], [tr("Configuración"), abrir_configuracion], [tr("Menú"), _ir_al_menu]]:
		var boton := Estilo.boton(opcion[0], 13, Color("262e25"), Color("4b5945"))
		boton.pressed.connect(opcion[1])
		fila.add_child(boton)
	return fila


func abrir_estadisticas() -> void:
	_abrir(PanelEstadisticas.new())


func abrir_configuracion() -> void:
	var panel := PanelConfiguracion.new()
	panel.idioma_cambiado.connect(func() -> void: get_tree().reload_current_scene())
	_abrir(panel)


func _abrir(ventana: VentanaModal) -> void:
	if is_instance_valid(_ventana):
		_ventana.queue_free()
	Sonido.tocar("clic", 0.9)
	_ventana = ventana
	add_child(ventana)


func _ir_al_menu() -> void:
	get_tree().change_scene_to_file("res://ui/menu.tscn")


func _seleccionar(rama: String) -> void:
	_rama = rama
	_mejora_seleccionada = ""
	_cambiar_pestana("hogar")
	_ficha_mejoras.show()
	Sonido.tocar("clic", 0.85)
	_refrescar()
	_posicionar_ficha()
	_posicionar_ficha.call_deferred()


func _seleccionar_mejora(id: String) -> void:
	_rama = Juego.mejoras_por_id[id].rama
	_cambiar_pestana("hogar")
	_mejora_seleccionada = id
	_ficha_mejoras.show()
	Sonido.tocar("clic", .85)
	_refrescar()
	_posicionar_ficha()
	_posicionar_ficha.call_deferred()


func _cerrar_ficha() -> void:
	_ficha_mejoras.hide()
	_mejora_seleccionada = ""
	_refrescar()


func _on_migas_cambiaron(_total: float) -> void:
	_refrescar()


func _refrescar() -> void:
	_boton_run.text = tr("Explorar") + "  →"
	_actualizar_revelados()
	_boton_run.tooltip_text = tr("Destino: %s") % tr(Mundos.INFO[Juego.lugar_actual].nombre)
	for cantidad in _cantidades:
		_cantidades[cantidad].add_theme_stylebox_override("normal", Estilo.caja(Color("536649") if cantidad == Juego.cantidad_compra else Color("282f26"), 10, Color("94b47e") if cantidad == Juego.cantidad_compra else Color("46503f"), 1, 10))
	_lbl_sala.text = tr(SALAS[_rama].titulo)
	_lbl_sala.label_settings.font_color = SALAS[_rama].color
	_lbl_detalle.text = tr(SALAS[_rama].detalle)
	_lbl_detalle.visible = _mejora_seleccionada == ""
	_lbl_proxima.text = tr("%d obreras + %d especialistas  ·  %d s  ·  %d cm") % [int(Juego.stat("hormigas_iniciales")), Juego.total_especialistas(), int(Juego.stat("duracion_run")), int(Juego.stat("radio_territorio") / 10.0)]
	if Juego.decretos_por_id.has(Juego.decreto):
		_lbl_proxima.text += "  ·  " + tr(Juego.decretos_por_id[Juego.decreto].nombre)
	for rama in _salas:
		var total := 0
		var disponibles := 0
		for m in Juego.mejoras:
			if m.rama == rama and _mejora_visible(m):
				total += Juego.nivel_de(m.id)
				if Juego.cotizar_mejora(m.id, Juego.cantidad_compra).puede:
					disponibles += 1
		_salas[rama].icono.disponibles = disponibles
		_salas[rama].aviso.text = (tr("1 disponible") if disponibles == 1 else tr("%d disponibles") % disponibles) if disponibles > 0 else ""
		_salas[rama].icono.nivel = total
		_salas[rama].icono.seleccionada = _seccion == "hogar" and rama == _rama
		_salas[rama].icono.queue_redraw()
	var estados := {}
	for id in _tarjetas:
		var t: Dictionary = _tarjetas[id]
		var m: Dictionary = Juego.mejoras_por_id[id]
		var boton: Button = t.boton
		boton.visible = m.rama == _rama and _mejora_visible(m) and (_mejora_seleccionada == "" or _mejora_seleccionada == id)
		var abierta := Juego.esta_desbloqueada(id)
		var maxima := Juego.esta_al_maximo(id)
		var oferta := Juego.cotizar_mejora(id, Juego.cantidad_compra)
		var disponible: bool = oferta.puede
		var color: Color = SALAS[m.rama].color
		t.nivel.text = "%d / %d" % [Juego.nivel_de(id), Juego.nivel_maximo(id)]
		if not abierta:
			if m.destino != "" and not Juego.destino_desbloqueado(m.destino):
				t.cambio.text = tr("Se descubre al llegar a %s") % tr(Mundos.INFO[m.destino].nombre)
			else:
				t.cambio.text = tr("Requiere %s · nivel %d") % [tr(Juego.mejoras_por_id[m.requiere_id].nombre), m.requiere_nivel]
		elif maxima:
			if m.tope_por_destino > 0 and Juego.lugares_completados.size() < Mundos.ORDEN.size():
				t.cambio.text = tr("Tope alcanzado: cada destino conquistado suma %d niveles.") % m.tope_por_destino
			elif m.elevable and not Juego.jalea_al_maximo("techo"):
				t.cambio.text = tr("Tope alcanzado: las Cámaras más hondas de la reina suman niveles.")
			else:
				t.cambio.text = tr("Tu colonia domina esta habilidad.")
		else:
			if m.stat == "materiales":
				t.cambio.text = tr("Nueva dieta: %s") % _valor_stat(m.stat, Juego.stat_tras_comprar(id, maxi(1, oferta.cantidad)))
			else:
				t.cambio.text = "%s  →  %s" % [_valor_stat(m.stat, Juego.stat(m.stat)), _valor_stat(m.stat, Juego.stat_tras_comprar(id, maxi(1, oferta.cantidad)))]
			var hito := Juego.proximo_hito_nivel(id)
			if hito > 0:
				t.cambio.text += "\n" + tr("Hito en nivel %d: daño ×%s") % [hito, _numero_corto(m.bonus_mult)]
		t.cambio.label_settings.font_color = color if abierta else Estilo.TEXTO_SUAVE
		t.costo.text = tr("COMPLETA") if maxima else (tr("Comprar ×%d · %s migas") % [oferta.cantidad, Juego.formatear(oferta.costo)] if disponible else tr("Faltan %s migas") % Juego.formatear(maxf(0, oferta.costo - Juego.migas)))
		if not abierta:
			t.costo.text = tr("Cámara por desarrollar")
		t.costo.label_settings.font_color = color if disponible else Estilo.TEXTO_SUAVE
		var fondo := Color("333c2d") if disponible else Color("252b24")
		boton.add_theme_stylebox_override("normal", Estilo.caja(fondo, 12, Color(color, 0.55 if disponible else 0.12), 1, 0))
		boton.add_theme_stylebox_override("hover", Estilo.caja(fondo.lightened(0.06), 12, color, 1, 0))
		boton.add_theme_stylebox_override("pressed", Estilo.caja(fondo.darkened(0.08), 12, color, 2, 0))
		boton.add_theme_stylebox_override("focus", Estilo.caja(Color.TRANSPARENT, 12, color, 2, 0))
		boton.modulate.a = 1.0 if abierta else 0.6
		var nodo: Dictionary = _nodos_mejoras[id]
		nodo.boton.visible = _mejora_visible(m)
		nodo.nivel.text = "%d/%d" % [Juego.nivel_de(id), Juego.nivel_maximo(id)]
		nodo.nombre.label_settings.font_color = color.lightened(.15) if Juego.nivel_de(id) > 0 else (Estilo.TEXTO if abierta else Color("baa88b"))
		nodo.icono.nivel = Juego.nivel_de(id)
		nodo.icono.abierta = abierta
		nodo.icono.queue_redraw()
		nodo.boton.tooltip_text = tr(m.nombre) + "\n" + tr(m.descripcion) + "\n" + t.cambio.text + "\n" + t.costo.text
		estados[id] = {"nivel": Juego.nivel_de(id), "puede": disponible, "abierta": abierta, "visible": _mejora_visible(m)}
	_corte_tierra.actualizar(estados, _mejora_seleccionada, _seccion)
	_actualizar_transito()


func _actualizar_transito() -> void:
	_animacion_hormiguero.indices_rutas.clear()
	for i in _corte_tierra.caminos.size():
		var id: String = _corte_tierra.caminos[i].id
		if id == "" or _corte_tierra.estados.get(id, {}).get("visible", true):
			_animacion_hormiguero.indices_rutas.append(i)


## Las mejoras de destino se muestran (bloqueadas) recién cuando aparecen los viajes.
func _mejora_visible(m: Dictionary) -> bool:
	return m.destino == "" or Juego.revelado("viajes")


func _numero_corto(n: float) -> String:
	return str(int(n)) if is_equal_approx(n, roundf(n)) else "%.2f" % n


## Pestañas y compra por lote aparecen recién cuando sirven; las nuevas
## llevan un punto hasta que el jugador las abre.
func _actualizar_revelados() -> void:
	for id in ["castas", "viajes", "legado"]:
		var boton: Button = _pestanas[id]
		boton.visible = Juego.revelado(id)
		_secciones_por_descubrir[id].visible = not boton.visible
		boton.text = tr(NOMBRES_PESTANAS[id]) + ("  ● " + tr("¡Nuevo!") if Juego.es_nuevo(id) else "")
	var lotes := Juego.revelado("compra_lote")
	_lbl_comprar.visible = lotes
	for cantidad in _cantidades:
		_cantidades[cantidad].visible = lotes


func _valor_stat(stat: String, valor: float) -> String:
	match stat:
		"duracion_run": return "%.0f s" % valor
		"intervalo_mordida": return tr("%.2f s entre mordidas") % valor
		"feromona_cantidad": return tr("%d hormigas") % int(valor)
		"materiales": return tr(MaterialesCasa.NIVELES[clampi(int(valor), 0, 3)])
		"velocidad": return tr("%.0f de velocidad") % valor
		"radio_territorio": return "%.0f cm" % (valor / 10.0)
		"entradas": return tr("%d accesos secundarios") % mini(6, int(valor))
		"multiplicador_migas": return tr("×%.2f migas") % valor
		"hormigas_iniciales": return tr("%d obreras") % int(valor)
		"cria": return tr("%d crías / 10 s") % int(valor)
		"olfato": return tr("%.0f de alcance") % valor
		"capacidad": return tr("%d bocados") % int(valor)
		"dano_clic": return tr("%s de daño por pisotón") % Juego.formatear(valor)
	return tr("%s de daño") % ("%.1f" % valor if valor < 1000.0 else Juego.formatear(valor))


func _comprar(id: String) -> void:
	var compradas := Juego.comprar_lote(id, Juego.cantidad_compra)
	if compradas == 0:
		Sonido.tocar("no")
		_lbl_estado.text = tr("Te faltan migas o una mejora previa. ¡Otra expedición!")
		return
	Sonido.tocar("comprar", 1.0, 0.01)
	_lbl_estado.text = tr("¡%s +%d niveles!") % [tr(Juego.mejoras_por_id[id].nombre), compradas]
	var icono: Control = _nodos_mejoras[id].icono
	if _tween_compra and _tween_compra.is_running():
		_tween_compra.kill()
	icono.pivot_offset = icono.size * 0.5
	icono.scale = Vector2.ONE * 1.22
	_tween_compra = icono.create_tween()
	_tween_compra.tween_property(icono, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _nueva_run() -> void:
	get_tree().change_scene_to_file(ESCENA_RUN)
