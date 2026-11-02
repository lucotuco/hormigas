class_name RecorridoDestino
extends Node2D
## Proyectos físicos: consultas al generar y eventos al devorar, no IA extra.
## Persisten objetos o componentes enteros. Una barra de HP nunca reconstruye
## material mordido ni inventa carga para la expedición siguiente.
var run: Run
var contexto_inicial := ""
var _partes: Dictionary = {}
var _objetivos_inicio: Array[String] = []
var _meta_pendiente_inicio := true
var _objetivo: PiezaCasa
var _fondo_etiqueta := Estilo.caja(Color("26362b"), 6, Color("a1b77d"), 1, 0)


func iniciar(r: Run) -> void:
	run = r
	z_index = 8
	for parte in r.comidas.partes:
		var id: String = parte.pieza.get("objetivo_proyecto", "")
		if id != "":
			_partes[id] = parte
	for objetivo in ProyectosCampana.objetivos_destino(Juego.lugar_actual):
		if not Juego.objetivo_proyecto_completo(objetivo.id):
			_objetivos_inicio.append(objetivo.id)
	_meta_pendiente_inicio = not Juego.meta_destino_devorada(Juego.lugar_actual) or Juego.coronas_cobradas.has(Juego.lugar_actual)
	var componentes_iniciales: Array[String] = []
	for id: String in Juego.componentes_proyecto_devorados:
		var datos_componente := ComponentesProyecto.componente(id)
		var datos_objetivo := ComponentesProyecto.objetivo(str(datos_componente.get("objetivo", "")))
		if datos_objetivo.get("destino", "") == Juego.lugar_actual:
			componentes_iniciales.append("c:" + id)
	for id: String in Juego.tesoros_proyecto_abiertos:
		if ComponentesProyecto.objetivo(id).get("destino", "") == Juego.lugar_actual:
			componentes_iniciales.append("t:" + id)
	if Juego.lugar_actual == "casa":
		for id: String in Juego.hallazgos_casa_abiertos:
			componentes_iniciales.append("h:" + id)
	componentes_iniciales.sort()
	if Juego.lugar_actual == "casa" or not ProyectosCampana.del_destino(Juego.lugar_actual).is_empty() or not componentes_iniciales.is_empty():
		var contexto := PackedStringArray(_objetivos_inicio)
		contexto.append("meta:%d" % int(_meta_pendiente_inicio))
		contexto.append("historico:%d" % int(Juego.lugares_completados.has(Juego.lugar_actual)))
		contexto.append_array(PackedStringArray(componentes_iniciales))
		contexto_inicial = "|".join(contexto).sha256_text()
	r.camara.vista_cambiada.connect(queue_redraw)
	_elegir_objetivo()


func conquista_pendiente() -> bool:
	return not Juego.coronas_cobradas.has(Juego.lugar_actual) and Juego.meta_destino_devorada(Juego.lugar_actual) and Juego.proyectos_completos(Juego.lugar_actual)


## O(1) mientras la pieza siga viva. Sólo se elige otra al terminar un objeto.
func objetivo_actual() -> PiezaCasa:
	var terminado := false
	if is_instance_valid(_objetivo):
		var id: String = _objetivo.pieza.get("objetivo_proyecto", "")
		terminado = id != "" and Juego.objetivo_proyecto_completo(id)
	if not is_instance_valid(_objetivo) or _objetivo.muerta or terminado:
		_elegir_objetivo()
	return _objetivo


func _elegir_objetivo() -> void:
	_objetivo = null
	if not is_instance_valid(run):
		return
	var dieta := int(Juego.stat("materiales"))
	# El orden es una sugerencia, no una cerradura: cualquier proyecto físico
	# puede devorarse primero y obtiene exactamente el mismo progreso.
	for id in _objetivos_inicio:
		var parte = _partes.get(id)
		if Juego.objetivo_proyecto_completo(id) or not is_instance_valid(parte) or parte.muerta:
			continue
		if _objetivo == null:
			_objetivo = parte
		if parte.nivel_requerido <= dieta:
			_objetivo = parte
			break
	if _objetivo == null and is_instance_valid(run.objetivo_mapa) and not run.objetivo_mapa.muerta:
		_objetivo = run.objetivo_mapa
	queue_redraw()


## La corona sólo se entrega cuando también está devorado el objetivo final.
## Run conserva una única celebración, aunque el último objeto sea un lateral.
func registrar_destruccion(parte: PiezaCasa) -> bool:
	var relevante := false
	var id: String = parte.pieza.get("objetivo_proyecto", "")
	if id != "" and Juego.registrar_objetivo_proyecto(id):
		relevante = true
		var proyecto_id: String = parte.pieza.get("proyecto_id", "")
		if Juego.proyecto_completo(proyecto_id):
			_premiar_proyecto(proyecto_id, parte.position)
	if parte.pieza.get("meta", false):
		Juego.registrar_meta_destino()
		relevante = true
	if relevante:
		_elegir_objetivo()
		if Juego.meta_destino_devorada(Juego.lugar_actual) and Juego.proyectos_completos(Juego.lugar_actual):
			return true
		if parte.pieza.get("meta", false):
			run.hud.mostrar_aviso(tr("Gran objetivo devorado. Terminá los proyectos del lugar para viajar."))
	return false


func _premiar_proyecto(id: String, pos: Vector2) -> void:
	var proyecto := ProyectosCampana.por_id(id)
	if proyecto.is_empty():
		return
	# Una sola comida real por proyecto, no ingreso automático ni multiplicador.
	# El catálogo limita a cuatro proyectos por destino y se cobra una sola vez.
	if str(proyecto.get("alijo", "")) != "":
		run.comidas.soltar_comida(proyecto.alijo, pos)
	if is_instance_valid(run.entradas):
		run.entradas.actualizar()
	run.hud.mostrar_aviso(tr("Proyecto terminado: %s") % tr(proyecto.nombre))
	run.efectos.texto(pos + Vector2(0, -60), tr(proyecto.premio), Color("c7d8a1"), 1.0)
	Sonido.tocar("crecer", 1.15, 0.0)


## Se calcula sólo al cerrar la expedición. El contexto inicial se conserva
## para no comparar récords de un recorrido intacto con otro ya adelantado.
func progreso() -> float:
	var total := _objetivos_inicio.size() + int(_meta_pendiente_inicio)
	if total <= 0:
		return 1.0
	var hechos := 0.0
	for id in _objetivos_inicio:
		if Juego.objetivo_proyecto_completo(id):
			hechos += 1.0
		else:
			var parte = _partes.get(id)
			if is_instance_valid(parte):
				hechos += clampf(1.0 - parte.vida / maxf(1.0, parte.vida_max), 0.0, 1.0)
	if _meta_pendiente_inicio:
		if run.objetivo_completado:
			hechos += 1.0
		elif is_instance_valid(run.objetivo_mapa):
			hechos += clampf(1.0 - run.objetivo_mapa.vida / maxf(1.0, run.objetivo_mapa.vida_max), 0.0, 1.0)
		elif Juego.meta_destino_devorada(Juego.lugar_actual):
			hechos += 1.0
	return clampf(hechos / total, 0.0, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _draw() -> void:
	if not is_instance_valid(run) or not run.activa or not is_instance_valid(_objetivo) or _objetivo.muerta or not _objetivo.pieza.has("objetivo_proyecto"):
		return
	if not _objetivo.en_territorio(run.radio_actual):
		return
	# Una sola etiqueta retenida y sin flechas. No se dibujan marcadores por
	# cada mueble ni se actualiza la selección en un _process.
	var escala := clampf(0.72 / maxf(run.camara.zoom.x, 0.08), 0.6, 3.0)
	var pos := _objetivo.rect_mundo.position + Vector2(12, -12 * escala)
	draw_set_transform(pos, 0, Vector2.ONE * escala)
	var texto := tr("Proyecto")
	var fuente := ThemeDB.fallback_font
	var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	draw_style_box(_fondo_etiqueta, Rect2(-8, -23, ancho + 16, 30))
	draw_string(fuente, Vector2.ZERO, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("e0e5c9"))
	draw_set_transform(Vector2.ZERO)
