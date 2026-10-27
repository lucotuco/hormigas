extends Control
## Tienda entre runs: el árbol de mejoras, armado como cámaras del hormiguero
## conectadas por túneles. Cada columna es una "rama" de datos/mejoras.csv.
## Las mejoras bloqueadas se ven en sombra para que el jugador sepa que existen.

const ESCENA_RUN := "res://mundo/run.tscn"
const TAMANO_TARJETA := Vector2(196, 128)

const COLOR_DISPONIBLE := Color(0.42, 0.29, 0.17)
const COLOR_CARA := Color(0.27, 0.19, 0.13)
const COLOR_BLOQUEADA := Color(0.12, 0.085, 0.06)
const COLOR_MAXIMA := Color(0.24, 0.33, 0.18)

var _tarjetas: Dictionary = {}   # id -> {boton, nombre, nivel, descripcion, costo}
var _lbl_migas: Label
var _lbl_proxima: Label
var _boton_run: Button
var _migas_mostradas := 0.0


class FondoTierra extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Estilo.TIERRA_OSCURA)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 900:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			var c := Estilo.TIERRA if rng.randf() < 0.7 else Estilo.TIERRA_CLARA
			draw_circle(p, rng.randf_range(0.8, 2.6), Color(c, rng.randf_range(0.3, 0.8)))


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fondo := FondoTierra.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.resized.connect(fondo.queue_redraw)
	add_child(fondo)

	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 24)
	add_child(margen)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 16)
	margen.add_child(columna)

	columna.add_child(_crear_encabezado())
	columna.add_child(_crear_arbol())
	if OS.is_debug_build():
		var ayuda := Estilo.etiqueta("Desarrollo  —  F1: +1000 migas  ·  F2: migas x10  ·  F9: borrar partida  ·  M: silenciar", 13, Estilo.TEXTO_SUAVE)
		ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		columna.add_child(ayuda)

	Juego.migas_cambiaron.connect(_on_migas_cambiaron)
	Juego.partida_borrada.connect(_refrescar)
	_migas_mostradas = Juego.migas
	_refrescar()
	_boton_run.grab_focus()


func _process(delta: float) -> void:
	_migas_mostradas = lerpf(_migas_mostradas, Juego.migas, 1.0 - exp(-10.0 * delta))
	if absf(Juego.migas - _migas_mostradas) < 0.5:
		_migas_mostradas = Juego.migas
	_lbl_migas.text = Juego.formatear(_migas_mostradas)


func _crear_encabezado() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 18)
	var titulos := VBoxContainer.new()
	titulos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulos.add_child(Estilo.etiqueta("El hormiguero", 36, Estilo.ACENTO, 5))
	_lbl_proxima = Estilo.etiqueta("", 15, Estilo.TEXTO_SUAVE)
	titulos.add_child(_lbl_proxima)
	fila.add_child(titulos)

	var caja := PanelContainer.new()
	caja.add_theme_stylebox_override("panel", Estilo.caja(Estilo.PANEL, 12, Color(1, 1, 1, 0.08), 1, 14))
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 0)
	columna.add_child(Estilo.etiqueta("MIGAS", 11, Estilo.TEXTO_SUAVE))
	_lbl_migas = Estilo.etiqueta("0", 30, Estilo.ACENTO, 4)
	columna.add_child(_lbl_migas)
	caja.add_child(columna)
	caja.custom_minimum_size = Vector2(170, 0)
	fila.add_child(caja)

	_boton_run = Estilo.boton("¡Nueva run!  ▸", 24, Color(0.45, 0.3, 0.12), Estilo.ACENTO)
	_boton_run.custom_minimum_size = Vector2(220, 0)
	_boton_run.pressed.connect(_nueva_run)
	fila.add_child(_boton_run)
	return fila


func _crear_arbol() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var centro := CenterContainer.new()
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(centro)
	var columnas := HBoxContainer.new()
	columnas.add_theme_constant_override("separation", 10)
	centro.add_child(columnas)
	for rama in Juego.ramas:
		var columna := VBoxContainer.new()
		columna.add_theme_constant_override("separation", 0)
		var titulo := Estilo.etiqueta(rama.to_upper(), 15, Estilo.ACENTO.darkened(0.1), 3)
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		titulo.custom_minimum_size = Vector2(0, 30)
		columna.add_child(titulo)
		var primera := true
		for m in Juego.mejoras:
			if m.rama != rama:
				continue
			if not primera:
				columna.add_child(_crear_tunel())
			primera = false
			columna.add_child(_crear_tarjeta(m))
		columnas.add_child(columna)
	return scroll


func _crear_tunel() -> Control:
	var centro := CenterContainer.new()
	var tunel := ColorRect.new()
	tunel.color = Color(0.06, 0.04, 0.025)
	tunel.custom_minimum_size = Vector2(14, 18)
	tunel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(tunel)
	return centro


func _crear_tarjeta(m: Dictionary) -> Control:
	var boton := Button.new()
	boton.custom_minimum_size = TAMANO_TARJETA
	boton.focus_mode = Control.FOCUS_NONE
	boton.pressed.connect(_comprar.bind(m.id))

	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lado in ["left", "right"]:
		margen.add_theme_constant_override("margin_" + lado, 14)
	for lado in ["top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 10)
	boton.add_child(margen)
	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_theme_constant_override("separation", 2)
	margen.add_child(columna)

	var nombre := Estilo.etiqueta("", 15, Estilo.TEXTO, 3)
	nombre.clip_text = true
	columna.add_child(nombre)

	var descripcion := Estilo.etiqueta("", 12, Estilo.TEXTO_SUAVE)
	descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	descripcion.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(descripcion)

	var pie := HBoxContainer.new()
	pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nivel := Estilo.etiqueta("", 13, Estilo.TEXTO_SUAVE)
	nivel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nivel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var costo := Estilo.etiqueta("", 15, Estilo.ACENTO, 3)
	costo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pie.add_child(nivel)
	pie.add_child(costo)
	columna.add_child(pie)

	_tarjetas[m.id] = {"boton": boton, "nombre": nombre, "nivel": nivel, "descripcion": descripcion, "costo": costo}
	return boton


func _on_migas_cambiaron(_total: float) -> void:
	_refrescar()


func _refrescar() -> void:
	for id in _tarjetas:
		_actualizar_tarjeta(id)
	_lbl_proxima.text = "Próxima run:  %d hormigas  ·  %d s  ·  daño %s  ·  territorio %d px" % [
		int(Juego.stat("hormigas_iniciales")), int(Juego.stat("duracion_run")),
		Juego.formatear_corto(Juego.stat("dano")), int(Juego.stat("radio_territorio"))]


func _actualizar_tarjeta(id: String) -> void:
	var t: Dictionary = _tarjetas[id]
	var m: Dictionary = Juego.mejoras_por_id[id]
	var boton: Button = t.boton
	var fondo: Color
	var borde: Color
	if not Juego.esta_desbloqueada(id):
		var requisito: Dictionary = Juego.mejoras_por_id[m.requiere_id]
		var nombre_requisito: String = requisito.nombre if Juego.esta_desbloqueada(requisito.id) else "???"
		t.nombre.text = "???"
		t.nivel.text = ""
		t.descripcion.text = "Requiere %s nivel %d" % [nombre_requisito, m.requiere_nivel]
		t.costo.text = ""
		fondo = COLOR_BLOQUEADA
		borde = Color(1, 1, 1, 0.05)
	else:
		t.nombre.text = m.nombre
		t.nivel.text = "Nv %d/%d" % [Juego.nivel_de(id), m.nivel_max]
		t.descripcion.text = m.descripcion
		if Juego.esta_al_maximo(id):
			t.costo.text = "MÁXIMO"
			t.costo.label_settings.font_color = Estilo.VERDE
			fondo = COLOR_MAXIMA
			borde = Estilo.VERDE.darkened(0.3)
		elif Juego.puede_comprar(id):
			t.costo.text = "%s migas" % Juego.formatear(Juego.costo(id))
			t.costo.label_settings.font_color = Estilo.ACENTO
			fondo = COLOR_DISPONIBLE
			borde = Estilo.ACENTO
		else:
			t.costo.text = "%s migas" % Juego.formatear(Juego.costo(id))
			t.costo.label_settings.font_color = Estilo.ROJO.lightened(0.2)
			fondo = COLOR_CARA
			borde = Color(1, 1, 1, 0.1)
	boton.add_theme_stylebox_override("normal", Estilo.caja(fondo, 18, borde, 2, 0))
	boton.add_theme_stylebox_override("hover", Estilo.caja(fondo.lightened(0.1), 18, borde.lightened(0.2), 2, 0))
	boton.add_theme_stylebox_override("pressed", Estilo.caja(fondo.darkened(0.1), 18, borde, 2, 0))
	boton.add_theme_stylebox_override("disabled", Estilo.caja(fondo, 18, borde, 2, 0))


func _comprar(id: String) -> void:
	var boton: Button = _tarjetas[id].boton
	boton.pivot_offset = boton.size / 2.0
	if Juego.comprar(id):
		Sonido.tocar("comprar", 1.0 + minf(Juego.nivel_de(id), 20) * 0.03, 0.0)
		boton.scale = Vector2.ONE * 1.08
		var tween := boton.create_tween()
		tween.tween_property(boton, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		Sonido.tocar("no")
		var tween := boton.create_tween()
		for i in 3:
			tween.tween_property(boton, "rotation", 0.03, 0.04)
			tween.tween_property(boton, "rotation", -0.03, 0.04)
		tween.tween_property(boton, "rotation", 0.0, 0.04)


func _nueva_run() -> void:
	get_tree().change_scene_to_file(ESCENA_RUN)
