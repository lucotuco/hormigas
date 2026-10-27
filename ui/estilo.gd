class_name Estilo
extends RefCounted
## Colores y helpers de interfaz compartidos por el HUD y la tienda.
## Cambiar algo acá cambia el look de toda la interfaz.

const TEXTO := Color(0.98, 0.94, 0.86)
const TEXTO_SUAVE := Color(0.98, 0.94, 0.86, 0.6)
const ACENTO := Color(1.0, 0.82, 0.35)
const VERDE := Color(0.55, 0.88, 0.45)
const ROJO := Color(0.95, 0.38, 0.28)
const PANEL := Color(0.1, 0.065, 0.04, 0.85)
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
		ajustes.outline_size = contorno
		ajustes.outline_color = Color(0.08, 0.05, 0.03)
	return ajustes


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
	b.add_theme_stylebox_override("normal", caja(fondo, 10, borde, 2, 14))
	b.add_theme_stylebox_override("hover", caja(fondo.lightened(0.12), 10, borde.lightened(0.2), 2, 14))
	b.add_theme_stylebox_override("pressed", caja(fondo.darkened(0.15), 10, borde, 2, 14))
	b.add_theme_stylebox_override("focus", caja(Color.TRANSPARENT, 10, Color(1, 1, 1, 0.5), 2, 14))
	return b
