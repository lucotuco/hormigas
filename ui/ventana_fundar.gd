class_name VentanaFundar
extends VentanaModal
## Confirmación de fundar: qué se gana, qué se reinicia y qué se conserva, y
## la elección del decreto que va a regir la colonia nueva.

signal fundada

var elegido := ""
var _tarjetas: Dictionary = {}
var _boton_fundar: Button


func _ready() -> void:
	titulo(tr("Fundar una nueva colonia"))
	ancho(720)
	var detalle := Juego.detalle_fundar()
	var lineas := PackedStringArray()
	lineas.append(tr("Ganás %d de jalea real (bonus pasivo: +%d%% → +%d%%).") % [detalle.total, roundi(Juego.legado * Juego.BONUS_LEGADO * 100), roundi((Juego.legado + detalle.total) * Juego.BONUS_LEGADO * 100)])
	var conserva := 10 * Juego.nivel_jalea("despensa")
	lineas.append(tr("Se reinician: migas%s, mejoras y castas%s.") % [
		tr(" (conservás el %d%%)") % conserva if conserva > 0 else "",
		tr(" (conservás el %d%%)") % (25 * Juego.nivel_jalea("linaje")) if Juego.nivel_jalea("linaje") > 0 else ""])
	lineas.append(tr("Se conservan: destinos, hitos, el árbol de la reina y lo descubierto."))
	lineas.append(tr("Cada gran objetivo vuelve a dar sus coronas una vez."))
	var texto := Estilo.etiqueta("\n".join(lineas), 15, Estilo.TEXTO)
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size.x = 660
	contenido.add_child(texto)
	contenido.add_child(Estilo.etiqueta(tr("EL DECRETO DE LA COLONIA NUEVA"), 12, Color("c9b779")))
	var ayuda := Estilo.etiqueta(tr("Rige toda la colonia, hasta la próxima fundación. Cada uno sirve para otra cosa."), 13, Estilo.TEXTO_SUAVE)
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenido.add_child(ayuda)
	var grilla := GridContainer.new()
	grilla.columns = 2
	grilla.add_theme_constant_override("h_separation", 10)
	grilla.add_theme_constant_override("v_separation", 10)
	contenido.add_child(grilla)
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


func fundar() -> void:
	if Juego.fundar_colonia(elegido):
		Sonido.tocar("crecer", 1.0, 0.0)
		fundada.emit()
	cerrar()
