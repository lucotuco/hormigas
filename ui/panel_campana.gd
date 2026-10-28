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
	_confirmar.ok_button_text = "Fundar la nueva colonia"
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
		columna.add_child(_texto(ReglasDestino.DESCRIPCIONES[id], 12))
		for adaptacion in Juego.adaptaciones:
			if adaptacion.destino == id:
				columna.add_child(_texto(("✓ " if Juego.lugares_completados.has(id) else "Al conquistar: ") + adaptacion.nombre + " · " + adaptacion.descripcion, 12, Color("b8d89b")))
		boton.custom_minimum_size.y = 230
		var record: Dictionary = Juego.records_destino.get(id, {})
		if not record.is_empty():
			columna.add_child(_texto("Mejor intento %.0f%% · %s migas/s" % [float(record.objetivo) * 100, Juego.formatear_corto(record.produccion)], 12))

## Pestaña Jalea real: resumen, fundar con vista previa, árbol de la reina e hitos.
func _legado() -> void:
	_contenido.add_child(_texto("La reina y la jalea real", 28, Estilo.TEXTO))
	_contenido.add_child(_texto("Fundar una colonia reinicia migas, mejoras y castas, y convierte lo logrado en jalea real. La jalea se gasta en el árbol de la reina, que es permanente, y toda la jalea que ganes da +%d%% de daño y migas por punto aunque la gastes." % roundi(Juego.BONUS_LEGADO * 100)))
	_contenido.add_child(_resumen())
	_contenido.add_child(_texto("EL ÁRBOL DE LA REINA", 12, Color("c9b779")))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_contenido.add_child(grid)
	for n in Juego.nodos_jalea:
		grid.add_child(_nodo_jalea(n))
	_contenido.add_child(_texto("HITOS", 12, Color("c9b779")))
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


func _resumen() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Estilo.caja(Color("2e3629"), 14, Color("8e9f6e"), 1, 18))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 24)
	panel.add_child(fila)
	var izquierda := VBoxContainer.new()
	izquierda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(izquierda)
	izquierda.add_child(_texto("JALEA DISPONIBLE", 11, Estilo.TEXTO_SUAVE))
	izquierda.add_child(_texto("%d" % Juego.jalea, 32, Color("f0d277")))
	var colonias := "1 colonia fundada" if Juego.fundaciones == 1 else "%d colonias fundadas" % Juego.fundaciones
	izquierda.add_child(_texto("Ganada en total: %d · bonus pasivo +%d%% de daño y migas · %s" % [Juego.legado, roundi(Juego.legado * Juego.BONUS_LEGADO * 100), colonias], 13, Estilo.TEXTO))
	var derecha := VBoxContainer.new()
	derecha.custom_minimum_size.x = 330
	fila.add_child(derecha)
	var detalle := Juego.detalle_fundar()
	derecha.add_child(_texto("SI FUNDÁS AHORA", 11, Estilo.TEXTO_SUAVE))
	derecha.add_child(_texto("+%d jalea" % detalle.total, 24, Color("f0d277") if detalle.total > 0 else Estilo.TEXTO_SUAVE))
	derecha.add_child(_texto("%d coronas × %d = %d · migas de esta colonia (%s) = %d" % [Juego.coronas, Juego.JALEA_POR_CORONA, detalle.coronas, Juego.formatear(Juego.migas_colonia), detalle.migas], 12, Estilo.TEXTO_SUAVE))
	derecha.add_child(_texto(Juego.oportunidades_jalea(), 13, Color("cde0a3")))
	var fundar := Estilo.boton("Fundar colonia…", 17, Color("56613e"), Color("bbcb8a"))
	fundar.disabled = not Juego.puede_fundar()
	fundar.tooltip_text = "Conquistá un gran objetivo o juntá más migas para ganar jalea." if fundar.disabled else "Reiniciar la colonia a cambio de jalea real"
	fundar.pressed.connect(_pedir_fundacion)
	derecha.add_child(fundar)
	return panel


func _nodo_jalea(n: Dictionary) -> Control:
	var nivel := Juego.nivel_jalea(n.id)
	var abierto := Juego.jalea_desbloqueada(n.id)
	var completo := Juego.jalea_al_maximo(n.id)
	var puede := Juego.puede_comprar_jalea(n.id)
	var color := Color("f0d277")
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(0, 100)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fondo := Color("3a3a26") if puede else (Color("2b3326") if nivel > 0 else Color("232822"))
	boton.add_theme_stylebox_override("normal", Estilo.caja(fondo, 12, Color(color, 0.6 if puede else 0.15), 1, 0))
	boton.add_theme_stylebox_override("hover", Estilo.caja(fondo.lightened(0.06), 12, color, 1, 0))
	boton.add_theme_stylebox_override("pressed", Estilo.caja(fondo.darkened(0.08), 12, color, 2, 0))
	boton.modulate.a = 1.0 if abierto else 0.55
	boton.pressed.connect(_comprar_jalea.bind(n.id))
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 12)
	boton.add_child(margen)
	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_theme_constant_override("separation", 4)
	margen.add_child(columna)
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(fila)
	var nombre := _texto(n.nombre, 15, Estilo.TEXTO)
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(nombre)
	# Sin ajuste de línea: con autowrap y sin ancho propio se partía letra por letra.
	fila.add_child(Estilo.etiqueta("%d / %d" % [nivel, n.nivel_max], 12, Estilo.TEXTO_SUAVE))
	columna.add_child(_texto(n.descripcion, 12, Estilo.TEXTO_SUAVE))
	var pie := "COMPLETO" if completo else ("Cuesta %d jalea" % Juego.costo_jalea(n.id))
	if not abierto:
		pie = "Requiere %s nivel %d" % [Juego.jalea_por_id[n.requiere_id].nombre, n.requiere_nivel]
	columna.add_child(_texto(pie, 13, color if puede else Estilo.TEXTO_SUAVE))
	for hijo in columna.get_children():
		hijo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for hijo in fila.get_children():
		hijo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return boton


func _comprar_jalea(id: String) -> void:
	if Juego.comprar_jalea(id):
		Sonido.tocar("comprar", 0.9, 0.0)
	else:
		Sonido.tocar("no")


func _pedir_fundacion() -> void:
	if not Juego.puede_fundar():
		return
	var detalle := Juego.detalle_fundar()
	var lineas := PackedStringArray()
	lineas.append("Ganás %d de jalea real (bonus pasivo: +%d%% → +%d%%)." % [detalle.total, roundi(Juego.legado * Juego.BONUS_LEGADO * 100), roundi((Juego.legado + detalle.total) * Juego.BONUS_LEGADO * 100)])
	lineas.append("")
	var conserva := 10 * Juego.nivel_jalea("despensa")
	lineas.append("Se reinician: migas%s, mejoras y castas%s." % [
		" (conservás el %d%%)" % conserva if conserva > 0 else "",
		" (conservás el %d%%)" % (25 * Juego.nivel_jalea("linaje")) if Juego.nivel_jalea("linaje") > 0 else ""])
	lineas.append("Se conservan: destinos, hitos, el árbol de la reina y lo descubierto.")
	lineas.append("Cada gran objetivo vuelve a dar sus coronas una vez.")
	lineas.append("También conservás adaptaciones de viaje, récords y evoluciones.")
	lineas.append(Juego.oportunidades_jalea())
	_confirmar.dialog_text = "\n".join(lineas)
	_confirmar.popup_centered(Vector2i(620, 260))
