extends Control
## Cámaras del hormiguero: navegación a la izquierda y mejoras a la derecha.
const ESCENA_RUN := "res://mundo/run.tscn"
const SALAS := {
	"Colonia": {"titulo": "El criadero", "detalle": "Una familia cada vez más grande.", "color": Color("b8cd91"), "pos": Vector2(0.25, 0.28)},
	"Mandíbulas": {"titulo": "El taller", "detalle": "Comida → madera y telas → materiales resistentes → paredes.", "color": Color("e7ac7d"), "pos": Vector2(0.74, 0.28)},
	"Recolección": {"titulo": "La despensa", "detalle": "Pequeños viajes, grandes tesoros.", "color": Color("e8cc86"), "pos": Vector2(0.23, 0.58)},
	"Feromonas": {"titulo": "El observatorio", "detalle": "Todos los caminos llevan a casa.", "color": Color("8dc3bc"), "pos": Vector2(0.77, 0.58)},
	"Tiempo": {"titulo": "El refugio", "detalle": "Siempre hay tiempo para otro bocado.", "color": Color("c3add4"), "pos": Vector2(0.31, 0.85)},
	"Territorio": {"titulo": "La excavación", "detalle": "La cocina es solo el comienzo.", "color": Color("c9b48c"), "pos": Vector2(0.69, 0.85)},
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
const NOMBRES_PESTANAS := {"hogar": "Mejoras", "castas": "Castas", "viajes": "Viajes", "legado": "Jalea real"}


class IconoSala extends Control:
	var rama := "Colonia"
	var color := Color.WHITE
	var nivel := 0
	var seleccionada := false
	var disponibles := 0
	var reloj := 0.0

	func _process(delta: float) -> void:
		reloj += delta
		if seleccionada:
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		# La cámara excavada se ensancha a medida que se desarrolla su rama.
		var crecimiento := minf(nivel, 15) * 0.6
		draw_set_transform(c, 0, Vector2(1.55, 0.84))
		draw_circle(Vector2(0, 3), 34 + crecimiento, Color(0, 0, 0, 0.25))
		draw_circle(Vector2.ZERO, 33 + crecimiento, Color("514332"))
		draw_circle(Vector2.ZERO, 30 + crecimiento, Color("2b261d"))
		for i in mini(nivel, 10):
			var p := Vector2.from_angle(i * 2.4) * (25 + crecimiento)
			draw_circle(p, 2, Color(color, 0.3))
		draw_set_transform(Vector2.ZERO)
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


class CorteTierra extends Control:
	var reloj := 0.0
	var proximo_dibujo := 0.0

	func _process(delta: float) -> void:
		reloj += delta
		if reloj >= proximo_dibujo:
			proximo_dibujo = reloj + 0.1
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("211e19"))
		for i in 8:
			var y := 24.0 + i * size.y / 8.0
			draw_line(Vector2(0, y), Vector2(size.x, y + 20), Color(0.76, 0.6, 0.4, 0.025), 14, true)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 210:
			draw_circle(Vector2(rng.randf() * size.x, rng.randf() * size.y), rng.randf_range(0.6, 2), Color(0.75, 0.61, 0.43, 0.08))
		var centro := Vector2(size.x * 0.5, size.y * 0.44)
		draw_line(Vector2(size.x * 0.5, 0), centro, Color("171612"), 22, true)
		for sala in SALAS.values():
			var p: Vector2 = sala.pos * size
			var camino := PackedVector2Array([centro, Vector2(centro.x, p.y), p])
			draw_polyline(camino, Color("151511"), 20, true)
			draw_polyline(camino, Color(0.65, 0.52, 0.35, 0.09), 2, true)
			for i in 2:
				var avance := fposmod(reloj * 0.1 + i * 0.5 + sala.pos.x, 1.0)
				var trabajador := centro.lerp(camino[1], avance * 2) if avance < 0.5 else camino[1].lerp(p, (avance - 0.5) * 2)
				draw_circle(trabajador, 1.7, Color("9b8d69"))
				draw_circle(trabajador + Vector2(3, 0), 1.1, Color("9b8d69"))
		draw_circle(centro, 24, Color("161612"))
		draw_circle(centro, 17, Color("675b40"))
		for i in 3:
			draw_circle(centro + Vector2(-7 + i * 7, 0), 5 - i, Color("e6ca86"))


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fondo := ColorRect.new()
	fondo.color = Color("171b18")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 24)
	add_child(margen)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 18)
	margen.add_child(columna)
	columna.add_child(_encabezado())
	columna.add_child(_crear_pestanas())
	var cuerpo := HBoxContainer.new()
	_cuerpo_mejoras = cuerpo
	cuerpo.add_theme_constant_override("separation", 20)
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(cuerpo)
	cuerpo.add_child(_crear_mapa())
	cuerpo.add_child(_crear_detalles())
	_panel_castas = PanelCastas.new()
	_panel_castas.visible = false
	columna.add_child(_panel_castas)
	_panel_viajes = PanelCampana.new()
	_panel_viajes.modo = "viajes"
	_panel_viajes.visible = false
	columna.add_child(_panel_viajes)
	_panel_legado = PanelCampana.new()
	_panel_legado.modo = "legado"
	_panel_legado.visible = false
	columna.add_child(_panel_legado)
	columna.add_child(_pie())
	Juego.migas_cambiaron.connect(_on_migas_cambiaron)
	Juego.partida_borrada.connect(_refrescar)
	Juego.modo_compra_cambio.connect(_refrescar)
	Juego.progreso_cambio.connect(_refrescar)
	_migas_mostradas = Juego.migas
	_refrescar()
	_cambiar_pestana("hogar")
	_boton_run.grab_focus()


func _process(delta: float) -> void:
	_migas_mostradas = lerpf(_migas_mostradas, Juego.migas, 1.0 - exp(-10.0 * delta))
	_lbl_migas.text = tr("%s migas") % Juego.formatear(_migas_mostradas)


func _encabezado() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 24)
	var titulos := VBoxContainer.new()
	titulos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulos.add_child(Estilo.etiqueta(tr("ENTRE RAÍCES Y MIGAS"), 11, Color("9db196")))
	titulos.add_child(Estilo.etiqueta(tr("Un hogar que crece"), 32, Estilo.TEXTO))
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
	_boton_run.custom_minimum_size = Vector2(235, 56)
	_boton_run.pressed.connect(_nueva_run)
	fila.add_child(_boton_run)
	return fila


func _crear_mapa() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(500, 0)
	panel.add_theme_stylebox_override("panel", Estilo.caja(Color("211e19"), 20, Color("494333"), 1, 0))
	var base := Control.new()
	panel.add_child(base)
	var mapa := CorteTierra.new()
	mapa.set_anchors_preset(Control.PRESET_FULL_RECT)
	mapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_child(mapa)
	mapa.resized.connect(mapa.queue_redraw)
	var ayuda := Estilo.etiqueta(tr("EL HORMIGUERO  /  Elegí una cámara"), 12, Color("b9ad94"))
	ayuda.position = Vector2(18, 15)
	base.add_child(ayuda)
	for rama in SALAS:
		var datos: Dictionary = SALAS[rama]
		var boton := Button.new()
		boton.anchor_left = datos.pos.x
		boton.anchor_right = datos.pos.x
		boton.anchor_top = datos.pos.y
		boton.anchor_bottom = datos.pos.y
		boton.offset_left = -85
		boton.offset_right = 85
		boton.offset_top = -44
		boton.offset_bottom = 54
		boton.tooltip_text = tr(datos.titulo) + ": " + tr(datos.detalle)
		boton.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		boton.add_theme_stylebox_override("hover", Estilo.caja(Color(datos.color, 0.06), 16, Color(datos.color, 0.2), 1, 0))
		boton.add_theme_stylebox_override("pressed", Estilo.caja(Color(datos.color, 0.1), 16, Color(datos.color, 0.4), 1, 0))
		boton.add_theme_stylebox_override("focus", Estilo.caja(Color.TRANSPARENT, 16, datos.color, 1, 0))
		boton.pressed.connect(_seleccionar.bind(rama))
		base.add_child(boton)
		var icono := IconoSala.new()
		icono.rama = rama
		icono.color = datos.color
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icono.position = Vector2(45, 0)
		icono.size = Vector2(80, 80)
		boton.add_child(icono)
		var etiqueta := Estilo.etiqueta(tr(datos.titulo), 13, datos.color)
		etiqueta.position = Vector2(0, 77)
		etiqueta.size.x = 170
		etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boton.add_child(etiqueta)
		var aviso := Estilo.etiqueta("", 10, Color("b8d891"))
		aviso.position = Vector2(0, 94)
		aviso.size.x = 170
		aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boton.add_child(aviso)
		_salas[rama] = {"boton": boton, "icono": icono, "aviso": aviso}
	return panel


func _crear_pestanas() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	for id in ["hogar", "castas", "viajes", "legado"]:
		var boton := Estilo.boton(tr(NOMBRES_PESTANAS[id]), 15, Color("282f26"), Color("52634a"))
		boton.pressed.connect(_cambiar_pestana.bind(id))
		fila.add_child(boton)
		_pestanas[id] = boton
	var espacio := Control.new()
	espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(espacio)
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
	Juego.marcar_visto(id)
	_cuerpo_mejoras.visible = id == "hogar"
	_panel_castas.visible = id == "castas"
	_panel_viajes.visible = id == "viajes"
	_panel_legado.visible = id == "legado"
	if id == "viajes":
		_panel_viajes.refrescar()
	elif id == "legado":
		_panel_legado.refrescar()
	for clave in _pestanas:
		var color := Color("536649") if clave == id else Color("282f26")
		_pestanas[clave].add_theme_stylebox_override("normal", Estilo.caja(color, 10, Color("94b47e") if clave == id else Color("46503f"), 1, 10))


func _crear_detalles() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(390, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Estilo.caja(Color("222923"), 20, Color("3e493d"), 1, 20))
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 10)
	panel.add_child(columna)
	columna.add_child(Estilo.etiqueta(tr("CUIDÁ TU COLONIA"), 11, Color("9db196")))
	_lbl_sala = Estilo.etiqueta("", 27)
	columna.add_child(_lbl_sala)
	_lbl_detalle = Estilo.etiqueta("", 13, Estilo.TEXTO_SUAVE)
	_lbl_detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_lbl_detalle)
	var scroll := ScrollContainer.new()
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
	boton.custom_minimum_size.y = 142
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
	var nombre := Estilo.etiqueta(("✦ " if m.destino != "" else "") + tr(m.nombre), 16)
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fila.add_child(nombre)
	var nivel := Estilo.etiqueta("", 12, Estilo.TEXTO_SUAVE)
	fila.add_child(nivel)
	var descripcion := Estilo.etiqueta(tr(m.descripcion), 12, Estilo.TEXTO_SUAVE)
	descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenido.add_child(descripcion)
	var cambio := Estilo.etiqueta("", 14, Estilo.VERDE)
	cambio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenido.add_child(cambio)
	var costo := Estilo.etiqueta("", 13, Estilo.ACENTO)
	contenido.add_child(costo)
	_tarjetas[m.id] = {"boton": boton, "nivel": nivel, "cambio": cambio, "costo": costo}


func _pie() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	var nota := Estilo.etiqueta(tr("Cada miga construye algo más grande."), 13, Estilo.TEXTO_SUAVE)
	nota.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(nota)
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
	Sonido.tocar("clic", 0.85)
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
		_salas[rama].icono.seleccionada = rama == _rama
		_salas[rama].icono.queue_redraw()
	for id in _tarjetas:
		var t: Dictionary = _tarjetas[id]
		var m: Dictionary = Juego.mejoras_por_id[id]
		var boton: Button = t.boton
		boton.visible = m.rama == _rama and _mejora_visible(m)
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
	var icono: Control = _salas[_rama].icono
	if _tween_compra and _tween_compra.is_running():
		_tween_compra.kill()
	icono.pivot_offset = icono.size * 0.5
	icono.scale = Vector2.ONE * 1.22
	_tween_compra = icono.create_tween()
	_tween_compra.tween_property(icono, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _nueva_run() -> void:
	get_tree().change_scene_to_file(ESCENA_RUN)
