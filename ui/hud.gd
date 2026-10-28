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
var _lbl_fin_titulo: Label
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
var _lbl_llamado: Label
var _boton_paso: Button
var _objetivo_paso: PiezaCasa
var _silla_inicial: PiezaCasa
var _silla_buscada := false
var _columna_progresion: VBoxContainer

var _ventana: VentanaModal
var _cartel: PanelContainer
var _lbl_cartel_titulo: Label
var _lbl_cartel_detalle: Label
var _tween_cartel: Tween
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


## Flechas en el borde de la pantalla hacia las amenazas y migas doradas
## que quedan fuera de la vista.
class IndicadorEventos extends Control:
	var run: Run
	var _reloj := 0.0
	var _habia_eventos := false
	var etiquetas: Array[Rect2] = []
	var _eventos: Array[Evento] = []
	var _fondo: StyleBoxFlat

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_fondo = Estilo.caja(Color("202b25"), 8, Color("807352"), 1, 0)

	func _process(delta: float) -> void:
		_reloj -= delta
		if _reloj > 0 or not is_instance_valid(run) or run.eventos == null:
			return
		_reloj = 0.1
		var hay := not run.eventos.activos.is_empty()
		if hay or _habia_eventos:
			queue_redraw()
		_habia_eventos = hay

	func nombre(tipo: String) -> String:
		match tipo:
			"arana": return tr("Araña · Ver")
			"mozo": return tr("Mozo · Ver")
			"aspiradora": return tr("Aspiradora · Ver")
			"paloma": return tr("Palomas · Ver")
			"gato": return tr("Gato · Ver")
			"rata": return tr("Rata · Ver")
			"dorada": return tr("Miga dorada · Ver")
		return ""

	func detalle(tipo: String) -> String:
		match tipo:
			"arana": return tr("Protegé a tus hormigas")
			"mozo": return tr("Hacé clic en su sombra")
			"aspiradora": return tr("Recuperá lo que se llevó")
			"paloma": return tr("Espantalas para proteger la comida")
			"gato": return tr("Está sobre tu comida")
			"rata": return tr("Está robando comida")
			"dorada": return tr("Recogela antes de que desaparezca")
		return ""

	# Sólo las tarjetas interceptan el mouse. El resto del mapa sigue recibiendo
	# las órdenes, el zoom y el arrastre sin una capa transparente que los tape.
	func _has_point(punto: Vector2) -> bool:
		return etiquetas.any(func(caja: Rect2) -> bool: return caja.has_point(punto))

	func enfocar(indice: int) -> bool:
		if indice < 0 or indice >= _eventos.size() or not is_instance_valid(run) or not run.activa:
			return false
		var evento := _eventos[indice]
		if not is_instance_valid(evento) or evento.resuelto:
			return false
		run.feromonas.soltar()
		run.camara.arrastrando = false
		run.camara.mirar(run.eventos.punto_de_clic(evento), Vector2(500, 400))
		queue_redraw()
		return true

	func _gui_input(evento: InputEvent) -> void:
		if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if evento.pressed:
				for i in etiquetas.size():
					if etiquetas[i].has_point(evento.position):
						enfocar(i)
						return

	func _draw() -> void:
		etiquetas.clear()
		_eventos.clear()
		if not is_instance_valid(run) or run.eventos == null or not run.activa:
			return
		# Reservar el HUD superior y los controles inferiores, incluida la punta.
		var area := Rect2(30, 150, maxf(1, size.x - 60), maxf(1, size.y - 290))
		var centro := area.get_center()
		var vistos: Dictionary = {}
		for e in run.eventos.activos:
			if not is_instance_valid(e) or e.resuelto or (e.tipo == "mozo" and e.estado != "avisando"):
				continue
			if vistos.has(e.tipo):
				continue # Una señal por bandada, no tres etiquetas superpuestas.
			var p := run.a_pantalla(run.eventos.punto_de_clic(e))
			if Rect2(Vector2.ZERO, size).has_point(p):
				continue
			vistos[e.tipo] = true
			var dir := (p - centro).normalized()
			# Punto del borde en esa dirección.
			var t := INF
			if absf(dir.x) > 0.001:
				t = minf(t, (area.size.x * 0.5) / absf(dir.x))
			if absf(dir.y) > 0.001:
				t = minf(t, (area.size.y * 0.5) / absf(dir.y))
			var borde := centro + dir * t
			var tinta := Color("f2c84b") if e.tipo == "dorada" else Color("e0634a")
			var texto := nombre(e.tipo)
			var ayuda := detalle(e.tipo)
			var ancho := maxf(ThemeDB.fallback_font.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x,
				ThemeDB.fallback_font.get_string_size(ayuda, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
			var caja := Rect2(borde - Vector2(ancho * 0.5 + 14, 24), Vector2(ancho + 28, 48))
			caja.position = caja.position.clamp(area.position, area.end - caja.size)
			var base := caja.position
			var sentido := -1.0 if caja.get_center().y > centro.y else 1.0
			for paso in 7:
				caja.position.y = clampf(base.y + paso * sentido * 56, area.position.y, area.end.y - caja.size.y)
				var libre := true
				for anterior in etiquetas:
					libre = libre and not caja.grow(5).intersects(anterior)
				if libre:
					break
			etiquetas.append(caja)
			_eventos.append(e)
			_fondo.border_color = Color(tinta, 0.65)
			draw_style_box(_fondo, caja)
			draw_string(ThemeDB.fallback_font, caja.position + Vector2(14, 19), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tinta)
			draw_string(ThemeDB.fallback_font, caja.position + Vector2(14, 36), ayuda, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Estilo.TEXTO_SUAVE)
			# Punta por fuera del cartel, orientada hacia el evento real.
			var salida := caja.get_center() + dir * minf((caja.size.x * 0.5) / maxf(absf(dir.x), 0.001), 24.0 / maxf(absf(dir.y), 0.001))
			draw_colored_polygon(PackedVector2Array([salida + dir * 12, salida + dir.orthogonal() * 5, salida - dir.orthogonal() * 5]), tinta)


func _ready() -> void:
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)
	_crear_migas(raiz)
	_crear_tiempo(raiz)
	_crear_hormigas(raiz)
	_crear_avisos(raiz)
	_crear_cartel(raiz)
	_crear_panel_fin(raiz)
	_crear_progresion(raiz)
	_crear_proxima_meta(raiz)
	_crear_prioridades(raiz)
	_lbl_llamado = Estilo.etiqueta("", 13, Color("c2ecd2"), 4)
	_lbl_llamado.add_theme_stylebox_override("normal", Estilo.caja(Color("20302a"), 8, Color(0.55, 0.75, 0.65, 0.25), 1, 10))
	_lbl_llamado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_llamado.visible = false
	raiz.add_child(_lbl_llamado)
	var indicador := IndicadorEventos.new()
	indicador.run = run
	indicador.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(indicador)
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
	if run.retirando:
		_lbl_tiempo.text = tr("Regreso · %d s") % ceili(run.retiro_restante)
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
		_lbl_etapa.text = tr("DIETA %d/4 · %s") % [int(Juego.stat("materiales")) + 1, tr(MaterialesCasa.NIVELES[clampi(int(Juego.stat("materiales")), 0, 3)])]
		_lbl_lugar.text = tr(Mundos.INFO[Juego.lugar_actual].nombre)
		_actualizar_meta()
		_lbl_meta.text = (tr("✓ Gran objetivo completado") if run.objetivo_completado else tr("Gran objetivo: %s") % tr(Mundos.INFO[Juego.lugar_actual].meta)) + "  [G]"
		_lbl_frenesi.text = tr("¡FRENESÍ! %.1f s") % run.frenesi_restante if run.frenesi_restante > 0 else tr("Frenesí · depósitos consecutivos")
		_barra_frenesi.value = run.frenesi_restante / 6.0 * 100 if run.frenesi_restante > 0 else run.frenesi
		var c := run.comidas.comida_en(run.get_global_mouse_position(), run.radio_actual, true)
		mostrar_inspeccion(c)
		_lbl_llamado.visible = run.feromonas.activa
		if _lbl_llamado.visible:
			var datos := run.feromonas.resumen()
			_lbl_llamado.text = tr("%d atraídas · %d trabajando · %d cargando") % [datos.atraidas, datos.trabajando, datos.cargando]
			if datos.esperando > 0:
				_lbl_llamado.text += tr("\n%d buscando un camino") % datos.esperando
			if run.feromonas.posicion.length() > run.radio_actual:
				_lbl_llamado.text = tr("Fuera del territorio descubierto")
			# El estado del llamado pertenece al HUD: no tapar el objeto que se muerde.
			_lbl_llamado.position = Vector2(32, get_viewport().get_visible_rect().size.y - 136)

	_lbl_hormigas.text = (tr("Hormigas: %d · colonia llena") if run.colonia.colonia_llena() else tr("Hormigas: %d")) % run.colonia.cantidad()
	_reloj_descubrimiento -= delta
	if _reloj_descubrimiento <= 0:
		_reloj_descubrimiento = 0.5
		var conteo := run.colonia.conteo_castas()
		var lineas := PackedStringArray()
		var grupo := PackedStringArray()
		var nombres := {"obrera": tr("Obreras"), "reina": tr("Reinas"), "roja": tr("Rojas"), "voladora": tr("Voladoras"), "veloz": tr("Veloces"), "cargadora": tr("Cargadoras"), "mini": tr("Minis"), "carpintera": tr("Carpinteras"), "demoledora": tr("Demoledoras")}
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
	_lbl_combo.text = tr("COMBO x%d") % combo
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
	_lbl_aviso.scale = Vector2.ONE * 0.96
	var tween := _lbl_aviso.create_tween().set_parallel(true)
	_tween_aviso = tween
	tween.tween_property(_lbl_aviso, "modulate:a", 1.0, 0.25)
	tween.tween_property(_lbl_aviso, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(1.8)
	tween.chain().tween_property(_lbl_aviso, "modulate:a", 0.0, 0.5)


func mostrar_fin() -> void:
	_lbl_aviso.hide()
	_lbl_fin_titulo.text = (tr("¡Mapa despejado!") if run.limpieza_completa else tr("¡Zona despejada!")) if run.limpieza_lograda else tr("¡Se acabó el tiempo!")
	_lbl_fin_migas.text = tr("+%s migas") % Juego.formatear(Juego.migas_run)
	_lbl_fin_detalle.text = tr("Comidas: %d · Partes de la casa: %d\nMejor combo: x%d\nTotal en el hormiguero: %s") % [
		Juego.comidas_destruidas_run, Juego.partes_destruidas_run, Juego.mejor_combo_run, Juego.formatear(Juego.migas)]
	_lbl_fin_detalle.text += tr("\n%s migas/s · %s") % [Juego.formatear_corto(run.produccion_run), (tr("%+.0f%% frente al récord anterior") % run.mejora_produccion) if run.tenia_record else tr("primer registro en este destino")]
	_lbl_fin_detalle.text += tr("\nAlimentos %s · Muebles %s · Estructuras %s") % [Juego.formatear_corto(run.ingresos[0]), Juego.formatear_corto(run.ingresos[1]), Juego.formatear_corto(run.ingresos[2])]
	if run.limpieza_lograda:
		_lbl_fin_detalle.text += tr("\nLimpieza: %.1f s · Total con entregas: %.1f s") % [run.tiempo_limpieza, run.tiempo_jugado + run.tiempo_retirada]
		_lbl_fin_detalle.text += "\n" + tr("Se agotó todo lo comestible dentro del territorio.")
		if run.limpieza_registrada:
			_lbl_fin_detalle.text += "\n" + (tr("Récord de limpieza para esta dieta y alcance") if run.nuevo_record_limpieza else tr("Marca de limpieza guardada en el archivo"))
	else:
		_lbl_fin_detalle.text += tr("\nTiempo de expedición: %.1f s") % (run.tiempo_jugado + run.tiempo_retirada)
	var record: Dictionary = Juego.records_destino.get(Juego.lugar_actual, {})
	_lbl_fin_detalle.text += tr("\nGran objetivo: %.0f%% · mejor intento %.0f%%") % [run.progreso_objetivo * 100, float(record.get("objetivo", 0)) * 100]
	if run.cargas_pendientes > 0:
		_lbl_fin_detalle.text += tr("\nQuedaron %s en camino: más velocidad o entradas acortan la vuelta.") % Juego.formatear_corto(run.cargas_pendientes)
	var meta := Juego.proxima_meta()
	if meta.tipo == "migas" and Juego.migas >= meta.objetivo:
		_lbl_fin_detalle.text += tr("\n¡Ya podés comprar tu próxima dieta en el taller!")
	# El prestigio a la vista: cuánto daría fundar ahora (ver pestaña Jalea real).
	if Juego.revelado("legado") and Juego.puede_fundar():
		_lbl_fin_detalle.text += "\n" + tr("Fundar ahora daría +%d de jalea real") % Juego.jalea_por_fundar()
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
	columna.add_child(Estilo.etiqueta(tr("MIGAS DE ESTA RUN"), 11, Estilo.TEXTO_SUAVE))
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
	_lbl_hormigas = Estilo.etiqueta(tr("Hormigas: %d") % 0, 18, Estilo.TEXTO)
	caja.add_child(_lbl_hormigas)
	_lbl_composicion = Estilo.etiqueta("", 12, Estilo.TEXTO, 3)
	_lbl_composicion.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_composicion.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_lbl_composicion.position = Vector2(-356, 78)
	_lbl_composicion.custom_minimum_size.x = 340
	raiz.add_child(_lbl_composicion)


func _crear_avisos(raiz: Control) -> void:
	_lbl_aviso = Estilo.etiqueta("", 18, Estilo.ACENTO)
	_lbl_aviso.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_lbl_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_aviso.custom_minimum_size = Vector2(620, 0)
	_lbl_aviso.size.x = 620
	_lbl_aviso.add_theme_stylebox_override("normal", Estilo.caja(Color(0.10, 0.14, 0.12, 0.94), 10, Color(0.7, 0.7, 0.5, 0.25), 1, 14))
	_lbl_aviso.position = Vector2(-310, 116)
	_lbl_aviso.visible = false
	raiz.add_child(_lbl_aviso)

	_lbl_ayuda = Estilo.etiqueta(
		tr("Mantené clic: llamar hormigas · Clic en amenazas y premios: interactuar\nRueda: zoom · Botón derecho o central / WASD: mover · R: hormiguero · H: mapa · Esc: pausa"),
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


## Cartel grande de conquista (ver Conquista): corona, título y coronas.
class Corona extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var w := minf(size.x * 0.42, size.y * 0.62)
		var puntas := PackedVector2Array([c + Vector2(-w, w * 0.45), c + Vector2(-w, -w * 0.25), c + Vector2(-w * 0.5, w * 0.1), c + Vector2(0, -w * 0.55), c + Vector2(w * 0.5, w * 0.1), c + Vector2(w, -w * 0.25), c + Vector2(w, w * 0.45)])
		draw_colored_polygon(puntas, Color("f0c94e"))
		draw_polyline(puntas + PackedVector2Array([puntas[0]]), Color("8a6420"), 2.0, true)
		for p in [puntas[1], puntas[3], puntas[5]]:
			draw_circle(p, w * 0.1, Color("d9534a"))


func _crear_cartel(raiz: Control) -> void:
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Más abajo del centro: que se vea el derrumbe arriba del cartel.
	centro.offset_top = 170
	raiz.add_child(centro)
	_cartel = PanelContainer.new()
	_cartel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartel.add_theme_stylebox_override("panel", Estilo.caja(Color(0.1, 0.07, 0.04, 0.9), 22, Color("f0c94e"), 3, 30))
	_cartel.visible = false
	centro.add_child(_cartel)
	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	columna.add_theme_constant_override("separation", 8)
	columna.custom_minimum_size.x = 520
	_cartel.add_child(columna)
	var corona := Corona.new()
	corona.custom_minimum_size = Vector2(0, 74)
	corona.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(corona)
	_lbl_cartel_titulo = Estilo.etiqueta("", 36, Estilo.ACENTO, 6)
	_lbl_cartel_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(_lbl_cartel_titulo)
	_lbl_cartel_detalle = Estilo.etiqueta("", 18, Estilo.TEXTO, 3)
	_lbl_cartel_detalle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(_lbl_cartel_detalle)


func mostrar_conquista(titulo: String, detalle: String) -> void:
	_lbl_cartel_titulo.text = titulo
	_lbl_cartel_detalle.text = detalle
	_cartel.visible = true
	_cartel.modulate.a = 0.0
	if _tween_cartel and _tween_cartel.is_running():
		_tween_cartel.kill()
	await get_tree().process_frame
	if not is_instance_valid(_cartel):
		return
	_cartel.pivot_offset = _cartel.size / 2.0
	_cartel.scale = Vector2.ONE * 0.6
	_tween_cartel = _cartel.create_tween().set_ignore_time_scale(true)
	_tween_cartel.set_parallel(true)
	_tween_cartel.tween_property(_cartel, "modulate:a", 1.0, 0.3)
	_tween_cartel.tween_property(_cartel, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_cartel.chain().tween_interval(3.2)
	_tween_cartel.chain().tween_property(_cartel, "modulate:a", 0.0, 0.6)
	_tween_cartel.chain().tween_callback(func() -> void: _cartel.visible = false)


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
	_lbl_fin_titulo = Estilo.etiqueta(tr("¡Se acabó el tiempo!"), 30, Estilo.TEXTO, 4)
	_lbl_fin_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(_lbl_fin_titulo)
	_lbl_fin_record = Estilo.etiqueta(tr("¡NUEVO RÉCORD!"), 18, Estilo.VERDE, 3)
	_lbl_fin_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(_lbl_fin_record)
	_lbl_fin_migas = Estilo.etiqueta(tr("+%s migas") % "0", 44, Estilo.ACENTO, 6)
	_lbl_fin_migas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(_lbl_fin_migas)
	_lbl_fin_detalle = Estilo.etiqueta("", 17, Estilo.TEXTO_SUAVE)
	_lbl_fin_detalle.custom_minimum_size.x = 620
	_lbl_fin_detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_fin_detalle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(_lbl_fin_detalle)
	var espacio := Control.new()
	espacio.custom_minimum_size = Vector2(0, 8)
	columna.add_child(espacio)
	_boton_tienda = Estilo.boton(tr("Mejorar el hormiguero") + "  ▸", 22, Color(0.45, 0.3, 0.12), Estilo.ACENTO)
	_boton_tienda.pressed.connect(run.ir_a_tienda)
	columna.add_child(_boton_tienda)
	var archivo := Estilo.boton(tr("Archivo de expediciones"), 15, Color("293329"), Color("71865b"))
	archivo.pressed.connect(_abrir_archivo)
	columna.add_child(archivo)


func _abrir_archivo() -> void:
	if is_instance_valid(_ventana):
		return
	_ventana = PanelArchivo.new()
	_ventana.cerrada.connect(func() -> void:
		_ventana = null
		_boton_tienda.grab_focus())
	get_child(0).add_child(_ventana)

func _crear_progresion(raiz: Control) -> void:
	_columna_progresion = VBoxContainer.new()
	_columna_progresion.position = Vector2(20, 250)
	_columna_progresion.size.x = 300
	_columna_progresion.custom_minimum_size.x = 300
	_columna_progresion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_columna_progresion.add_theme_constant_override("separation", 7)
	raiz.add_child(_columna_progresion)
	_lbl_lugar = Estilo.etiqueta("", 14, Estilo.TEXTO, 3)
	_columna_progresion.add_child(_lbl_lugar)
	_lbl_etapa = Estilo.etiqueta("", 13, Color("d4ccaa"), 3)
	_columna_progresion.add_child(_lbl_etapa)
	_lbl_meta = Estilo.etiqueta("", 12, Color("c4cfa0"), 3)
	_lbl_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_columna_progresion.add_child(_lbl_meta)
	_lbl_objetivo = Estilo.etiqueta("", 13, Estilo.TEXTO, 3)
	_lbl_objetivo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_columna_progresion.add_child(_lbl_objetivo)

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
	var titulo := Estilo.etiqueta(tr("PRIORIDAD"), 11, Estilo.TEXTO_SUAVE)
	fila.add_child(titulo)
	_nodos_prioridad.append(titulo)
	for id in ["automatico", "alimentos", "muebles", "estructuras"]:
		var nombres := {"automatico": tr("Auto"), "alimentos": tr("Alimentos"), "muebles": tr("Muebles"), "estructuras": tr("Estructuras")}
		var boton := Estilo.boton(nombres[id], 13, Color("303d2b"), Color("78936a"))
		boton.toggle_mode = true
		boton.button_pressed = Juego.prioridad == id
		boton.tooltip_text = tr("Prioridad de búsqueda. El llamado manual siempre manda.")
		boton.pressed.connect(_cambiar_prioridad.bind(id))
		fila.add_child(boton)
		_prioridades[id] = boton
		_nodos_prioridad.append(boton)
	var espacio := Control.new()
	espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(espacio)
	var objetivo := Estilo.boton(tr("Gran objetivo") + " [G]", 13, Color("303d2b"), Color("78936a"))
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
	_lbl_meta_titulo = Estilo.etiqueta(tr("PRÓXIMO DESBLOQUEO"), 11, Estilo.TEXTO_SUAVE)
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
	_lbl_meta_progreso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_meta_progreso.custom_minimum_size.x = 276
	columna.add_child(_lbl_meta_progreso)
	_boton_paso = Estilo.boton(tr("Ver en el mapa"), 12, Color("293629"), Color("71865b"))
	_boton_paso.custom_minimum_size.y = 30
	_boton_paso.visible = false
	_boton_paso.pressed.connect(_ver_paso)
	columna.add_child(_boton_paso)
	_actualizar_meta()


func _ver_paso() -> void:
	if not is_instance_valid(_objetivo_paso) or not _objetivo_paso.disponible() or not run.activa:
		return
	run.feromonas.soltar()
	run.camara.arrastrando = false
	run.camara.mirar(_objetivo_paso.position, _objetivo_paso.rect_mundo.size)


func _actualizar_meta() -> void:
	var meta := Juego.proxima_meta()
	var practica := run.objetivo_practica
	_objetivo_paso = null
	# La geometría se consulta una sola vez, después de generar el escenario.
	if run.activa and not _silla_buscada:
		_silla_buscada = true
		for parte in run.comidas.partes:
			if parte.pieza.get("perfil", "") == "silla_inicial":
				_silla_inicial = parte
				break
	if is_instance_valid(practica) and not practica.muerta and Juego.stat("materiales") < 1 and not Juego.hitos.has("primer_derrumbe"):
		meta = {"tipo": "practica", "nombre": tr("Desarmá el banquito de cartón")}
		_objetivo_paso = practica
	if is_instance_valid(_silla_inicial) and _silla_inicial.disponible() and not Juego.hitos.has("primera_silla"):
		meta = {"tipo": "madera", "nombre": tr("Tu primera silla de madera")}
		_objetivo_paso = _silla_inicial
	var actual := 0.0
	var objetivo := 1.0
	var texto := ""
	match meta.tipo:
		"practica":
			actual = practica.vida_max - practica.vida
			objetivo = practica.vida_max
			texto = tr("Mantené clic sobre el banquito · no requiere mejoras")
		"madera":
			actual = _silla_inicial.vida_max - _silla_inicial.vida
			objetivo = _silla_inicial.vida_max
			texto = tr("Ya comen madera: llamalas sobre la silla y mirá cómo la desarman.")
		"migas":
			actual = meta.actual
			objetivo = maxf(1.0, meta.objetivo)
			texto = tr("%s / %s migas") % [Juego.formatear(actual), Juego.formatear(objetivo)]
		"nivel":
			actual = meta.actual
			objetivo = maxf(1.0, meta.objetivo)
			texto = tr("nivel %d / %d · %s") % [int(actual), int(objetivo), meta.detalle]
		"objetivo":
			var gran := run.objetivo_mapa
			if is_instance_valid(gran) and not gran.muerta:
				objetivo = maxf(1.0, gran.vida_max)
				actual = objetivo - gran.vida
			else:
				actual = objetivo
			texto = tr("%d%% devorado · %s") % [int(actual / objetivo * 100.0), meta.detalle]
		_:
			actual = 1.0
			texto = meta.detalle
	_lbl_meta_titulo.text = tr("GRAN OBJETIVO") if meta.tipo == "objetivo" else (tr("SIGUIENTE PASO") if meta.tipo in ["viaje", "madera", "practica"] else tr("PRÓXIMO DESBLOQUEO"))
	_lbl_meta_nombre.text = meta.nombre
	_boton_paso.visible = is_instance_valid(_objetivo_paso) and run.activa and _objetivo_paso.disponible()
	_barra_meta.value = clampf(actual / objetivo, 0.0, 1.0) * 100.0
	var lista: bool = meta.tipo == "migas" and actual >= objetivo
	if lista:
		texto = tr("¡Ya te alcanza! Compralo en el taller al terminar")
	_lbl_meta_progreso.text = texto
	_columna_progresion.position.y = _panel_meta.position.y + _panel_meta.get_combined_minimum_size().y + 14
	_relleno_meta.bg_color = Estilo.VERDE if lista else Estilo.ACENTO
	if lista and not _meta_lista:
		Sonido.tocar("comprar", 1.2, 0.0)
		mostrar_aviso(tr("¡Ya podés comprar: %s!") % meta.nombre)
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
	for id in ["frenesi", "gran_objetivo", "prioridades", "doradas", "amenazas"]:
		if Juego.revelado(id) and Juego.es_nuevo(id):
			nuevas.append(tr(Juego.REVELABLES[id]))
			Juego.marcar_visto(id)
	if nuevas.is_empty():
		return
	await get_tree().create_timer(2.6, false).timeout  # después del aviso de territorio
	for novedad in nuevas:
		if not is_inside_tree():
			return
		mostrar_aviso(tr("Nuevo · %s") % novedad)
		await get_tree().create_timer(3.0, false).timeout


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
		mostrar_aviso(tr("¡Hito! %s") % tr(Juego.HITOS[id].nombre))

func mostrar_inspeccion(c: Comida) -> void:
	_lbl_objetivo.text = "" # las reglas están en Viajes; no tapar el mapa vacío
	if c is PiezaCasa:
		_lbl_objetivo.text = tr("%s · %s\n%s / %s de resistencia · %d trabajadoras\n%s") % [c.nombre, c.nombre_etapa(), Juego.formatear(c.vida), Juego.formatear(c.vida_max), c.trabajadoras, tr("Mantené clic para llamar hormigas") if c.disponible() else tr("Requiere: %s") % tr(MaterialesCasa.NIVELES[c.nivel_requerido])]
	elif c is FragmentoCasa:
		_lbl_objetivo.text = tr("%s · %s migas\nPeso %d · las cargadoras priorizan estos restos") % [c.nombre, Juego.formatear(c.recompensa), c.peso]


# =====================================================================
# Pausa
# =====================================================================

func pausado() -> bool:
	return get_tree().paused and is_instance_valid(_ventana)


func pausar() -> void:
	if not is_inside_tree() or not is_node_ready() or not run.activa or pausado():
		return
	run.feromonas.soltar()
	run.camara.arrastrando = false
	get_tree().paused = true
	Sonido.tocar("clic", 0.7)
	_menu_pausa()


func reanudar() -> void:
	if is_instance_valid(_ventana):
		_ventana.queue_free()
	_ventana = null
	get_tree().paused = false


func _menu_pausa() -> void:
	var ventana := VentanaModal.new()
	ventana.titulo(tr("Pausa"))
	ventana.ancho(380)
	_mostrar_ventana(ventana)
	ventana.cerrada.connect(reanudar)
	var opciones := [
		[tr("Seguir"), reanudar],
		[tr("Configuración"), _abrir_configuracion],
		[tr("Estadísticas"), func() -> void: _mostrar_ventana(PanelEstadisticas.new(), true)],
		[tr("Terminar la expedición"), _terminar_desde_pausa],
		[tr("Salir al menú"), run.salir_al_menu],
	]
	for i in opciones.size():
		var boton := Estilo.boton(opciones[i][0], 17, Color("46593e") if i == 0 else Color("262e25"), Color("94b47e") if i == 0 else Color("4b5945"))
		boton.custom_minimum_size.y = 46
		boton.pressed.connect(opciones[i][1])
		ventana.contenido.add_child(boton)
		if i == 0:
			boton.call_deferred("grab_focus")


## Muestra una ventana en pausa. Las secundarias (configuración,
## estadísticas) vuelven al menú de pausa al cerrarse.
func _mostrar_ventana(ventana: VentanaModal, secundaria := false) -> void:
	if is_instance_valid(_ventana):
		if _ventana.cerrada.is_connected(reanudar):
			_ventana.cerrada.disconnect(reanudar)
		_ventana.queue_free()
	_ventana = ventana
	add_child(ventana)
	if secundaria:
		ventana.cerrada.connect(func() -> void:
			_ventana = null
			_menu_pausa())


func _abrir_configuracion() -> void:
	var panel := PanelConfiguracion.new()
	# Los textos del HUD se rearman solos; la pausa se vuelve a armar al cerrar.
	_mostrar_ventana(panel, true)


func _terminar_desde_pausa() -> void:
	reanudar()
	run.tiempo_restante = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and Ajustes.pausar_sin_foco and is_inside_tree():
		# Godot bloquea los hijos mientras propaga esta notificación. Abrir
		# la ventana al terminar ese recorrido evita una pausa sin controles.
		pausar.call_deferred()


func _miga_llego(miga: Control) -> void:
	_volando -= 1
	miga.queue_free()
	if _tween_pulso and _tween_pulso.is_running():
		return
	_caja_migas.pivot_offset = _caja_migas.size / 2.0
	_caja_migas.scale = Vector2.ONE * 1.06
	_tween_pulso = _caja_migas.create_tween()
	_tween_pulso.tween_property(_caja_migas, "scale", Vector2.ONE, 0.12)
