class_name VentanaModal
extends Control
## Ventana sobre lo que haya abajo (menú, tienda o la run en pausa): fondo
## oscurecido, panel centrado con título y botón de cerrar. Esc la cierra.
## Funciona con el juego en pausa. Las subclases llenan `contenido`.

signal cerrada

var contenido: VBoxContainer
var _titulo: Label
var _panel: PanelContainer


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fondo := ColorRect.new()
	fondo.color = Color(0.04, 0.05, 0.04, 0.78)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", Estilo.caja(Color("1d241e"), 18, Color("58664b"), 1, 24))
	centro.add_child(_panel)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 16)
	_panel.add_child(columna)
	var cabecera := HBoxContainer.new()
	columna.add_child(cabecera)
	_titulo = Estilo.etiqueta("", 26, Estilo.TEXTO)
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(_titulo)
	var cerrar_boton := Estilo.boton("✕", 16, Color("2a3329"), Color("52634a"))
	cerrar_boton.custom_minimum_size = Vector2(44, 40)
	cerrar_boton.pressed.connect(cerrar)
	cabecera.add_child(cerrar_boton)
	contenido = VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 12)
	columna.add_child(contenido)


func titulo(texto: String) -> void:
	_titulo.text = texto


func ancho(minimo: float) -> void:
	_panel.custom_minimum_size.x = minimo


func cerrar() -> void:
	Sonido.tocar("clic", 0.8)
	cerrada.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla and tecla.pressed and not tecla.echo and tecla.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cerrar()
