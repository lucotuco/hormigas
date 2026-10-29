extends Node
## Observador local de la escena F6. No guarda, no usa red, no pregunta datos
## personales ni inspecciona hormigas/objetos. Señales y una muestra a 10 Hz.
const MAX_EVENTOS := 256
const MAX_EXPEDICIONES := 32
const INTERVALO := 0.1
const DIETAS := {"mordida_madera": "madera", "mordida_resistente": "resistentes", "mordida_muros": "muros"}

var eventos: Array[Dictionary] = []
var expediciones: Array[Dictionary] = []
var primeros: Dictionary = {}
var eventos_omitidos := 0
var expediciones_comenzadas := 0
var _tiempo_activo := 0.0
var _inicio_usec := 0
var _reloj := 0.0
var _fundaciones := 0
var _hitos: Dictionary = {}
var _casa := false
var _escena_previa := ""
var _run_actual: Run
var _run_cerrada := false
var _run_contexto: Dictionary = {}
var _capa: CanvasLayer
var _aviso: Label
var _panel: VentanaModal
var _dialogo: FileDialog
var _estado_exportacion: Label
var _pausa_previa := false
var _pausar_sin_foco_previo := false

func _ready() -> void:
	Juego.guardado_habilitado = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_inicio_usec = Time.get_ticks_usec()
	_fundaciones = Juego.fundaciones
	_hitos = Juego.hitos.duplicate()
	_casa = Juego.lugares_completados.has("casa")
	Juego.mejora_comprada.connect(_al_comprar_mejora)
	Juego.casta_comprada.connect(_al_comprar_casta)
	Juego.progreso_cambio.connect(_al_progreso)
	Juego.migas_cambiaron.connect(_al_cambiar_migas)
	Juego.partida_borrada.connect(func() -> void: _agregar_evento("reinicio_manual"))
	_crear_aviso()
	_agregar_evento("inicio_sesion")
	_muestrear()

func _process(delta: float) -> void:
	if not get_tree().paused:
		_tiempo_activo += delta
	_reloj -= delta
	if _reloj <= 0:
		_reloj = INTERVALO
		_muestrear()

func _input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if tecla == null:
		return
	# Ocurre antes de los _unhandled_input de Juego. F8 sigue siendo del
	# editor; no se consume ni se cambia el comportamiento del juego publicado.
	if tecla.keycode in [KEY_F1, KEY_F2, KEY_F9]:
		get_viewport().set_input_as_handled()
	elif tecla.keycode == KEY_F7 and tecla.pressed and not tecla.echo:
		get_viewport().set_input_as_handled()
		if is_instance_valid(_panel):
			_panel.cerrar()
		else:
			abrir_informe()

func _crear_aviso() -> void:
	_capa = CanvasLayer.new()
	_capa.layer = 120
	add_child(_capa)
	_aviso = Estilo.etiqueta(tr("Sesión de prueba: no guarda tu partida · F7: informe"), 12, Estilo.TEXTO_SUAVE)
	_aviso.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.offset_left = -290
	_aviso.offset_right = 290
	_aviso.offset_top = 60
	_aviso.offset_bottom = 78
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.add_child(_aviso)

func _muestrear() -> void:
	_observar_escena(get_tree().current_scene)
	_observar_run()

func _observar_run() -> void:
	if is_instance_valid(_run_actual):
		if Juego.migas_run > 0:
			_marcar_primero("primer_ingreso_observado", {"migas": Juego.migas_run, "precision_segundos": INTERVALO})
		if _run_actual.terminada:
			_resumir_run()

func _observar_escena(escena: Node) -> void:
	if not is_instance_valid(escena):
		return
	var ruta := escena.scene_file_path
	if ruta != _escena_previa:
		_escena_previa = ruta
		_agregar_evento("pantalla", {"escena": ruta.get_file().get_basename()})
	if escena is Run and escena != _run_actual:
		_run_actual = escena
		_run_cerrada = false
		expediciones_comenzadas += 1
		_run_contexto = {"expedicion": expediciones_comenzadas, "destino": Juego.lugar_actual,
			"colonia": Juego.fundaciones, "dieta": int(Juego.stat("materiales")),
			"hormigas_iniciales": int(Juego.stat("hormigas_iniciales")),
			"territorio": Juego.stat("radio_territorio"), "inicio_activo": _tiempo_activo}
		_agregar_evento("inicio_expedicion", _run_contexto)
		_marcar_primero("primera_expedicion", _run_contexto)
	elif not escena is Run:
		_run_actual = null

func _al_comprar_mejora(id: String, nivel: int) -> void:
	_agregar_evento("compra_mejora", {"id": id, "nivel": nivel})
	_marcar_primero("primera_compra", {"id": id, "nivel": nivel})
	if DIETAS.has(id):
		_marcar_primero(DIETAS[id], {"nivel": nivel})

func _al_comprar_casta(id: String, cantidad: int) -> void:
	_agregar_evento("compra_casta", {"id": id, "cantidad": cantidad})
	_marcar_primero("primera_casta", {"id": id})

func _al_progreso() -> void:
	# Una memoria comprada al fundar puede enseñar una dieta sin que exista
	# la compra normal. También se registra, con su procedencia explícita.
	var material := int(Juego.stat("materiales"))
	for i in DIETAS.size():
		if material > i:
			_marcar_primero(DIETAS.values()[i], {"fuente": "progreso"})
	for id: String in Juego.HITOS:
		if Juego.hitos.has(id) and not _hitos.has(id):
			_hitos[id] = true
			_agregar_evento("hito", {"id": id})
			if id == "primera_silla":
				_marcar_primero("primera_silla")
	if not _casa and Juego.lugares_completados.has("casa"):
		_casa = true
		_marcar_primero("casa_conquistada")
	if Juego.fundaciones > _fundaciones:
		_fundaciones = Juego.fundaciones
		_agregar_evento("fundacion", {"colonia": _fundaciones, "jalea": Juego.jalea, "decreto": Juego.decreto})
		_marcar_primero("primera_fundacion", {"jalea": Juego.jalea, "decreto": Juego.decreto})

func _al_cambiar_migas(_saldo: float) -> void:
	# terminar_run emite después de fijar terminada: conserva la última run
	# aunque el jugador pase al hormiguero antes del siguiente muestreo.
	if is_instance_valid(_run_actual) and _run_actual.terminada:
		if Juego.migas_run > 0:
			_marcar_primero("primer_ingreso_observado", {"migas": Juego.migas_run, "precision_segundos": INTERVALO})
		_resumir_run()
		return
	_observar_escena(get_tree().current_scene)
	if is_instance_valid(_run_actual) and _run_actual.terminada:
		_resumir_run()

func _resumir_run() -> void:
	if _run_cerrada or not is_instance_valid(_run_actual):
		return
	_run_cerrada = true
	var resumen := _run_contexto.duplicate(true)
	resumen.merge({"migas": Juego.migas_run, "duracion": _run_actual.tiempo_jugado,
		"retirada": _run_actual.tiempo_retirada, "produccion": _run_actual.produccion_run,
		"ingresos_por_material": _run_actual.ingresos.duplicate(),
		"comidas": Juego.comidas_destruidas_run, "partes": Juego.partes_destruidas_run,
		"objetivo": _run_actual.progreso_objetivo, "limpieza": _run_actual.limpieza_lograda,
		"carga_pendiente": _run_actual.cargas_pendientes}, true)
	_guardar_resumen(resumen)
	_agregar_evento("fin_expedicion", {"expedicion": expediciones_comenzadas, "migas": Juego.migas_run,
		"duracion": _run_actual.tiempo_jugado + _run_actual.tiempo_retirada})

func _guardar_resumen(resumen: Dictionary) -> void:
	if expediciones.size() >= MAX_EXPEDICIONES:
		expediciones.pop_front()
	expediciones.append(resumen.duplicate(true))

func _agregar_evento(tipo: String, datos: Dictionary = {}) -> void:
	if eventos.size() >= MAX_EVENTOS:
		eventos.pop_front()
		eventos_omitidos += 1
	eventos.append({"tipo": tipo, "activo": _tiempo_activo,
		"transcurrido": tiempo_transcurrido(), "datos": datos.duplicate(true)})

func _marcar_primero(id: String, datos: Dictionary = {}) -> void:
	if primeros.has(id):
		return
	primeros[id] = {"activo": _tiempo_activo, "transcurrido": tiempo_transcurrido(), "datos": datos.duplicate(true)}
	_agregar_evento(id, datos)

func tiempo_transcurrido() -> float:
	return maxf(0, (Time.get_ticks_usec() - _inicio_usec) / 1000000.0)

func informe() -> Dictionary:
	return {"formato": "hormigas_sesion_casa", "version": 1, "version_mapa": Mundos.VERSION_CONTENIDO,
		"guardado_personal": false, "tiempo_activo": _tiempo_activo,
		"tiempo_transcurrido": tiempo_transcurrido(), "primeros": primeros.duplicate(true),
		"eventos": eventos.duplicate(true), "eventos_omitidos": eventos_omitidos,
		"expediciones": expediciones.duplicate(true), "expediciones_comenzadas": expediciones_comenzadas,
		"estado": {"fundaciones": Juego.fundaciones, "destino": Juego.lugar_actual,
			"migas": Juego.migas, "migas_totales": Juego.estadistica("migas_totales"), "jalea": Juego.jalea}}

func abrir_informe() -> void:
	if is_instance_valid(_panel):
		return
	_muestrear()
	_pausa_previa = get_tree().paused
	# Un recorte de pantalla o el selector no debe crear otra pausa del HUD
	# debajo del informe. Es sólo temporal y jamás se guarda la configuración.
	_pausar_sin_foco_previo = Ajustes.pausar_sin_foco
	Ajustes.pausar_sin_foco = false
	get_tree().paused = true
	if is_instance_valid(_run_actual):
		_run_actual.feromonas.soltar()
		_run_actual.camara.arrastrando = false
	_panel = VentanaModal.new()
	_panel.titulo(tr("Informe de la sesión de prueba"))
	_panel.ancho(800)
	_capa.add_child(_panel)
	_panel.cerrada.connect(_cerrar_informe)
	var aviso := Estilo.etiqueta(tr("Sesión de prueba: no guarda tu partida"), 17, Estilo.ACENTO)
	_panel.contenido.add_child(aviso)
	var resumen := Estilo.etiqueta(tr("%.1f min activas · %d expediciones · %d fundaciones") % [_tiempo_activo / 60.0, expediciones_comenzadas, Juego.fundaciones], 16, Estilo.TEXTO)
	_panel.contenido.add_child(resumen)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, clampf(get_viewport().get_visible_rect().size.y - 380, 170, 450))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.contenido.add_child(scroll)
	var hitos := VBoxContainer.new()
	hitos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(hitos)
	hitos.add_child(Estilo.etiqueta(tr("Primeros hitos · tiempo activo"), 18, Estilo.TEXTO))
	var nombres := {"primera_expedicion": tr("Primera expedición"), "primer_ingreso_observado": tr("Primer ingreso observado"),
		"primera_compra": tr("Primera mejora comprada"), "primera_casta": tr("Primera casta comprada"),
		"madera": tr("Madera y telas"), "resistentes": tr("Materiales resistentes"), "muros": tr("Paredes"),
		"primera_silla": tr("Primera silla devorada"), "casa_conquistada": tr("Casa conquistada"),
		"primera_fundacion": tr("Primera fundación")}
	for id: String in nombres:
		var tiempo := tr("Pendiente")
		if primeros.has(id):
			tiempo = tr("%.1f s") % float(primeros[id].activo)
		hitos.add_child(Estilo.etiqueta(tr("%s: %s") % [nombres[id], tiempo], 14, Estilo.TEXTO_SUAVE))
	var ayuda := Estilo.etiqueta(tr("El primer ingreso se observa cada 0,1 s y puede incluir veneno o premios: no equivale a la primera entrega. Las compras e hitos se registran por señal. Las pausas no suman tiempo activo."), 12, Estilo.TEXTO_SUAVE)
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hitos.add_child(ayuda)
	var exportar := Estilo.boton(tr("Exportar informe JSON"), 16, Color("46593e"), Color("94b47e"))
	exportar.pressed.connect(_pedir_exportacion)
	_panel.contenido.add_child(exportar)
	_estado_exportacion = Estilo.etiqueta(tr("Sólo se exporta si lo pedís. No se envían datos ni se incluyen nombres o archivos personales."), 12, Estilo.TEXTO_SUAVE)
	_estado_exportacion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.contenido.add_child(_estado_exportacion)

func _cerrar_informe() -> void:
	get_tree().paused = _pausa_previa
	Ajustes.pausar_sin_foco = _pausar_sin_foco_previo
	_panel = null
	_dialogo = null

func _pedir_exportacion() -> void:
	if not is_instance_valid(_panel):
		return
	if not is_instance_valid(_dialogo):
		_dialogo = FileDialog.new()
		_dialogo.title = tr("Guardar informe de la sesión")
		_dialogo.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_dialogo.access = FileDialog.ACCESS_FILESYSTEM
		_dialogo.filters = PackedStringArray(["*.json ; JSON"])
		_dialogo.current_file = "hormigas_sesion_casa.json"
		_dialogo.file_selected.connect(_exportar_a)
		_panel.add_child(_dialogo)
	_dialogo.popup_centered_ratio(0.7)

func _exportar_a(ruta: String) -> bool:
	# Ni siquiera una selección manual puede pisar la partida/configuración.
	if _ruta_personal_protegida(ruta):
		_avisar_exportacion(tr("Ese archivo está protegido. Elegí otro nombre para el informe."))
		return false
	return _escribir_json(ruta)

func _ruta_personal_protegida(ruta: String) -> bool:
	var absoluta := ProjectSettings.globalize_path(ruta).replace("\\", "/").simplify_path().to_lower()
	for protegida: String in [Juego.RUTA_PARTIDA, Ajustes.RUTA, Ajustes.ruta]:
		if absoluta == ProjectSettings.globalize_path(protegida).replace("\\", "/").simplify_path().to_lower():
			return true
	return false

func _escribir_json(ruta: String) -> bool:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		_avisar_exportacion(tr("No se pudo exportar el informe. Elegí otra carpeta."))
		return false
	archivo.store_string(JSON.stringify(informe(), "\t"))
	_avisar_exportacion(tr("Informe exportado."))
	return true

func _avisar_exportacion(texto: String) -> void:
	if is_instance_valid(_estado_exportacion):
		_estado_exportacion.text = texto

func _exit_tree() -> void:
	if is_instance_valid(_panel):
		get_tree().paused = _pausa_previa
		Ajustes.pausar_sin_foco = _pausar_sin_foco_previo
