extends Control
## El hormiguero es el árbol: cada mejora y cada casta es una cámara.
## Al pasar el mouse se abre su ficha; un clic la mejora (o recluta).
## La reina, en el centro, abre la jalea real; la boca, los viajes; la sala
## de castas, las fichas completas y las evoluciones. Ver ui/arbol_hormiguero.gd.
const ESCENA_RUN := "res://mundo/run.tscn"
## Ramas del hormiguero: nombre, frase, color y la cámara por la que empiezan.
const SALAS := {
	"Castas": {"titulo": "Las especialistas", "detalle": "Cada casta trabaja a su manera.", "color": Color("e5879a"), "raiz": "veloz"},
	"Colonia": {"titulo": "El criadero", "detalle": "Una familia cada vez más grande.", "color": Color("b8cd91"), "raiz": "mas_obreras"},
	"Recolección": {"titulo": "La despensa", "detalle": "Pequeños viajes, grandes tesoros.", "color": Color("e8cc86"), "raiz": "buche"},
	"Mandíbulas": {"titulo": "El taller", "detalle": "Comida → madera y telas → materiales resistentes → paredes.", "color": Color("e7ac7d"), "raiz": "mandibulas"},
	"Feromonas": {"titulo": "El observatorio", "detalle": "Todos los caminos llevan a casa.", "color": Color("8dc3bc"), "raiz": "rastro_persistente"},
	"Tiempo": {"titulo": "El refugio", "detalle": "Siempre hay tiempo para otro bocado.", "color": Color("c3add4"), "raiz": "reservas"},
	"Territorio": {"titulo": "La excavación", "detalle": "La cocina es solo el comienzo.", "color": Color("c9b48c"), "raiz": "excavar"},
}
const NOMBRES_PESTANAS := {"hogar": "Mejoras", "castas": "Castas", "viajes": "Viajes", "legado": "Jalea real"}
const COLORES_SECCIONES := {"castas": Color("e5879a"), "viajes": Color("d8c49a"), "legado": Color("ebc67d")}

var _lbl_migas: Label
var _lbl_proxima: Label
var _boton_run: Button
var _migas_mostradas := 0.0
var _ventana: VentanaModal
var _area_nido: Control
var _mapa_hormiguero: Control
var _corte_tierra: ArbolHormiguero
var _animacion_hormiguero: ArbolHormiguero.TransitoNido
var _cuerpo_mejoras: Control
var _pestanas: Dictionary = {}
var _leyenda: Dictionary = {}
var _seccion := "hogar"
var _panel_seccion: PanelContainer
var _titulo_seccion: Label
var _boton_volver: Button
var _panel_castas: PanelCastas
var _panel_viajes: PanelCampana
var _panel_legado: PanelCampana
var _cantidades: Dictionary = {}
var _lbl_comprar: Label
var _lbl_paso: Label
var _lbl_paso_detalle: Label
var _boton_paso: Button
var _siguiente_paso: Dictionary = {}
# La ficha: se abre al pasar el mouse; "Ver mejora" la deja fija.
var _ficha_mejoras: PanelContainer
var _ficha_franja: ColorRect
var _ficha_id := ""
var _mejora_seleccionada := ""
var _lbl_sala: Label
var _lbl_nivel: Label
var _lbl_rama: Label
var _lbl_detalle: Label
var _lbl_cambio: Label
var _lbl_costo: Label
var _lbl_estado: Label
var _lbl_pista: Label
var _aviso_compra := {"id": "", "texto": ""}
var _estados: Dictionary = {}


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
	_cuerpo_mejoras.add_child(_crear_leyenda())
	var ayuda := PanelContainer.new()
	ayuda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ayuda.add_theme_stylebox_override("panel", Estilo.caja(Color(0.09, 0.07, 0.05, 0.72), 8, Color.TRANSPARENT, 0, 7))
	ayuda.add_child(Estilo.etiqueta(tr("Pasá el mouse por una cámara para ver qué hace · clic para mejorarla · arrastrá y usá la rueda para recorrer"), 13, Color(0.88, 0.88, 0.79, 0.7)))
	ayuda.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ayuda.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ayuda.position = Vector2(14, -14)
	_cuerpo_mejoras.add_child(ayuda)
	_ficha_mejoras = _crear_ficha()
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
	_boton_volver = Estilo.boton(tr("Volver al hormiguero") + "  ×", 15, Color("283126"), Color("697652"))
	_boton_volver.pressed.connect(_cambiar_pestana.bind("hogar"))
	barra.add_child(_boton_volver)
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
	pie.add_child(_crear_siguiente_paso())
	pie.add_child(_pie())
	columna.add_child(pie)
	_area_nido.resized.connect(_acomodar_paneles)
	Juego.migas_cambiaron.connect(_on_migas_cambiaron)
	Juego.partida_borrada.connect(_refrescar)
	Juego.modo_compra_cambio.connect(_refrescar)
	Juego.progreso_cambio.connect(_refrescar)
	Juego.casta_comprada.connect(func(_id: String, _cantidad: int) -> void: _refrescar())
	_migas_mostradas = Juego.migas
	_refrescar()
	_cambiar_pestana("hogar")
	_boton_run.grab_focus()
	_acomodar_paneles.call_deferred()


func _acomodar_paneles() -> void:
	if not is_instance_valid(_panel_seccion):
		return
	var tam := _area_nido.size
	_panel_seccion.position = Vector2(tam.x * .16, tam.y * .12)
	_panel_seccion.size = Vector2(tam.x * .68, tam.y * .82)
	if _ficha_mejoras.visible:
		_posicionar_ficha()


## Lo que ya se ve del hormiguero: secciones, cámaras compradas y las que se
## pueden comprar. El encuadre inicial muestra eso y un poco de alrededor.
func zona_explorada() -> Rect2:
	var zona := PlanoHormiguero.rect("viajes").merge(PlanoHormiguero.rect("legado"))
	for id in _estados:
		var e: Dictionary = _estados[id]
		if e.nivel > 0 or (e.abierta and not e.misterio):
			zona = zona.merge(PlanoHormiguero.rect(id))
	return zona.grow(40)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel") and not is_instance_valid(_ventana):
		if _seccion != "hogar":
			_cambiar_pestana("hogar")
		else:
			_cerrar_ficha()
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


## El árbol no elige por el jugador: acerca una cámara útil sin comprarla ni
## cambiar el destino. Se refresca con las mismas señales que la tienda.
func _crear_siguiente_paso() -> Control:
	var fila := HBoxContainer.new()
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_theme_constant_override("separation", 12)
	var columna := VBoxContainer.new()
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.add_theme_constant_override("separation", 2)
	fila.add_child(columna)
	_lbl_paso = Estilo.etiqueta("", 14, Estilo.ACENTO)
	_lbl_paso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_lbl_paso)
	_lbl_paso_detalle = Estilo.etiqueta("", 12, Estilo.TEXTO_SUAVE)
	_lbl_paso_detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_lbl_paso_detalle)
	_boton_paso = Estilo.boton(tr("Ver mejora"), 13, Color("293629"), Color("71865b"))
	_boton_paso.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_boton_paso.pressed.connect(_ver_siguiente_paso)
	fila.add_child(_boton_paso)
	return fila


func _actualizar_siguiente_paso() -> void:
	_siguiente_paso = Juego.proxima_meta()
	_lbl_paso.text = tr("SIGUIENTE PASO · %s") % _siguiente_paso.nombre
	_lbl_paso_detalle.text = _siguiente_paso.detalle
	if _siguiente_paso.tipo == "migas":
		var disponible := Juego.migas >= float(_siguiente_paso.objetivo)
		_lbl_paso_detalle.text = (tr("¡Ya te alcanza! Podés comprarla cuando quieras.") if disponible else tr("%s / %s migas") % [Juego.formatear(Juego.migas), Juego.formatear(_siguiente_paso.objetivo)])
	var accion: String = _siguiente_paso.get("accion", "")
	_boton_paso.visible = accion in ["mejora", "casta", "viajes", "legado"]
	match accion:
		"mejora": _boton_paso.text = tr("Ver mejora")
		"casta": _boton_paso.text = tr("Ver castas")
		"viajes": _boton_paso.text = tr("Ver viajes")
		"legado": _boton_paso.text = tr("Ver fundación")


func _ver_siguiente_paso() -> void:
	var id: String = _siguiente_paso.get("id", "")
	match _siguiente_paso.get("accion", ""):
		"mejora", "casta":
			if PlanoHormiguero.CAMARAS.has(id):
				_seleccionar_mejora(id)
		"viajes": _cambiar_pestana("viajes")
		"legado": _cambiar_pestana("legado")


func _crear_mapa() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Estilo.caja(Color("211e19"), 18, Color("6f563b"), 1, 0))
	_corte_tierra = ArbolHormiguero.new()
	panel.add_child(_corte_tierra)
	# Hasta que el jugador mueva la vista, se encuadra lo ya explorado.
	_corte_tierra.resized.connect(func() -> void:
		if not _corte_tierra.movida_por_jugador and _corte_tierra.size.x > 1:
			_corte_tierra.encuadrar(zona_explorada(), false, 0.95, 0.62))
	_animacion_hormiguero = _corte_tierra.transito
	_corte_tierra.camara_pulsada.connect(_on_camara_pulsada)
	_corte_tierra.camara_pulsada_derecha.connect(_on_camara_pulsada_derecha)
	_corte_tierra.camara_sobrevolada.connect(_on_camara_sobrevolada)
	_corte_tierra.vista_cambiada.connect(func() -> void:
		if _ficha_mejoras.visible:
			_posicionar_ficha())
	_pestanas = _corte_tierra.etiquetas
	for id in _pestanas:
		var boton: Button = _pestanas[id]
		var color: Color = COLORES_SECCIONES[id]
		for estado in ["normal", "hover", "pressed", "focus"]:
			boton.add_theme_stylebox_override(estado, Estilo.caja(Color(0.09, 0.07, 0.05, 0.82 if estado == "normal" else 0.95), 10, Color(color, 0.35 if estado == "normal" else 0.8), 1, 8))
		boton.add_theme_color_override("font_color", color)
		boton.add_theme_color_override("font_hover_color", color.lightened(0.25))
	return panel


## Las siete ramas con su color y cuántas cámaras podés comprar ahora.
## Un clic encuadra la rama entera.
func _crear_leyenda() -> Control:
	var caja := HFlowContainer.new()
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.position = Vector2(14, 12)
	caja.add_theme_constant_override("h_separation", 6)
	caja.add_theme_constant_override("v_separation", 6)
	for rama in SALAS:
		var datos: Dictionary = SALAS[rama]
		var boton := Button.new()
		boton.focus_mode = Control.FOCUS_NONE
		boton.add_theme_font_size_override("font_size", 14)
		boton.add_theme_color_override("font_color", datos.color)
		boton.add_theme_color_override("font_hover_color", datos.color.lightened(0.25))
		for estado in ["normal", "hover", "pressed", "focus"]:
			boton.add_theme_stylebox_override(estado, Estilo.caja(Color(0.09, 0.07, 0.05, 0.78 if estado == "normal" else 0.95), 8, Color(datos.color, 0.25 if estado == "normal" else 0.7), 1, 7))
		boton.tooltip_text = tr(datos.titulo) + ": " + tr(datos.detalle)
		boton.pressed.connect(_encuadrar_rama.bind(rama))
		caja.add_child(boton)
		_leyenda[rama] = boton
	return caja


func _encuadrar_rama(rama: String) -> void:
	var zona := PlanoHormiguero.rect(SALAS[rama].raiz)
	for id in _estados:
		if rama in String(_estados[id].get("rama", "")).split("|"):
			zona = zona.merge(PlanoHormiguero.rect(id))
	Sonido.tocar("clic", 0.85)
	_corte_tierra.encuadrar(zona.grow(50), true, 1.1)


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
	_cerrar_ficha()
	_panel_castas.visible = id == "castas"
	_panel_viajes.visible = id == "viajes"
	_panel_legado.visible = id == "legado"
	if id == "viajes":
		_panel_viajes.refrescar()
	elif id == "legado":
		_panel_legado.refrescar()
	_actualizar_revelados()


# =====================================================================
# Ficha de la cámara bajo el mouse
# =====================================================================

func _crear_ficha() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size.x = 350
	var caja := Estilo.caja(Color("1d221d"), 12, Color("4b5945"), 2, 0)
	caja.shadow_color = Color(0, 0, 0, 0.5)
	caja.shadow_size = 14
	caja.shadow_offset = Vector2(0, 8)
	panel.add_theme_stylebox_override("panel", caja)
	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_theme_constant_override("separation", 0)
	panel.add_child(columna)
	_ficha_franja = ColorRect.new()
	_ficha_franja.custom_minimum_size.y = 6
	_ficha_franja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(_ficha_franja)
	var margen := MarginContainer.new()
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lado in ["left", "right"]:
		margen.add_theme_constant_override("margin_" + lado, 14)
	margen.add_theme_constant_override("margin_top", 10)
	margen.add_theme_constant_override("margin_bottom", 12)
	columna.add_child(margen)
	var textos := VBoxContainer.new()
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_theme_constant_override("separation", 6)
	margen.add_child(textos)
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_child(fila)
	_lbl_sala = Estilo.etiqueta("", 19)
	_lbl_sala.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_sala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_sala.custom_minimum_size.x = 240
	fila.add_child(_lbl_sala)
	_lbl_nivel = Estilo.etiqueta("", 15, Estilo.TEXTO_SUAVE)
	_lbl_nivel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	fila.add_child(_lbl_nivel)
	_lbl_rama = Estilo.etiqueta("", 11)
	textos.add_child(_lbl_rama)
	for nombre in ["_lbl_detalle", "_lbl_cambio", "_lbl_costo", "_lbl_estado", "_lbl_pista"]:
		var tamano: int = {"_lbl_detalle": 14, "_lbl_cambio": 16, "_lbl_costo": 15, "_lbl_estado": 13, "_lbl_pista": 12}[nombre]
		var color: Color = {"_lbl_detalle": Estilo.TEXTO_SUAVE, "_lbl_cambio": Estilo.VERDE, "_lbl_costo": Estilo.ACENTO, "_lbl_estado": Estilo.TEXTO_SUAVE, "_lbl_pista": Color("8d927f")}[nombre]
		var etiqueta := Estilo.etiqueta("", tamano, color)
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiqueta.custom_minimum_size.x = 322
		textos.add_child(etiqueta)
		set(nombre, etiqueta)
	return panel


func _on_camara_sobrevolada(id: String) -> void:
	if _seccion != "hogar":
		return
	if id == "":
		if _mejora_seleccionada != "":
			_mostrar_ficha(_mejora_seleccionada)
		else:
			_ficha_mejoras.hide()
			_ficha_id = ""
		return
	if id != _mejora_seleccionada:
		_mejora_seleccionada = ""
		_corte_tierra.seleccion = ""
	_mostrar_ficha(id)


func _on_camara_pulsada(id: String) -> void:
	if _seccion != "hogar":
		# Con una sección abierta, tocar el hormiguero vuelve a él sin comprar.
		_cambiar_pestana("hogar")
		return
	if id == "":
		_cerrar_ficha()
		return
	if id in PlanoHormiguero.SECCIONES:
		if Juego.revelado(id):
			Sonido.tocar("clic", 0.9)
			_cambiar_pestana(id)
		else:
			Sonido.tocar("no")
		return
	_comprar(id)


func _on_camara_pulsada_derecha(id: String) -> void:
	if _seccion == "hogar" and Juego.castas_por_id.has(id) and Juego.revelado("castas"):
		_cambiar_pestana("castas")
		_panel_castas._seleccionar(id)


## Acerca una cámara y deja su ficha abierta (el "Ver mejora" del pie).
func _seleccionar_mejora(id: String) -> void:
	_cambiar_pestana("hogar")
	_mejora_seleccionada = id
	_corte_tierra.seleccion = id
	_corte_tierra.resalte.queue_redraw()
	_corte_tierra.enfocar(id)
	Sonido.tocar("clic", .85)
	_mostrar_ficha(id)


func _cerrar_ficha() -> void:
	_ficha_mejoras.hide()
	_ficha_id = ""
	_mejora_seleccionada = ""
	if is_instance_valid(_corte_tierra):
		_corte_tierra.seleccion = ""
		_corte_tierra.resalte.queue_redraw()


func _mostrar_ficha(id: String) -> void:
	if not _estados.has(id):
		return
	if id != _ficha_id and _aviso_compra.id != id:
		_aviso_compra = {"id": "", "texto": ""}
	_ficha_id = id
	var e: Dictionary = _estados[id]
	_ficha_franja.color = e.color
	_lbl_sala.label_settings.font_color = Estilo.TEXTO
	_lbl_nivel.visible = e.maximo > 0 and not e.misterio
	_lbl_nivel.text = "%d / %d" % [e.nivel, e.maximo]
	_lbl_rama.label_settings.font_color = e.color
	_lbl_cambio.label_settings.font_color = Estilo.VERDE
	_lbl_costo.label_settings.font_color = Estilo.ACENTO
	match e.tipo:
		"seccion": _ficha_seccion(id, e)
		"casta": _ficha_casta(id, e)
		_: _ficha_mejora(id, e)
	if _aviso_compra.id == id:
		_lbl_estado.text = _aviso_compra.texto
	for etiqueta in [_lbl_rama, _lbl_detalle, _lbl_cambio, _lbl_costo, _lbl_estado, _lbl_pista]:
		etiqueta.visible = etiqueta.text != ""
	_ficha_mejoras.show()
	_ficha_mejoras.reset_size()
	_posicionar_ficha()


func _ficha_mejora(id: String, e: Dictionary) -> void:
	var m: Dictionary = Juego.mejoras_por_id[id]
	if e.misterio:
		_lbl_sala.text = tr("Cámara sin excavar")
		_lbl_rama.text = _nombre_rama(m.rama)
		_lbl_detalle.text = tr("Se descubre más adelante, en tus viajes.")
		_lbl_cambio.text = ""
		_lbl_costo.text = ""
		_lbl_estado.text = ""
		_lbl_pista.text = ""
		return
	var maxima := Juego.esta_al_maximo(id)
	var oferta := Juego.cotizar_mejora(id, Juego.cantidad_compra)
	_lbl_sala.text = ("✦ " if m.destino != "" else "") + tr(m.nombre)
	_lbl_rama.text = _nombre_rama(m.rama)
	_lbl_detalle.text = tr(m.descripcion)
	_lbl_estado.text = _efecto_practico(m.stat)
	if not e.abierta:
		if m.destino != "" and not Juego.destino_desbloqueado(m.destino):
			_lbl_cambio.text = tr("Se descubre al llegar a %s") % tr(Mundos.INFO[m.destino].nombre)
		else:
			_lbl_cambio.text = texto_requisitos(Juego.requisitos_faltantes(m.requisitos))
		_lbl_cambio.label_settings.font_color = Estilo.TEXTO_SUAVE
		_lbl_costo.text = tr("Cámara por desarrollar")
		_lbl_costo.label_settings.font_color = Estilo.TEXTO_SUAVE
		_lbl_pista.text = ""
		return
	if maxima:
		if m.tope_por_destino > 0 and Juego.lugares_completados.size() < Mundos.ORDEN.size():
			_lbl_cambio.text = tr("Tope alcanzado: cada destino conquistado suma %d niveles.") % m.tope_por_destino
		elif m.elevable and not Juego.jalea_al_maximo("techo"):
			_lbl_cambio.text = tr("Tope alcanzado: las Cámaras más hondas de la reina suman niveles.")
		else:
			_lbl_cambio.text = tr("Tu colonia domina esta habilidad.")
		_lbl_costo.text = tr("COMPLETA")
		_lbl_pista.text = ""
		return
	if m.stat == "materiales":
		_lbl_cambio.text = tr("Nueva dieta: %s") % _valor_stat(m.stat, Juego.stat_tras_comprar(id, maxi(1, oferta.cantidad)))
	else:
		_lbl_cambio.text = "%s  →  %s" % [_valor_stat(m.stat, Juego.stat(m.stat)), _valor_stat(m.stat, Juego.stat_tras_comprar(id, maxi(1, oferta.cantidad)))]
	var hito := Juego.proximo_hito_nivel(id)
	if hito > 0:
		_lbl_cambio.text += "\n" + tr("Hito en nivel %d: daño ×%s") % [hito, _numero_corto(m.bonus_mult)]
	if oferta.puede:
		_lbl_costo.text = tr("Comprar ×%d · %s migas") % [oferta.cantidad, Juego.formatear(oferta.costo)]
		_lbl_pista.text = tr("Clic para mejorar")
	else:
		_lbl_costo.text = tr("Faltan %s migas") % Juego.formatear(maxf(0, oferta.costo - Juego.migas))
		_lbl_costo.label_settings.font_color = Estilo.TEXTO_SUAVE
		_lbl_pista.text = ""


func _ficha_casta(id: String, e: Dictionary) -> void:
	var c: Dictionary = Juego.castas_por_id[id]
	if e.misterio:
		_lbl_sala.text = tr("Cámara por desarrollar")
		_lbl_rama.text = tr("CASTAS")
		_lbl_detalle.text = tr("Las especialistas aparecen después de tu cuarta expedición.")
		_lbl_cambio.text = ""
		_lbl_costo.text = ""
		_lbl_estado.text = ""
		_lbl_pista.text = ""
		return
	_lbl_sala.text = tr(c.nombre)
	_lbl_sala.label_settings.font_color = c.color.lightened(0.25)
	_lbl_rama.text = tr("CASTA · %s") % tr(c.rol).to_upper()
	_lbl_detalle.text = tr(c.habilidad)
	_lbl_estado.text = _panel_castas.consejo_equipo(id)
	_lbl_pista.text = tr("Clic derecho: ficha completa y evoluciones")
	var oferta := Juego.cotizar_casta(id, Juego.cantidad_compra)
	if not e.abierta:
		_lbl_cambio.text = texto_requisitos(Juego.requisitos_faltantes(c.requisitos))
		_lbl_cambio.label_settings.font_color = Estilo.TEXTO_SUAVE
		_lbl_costo.text = tr("Cámara por desarrollar")
		_lbl_costo.label_settings.font_color = Estilo.TEXTO_SUAVE
	elif e.nivel >= e.maximo:
		_lbl_cambio.text = tr("Compra permanente: esta unidad saldrá en cada expedición.")
		_lbl_costo.text = tr("Colonia completa")
	else:
		_lbl_cambio.text = tr("Compra permanente: esta unidad saldrá en cada expedición.")
		if oferta.puede:
			_lbl_costo.text = tr("Reclutar ×%d · %s migas") % [maxi(1, oferta.cantidad), Juego.formatear(oferta.costo)]
			_lbl_pista.text = tr("Clic para reclutar · clic derecho: ficha completa y evoluciones")
		else:
			_lbl_costo.text = tr("Faltan %s migas") % Juego.formatear(maxf(0, oferta.costo - Juego.migas))
			_lbl_costo.label_settings.font_color = Estilo.TEXTO_SUAVE


func _ficha_seccion(id: String, e: Dictionary) -> void:
	_lbl_sala.text = tr(NOMBRES_PESTANAS[id])
	_lbl_rama.text = ""
	_lbl_cambio.text = ""
	_lbl_costo.text = ""
	_lbl_estado.text = ""
	_lbl_pista.text = tr("Clic para entrar") if e.abierta else ""
	match id:
		"viajes":
			_lbl_detalle.text = tr("Elegí el próximo destino. Conquistaste %d de %d.") % [Juego.lugares_completados.size(), Mundos.ORDEN.size()] if e.abierta else tr("Se abre al conquistar el gran objetivo de la casa.")
		"castas":
			_lbl_detalle.text = tr("Fichas completas, evoluciones y equipo de tus especialistas.") if e.abierta else tr("Las especialistas aparecen después de tu cuarta expedición.")
		"legado":
			_lbl_detalle.text = tr("Fundá colonias nuevas y mejorá a la reina. Tenés %d de jalea.") % Juego.jalea if e.abierta else tr("Se abre con tu primer hito o tu primera corona.")


func _nombre_rama(rama: String) -> String:
	if rama == "Fondo":
		return tr("EL FONDO DEL HORMIGUERO")
	var partes := PackedStringArray()
	for parte in rama.split("|"):
		partes.append(tr(parte).to_upper())
	return " + ".join(partes)


func _posicionar_ficha() -> void:
	if _ficha_id == "" or not is_instance_valid(_corte_tierra):
		return
	var tam := _ficha_mejoras.get_combined_minimum_size()
	_ficha_mejoras.size = tam
	var r := _corte_tierra.rect_en_pantalla(_ficha_id)
	r.position += _corte_tierra.global_position - _area_nido.global_position
	var x := r.end.x + 18.0
	if x + tam.x > _area_nido.size.x - 10.0:
		x = r.position.x - tam.x - 18.0
	_ficha_mejoras.position = Vector2(clampf(x, 10.0, maxf(10.0, _area_nido.size.x - tam.x - 10.0)), clampf(r.get_center().y - 70.0, 10.0, maxf(10.0, _area_nido.size.y - tam.y - 10.0)))


# =====================================================================
# Estado de cada cámara
# =====================================================================

func _calcular_estados() -> Dictionary:
	var estados := {}
	var castas_vistas := Juego.revelado("castas")
	var viajes_vistos := Juego.revelado("viajes")
	for id in PlanoHormiguero.CAMARAS:
		var e := {"tipo": "mejora", "rama": "", "kit": "comun", "mezcla": [], "color": Estilo.ACENTO, "nivel": 0, "maximo": 0,
			"lleno": 0.0, "abierta": false, "puede": false, "lejana": false, "misterio": false, "extra": 0, "seccion": false}
		if id in PlanoHormiguero.SECCIONES:
			e.tipo = "seccion"
			e.seccion = true
			e.abierta = Juego.revelado(id)
			e.color = COLORES_SECCIONES[id]
			e.lleno = 1.0
			match id:
				"viajes":
					e.kit = "viajes"
					e.extra = Juego.lugares_completados.size()
				"castas":
					e.kit = "castas"
					e.lleno = clampf(Juego.total_especialistas() / 12.0, 0.0, 1.0)
				"legado":
					e.kit = "reina"
					e.extra = mini(6, Juego.fundaciones)
		elif Juego.mejoras_por_id.has(id):
			var m: Dictionary = Juego.mejoras_por_id[id]
			e.rama = m.rama
			e.kit = ArteCamara.kit_de(m.rama)
			e.mezcla = ArteCamara.mezcla_de(m.rama) if e.kit == "comun" else []
			e.color = ArteCamara.color_de(m.rama) if e.kit != "comun" else ArteCamara.COLORES.comun
			e.nivel = Juego.nivel_de(id)
			e.maximo = Juego.nivel_maximo(id)
			e.misterio = m.destino != "" and not viajes_vistos
			e.abierta = Juego.esta_desbloqueada(id) and not e.misterio
			e.puede = e.abierta and Juego.cotizar_mejora(id, Juego.cantidad_compra).puede
		elif Juego.castas_por_id.has(id):
			e.tipo = "casta"
			e.rama = "Castas"
			e.kit = "castas"
			e.color = Juego.castas_por_id[id].color.lerp(SALAS.Castas.color, 0.55)
			e.nivel = Juego.cantidad_casta(id)
			e.maximo = Juego.maximo_casta(id)
			e.misterio = not castas_vistas
			e.abierta = castas_vistas and Juego.casta_desbloqueada(id)
			e.puede = e.abierta and Juego.cotizar_casta(id, Juego.cantidad_compra).puede
		else:
			continue
		if e.tipo != "seccion" and e.nivel > 0 and e.maximo > 0:
			e.lleno = 0.15 + 0.85 * sqrt(clampf(float(e.nivel) / e.maximo, 0.0, 1.0))
		estados[id] = e
	# Lejanas: ninguna de las cámaras que llevan a ellas tiene niveles todavía.
	var alcanzadas := {}
	for tunel in PlanoHormiguero.TUNELES:
		if estados.has(tunel[1]) and (tunel[0] == "legado" or _nivel(tunel[0]) > 0):
			alcanzadas[tunel[1]] = true
	for id in estados:
		var e: Dictionary = estados[id]
		e.lejana = e.tipo != "seccion" and not e.abierta and e.nivel == 0 and not alcanzadas.has(id)
	return estados


func _nivel(id: String) -> int:
	if Juego.mejoras_por_id.has(id):
		return Juego.nivel_de(id)
	return Juego.cantidad_casta(id) if Juego.castas_por_id.has(id) else 0


## Cuánto está cavado cada túnel y qué rastro deja. Un túnel hacia una cámara
## cerrada se va cavando a medida que sube el requisito del que sale.
func _calcular_tuneles() -> Array:
	var cavado: Array[float] = []
	var rastros: Array[String] = []
	for tunel in PlanoHormiguero.TUNELES:
		var desde: String = tunel[0]
		var hasta: String = tunel[1]
		var valor := 1.0
		var rastro := ""
		if hasta in PlanoHormiguero.SECCIONES and not desde in ["boca", "viajes", "castas"]:
			valor = 1.0 if _nivel(desde) > 0 else 0.0
		elif desde != "boca" and not desde in PlanoHormiguero.SECCIONES:
			var e: Dictionary = _estados.get(hasta, {})
			if e.is_empty() or e.misterio:
				valor = 0.0
			elif not e.abierta and e.nivel == 0:
				valor = clampf(float(_nivel(desde)) / maxf(1.0, _nivel_pedido(hasta, desde)), 0.0, 1.0) * 0.9
			if valor >= 1.0 and e.get("nivel", 0) > 0:
				var kit_hasta: String = e.kit
				var kit_desde: String = _estados.get(desde, {}).get("kit", "")
				if ArteCamara.RASTROS.has(kit_hasta):
					rastro = kit_hasta
				elif kit_hasta == "comun" and ArteCamara.RASTROS.has(kit_desde):
					rastro = kit_desde
		cavado.append(valor)
		rastros.append(rastro)
	return [cavado, rastros]


## El nivel que una cámara pide de otra para abrirse.
func _nivel_pedido(id: String, requisito: String) -> float:
	var requisitos: Array = Juego.mejoras_por_id[id].requisitos if Juego.mejoras_por_id.has(id) else Juego.castas_por_id[id].requisitos
	for r in requisitos:
		if r.id == requisito:
			return float(r.nivel)
	return 1.0


func disponibles_por_rama() -> Dictionary:
	var cuenta := {}
	for rama in SALAS:
		cuenta[rama] = 0
	for id in _estados:
		var e: Dictionary = _estados[id]
		if e.puede:
			for parte in String(e.rama).split("|"):
				if cuenta.has(parte):
					cuenta[parte] += 1
	return cuenta


## Centro de una cámara en coordenadas globales (para clics de las pruebas).
func posicion_camara(id: String) -> Vector2:
	return _corte_tierra.get_global_transform() * _corte_tierra.rect_en_pantalla(id).get_center()


# =====================================================================
# Refresco, pie y compras
# =====================================================================

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


func _on_migas_cambiaron(_total: float) -> void:
	_refrescar()


func _refrescar() -> void:
	_boton_run.text = tr("Explorar") + "  →"
	_actualizar_revelados()
	_actualizar_siguiente_paso()
	_boton_run.tooltip_text = tr("Destino: %s") % tr(Mundos.INFO[Juego.lugar_actual].nombre)
	for cantidad in _cantidades:
		_cantidades[cantidad].add_theme_stylebox_override("normal", Estilo.caja(Color("536649") if cantidad == Juego.cantidad_compra else Color("282f26"), 10, Color("94b47e") if cantidad == Juego.cantidad_compra else Color("46503f"), 1, 10))
	_lbl_proxima.text = tr("%d obreras + %d especialistas  ·  %d s  ·  %d cm") % [int(Juego.stat("hormigas_iniciales")), Juego.total_especialistas(), int(Juego.stat("duracion_run")), int(Juego.stat("radio_territorio") / 10.0)]
	if Juego.decretos_por_id.has(Juego.decreto):
		_lbl_proxima.text += "  ·  " + tr(Juego.decretos_por_id[Juego.decreto].nombre)
	_estados = _calcular_estados()
	var tuneles := _calcular_tuneles()
	_corte_tierra.actualizar(_estados, tuneles[0], tuneles[1])
	var disponibles := disponibles_por_rama()
	for rama in _leyenda:
		var boton: Button = _leyenda[rama]
		boton.text = "●  " + tr(rama) + ("   %d" % disponibles[rama] if disponibles[rama] > 0 else "")
		boton.visible = rama != "Castas" or Juego.revelado("castas")
	if _ficha_mejoras.visible and _ficha_id != "":
		_mostrar_ficha(_ficha_id)


## "Requiere Buche grande · nivel 2" o, si faltan varios, "Requiere: Buche grande nivel 2 + Cría acelerada nivel 3".
func texto_requisitos(faltan: Array) -> String:
	return Juego.texto_requisitos(faltan)


## Las mejoras de destino se muestran (bloqueadas) recién cuando aparecen los viajes.
func _mejora_visible(m: Dictionary) -> bool:
	return m.destino == "" or Juego.revelado("viajes")


func _numero_corto(n: float) -> String:
	return str(int(n)) if is_equal_approx(n, roundf(n)) else "%.2f" % n


## Secciones y compra por lote aparecen recién cuando sirven; las nuevas
## llevan un punto hasta que el jugador las abre.
func _actualizar_revelados() -> void:
	for id in _pestanas:
		var boton: Button = _pestanas[id]
		boton.visible = Juego.revelado(id)
		boton.text = tr(NOMBRES_PESTANAS[id]) + ("  ● " + tr("¡Nuevo!") if Juego.es_nuevo(id) else "")
	_corte_tierra._ubicar_etiquetas()
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
		"pisotones_auto": return tr("%.1f pisotones automáticos/s") % valor
		"retirada": return tr("%.0f s de retirada") % valor
		"frenesi_duracion": return tr("%.0f s de frenesí") % valor
		"frenesi_ritmo": return tr("frenesí ×%.2f") % valor
		"bonus_destruir": return tr("%d%% al destruir") % roundi(valor * 100.0)
		"botin_eventos": return tr("%d%% de la run por botín") % roundi(valor * 100.0)
		"intervalo_doradas": return tr("una dorada cada %.0f s") % ((Eventos.ENTRE_DORADAS.x + Eventos.ENTRE_DORADAS.y) * 0.5 * valor)
		"fuerza_especialistas": return tr("especialistas ×%.2f") % valor
		"limite_castas": return tr("+%d por casta") % int(valor)
		"tesoros_extra": return tr("%d alimentos por escondite") % (3 + int(valor))
		"domino": return tr("%d%% a dos vecinas") % roundi(valor * 100.0)
		"corrosion_factor": return tr("+%d%% sobre lo corroído") % roundi(valor * 100.0)
		"festin_duracion": return tr("%.0f s de festín") % valor
	return tr("%s de daño") % ("%.1f" % valor if valor < 1000.0 else Juego.formatear(valor))


## Efecto sobre el trabajo que ya existe, no una promesa de producción: ésta
## depende del material, los caminos y el resto de la colonia.
func _efecto_practico(stat: String) -> String:
	match stat:
		"hormigas_iniciales", "cria": return tr("Más trabajadoras reparten la búsqueda, el corte y las entregas.")
		"velocidad": return tr("Llegan antes a los recursos y tardan menos en entregar cada carga.")
		"capacidad": return tr("Juntan más bocados antes de volver: menos viajes para transportar lo extraído.")
		"dano", "intervalo_mordida": return tr("Recortan los materiales antes. Las cargadoras ayudan a llevarse los restos.")
		"materiales": return tr("La colonia puede trabajar otro material: no hace falta romperlo a clics.")
		"entradas": return tr("Al alcanzar otro ambiente pueden entregar allí, sin volver siempre a la entrada principal.")
		"radio_territorio": return tr("Abre terreno para explorar; las entradas secundarias pueden acortar el regreso.")
		"olfato": return tr("Encuentran recursos desde más lejos sin necesitar un llamado.")
		"feromona_cantidad": return tr("El llamado reúne más hormigas cercanas; la colonia sigue buscando sola cuando lo soltás.")
		"duracion_run": return tr("Tienen más tiempo para extraer y transportar antes de la retirada.")
		"multiplicador_migas": return tr("Cada recurso entregado vale más. Lo que queda en camino todavía no se cobra.")
		"pisotones_auto", "dano_clic": return tr("El apoyo automático corta comida cerca del cursor, sin agregar daño al clic manual.")
		"retirada": return tr("Al final de la expedición tienen más tiempo para entregar lo que llevan.")
		"frenesi_duracion", "frenesi_ritmo": return tr("Cada depósito carga el frenesí: con veinte seguidos la colonia acelera.")
		"bonus_destruir": return tr("Terminar una comida o una pieza paga un extra, además de lo que se transporta.")
		"botin_eventos", "intervalo_doradas": return tr("Pisar las migas doradas y vencer amenazas paga más: conviene mirar la pantalla.")
		"fuerza_especialistas", "limite_castas": return tr("Las especialistas reclutadas salen en todas las expediciones.")
		"tesoros_extra": return tr("Las alacenas, heladeras y vitrinas que se abren sueltan más comida.")
		"domino": return tr("Al caer un mueble devorado sacude a los vecinos: un derrumbe puede abrir varios.")
		"corrosion_factor": return tr("Las hormigas rojas ablandan los materiales para todo el grupo.")
		"festin_duracion": return tr("Los festines del restaurante cargan el frenesí al doble.")
	return tr("Las mejoras se guardan al comprar.")


func _comprar(id: String) -> void:
	var texto := ""
	if Juego.castas_por_id.has(id) and not Juego.mejoras_por_id.has(id):
		if not Juego.revelado("castas"):
			Sonido.tocar("no")
			return
		var reclutadas := Juego.comprar_castas_lote(id, Juego.cantidad_compra)
		if reclutadas == 0:
			Sonido.tocar("no")
			_aviso(id, tr("Te faltan migas o una casta previa. ¡Otra expedición!"))
			return
		texto = tr("¡%s ×%d! Salen en todas las próximas expediciones.") % [tr(Juego.castas_por_id[id].nombre), reclutadas]
	elif Juego.mejoras_por_id.has(id):
		if _estados.get(id, {}).get("misterio", false):
			Sonido.tocar("no")
			return
		var stat: String = Juego.mejoras_por_id[id].stat
		var antes := Juego.stat(stat)
		var compradas := Juego.comprar_lote(id, Juego.cantidad_compra)
		if compradas == 0:
			Sonido.tocar("no")
			_aviso(id, tr("Te faltan migas o una mejora previa. ¡Otra expedición!"))
			return
		texto = tr("¡%s +%d niveles!\n%s → %s") % [tr(Juego.mejoras_por_id[id].nombre), compradas, _valor_stat(stat, antes), _valor_stat(stat, Juego.stat(stat))]
	else:
		return
	Sonido.tocar("comprar", 1.0, 0.01)
	_corte_tierra.celebrar(id)
	_aviso(id, texto)


## Mensaje en la ficha de la cámara hasta que el mouse pase a otra.
func _aviso(id: String, texto: String) -> void:
	_aviso_compra = {"id": id, "texto": texto}
	_lbl_estado.text = texto
	if _ficha_id == id and _ficha_mejoras.visible:
		_mostrar_ficha(id)


func _nueva_run() -> void:
	get_tree().change_scene_to_file(ESCENA_RUN)
