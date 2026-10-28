class_name PanelConfiguracion
extends VentanaModal
## Configuración: idioma, sonido, pantalla y comodidad (ver Ajustes), y borrar
## la partida. Se abre desde el menú, la tienda y la pausa.

## Lo emite al cambiar de idioma: la pantalla que la abrió decide si se rearma.
signal idioma_cambiado

var _confirmar_borrado: ConfirmationDialog
var _lbl_volumen: Label
var _lbl_temblor: Label


func _ready() -> void:
	titulo(tr("Configuración"))
	ancho(560)
	var idiomas := HBoxContainer.new()
	idiomas.add_theme_constant_override("separation", 8)
	for codigo in Juego.IDIOMAS:
		var nombre: String = {"es": "Español", "en": "English"}[codigo]
		var boton := Estilo.boton(nombre, 15, Color("536649") if Juego.idioma == codigo else Color("282f26"), Color("94b47e") if Juego.idioma == codigo else Color("46503f"))
		boton.name = "Idioma_" + codigo
		boton.pressed.connect(_elegir_idioma.bind(codigo))
		idiomas.add_child(boton)
	_fila(tr("Idioma"), idiomas)

	var sonido := CheckButton.new()
	sonido.name = "Sonido"
	sonido.button_pressed = Ajustes.sonido
	sonido.toggled.connect(func(valor: bool) -> void: Ajustes.cambiar("sonido", valor))
	_fila(tr("Sonido"), sonido)

	var volumen := HBoxContainer.new()
	var deslizador := HSlider.new()
	deslizador.name = "Volumen"
	deslizador.custom_minimum_size.x = 200
	deslizador.max_value = 1.0
	deslizador.step = 0.05
	deslizador.value = Ajustes.volumen
	deslizador.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	deslizador.value_changed.connect(_cambiar_volumen)
	volumen.add_child(deslizador)
	_lbl_volumen = Estilo.etiqueta("", 14, Estilo.TEXTO_SUAVE)
	_lbl_volumen.custom_minimum_size.x = 56
	volumen.add_child(_lbl_volumen)
	_fila(tr("Volumen de los efectos"), volumen)

	var pantalla := CheckButton.new()
	pantalla.name = "PantallaCompleta"
	pantalla.button_pressed = Ajustes.pantalla_completa
	pantalla.toggled.connect(func(valor: bool) -> void: Ajustes.cambiar("pantalla_completa", valor))
	_fila(tr("Pantalla completa (F11)"), pantalla)

	var temblor := HBoxContainer.new()
	var deslizador_temblor := HSlider.new()
	deslizador_temblor.name = "Temblor"
	deslizador_temblor.custom_minimum_size.x = 200
	deslizador_temblor.max_value = 1.0
	deslizador_temblor.step = 0.25
	deslizador_temblor.value = Ajustes.temblor
	deslizador_temblor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	deslizador_temblor.value_changed.connect(_cambiar_temblor)
	temblor.add_child(deslizador_temblor)
	_lbl_temblor = Estilo.etiqueta("", 14, Estilo.TEXTO_SUAVE)
	_lbl_temblor.custom_minimum_size.x = 56
	temblor.add_child(_lbl_temblor)
	_fila(tr("Temblor de cámara"), temblor)

	var foco := CheckButton.new()
	foco.name = "PausarSinFoco"
	foco.button_pressed = Ajustes.pausar_sin_foco
	foco.toggled.connect(func(valor: bool) -> void: Ajustes.cambiar("pausar_sin_foco", valor))
	_fila(tr("Pausar al cambiar de ventana"), foco)

	var separador := HSeparator.new()
	contenido.add_child(separador)
	var borrar := Estilo.boton(tr("Borrar la partida…"), 14, Color("3a2622"), Color("8a4a3c"))
	borrar.name = "Borrar"
	borrar.pressed.connect(_pedir_borrado)
	contenido.add_child(borrar)
	_confirmar_borrado = ConfirmationDialog.new()
	_confirmar_borrado.process_mode = Node.PROCESS_MODE_ALWAYS
	_confirmar_borrado.title = tr("Borrar la partida")
	_confirmar_borrado.dialog_text = tr("Se pierden las migas, las mejoras, las castas, los destinos, la jalea real y las estadísticas. La configuración se conserva. No se puede deshacer.")
	_confirmar_borrado.ok_button_text = tr("Borrar todo")
	_confirmar_borrado.cancel_button_text = tr("Cancelar")
	_confirmar_borrado.confirmed.connect(_borrar)
	add_child(_confirmar_borrado)
	_actualizar_etiquetas()


func _fila(texto: String, control: Control) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 16)
	var etiqueta := Estilo.etiqueta(texto, 16, Estilo.TEXTO)
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(etiqueta)
	fila.add_child(control)
	contenido.add_child(fila)


func _actualizar_etiquetas() -> void:
	_lbl_volumen.text = "%d%%" % roundi(Ajustes.volumen * 100)
	_lbl_temblor.text = tr("Apagado") if Ajustes.temblor <= 0.0 else "%d%%" % roundi(Ajustes.temblor * 100)


func _cambiar_volumen(valor: float) -> void:
	Ajustes.cambiar("volumen", valor)
	_actualizar_etiquetas()
	Sonido.tocar("deposito", 1.0, 0.0)


func _cambiar_temblor(valor: float) -> void:
	Ajustes.cambiar("temblor", valor)
	_actualizar_etiquetas()


func _elegir_idioma(codigo: String) -> void:
	if codigo == Juego.idioma:
		return
	Ajustes.cambiar("idioma", codigo)
	idioma_cambiado.emit()


func _pedir_borrado() -> void:
	_confirmar_borrado.popup_centered(Vector2i(560, 200))


func _borrar() -> void:
	Juego.borrar_partida()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/menu.tscn")
