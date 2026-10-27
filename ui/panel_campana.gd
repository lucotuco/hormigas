class_name PanelCampana
extends VBoxContainer
## Menús construidos al entrar o cambiar progreso, nunca por cuadro.
var modo := "viajes"
var _contenido: VBoxContainer
var _confirmar: ConfirmationDialog

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_contenido = VBoxContainer.new()
	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.add_theme_constant_override("separation", 14)
	scroll.add_child(_contenido)
	_confirmar = ConfirmationDialog.new()
	_confirmar.title = "Fundar una nueva colonia"
	_confirmar.ok_button_text = "Fundar y conservar mi legado"
	_confirmar.cancel_button_text = "Seguir creciendo"
	_confirmar.confirmed.connect(Juego.fundar_colonia)
	add_child(_confirmar)
	Juego.progreso_cambio.connect(refrescar)
	Juego.partida_borrada.connect(refrescar)
	refrescar()

func refrescar() -> void:
	if not is_instance_valid(_contenido):
		return
	for hijo in _contenido.get_children():
		_contenido.remove_child(hijo)
		hijo.queue_free()
	if modo == "viajes":
		_viajes()
	else:
		_legado()

func _texto(texto: String, tamano := 14, color := Color("b8baa9")) -> Label:
	var label := Estilo.etiqueta(texto, tamano, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _viajes() -> void:
	_contenido.add_child(_texto("El mundo es un banquete", 28, Estilo.TEXTO))
	_contenido.add_child(_texto("Devorá el gran objetivo de un destino para abrir el siguiente. Cada expedición empieza con el escenario completo; tu colonia y sus descubrimientos se conservan."))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	_contenido.add_child(grid)
	for id in Mundos.ORDEN:
		var datos: Dictionary = Mundos.INFO[id]
		var abierto := Juego.destino_desbloqueado(id)
		var actual: bool = Juego.lugar_actual == id
		var boton := Estilo.boton("", 16, Color("33412e") if actual else Color("232b24"), Color("91ad7b") if abierto else Color("465043"))
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.custom_minimum_size.y = 124
		boton.disabled = not abierto
		boton.pressed.connect(Juego.elegir_destino.bind(id))
		grid.add_child(boton)
		var margen := MarginContainer.new()
		margen.set_anchors_preset(Control.PRESET_FULL_RECT)
		margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for lado in ["left", "right", "top", "bottom"]:
			margen.add_theme_constant_override("margin_" + lado, 14)
		boton.add_child(margen)
		var columna := VBoxContainer.new()
		columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margen.add_child(columna)
		columna.add_child(_texto(("● " if actual else "") + datos.nombre, 19, Estilo.TEXTO if abierto else Estilo.TEXTO_SUAVE))
		columna.add_child(_texto(datos.subtitulo, 13))
		var detalle := "Gran objetivo: %s · %d coronas" % [datos.meta, datos.coronas]
		if not abierto:
			var anterior: String = Mundos.ORDEN[Mundos.ORDEN.find(id) - 1]
			detalle = "Requiere devorar: " + Mundos.INFO[anterior].meta
		elif Juego.coronas_cobradas.has(id):
			detalle = "CONQUISTADO · Gran objetivo: %s · coronas ya cobradas en esta colonia" % datos.meta
		elif Juego.lugares_completados.has(id):
			detalle = "CONQUISTADO · " + detalle + " disponibles otra vez"
		columna.add_child(_texto(detalle, 12, Color("d1c490")))

func _legado() -> void:
	_contenido.add_child(_texto("Tu colonia deja huella", 28, Estilo.TEXTO))
	_contenido.add_child(_texto("Los hitos son opcionales y su recompensa es permanente. El legado permite volver a empezar más fuerte; no conserva objetos destruidos."))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Estilo.caja(Color("2e3629"), 14, Color("8e9f6e"), 1, 18))
	_contenido.add_child(panel)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 20)
	panel.add_child(fila)
	var texto := _texto("Legado: %d · Coronas disponibles: %d\nBonificación permanente de daño y migas: +%d%%\nAl fundar perdés migas, mejoras y reclutas. Conservás destinos e hitos." % [Juego.legado, Juego.coronas, Juego.legado * 10], 14, Estilo.TEXTO)
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(texto)
	var fundar := Estilo.boton("Fundar colonia…", 17, Color("56613e"), Color("bbcb8a"))
	fundar.disabled = Juego.coronas <= 0
	fundar.tooltip_text = "Devorá un gran objetivo para ganar coronas."
	fundar.pressed.connect(_pedir_fundacion)
	fila.add_child(fundar)
	for id in Juego.HITOS:
		var datos: Dictionary = Juego.HITOS[id]
		var obtenido := Juego.hitos.has(id)
		var tarjeta := PanelContainer.new()
		tarjeta.add_theme_stylebox_override("panel", Estilo.caja(Color("29362b") if obtenido else Color("242a24"), 12, Color("687f58") if obtenido else Color("3b4639"), 1, 14))
		_contenido.add_child(tarjeta)
		var columna := VBoxContainer.new()
		tarjeta.add_child(columna)
		columna.add_child(_texto(("✓ " if obtenido else "○ ") + datos.nombre, 18, Estilo.TEXTO))
		columna.add_child(_texto(datos.detalle + " · " + datos.premio, 13, Color("b8c993") if obtenido else Estilo.TEXTO_SUAVE))

func _pedir_fundacion() -> void:
	if Juego.coronas <= 0:
		return
	_confirmar.dialog_text = "Convertir %d coronas en legado.\nDaño y migas: +%d%% → +%d%% permanentes.\n\nSe reinician tus migas, niveles de mejoras y reclutas.\nSe conservan tus destinos desbloqueados e hitos.\nCada gran objetivo vuelve a dar sus coronas una vez.\nLa casa y los otros escenarios vuelven a estar completos." % [Juego.coronas, Juego.legado * 10, (Juego.legado + Juego.coronas) * 10]
	_confirmar.popup_centered(Vector2i(610, 290))
