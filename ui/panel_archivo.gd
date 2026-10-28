class_name PanelArchivo
extends VentanaModal
## Archivo paginado: no crea una tarjeta por cada expedición de toda la partida.
const POR_PAGINA := 8
var _pagina := 0
var _modo := 0
var _destino := ""
var _lista: VBoxContainer
var _pagina_texto: Label
var _anterior: Button
var _siguiente: Button
var _exportar: Button
var _aviso: Label
var _scroll: ScrollContainer
var _dialogo: FileDialog

func _ready() -> void:
	titulo(tr("Archivo de expediciones"))
	ancho(940)
	var ayuda := Estilo.etiqueta(tr("Tus tiempos de limpieza. Las marcas se comparan sólo con la misma dieta, alcance y versión del mapa; las mejoras de la colonia pueden cambiar."), 13, Estilo.TEXTO_SUAVE)
	ayuda.custom_minimum_size.x = 860
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenido.add_child(ayuda)
	var opciones := HBoxContainer.new()
	opciones.add_theme_constant_override("separation", 12)
	contenido.add_child(opciones)
	var modo := OptionButton.new()
	modo.add_item(tr("Marcas personales"))
	modo.add_item(tr("Últimas expediciones"))
	modo.item_selected.connect(func(indice: int) -> void:
		_modo = indice
		_pagina = 0
		_refrescar())
	opciones.add_child(modo)
	var destino := OptionButton.new()
	destino.add_item(tr("Todos los destinos"))
	for id in Mundos.ORDEN:
		destino.add_item(tr(Mundos.INFO[id].nombre))
	destino.item_selected.connect(func(indice: int) -> void:
		_destino = "" if indice == 0 else Mundos.ORDEN[indice - 1]
		_pagina = 0
		_refrescar())
	opciones.add_child(destino)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	contenido.add_child(_scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 10)
	_scroll.add_child(_lista)
	var pie := HBoxContainer.new()
	pie.add_theme_constant_override("separation", 12)
	contenido.add_child(pie)
	_anterior = Estilo.boton(tr("Anterior"), 14, Color("293329"), Color("52634a"))
	_anterior.pressed.connect(_pasar.bind(-1))
	pie.add_child(_anterior)
	_pagina_texto = Estilo.etiqueta("", 13, Estilo.TEXTO_SUAVE)
	_pagina_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pagina_texto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pagina_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pie.add_child(_pagina_texto)
	_siguiente = Estilo.boton(tr("Siguiente"), 14, Color("293329"), Color("52634a"))
	_siguiente.pressed.connect(_pasar.bind(1))
	pie.add_child(_siguiente)
	_exportar = Estilo.boton(tr("Exportar archivo JSON"), 14, Color("46593e"), Color("94b47e"))
	_exportar.pressed.connect(_pedir_exportacion)
	pie.add_child(_exportar)
	_aviso = Estilo.etiqueta("", 12, Estilo.TEXTO_SUAVE)
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenido.add_child(_aviso)
	_ajustar_alto()
	get_viewport().size_changed.connect(_ajustar_alto)
	_refrescar()

func _ajustar_alto() -> void:
	_scroll.custom_minimum_size = Vector2(860, clampf(get_viewport_rect().size.y - 350, 220, 600))

func registros_visibles() -> Array[Dictionary]:
	var registros: Array[Dictionary] = []
	if _modo == 0:
		registros.assign(Juego.records_limpieza.values())
		registros.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a.destino != b.destino:
				return Mundos.ORDEN.find(a.destino) < Mundos.ORDEN.find(b.destino)
			if a.dieta != b.dieta:
				return a.dieta < b.dieta
			if a.territorio != b.territorio:
				return a.territorio < b.territorio
			return a.version_mapa > b.version_mapa)
	else:
		registros.assign(Juego.archivo_expediciones)
		registros.reverse()
	if _destino != "":
		registros = registros.filter(func(r: Dictionary) -> bool: return r.destino == _destino)
	return registros

func _refrescar() -> void:
	for hijo in _lista.get_children():
		_lista.remove_child(hijo)
		hijo.queue_free()
	var registros := registros_visibles()
	var paginas := maxi(1, ceili(float(registros.size()) / POR_PAGINA))
	_pagina = clampi(_pagina, 0, paginas - 1)
	_pagina_texto.text = tr("Página %d / %d · %d registros") % [_pagina + 1, paginas, registros.size()]
	_anterior.disabled = _pagina == 0
	_siguiente.disabled = _pagina + 1 >= paginas
	_exportar.disabled = Juego.archivo_expediciones.is_empty() and Juego.records_limpieza.is_empty()
	if registros.is_empty():
		var vacio := Estilo.etiqueta(tr("Todavía no hay marcas. Devorá todo lo disponible en una expedición para archivar tu primer tiempo."), 17, Estilo.TEXTO_SUAVE)
		vacio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lista.add_child(vacio)
		return
	for i in range(_pagina * POR_PAGINA, mini((_pagina + 1) * POR_PAGINA, registros.size())):
		_lista.add_child(_tarjeta(registros[i]))

func _tarjeta(registro: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Estilo.caja(Color("293128"), 12, Color("56634a"), 1, 14))
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 5)
	panel.add_child(columna)
	var fila := HBoxContainer.new()
	columna.add_child(fila)
	var nombre := Estilo.etiqueta(tr(Mundos.INFO[registro.destino].nombre), 19, Estilo.TEXTO)
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(nombre)
	fila.add_child(Estilo.etiqueta(tr("%.1f s de limpieza") % registro.tiempo_limpieza, 21, Estilo.ACENTO))
	var categoria := tr("Mapa completo") if registro.completa else tr("Zona disponible")
	var detalle := Estilo.etiqueta(tr("%s · %s · alcance %.0f cm · mapa v%d") % [categoria,
		tr(MaterialesCasa.NIVELES[registro.dieta]), registro.territorio / 10.0, registro.version_mapa], 13, Estilo.TEXTO_SUAVE)
	detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(detalle)
	var entregas := Estilo.etiqueta(tr("Total con entregas: %.1f s · %s migas · %s migas/s\nColonia %d · expedición %d · %s") % [
		registro.tiempo_total, Juego.formatear_corto(registro.migas), Juego.formatear_corto(registro.produccion),
		registro.colonia + 1, registro.expedicion, registro.fecha.replace("T", " ")], 12, Estilo.TEXTO_SUAVE)
	entregas.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(entregas)
	return panel

func _pasar(direccion: int) -> void:
	_pagina += direccion
	_refrescar()

func _pedir_exportacion() -> void:
	if is_instance_valid(_dialogo):
		_dialogo.popup_centered_ratio(0.7)
		return
	_dialogo = FileDialog.new()
	_dialogo.title = tr("Guardar archivo de expediciones")
	_dialogo.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_dialogo.access = FileDialog.ACCESS_FILESYSTEM
	_dialogo.filters = PackedStringArray(["*.json ; JSON"])
	_dialogo.current_file = "hormigas_expediciones.json"
	_dialogo.file_selected.connect(_exportar_a)
	add_child(_dialogo)
	_dialogo.popup_centered_ratio(0.7)

func _exportar_a(ruta: String) -> void:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		_aviso.text = tr("No se pudo exportar el archivo. Elegí otra carpeta.")
		return
	archivo.store_string(JSON.stringify(Juego.datos_archivo_expediciones(), "\t"))
	_aviso.text = tr("Archivo exportado: %s") % ruta
