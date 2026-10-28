class_name PanelCastas
extends HBoxContainer
## Catálogo, fichas y reclutamiento persistente de especialistas.

var seleccion := "reina"
var _filas: Dictionary = {}
var _retrato: RetratoCasta
var _nombre: Label
var _rol: Label
var _descripcion: Label
var _habilidad: Label
var _cantidad: Label
var _aviso: Label
var _boton: Button
var _stats: Dictionary = {}
var _tween: Tween
var _evoluciones: Dictionary = {}
var _lbl_evoluciones: Label
var _detalle_evolucion: Label


func _ready() -> void:
	add_theme_constant_override("separation", 20)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_crear_catalogo())
	add_child(_crear_ficha())
	Juego.migas_cambiaron.connect(_cambio_migas)
	Juego.mejora_comprada.connect(_cambio_mejora)
	Juego.partida_borrada.connect(_refrescar)
	Juego.modo_compra_cambio.connect(_refrescar)
	Juego.progreso_cambio.connect(_refrescar)
	_refrescar()


func _crear_catalogo() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 310
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.75
	panel.add_theme_stylebox_override("panel", Estilo.caja(Color("211e19"), 18, Color("494333"), 1, 18))
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	panel.add_child(columna)
	columna.add_child(Estilo.etiqueta(tr("UNA COLONIA CON PERSONALIDAD"), 11, Color("b9ad94")))
	columna.add_child(Estilo.etiqueta(tr("Conocé a tus hormigas"), 24))
	var ayuda := Estilo.etiqueta(tr("Elegí una casta para ver su habilidad y reclutarla."), 13, Estilo.TEXTO_SUAVE)
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(ayuda)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columna.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 8)
	scroll.add_child(lista)
	for c in Juego.castas:
		if not c.comprable:
			continue
		var boton := Button.new()
		boton.custom_minimum_size.y = 84
		boton.pressed.connect(_seleccionar.bind(c.id))
		lista.add_child(boton)
		var margen := MarginContainer.new()
		margen.set_anchors_preset(Control.PRESET_FULL_RECT)
		margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margen.add_theme_constant_override("margin_left", 10)
		margen.add_theme_constant_override("margin_right", 12)
		boton.add_child(margen)
		var fila := HBoxContainer.new()
		fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila.add_theme_constant_override("separation", 12)
		margen.add_child(fila)
		var retrato := RetratoCasta.new()
		retrato.tipo = c.id
		retrato.custom_minimum_size = Vector2(62, 70)
		fila.add_child(retrato)
		var textos := VBoxContainer.new()
		textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
		textos.alignment = BoxContainer.ALIGNMENT_CENTER
		textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(textos)
		textos.add_child(Estilo.etiqueta(tr(c.nombre), 17, c.color))
		textos.add_child(Estilo.etiqueta(tr(c.rol), 12, Estilo.TEXTO_SUAVE))
		var cantidad := Estilo.etiqueta("", 12)
		textos.add_child(cantidad)
		_filas[c.id] = {"boton": boton, "cantidad": cantidad}
	var base := Estilo.etiqueta(tr("Las obreras de siempre siguen saliendo del hormiguero. Las miniobreras nacen de las reinas."), 12, Estilo.TEXTO_SUAVE)
	base.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(base)
	return panel


func _crear_ficha() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 420
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Estilo.caja(Color("222923"), 18, Color("3e493d"), 1, 20))
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 12)
	panel.add_child(columna)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columna.add_child(scroll)
	var ficha := VBoxContainer.new()
	ficha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ficha.add_theme_constant_override("separation", 12)
	scroll.add_child(ficha)
	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 16)
	ficha.add_child(cabecera)
	_retrato = RetratoCasta.new()
	_retrato.custom_minimum_size = Vector2(104, 104)
	cabecera.add_child(_retrato)
	var titulos := VBoxContainer.new()
	titulos.alignment = BoxContainer.ALIGNMENT_CENTER
	titulos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(titulos)
	titulos.add_child(Estilo.etiqueta(tr("FICHA DE CASTA"), 11, Estilo.TEXTO_SUAVE))
	_nombre = Estilo.etiqueta("", 25)
	_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulos.add_child(_nombre)
	_rol = Estilo.etiqueta("", 13, Estilo.TEXTO_SUAVE)
	_rol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulos.add_child(_rol)
	_cantidad = Estilo.etiqueta("", 13)
	titulos.add_child(_cantidad)
	_descripcion = Estilo.etiqueta("", 14, Estilo.TEXTO)
	_descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ficha.add_child(_descripcion)
	var cuadricula := GridContainer.new()
	cuadricula.columns = 2
	cuadricula.add_theme_constant_override("h_separation", 10)
	cuadricula.add_theme_constant_override("v_separation", 10)
	ficha.add_child(cuadricula)
	for clave in ["velocidad", "dano", "capacidad", "olfato"]:
		var caja := PanelContainer.new()
		caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caja.add_theme_stylebox_override("panel", Estilo.caja(Color("1c221d"), 10, Color("3b4438"), 1, 10))
		cuadricula.add_child(caja)
		var valor := Estilo.etiqueta("", 14)
		caja.add_child(valor)
		_stats[clave] = valor
	ficha.add_child(Estilo.etiqueta(tr("SU HABILIDAD"), 11, Color("9db196")))
	_habilidad = Estilo.etiqueta("", 13)
	_habilidad.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ficha.add_child(_habilidad)
	var herencia := Estilo.etiqueta(tr("Estos valores incluyen tus mejoras del hormiguero. Las obreras varían levemente su velocidad al nacer."), 11, Estilo.TEXTO_SUAVE)
	herencia.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ficha.add_child(herencia)
	_lbl_evoluciones = Estilo.etiqueta("", 13, Color("d5cb96"))
	ficha.add_child(_lbl_evoluciones)
	for id in EvolucionesHormiga.DATOS:
		var datos: Dictionary = EvolucionesHormiga.DATOS[id]
		var boton := Estilo.boton(datos.nombre, 13, Color("303c2b"), Color("8eaa72"))
		boton.toggle_mode = true
		boton.tooltip_text = tr(datos.detalle) + tr("\nRequiere %d %s y Mandíbulas nivel %d. Elegí hasta dos sin perder lo desbloqueado.") % [datos.unidades, tr(Juego.castas_por_id[datos.casta].nombre), datos.mandibulas]
		boton.pressed.connect(_alternar_evolucion.bind(id))
		ficha.add_child(boton)
		_evoluciones[id] = boton
	_detalle_evolucion = Estilo.etiqueta("", 12, Estilo.TEXTO_SUAVE)
	_detalle_evolucion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ficha.add_child(_detalle_evolucion)
	_boton = Estilo.boton("", 19, Color("46593e"), Color("94b47e"))
	_boton.custom_minimum_size.y = 54
	_boton.pressed.connect(_reclutar)
	columna.add_child(_boton)
	_aviso = Estilo.etiqueta("", 12, Estilo.TEXTO_SUAVE)
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_aviso)
	return panel


func _seleccionar(id: String) -> void:
	seleccion = id
	Sonido.tocar("clic", 0.9)
	_refrescar()


func _cambio_migas(_total: float) -> void:
	_refrescar()


func _cambio_mejora(_id: String, _nivel: int) -> void:
	_refrescar()


func _refrescar() -> void:
	var c: Dictionary = Juego.castas_por_id[seleccion]
	_lbl_evoluciones.text = tr("EVOLUCIONES · %d / %d activas · cambio gratuito") % [Juego.evoluciones_equipadas.size(), EvolucionesHormiga.MAX_EQUIPADAS]
	_detalle_evolucion.text = ""
	for id in _evoluciones:
		var boton: Button = _evoluciones[id]
		var datos: Dictionary = EvolucionesHormiga.DATOS[id]
		boton.visible = datos.casta == seleccion
		boton.disabled = not Juego.evoluciones_desbloqueadas.has(id)
		boton.set_pressed_no_signal(Juego.evolucion_activa(id))
		boton.text = ("✓ " if Juego.evolucion_activa(id) else "○ ") + tr(datos.nombre) + (tr(" · bloqueada") if boton.disabled else "")
		if boton.visible:
			_detalle_evolucion.text = tr(datos.detalle)
			if boton.disabled:
				_detalle_evolucion.text += tr("\nRequiere %d %s y Mandíbulas nivel %d.") % [datos.unidades, tr(Juego.castas_por_id[datos.casta].nombre), datos.mandibulas]

	_retrato.tipo = seleccion
	_nombre.text = tr(c.nombre)
	_nombre.label_settings.font_color = c.color
	_rol.text = tr(c.rol)
	_cantidad.text = tr("En tu colonia: %d / %d") % [Juego.cantidad_casta(seleccion), c.maximo]
	_descripcion.text = tr(c.descripcion)
	_habilidad.text = tr(c.habilidad)
	_habilidad.label_settings.font_color = c.color.lightened(0.2)
	var stats := Juego.stats_casta(seleccion)
	_stats.velocidad.text = tr("Velocidad · %.0f px/s") % stats.velocidad
	_stats.dano.text = tr("Mordida · %.2f daño") % stats.dano
	_stats.capacidad.text = tr("Carga · %d bocados") % stats.capacidad
	_stats.olfato.text = tr("Olfato · %.0f px") % stats.olfato
	var maximo: bool = Juego.cantidad_casta(seleccion) >= c.maximo
	var oferta := Juego.cotizar_casta(seleccion, Juego.cantidad_compra)
	var disponible: bool = oferta.puede
	_boton.disabled = not disponible
	_boton.text = tr("Colonia completa") if maximo else tr("Reclutar ×%d · %s migas") % [maxi(1, oferta.cantidad), Juego.formatear(oferta.costo)]
	_boton.add_theme_stylebox_override("disabled", Estilo.caja(Color("30372e"), 10, Color("4e5848"), 1, 14))
	_aviso.text = tr("Compra permanente: esta unidad saldrá en cada expedición.")
	if not disponible and not maximo:
		_aviso.text = tr("Faltan %s migas para este lote. Las unidades son permanentes.") % Juego.formatear(maxf(0, oferta.costo - Juego.migas))
	if not Juego.casta_desbloqueada(seleccion):
		_aviso.text = tr("Requiere aprender a devorar madera y telas.") if seleccion == "carpintera" else tr("Requiere aprender a devorar paredes.")
	for id in _filas:
		var fila: Dictionary = _filas[id]
		var datos: Dictionary = Juego.castas_por_id[id]
		fila.cantidad.text = tr("%d en la colonia · desde %s migas") % [Juego.cantidad_casta(id), Juego.formatear(Juego.costo_casta(id))]
		if not Juego.casta_desbloqueada(id):
			fila.cantidad.text = tr("Bloqueada · requiere nueva dieta")
		var color: Color = datos.color
		fila.boton.add_theme_stylebox_override("normal", Estilo.caja(Color(color, 0.12) if id == seleccion else Color("28271f"), 12, Color(color, 0.8 if id == seleccion else 0.14), 1, 0))
		fila.boton.add_theme_stylebox_override("hover", Estilo.caja(Color(color, 0.15), 12, color, 1, 0))
		fila.boton.add_theme_stylebox_override("pressed", Estilo.caja(Color(color, 0.22), 12, color, 2, 0))
		fila.boton.add_theme_stylebox_override("focus", Estilo.caja(Color.TRANSPARENT, 12, color, 2, 0))


func _reclutar() -> void:
	var compradas := Juego.comprar_castas_lote(seleccion, Juego.cantidad_compra)
	if compradas == 0:
		Sonido.tocar("no")
		_refrescar()
		return
	Sonido.tocar("comprar", 0.95)
	_aviso.text = tr("¡%s ×%d! Salen en todas las próximas expediciones.") % [tr(Juego.castas_por_id[seleccion].nombre), compradas]
	if _tween and _tween.is_running():
		_tween.kill()
	_retrato.pivot_offset = _retrato.size * 0.5
	_retrato.scale = Vector2.ONE * 1.12
	_tween = _retrato.create_tween()
	_tween.tween_property(_retrato, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _alternar_evolucion(id: String) -> void:
	var cambio := Juego.alternar_evolucion(id)
	_refrescar()
	if not cambio:
		_aviso.text = tr("Hay dos evoluciones activas: desactivá una antes de equipar otra. No perdés ninguna compra.")
