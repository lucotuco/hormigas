class_name VentanaFundar
extends VentanaModal
## Confirmación de fundar: qué se gana, qué se reinicia y qué se conserva, y
## la elección del decreto que va a regir la colonia nueva.

signal fundada

var elegido := ""
var _tarjetas: Dictionary = {}
var _boton_fundar: Button
var _lbl_inicio: Label
var _scroll: ScrollContainer
var preparacion := "guardar"
var _preparacion: OptionButton
var _lbl_preparacion: Label
var _lbl_aclaracion: Label
const PREPARACIONES := {
	"guardar": {"nombre": "Elegir mejoras después", "detalle": "Conservás toda la jalea para decidir en el árbol de la reina.", "objetivos": {}},
	"madera": {"nombre": "Memoria de la madera", "detalle": "La colonia nueva nace pudiendo devorar muebles. No necesitás volver a comprar esa dieta.", "objetivos": {"herencia_madera": 1}},
	"cuadrilla": {"nombre": "Cuadrilla para la casa", "detalle": "Memoria de la madera, cuatro obreras más y un nivel de daño permanente.", "objetivos": {"herencia_madera": 1, "obreras_reales": 1, "jalea_dano": 1}},
}


func _ready() -> void:
	titulo(tr("Fundar una nueva colonia"))
	ancho(720)
	# La confirmación y el cierre quedan accesibles incluso en una ventana baja.
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.custom_minimum_size = Vector2(660, clampf(get_viewport_rect().size.y - 240, 280, 680))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	contenido.add_child(scroll)
	var cuerpo := VBoxContainer.new()
	cuerpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 12)
	scroll.add_child(cuerpo)
	var detalle := Juego.detalle_fundar()
	var lineas := PackedStringArray()
	lineas.append(tr("Ganás %d de jalea real (bonus pasivo: +%d%% → +%d%%).") % [detalle.total, roundi(Juego.legado * Juego.BONUS_LEGADO * 100), roundi((Juego.legado + detalle.total) * Juego.BONUS_LEGADO * 100)])
	var conserva := 10 * Juego.nivel_jalea("despensa")
	lineas.append(tr("Se reinician: migas%s, mejoras y castas%s.") % [
		tr(" (conservás el %d%%)") % conserva if conserva > 0 else "",
		tr(" (conservás el %d%%)") % (25 * Juego.nivel_jalea("linaje")) if Juego.nivel_jalea("linaje") > 0 else ""])
	lineas.append(tr("Volvés a la casa. Los viajes se desbloquean otra vez al conquistar cada destino."))
	lineas.append(tr("Se conservan: destinos visitados, hitos, el árbol de la reina y lo descubierto."))
	lineas.append(tr("Cada gran objetivo vuelve a dar sus coronas una vez."))
	lineas.append(tr("También conservás adaptaciones de viaje, récords y evoluciones."))
	lineas.append(Juego.oportunidades_jalea())
	var texto := Estilo.etiqueta("\n".join(lineas), 15, Estilo.TEXTO)
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size.x = 660
	cuerpo.add_child(texto)
	var inicio := PanelContainer.new()
	inicio.add_theme_stylebox_override("panel", Estilo.caja(Color("2b3528"), 12, Color("718459"), 1, 14))
	cuerpo.add_child(inicio)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 6)
	inicio.add_child(columna)
	columna.add_child(Estilo.etiqueta(tr("ASÍ NACE TU PRÓXIMA COLONIA"), 12, Estilo.VERDE))
	_lbl_inicio = Estilo.etiqueta("", 15)
	_lbl_inicio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_lbl_inicio)
	var aclaracion := Estilo.etiqueta(tr("Con tus mejoras permanentes actuales y el decreto elegido, antes de gastar la nueva jalea."), 12, Estilo.TEXTO_SUAVE)
	_lbl_aclaracion = aclaracion
	aclaracion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(aclaracion)
	cuerpo.add_child(Estilo.etiqueta(tr("PREPARÁ EL REGRESO A CASA"), 12, Color("c9b779")))
	_preparacion = OptionButton.new()
	for datos in PREPARACIONES.values():
		_preparacion.add_item(tr(datos.nombre))
	_preparacion.item_selected.connect(func(indice: int) -> void:
		preparacion = PREPARACIONES.keys()[indice]
		elegir(elegido))
	cuerpo.add_child(_preparacion)
	_lbl_preparacion = Estilo.etiqueta("", 13, Estilo.TEXTO_SUAVE)
	_lbl_preparacion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cuerpo.add_child(_lbl_preparacion)
	cuerpo.add_child(Estilo.etiqueta(tr("EL DECRETO DE LA COLONIA NUEVA"), 12, Color("c9b779")))
	var ayuda := Estilo.etiqueta(tr("Rige toda la colonia, hasta la próxima fundación. Cada uno sirve para otra cosa."), 13, Estilo.TEXTO_SUAVE)
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cuerpo.add_child(ayuda)
	var grilla := GridContainer.new()
	grilla.columns = 2
	grilla.add_theme_constant_override("h_separation", 10)
	grilla.add_theme_constant_override("v_separation", 10)
	cuerpo.add_child(grilla)
	for d in Juego.decretos:
		grilla.add_child(_tarjeta(d))
	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_END
	botones.add_theme_constant_override("separation", 10)
	contenido.add_child(botones)
	var seguir := Estilo.boton(tr("Seguir creciendo"), 16, Color("262e25"), Color("4b5945"))
	seguir.pressed.connect(cerrar)
	botones.add_child(seguir)
	_boton_fundar = Estilo.boton(tr("Fundar la nueva colonia"), 16, Color("56613e"), Color("bbcb8a"))
	_boton_fundar.pressed.connect(fundar)
	botones.add_child(_boton_fundar)
	# Por defecto, el mismo decreto que la colonia actual (o el primero).
	elegir(Juego.decreto if Juego.decretos_por_id.has(Juego.decreto) else Juego.decretos[0].id)
	get_viewport().size_changed.connect(_ajustar_alto)


func _ajustar_alto() -> void:
	_scroll.custom_minimum_size.y = clampf(get_viewport_rect().size.y - 240, 280, 680)


func _tarjeta(d: Dictionary) -> Control:
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(320, 86)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.pressed.connect(elegir.bind(d.id))
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 12)
	boton.add_child(margen)
	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.add_child(columna)
	columna.add_child(Estilo.etiqueta(tr(d.nombre), 16, Estilo.TEXTO))
	var descripcion := Estilo.etiqueta(tr(d.descripcion), 12, Estilo.TEXTO_SUAVE)
	descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(descripcion)
	_tarjetas[d.id] = boton
	return boton


func elegir(id: String) -> void:
	elegido = id
	for clave in _tarjetas:
		var activo: bool = clave == id
		var color := Color("f0d277")
		var fondo := Color("3a3a26") if activo else Color("232822")
		_tarjetas[clave].add_theme_stylebox_override("normal", Estilo.caja(fondo, 12, Color(color, 0.9 if activo else 0.15), 2 if activo else 1, 0))
		_tarjetas[clave].add_theme_stylebox_override("hover", Estilo.caja(fondo.lightened(0.05), 12, color, 1, 0))
		_tarjetas[clave].add_theme_stylebox_override("pressed", Estilo.caja(fondo, 12, color, 2, 0))
	var compras := compras_preparacion()
	var previa := Juego.vista_previa_fundar(id, compras)
	var plan: Dictionary = PREPARACIONES[preparacion]
	_lbl_preparacion.text = tr(plan.detalle)
	if preparacion == "guardar" and Juego.fundaciones == 0 and Juego.nivel_jalea("herencia_madera") == 0:
		_lbl_preparacion.text += "\n" + tr("Para tu primer regreso, Memoria de la madera permite empezar directamente con muebles.")
	if compras.is_empty() and preparacion != "guardar":
		_lbl_preparacion.text += "\n" + tr("Ya tenés todas las mejoras de esta preparación. No se cobra nada.")
	elif previa.plan_valido and not compras.is_empty():
		var nombres := PackedStringArray()
		for compra in previa.compras:
			nombres.append(tr(Juego.jalea_por_id[compra.id].nombre))
		_lbl_preparacion.text += "\n" + tr("Al confirmar se compran: %s. Costo total: %d de jalea; quedan %d.") % [", ".join(nombres), previa.costo_jalea, previa.jalea]
	elif not previa.plan_valido:
		_lbl_preparacion.text += "\n" + tr("No alcanza la jalea para esta preparación completa. Elegí otra opción o conservá la jalea.")
	_lbl_aclaracion.text = tr("Incluye el decreto y las compras de preparación elegidas. No se compra nada hasta confirmar.") if not compras.is_empty() and previa.plan_valido else tr("Con tus mejoras permanentes actuales y el decreto elegido, antes de gastar la nueva jalea.")
	_boton_fundar.disabled = not Juego.puede_fundar() or not previa.plan_valido
	_boton_fundar.text = tr("Fundar y comprar preparación") if not compras.is_empty() else tr("Fundar la nueva colonia")
	var especialistas := 0
	for cantidad in previa.castas.values():
		especialistas += int(cantidad)
	_lbl_inicio.text = tr("%d obreras · %d especialistas · %d s por expedición\nDieta inicial: %s\nMordida: %s · Migas: ×%.2f\nReservas: %s migas · Jalea disponible: %d") % [
		int(previa.stats.hormigas_iniciales), especialistas, int(previa.stats.duracion_run),
		tr(MaterialesCasa.NIVELES[clampi(int(previa.stats.materiales), 0, 3)]),
		Juego.formatear_corto(previa.stats.dano), previa.stats.multiplicador_migas, Juego.formatear_corto(previa.migas), previa.jalea]


## Los planes alcanzan niveles mínimos: no vuelven a cobrar una memoria ni
## agregan niveles sin mostrarlos. La compra real usa la misma cotización.
func compras_preparacion() -> Array[String]:
	var compras: Array[String] = []
	for id in PREPARACIONES[preparacion].objetivos:
		for nivel in range(Juego.nivel_jalea(id), int(PREPARACIONES[preparacion].objetivos[id])):
			compras.append(id)
	return compras


func elegir_preparacion(id: String) -> void:
	if not PREPARACIONES.has(id):
		return
	preparacion = id
	_preparacion.select(PREPARACIONES.keys().find(id))
	elegir(elegido)


func fundar() -> void:
	if Juego.fundar_colonia(elegido, compras_preparacion()):
		Sonido.tocar("crecer", 1.0, 0.0)
		fundada.emit()
		cerrar()
	else:
		elegir(elegido)
