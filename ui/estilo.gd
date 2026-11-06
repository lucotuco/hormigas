class_name Estilo
extends RefCounted
## Colores y helpers de interfaz compartidos por el HUD y la tienda.
## Cambiar algo acá cambia el look de toda la interfaz.

const TEXTO := Color("f1eee4")
const TEXTO_SUAVE := Color("bcc4b5")
const ACENTO := Color("ebc67d")
const VERDE := Color("a8c88c")
const ROJO := Color(0.95, 0.38, 0.28)
const PANEL := Color("202a24f5")
const BORDE_PANEL := Color("81937c42")
const TIERRA := Color(0.23, 0.16, 0.11)
const TIERRA_CLARA := Color(0.36, 0.25, 0.17)
const TIERRA_OSCURA := Color(0.13, 0.09, 0.06)


static func caja(fondo: Color, radio := 10, borde := Color.TRANSPARENT, ancho_borde := 0, margen := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.set_corner_radius_all(radio)
	s.border_color = borde
	s.set_border_width_all(ancho_borde)
	s.set_content_margin_all(margen)
	s.anti_aliasing = true
	return s


static func ajustes_texto(tamano: int, color := TEXTO, contorno := 0) -> LabelSettings:
	var ajustes := LabelSettings.new()
	ajustes.font_size = tamano
	ajustes.font_color = color
	if contorno > 0:
		ajustes.outline_size = mini(contorno, 2)
		ajustes.outline_color = Color(0.08, 0.10, 0.08, 0.9)
	return ajustes


## Placas compartidas de lectura: una superficie y un borde fino, sin
## transparencias que vuelvan a mezclar las letras con el piso del mapa.
static func panel(margen := 12, radio := 12) -> StyleBoxFlat:
	return caja(PANEL, radio, BORDE_PANEL, 1, margen)


static func etiqueta(contenido: String, tamano: int, color := TEXTO, contorno := 0) -> Label:
	var l := Label.new()
	l.text = contenido
	l.label_settings = ajustes_texto(tamano, color, contorno)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func boton(contenido: String, tamano: int, fondo: Color, borde: Color) -> Button:
	var b := Button.new()
	b.text = contenido
	b.add_theme_font_size_override("font_size", tamano)
	b.add_theme_color_override("font_color", TEXTO)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", TEXTO_SUAVE.darkened(0.18))
	b.add_theme_stylebox_override("normal", caja(fondo, 9, Color(borde, 0.6), 1, 14))
	b.add_theme_stylebox_override("hover", caja(fondo.lightened(0.10), 9, borde.lightened(0.12), 1, 14))
	b.add_theme_stylebox_override("pressed", caja(fondo.lightened(0.13), 9, borde.lightened(0.2), 1, 14))
	b.add_theme_stylebox_override("hover_pressed", caja(fondo.lightened(0.18), 9, borde.lightened(0.25), 1, 14))
	b.add_theme_stylebox_override("disabled", caja(fondo.darkened(0.14), 9, Color(borde, 0.22), 1, 14))
	b.add_theme_stylebox_override("focus", caja(Color.TRANSPARENT, 9, Color(TEXTO, 0.72), 1, 14))
	return b
