class_name HUD
extends CanvasLayer
## Interfaz durante la run: migas, tiempo, hormigas, combo, avisos y el panel
## de fin de run. Se arma por código para no tener que tocar la escena.

const MAX_MIGAS_VOLANDO := 40
const DURACION_COMBO_VISIBLE := 1.2
const RUNS_CON_AYUDA := 3

@onready var run: Run = get_parent()

var _lbl_migas: Label
var _caja_migas: PanelContainer
var _barra_tiempo: ProgressBar
var _relleno_tiempo: StyleBoxFlat
var _lbl_tiempo: Label
var _lbl_hormigas: Label
var _lbl_combo: Label
var _lbl_aviso: Label
var _lbl_ayuda: Label
var _panel_fin: PanelContainer
var _lbl_fin_migas: Label
var _lbl_fin_detalle: Label
var _lbl_fin_record: Label
var _boton_tienda: Button
var _reloj_descubrimiento := 0.0
var _lbl_composicion: Label

var _migas_mostradas := 0.0
var _volando := 0
var _tiempo_combo := -100.0
var _reloj := 0.0
var _tween_pulso: Tween


class IconoMiga extends Control:
	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c + Vector2(-3, 2), 6.0, Color(0.85, 0.66, 0.4))
		draw_circle(c + Vector2(4, -1), 5.0, Color(0.92, 0.75, 0.48))
		draw_circle(c + Vector2(0, -5), 3.5, Color(0.8, 0.6, 0.36))


func _ready() -> void:
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)
	_crear_migas(raiz)
	_crear_tiempo(raiz)
	_crear_hormigas(raiz)
	_crear_avisos(raiz)
	_crear_panel_fin(raiz)


func _process(delta: float) -> void:
	_reloj += delta
	# Contador de migas que "corre" hacia el valor real.
	var real := Juego.migas_run
	_migas_mostradas = lerpf(_migas_mostradas, real, 1.0 - exp(-10.0 * delta))
	if absf(real - _migas_mostradas) < 0.5:
		_migas_mostradas = real
	_lbl_migas.text = Juego.formatear(_migas_mostradas)

	var restante := run.tiempo_restante
	_lbl_tiempo.text = "%d s" % int(ceil(restante))
	_barra_tiempo.value = restante / maxf(run.duracion_total, 0.01) * 100.0
	if restante <= 5.0 and run.activa:
		var parpadeo := 0.5 + 0.5 * sin(_reloj * 14.0)
		_relleno_tiempo.bg_color = Estilo.ROJO.lerp(Color.WHITE, parpadeo * 0.3)
		_lbl_tiempo.label_settings.font_color = Estilo.ROJO.lerp(Estilo.TEXTO, parpadeo * 0.5)
	else:
		_relleno_tiempo.bg_color = Estilo.VERDE
		_lbl_tiempo.label_settings.font_color = Estilo.TEXTO

	_lbl_hormigas.text = "Hormigas: %d" % run.colonia.cantidad()
	_reloj_descubrimiento -= delta
	if _reloj_descubrimiento <= 0:
		_reloj_descubrimiento = 0.5
		var conteo := run.colonia.conteo_castas()
		var lineas := PackedStringArray()
		var grupo := PackedStringArray()
		var nombres := {"obrera": "Obreras", "reina": "Reinas", "roja": "Rojas", "voladora": "Voladoras", "veloz": "Veloces", "cargadora": "Cargadoras", "mini": "Minis"}
		for tipo in nombres:
			if conteo.has(tipo):
				grupo.append("%s %d" % [nombres[tipo], conteo[tipo]])
				if grupo.size() == 3:
					lineas.append(" · ".join(grupo))
					grupo.clear()
		if not grupo.is_empty():
			lineas.append(" · ".join(grupo))
		_lbl_composicion.text = "\n".join(lineas)

	if _lbl_combo.visible and _reloj - _tiempo_combo > DURACION_COMBO_VISIBLE:
		_lbl_combo.modulate.a = move_toward(_lbl_combo.modulate.a, 0.0, delta * 3.0)
		if _lbl_combo.modulate.a <= 0.0:
			_lbl_combo.visible = false


# =====================================================================
# API que usa la run
# =====================================================================

## Migas que salen volando desde un punto de la pantalla hasta el contador.
func migas_voladoras(desde: Vector2, cantidad: int) -> void:
	var destino := _caja_migas.global_position + Vector2(36, _caja_migas.size.y * 0.62)
	for i in cantidad:
		if _volando >= MAX_MIGAS_VOLANDO:
			return
		_volando += 1
		var miga := Panel.new()
		miga.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lado := randf_range(5.0, 9.0)
		miga.size = Vector2(lado, lado)
		miga.add_theme_stylebox_override("panel", Estilo.caja(Color(0.92, 0.74, 0.45).lightened(randf() * 0.2), int(lado / 2), Color(0.3, 0.18, 0.08), 1, 0))
		miga.position = desde + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		add_child(miga)
		var origen := miga.position
		var control := origen.lerp(destino, 0.3) + Vector2(randf_range(-120, 120), randf_range(-160, -40))
		var duracion := randf_range(0.45, 0.75)
		# Curva de Bézier: sale hacia un costado y cae en el contador.
		var mover := func(t: float) -> void:
			miga.position = origen.lerp(control, t).lerp(control.lerp(destino, t), t)
		var tween := miga.create_tween()
		tween.tween_interval(randf() * 0.12)
		tween.tween_method(mover, 0.0, 1.0, duracion).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(_miga_llego.bind(miga))


func mostrar_combo(combo: int) -> void:
	if combo < 3:
		return
	_tiempo_combo = _reloj
	_lbl_combo.text = "COMBO x%d" % combo
	_lbl_combo.visible = true
	_lbl_combo.modulate.a = 1.0
	_lbl_combo.pivot_offset = Vector2(0.0, _lbl_combo.size.y / 2.0)
	_lbl_combo.scale = Vector2.ONE * (1.0 + minf(combo, 50) * 0.008 + 0.25)
	var tween := _lbl_combo.create_tween()
	tween.tween_property(_lbl_combo, "scale", Vector2.ONE * (1.0 + minf(combo, 50) * 0.008), 0.15)


func mostrar_aviso(texto: String) -> void:
	_lbl_aviso.text = texto
	_lbl_aviso.visible = true
	_lbl_aviso.modulate.a = 0.0
	_lbl_aviso.pivot_offset = _lbl_aviso.size / 2.0
	_lbl_aviso.scale = Vector2.ONE * 0.7
	var tween := _lbl_aviso.create_tween().set_parallel(true)
	tween.tween_property(_lbl_aviso, "modulate:a", 1.0, 0.25)
	tween.tween_property(_lbl_aviso, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(1.4)
	tween.chain().tween_property(_lbl_aviso, "modulate:a", 0.0, 0.5)


func mostrar_fin() -> void:
	_lbl_fin_migas.text = "+%s migas" % Juego.formatear(Juego.migas_run)
	_lbl_fin_detalle.text = "Comidas destruidas: %d\nMejor combo: x%d\nTotal en el hormiguero: %s" % [
		Juego.comidas_destruidas_run, Juego.mejor_combo_run, Juego.formatear(Juego.migas)]
	_lbl_fin_record.visible = Juego.ultima_run_fue_record
	_lbl_ayuda.visible = false
	_panel_fin.visible = true
	_panel_fin.modulate.a = 0.0
	await get_tree().process_frame  # esperar a que se calcule el tamaño
	_panel_fin.pivot_offset = _panel_fin.size / 2.0
	_panel_fin.scale = Vector2.ONE * 0.85
	var tween := _panel_fin.create_tween().set_parallel(true)
	tween.tween_property(_panel_fin, "modulate:a", 1.0, 0.2)
	tween.tween_property(_panel_fin, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_boton_tienda.grab_focus()


# =====================================================================
# Construcción de la interfaz
# =====================================================================

func _crear_migas(raiz: Control) -> void:
	_caja_migas = PanelContainer.new()
	_caja_migas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja_migas.add_theme_stylebox_override("panel", Estilo.caja(Estilo.PANEL, 12, Color(1, 1, 1, 0.08), 1, 12))
	_caja_migas.position = Vector2(16, 16)
	_caja_migas.custom_minimum_size = Vector2(190, 0)
	raiz.add_child(_caja_migas)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 0)
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja_migas.add_child(columna)
	columna.add_child(Estilo.etiqueta("MIGAS DE ESTA RUN", 11, Estilo.TEXTO_SUAVE))
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(fila)
	var icono := IconoMiga.new()
	icono.custom_minimum_size = Vector2(28, 28)
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(icono)
	_lbl_migas = Estilo.etiqueta("0", 32, Estilo.ACENTO, 4)
	fila.add_child(_lbl_migas)

	_lbl_combo = Estilo.etiqueta("", 24, Estilo.ACENTO, 6)
	_lbl_combo.position = Vector2(24, 104)
	_lbl_combo.visible = false
	raiz.add_child(_lbl_combo)


func _crear_tiempo(raiz: Control) -> void:
	var caja := VBoxContainer.new()
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.set_anchors_preset(Control.PRESET_CENTER_TOP)
	caja.custom_minimum_size = Vector2(380, 0)
	caja.position = Vector2(-190, 14)
	caja.add_theme_constant_override("separation", 4)
	raiz.add_child(caja)
	_lbl_tiempo = Estilo.etiqueta("%d s" % int(Juego.stat("duracion_run")), 22, Estilo.TEXTO, 5)
	_lbl_tiempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(_lbl_tiempo)
	_barra_tiempo = ProgressBar.new()
	_barra_tiempo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra_tiempo.show_percentage = false
	_barra_tiempo.custom_minimum_size = Vector2(380, 12)
	_barra_tiempo.value = 100.0
	_barra_tiempo.add_theme_stylebox_override("background", Estilo.caja(Color(0, 0, 0, 0.5), 6, Color(1, 1, 1, 0.1), 1, 0))
	_relleno_tiempo = Estilo.caja(Estilo.VERDE, 6, Color.TRANSPARENT, 0, 0)
	_barra_tiempo.add_theme_stylebox_override("fill", _relleno_tiempo)
	caja.add_child(_barra_tiempo)


func _crear_hormigas(raiz: Control) -> void:
	var caja := PanelContainer.new()
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_theme_stylebox_override("panel", Estilo.caja(Estilo.PANEL, 12, Color(1, 1, 1, 0.08), 1, 12))
	caja.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	caja.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	caja.position = Vector2(-16, 16)
	raiz.add_child(caja)
	_lbl_hormigas = Estilo.etiqueta("Hormigas: 0", 18, Estilo.TEXTO)
	caja.add_child(_lbl_hormigas)
	_lbl_composicion = Estilo.etiqueta("", 12, Estilo.TEXTO, 3)
	_lbl_composicion.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_composicion.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_lbl_composicion.position = Vector2(-356, 78)
	_lbl_composicion.custom_minimum_size.x = 340
	raiz.add_child(_lbl_composicion)


func _crear_avisos(raiz: Control) -> void:
	_lbl_aviso = Estilo.etiqueta("", 36, Estilo.ACENTO, 8)
	_lbl_aviso.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_lbl_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_aviso.custom_minimum_size = Vector2(800, 0)
	_lbl_aviso.position = Vector2(-400, 130)
	_lbl_aviso.visible = false
	raiz.add_child(_lbl_aviso)

	_lbl_ayuda = Estilo.etiqueta(
		"Mantené clic izquierdo: atraer hormigas cercanas hacia el cursor\nRueda: zoom · Botón derecho o central / WASD: mover · R: hormiguero · H: ver la casa · Esc: terminar",
		13, Estilo.TEXTO, 4)
	_lbl_ayuda.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_lbl_ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_ayuda.custom_minimum_size = Vector2(1100, 0)
	_lbl_ayuda.position = Vector2(-550, -52)
	_lbl_ayuda.visible = Juego.runs_jugadas < RUNS_CON_AYUDA
	raiz.add_child(_lbl_ayuda)
	if _lbl_ayuda.visible:
		var tween := _lbl_ayuda.create_tween()
		tween.tween_interval(12.0)
		tween.tween_property(_lbl_ayuda, "modulate:a", 0.0, 1.5)


func _crear_panel_fin(raiz: Control) -> void:
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(centro)
	_panel_fin = PanelContainer.new()
	_panel_fin.add_theme_stylebox_override("panel", Estilo.caja(Color(0.12, 0.08, 0.05, 0.96), 18, Estilo.ACENTO.darkened(0.3), 2, 28))
	_panel_fin.visible = false
	centro.add_child(_panel_fin)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 10)
	columna.custom_minimum_size = Vector2(420, 0)
	_panel_fin.add_child(columna)
	var titulo := Estilo.etiqueta("¡Se acabó el tiempo!", 30, Estilo.TEXTO, 4)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(titulo)
	_lbl_fin_record = Estilo.etiqueta("¡NUEVO RÉCORD!", 18, Estilo.VERDE, 3)
	_lbl_fin_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(_lbl_fin_record)
	_lbl_fin_migas = Estilo.etiqueta("+0 migas", 44, Estilo.ACENTO, 6)
	_lbl_fin_migas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(_lbl_fin_migas)
	_lbl_fin_detalle = Estilo.etiqueta("", 17, Estilo.TEXTO_SUAVE)
	_lbl_fin_detalle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(_lbl_fin_detalle)
	var espacio := Control.new()
	espacio.custom_minimum_size = Vector2(0, 8)
	columna.add_child(espacio)
	_boton_tienda = Estilo.boton("Mejorar el hormiguero  ▸", 22, Color(0.45, 0.3, 0.12), Estilo.ACENTO)
	_boton_tienda.pressed.connect(run.ir_a_tienda)
	columna.add_child(_boton_tienda)


func _miga_llego(miga: Control) -> void:
	_volando -= 1
	miga.queue_free()
	if _tween_pulso and _tween_pulso.is_running():
		return
	_caja_migas.pivot_offset = _caja_migas.size / 2.0
	_caja_migas.scale = Vector2.ONE * 1.06
	_tween_pulso = _caja_migas.create_tween()
	_tween_pulso.tween_property(_caja_migas, "scale", Vector2.ONE, 0.12)
