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
var _lbl_etapa: Label
var _lbl_objetivo: Label
var _tiempo_inspeccion := 0.0
var _lbl_lugar: Label
var _lbl_meta: Label
var _lbl_frenesi: Label
var _barra_frenesi: ProgressBar
var _prioridades: Dictionary = {}
var _hitos_vistos := 0
var _tween_aviso: Tween
var _tween_combo: Tween
var _panel_inferior: PanelContainer
var _nodos_prioridad: Array[Control] = []
var _boton_objetivo: Button
var _columna_frenesi: VBoxContainer
var _panel_meta: PanelContainer
var _lbl_meta_titulo: Label
var _lbl_meta_nombre: Label
var _lbl_meta_progreso: Label
var _barra_meta: ProgressBar
var _relleno_meta: StyleBoxFlat
var _meta_lista := false

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
	_crear_progresion(raiz)
	_crear_proxima_meta(raiz)
	_crear_prioridades(raiz)
	_hitos_vistos = Juego.hitos.size()
	Juego.progreso_cambio.connect(_notificar_hito)
	_actualizar_revelados()
	_anunciar_novedades()


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
		if _relleno_tiempo.bg_color != Estilo.VERDE:
			_relleno_tiempo.bg_color = Estilo.VERDE
			_lbl_tiempo.label_settings.font_color = Estilo.TEXTO
	_tiempo_inspeccion -= delta
	if _tiempo_inspeccion <= 0:
		_tiempo_inspeccion = 0.12
		_lbl_etapa.text = "DIETA %d/4 · %s" % [int(Juego.stat("materiales")) + 1, MaterialesCasa.NIVELES[clampi(int(Juego.stat("materiales")), 0, 3)]]
		_lbl_lugar.text = Mundos.INFO[Juego.lugar_actual].nombre
		_actualizar_meta()
		_lbl_meta.text = ("✓ Gran objetivo completado" if run.objetivo_completado else "Gran objetivo: " + Mundos.INFO[Juego.lugar_actual].meta) + "  [G]"
		_lbl_frenesi.text = "¡FRENESÍ! %.1f s" % run.frenesi_restante if run.frenesi_restante > 0 else "Frenesí · depósitos consecutivos"
		_barra_frenesi.value = run.frenesi_restante / 6.0 * 100 if run.frenesi_restante > 0 else run.frenesi
		var c := run.comidas.comida_en(run.get_global_mouse_position(), run.radio_actual, true)
		mostrar_inspeccion(c)

	_lbl_hormigas.text = "Hormigas: %d%s" % [run.colonia.cantidad(), " · colonia llena" if run.colonia.colonia_llena() else ""]
	_reloj_descubrimiento -= delta
	if _reloj_descubrimiento <= 0:
		_reloj_descubrimiento = 0.5
		var conteo := run.colonia.conteo_castas()
		var lineas := PackedStringArray()
		var grupo := PackedStringArray()
		var nombres := {"obrera": "Obreras", "reina": "Reinas", "roja": "Rojas", "voladora": "Voladoras", "veloz": "Veloces", "cargadora": "Cargadoras", "mini": "Minis", "carpintera": "Carpinteras", "demoledora": "Demoledoras"}
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
	if _tween_combo and _tween_combo.is_running():
		_tween_combo.kill()
	_tween_combo = tween
	tween.tween_property(_lbl_combo, "scale", Vector2.ONE * (1.0 + minf(combo, 50) * 0.008), 0.15)


func mostrar_aviso(texto: String) -> void:
	if _tween_aviso and _tween_aviso.is_running():
		_tween_aviso.kill()
	_lbl_aviso.text = texto
	_lbl_aviso.visible = true
	_lbl_aviso.modulate.a = 0.0
	_lbl_aviso.pivot_offset = _lbl_aviso.size / 2.0
	_lbl_aviso.scale = Vector2.ONE * 0.7
	var tween := _lbl_aviso.create_tween().set_parallel(true)
	_tween_aviso = tween
	tween.tween_property(_lbl_aviso, "modulate:a", 1.0, 0.25)
	tween.tween_property(_lbl_aviso, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(1.4)
	tween.chain().tween_property(_lbl_aviso, "modulate:a", 0.0, 0.5)


func mostrar_fin() -> void:
	_lbl_fin_migas.text = "+%s migas" % Juego.formatear(Juego.migas_run)
	_lbl_fin_detalle.text = "Comidas: %d · Partes de la casa: %d\nMejor combo: x%d\nTotal en el hormiguero: %s" % [
		Juego.comidas_destruidas_run, Juego.partes_destruidas_run, Juego.mejor_combo_run, Juego.formatear(Juego.migas)]
	# El prestigio a la vista: cuánto daría fundar ahora (ver pestaña Jalea real).
	if Juego.revelado("legado") and Juego.puede_fundar():
		_lbl_fin_detalle.text += "\nFundar ahora daría +%d de jalea real" % Juego.jalea_por_fundar()
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
		"Clic sobre la comida: pisotón · Mantené el clic: llamar a las hormigas cercanas\nRueda: zoom · Botón derecho o central / WASD: mover · R: hormiguero · H: ver la casa · Esc: terminar",
		13, Estilo.TEXTO, 4)
	_lbl_ayuda.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_lbl_ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_ayuda.custom_minimum_size = Vector2(1100, 0)
	_lbl_ayuda.position = Vector2(-550, -106)
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

func _crear_progresion(raiz: Control) -> void:
	_lbl_etapa = Estilo.etiqueta("", 13, Color("d4ccaa"), 3)
	_lbl_etapa.position = Vector2(20, 274)
	_lbl_etapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(_lbl_etapa)
	_lbl_objetivo = Estilo.etiqueta("", 13, Estilo.TEXTO, 3)
	_lbl_objetivo.position = Vector2(20, 350)
	_lbl_objetivo.size.x = 430
	_lbl_objetivo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_objetivo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(_lbl_objetivo)
	_lbl_lugar = Estilo.etiqueta("", 14, Estilo.TEXTO, 3)
	_lbl_lugar.position = Vector2(20, 250)
	raiz.add_child(_lbl_lugar)
	_lbl_meta = Estilo.etiqueta("", 12, Color("c4cfa0"), 3)
	_lbl_meta.position = Vector2(20, 299)
	_lbl_meta.size.x = 400
	_lbl_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	raiz.add_child(_lbl_meta)

func _crear_prioridades(raiz: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_top = -64
	panel.offset_bottom = -12
	panel.add_theme_stylebox_override("panel", Estilo.caja(Color("1f2921"), 12, Color("58664b"), 1, 9))
	raiz.add_child(panel)
	_panel_inferior = panel
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	panel.add_child(fila)
	var titulo := Estilo.etiqueta("PRIORIDAD", 11, Estilo.TEXTO_SUAVE)
	fila.add_child(titulo)
	_nodos_prioridad.append(titulo)
	for id in ["automatico", "alimentos", "muebles", "estructuras"]:
		var nombres := {"automatico": "Auto", "alimentos": "Alimentos", "muebles": "Muebles", "estructuras": "Estructuras"}
		var boton := Estilo.boton(nombres[id], 13, Color("303d2b"), Color("78936a"))
		boton.toggle_mode = true
		boton.button_pressed = Juego.prioridad == id
		boton.tooltip_text = "Prioridad de búsqueda. El llamado manual siempre manda."
		boton.pressed.connect(_cambiar_prioridad.bind(id))
		fila.add_child(boton)
		_prioridades[id] = boton
		_nodos_prioridad.append(boton)
	var espacio := Control.new()
	espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(espacio)
	var objetivo := Estilo.boton("Gran objetivo [G]", 13, Color("303d2b"), Color("78936a"))
	objetivo.pressed.connect(func() -> void: run.camara.ver_objetivo())
	fila.add_child(objetivo)
	_boton_objetivo = objetivo
	var columna := VBoxContainer.new()
	columna.custom_minimum_size.x = 210
	fila.add_child(columna)
	_columna_frenesi = columna
	_lbl_frenesi = Estilo.etiqueta("", 11, Estilo.TEXTO)
	columna.add_child(_lbl_frenesi)
	_barra_frenesi = ProgressBar.new()
	_barra_frenesi.show_percentage = false
	_barra_frenesi.custom_minimum_size.y = 8
	_barra_frenesi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra_frenesi.add_theme_stylebox_override("fill", Estilo.caja(Color("d9bd72"), 4))
	_barra_frenesi.add_theme_stylebox_override("background", Estilo.caja(Color("111c15"), 4))
	columna.add_child(_barra_frenesi)

## Panel "PRÓXIMO DESBLOQUEO": la meta cercana siempre a la vista.
func _crear_proxima_meta(raiz: Control) -> void:
	_panel_meta = PanelContainer.new()
	_panel_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_meta.add_theme_stylebox_override("panel", Estilo.caja(Estilo.PANEL, 12, Color(1, 1, 1, 0.08), 1, 12))
	_panel_meta.position = Vector2(16, 140)
	_panel_meta.custom_minimum_size = Vector2(300, 0)
	raiz.add_child(_panel_meta)
	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_theme_constant_override("separation", 3)
	_panel_meta.add_child(columna)
	_lbl_meta_titulo = Estilo.etiqueta("PRÓXIMO DESBLOQUEO", 11, Estilo.TEXTO_SUAVE)
	columna.add_child(_lbl_meta_titulo)
	_lbl_meta_nombre = Estilo.etiqueta("", 15, Estilo.TEXTO, 3)
	_lbl_meta_nombre.custom_minimum_size.x = 276
	_lbl_meta_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_lbl_meta_nombre)
	_barra_meta = ProgressBar.new()
	_barra_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra_meta.show_percentage = false
	_barra_meta.custom_minimum_size = Vector2(276, 10)
	_barra_meta.add_theme_stylebox_override("background", Estilo.caja(Color(0, 0, 0, 0.5), 5, Color(1, 1, 1, 0.1), 1, 0))
	_relleno_meta = Estilo.caja(Estilo.ACENTO, 5, Color.TRANSPARENT, 0, 0)
	_barra_meta.add_theme_stylebox_override("fill", _relleno_meta)
	columna.add_child(_barra_meta)
	_lbl_meta_progreso = Estilo.etiqueta("", 12, Estilo.TEXTO_SUAVE)
	columna.add_child(_lbl_meta_progreso)
	_actualizar_meta()


func _actualizar_meta() -> void:
	var meta := Juego.proxima_meta()
	var actual := 0.0
	var objetivo := 1.0
	var texto := ""
	match meta.tipo:
		"migas":
			actual = meta.actual
			objetivo = maxf(1.0, meta.objetivo)
			texto = "%s / %s migas" % [Juego.formatear(actual), Juego.formatear(objetivo)]
		"nivel":
			actual = meta.actual
			objetivo = maxf(1.0, meta.objetivo)
			texto = "nivel %d / %d · %s" % [int(actual), int(objetivo), meta.detalle]
		"objetivo":
			var gran := run.objetivo_mapa
			if is_instance_valid(gran) and not gran.muerta:
				objetivo = maxf(1.0, gran.vida_max)
				actual = objetivo - gran.vida
			else:
				actual = objetivo
			texto = "%d%% devorado · %s" % [int(actual / objetivo * 100.0), meta.detalle]
		_:
			actual = 1.0
			texto = meta.detalle
	_lbl_meta_titulo.text = "GRAN OBJETIVO" if meta.tipo == "objetivo" else ("SIGUIENTE PASO" if meta.tipo == "viaje" else "PRÓXIMO DESBLOQUEO")
	_lbl_meta_nombre.text = meta.nombre
	_barra_meta.value = clampf(actual / objetivo, 0.0, 1.0) * 100.0
	var lista: bool = meta.tipo == "migas" and actual >= objetivo
	if lista:
		texto = "¡Ya te alcanza! Compralo en el taller al terminar"
	_lbl_meta_progreso.text = texto
	_relleno_meta.bg_color = Estilo.VERDE if lista else Estilo.ACENTO
	if lista and not _meta_lista:
		Sonido.tocar("comprar", 1.2, 0.0)
		mostrar_aviso("¡Ya podés comprar: %s!" % meta.nombre)
	_meta_lista = lista


## Muestra sólo las mecánicas que el jugador ya desbloqueó.
func _actualizar_revelados() -> void:
	var prioridades := Juego.revelado("prioridades")
	for nodo in _nodos_prioridad:
		nodo.visible = prioridades
	_boton_objetivo.visible = Juego.revelado("gran_objetivo")
	_lbl_meta.visible = _boton_objetivo.visible
	_columna_frenesi.visible = Juego.revelado("frenesi")
	_panel_inferior.visible = prioridades or _boton_objetivo.visible or _columna_frenesi.visible
	# Sin prioridades, la barra se achica a la derecha en vez de quedar vacía.
	_panel_inferior.anchor_left = 0.0 if prioridades else 1.0
	_panel_inferior.offset_left = 16 if prioridades else -490


## Al empezar la run, avisa qué mecánicas aparecieron desde la última vez.
func _anunciar_novedades() -> void:
	var nuevas := PackedStringArray()
	for id in ["frenesi", "gran_objetivo", "prioridades"]:
		if Juego.revelado(id) and Juego.es_nuevo(id):
			nuevas.append(Juego.REVELABLES[id])
			Juego.marcar_visto(id)
	if nuevas.is_empty():
		return
	await get_tree().create_timer(2.6).timeout  # después del aviso de territorio
	if is_inside_tree():
		mostrar_aviso("Nuevo · " + "\n".join(nuevas))


func _cambiar_prioridad(id: String) -> void:
	Juego.prioridad = id
	for clave in _prioridades:
		_prioridades[clave].set_pressed_no_signal(clave == id)
	for h in run.colonia.hormigas:
		if h.carga == 0 and h.estado != Hormiga.Estado.VOLVIENDO:
			h.comida = null
			h.estado = Hormiga.Estado.EXPLORANDO
			# Repartir la búsqueda entre cuadros, incluso al cambiar toda la colonia.
			h._reloj_pensar = randf() * Hormiga.INTERVALO_PENSAR

func _notificar_hito() -> void:
	if Juego.hitos.size() > _hitos_vistos:
		_hitos_vistos = Juego.hitos.size()
		var id: String = Juego.hitos.keys().back()
		mostrar_aviso("¡Hito! " + Juego.HITOS[id].nombre)

func mostrar_inspeccion(c: Comida) -> void:
	_lbl_objetivo.text = ""
	if c is PiezaCasa:
		_lbl_objetivo.text = "%s · %s / %s de resistencia\n%s" % [c.nombre, Juego.formatear(c.vida), Juego.formatear(c.vida_max), "Mantené clic para llamar hormigas · recompensa %s" % Juego.formatear(c.recompensa) if c.disponible() else "Requiere: " + MaterialesCasa.NIVELES[c.nivel_requerido]]
	elif c is FragmentoCasa:
		_lbl_objetivo.text = "%s · %s migas\nPeso %d · las cargadoras priorizan estos restos" % [c.nombre, Juego.formatear(c.recompensa), c.peso]


func _miga_llego(miga: Control) -> void:
	_volando -= 1
	miga.queue_free()
	if _tween_pulso and _tween_pulso.is_running():
		return
	_caja_migas.pivot_offset = _caja_migas.size / 2.0
	_caja_migas.scale = Vector2.ONE * 1.06
	_tween_pulso = _caja_migas.create_tween()
	_tween_pulso.tween_property(_caja_migas, "scale", Vector2.ONE, 0.12)
