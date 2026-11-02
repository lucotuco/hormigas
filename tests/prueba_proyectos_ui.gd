extends Node
## Lectura del recorrido: objetos persistentes, corona pendiente y foco manual.
## La física y los premios se verifican en la suite propia de proyectos.
var total := 0
var fallas := 0


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("OK " if ok else "FALLA ", detalle)


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	await probar_viajes()
	await probar_hud()
	await probar_evoluciones()
	Juego.reiniciar_estado()
	print("Proyectos en la interfaz: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func preparar_restaurante() -> void:
	Juego.reiniciar_estado()
	Juego.completar_destino() # Fixture pública: casa conquistada, sin regalos de proyectos posteriores.
	Juego.elegir_destino("restaurante")
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()


func textos(nodo: Node) -> String:
	var texto := str(nodo.text) + "\n" if nodo is Label else ""
	for hijo in nodo.get_children():
		texto += textos(hijo)
	return texto


func probar_viajes() -> void:
	preparar_restaurante()
	var marco := Control.new()
	marco.size = get_viewport().get_visible_rect().size
	add_child(marco)
	var panel := PanelCampana.new()
	marco.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	await get_tree().process_frame
	verificar(panel._tarjetas_destino.size() == 6 and panel._filas_proyectos.size() == 4, "viajes conserva seis destinos y amplía sólo los cuatro proyectos del actual")
	verificar(panel._grid_proyectos.columns == (2 if panel._grid_proyectos.size.x >= 760 else 1), "los cuatro proyectos usan dos columnas cuando hay ancho disponible")
	marco.size.x = 700
	await get_tree().process_frame
	await get_tree().process_frame
	verificar(panel._grid_proyectos.columns == 1, "en una ventana angosta los proyectos vuelven a una columna legible")
	var sin_desborde := true
	for proyecto: Control in panel._filas_proyectos.values():
		sin_desborde = sin_desborde and proyecto.get_global_rect().end.x <= panel.get_global_rect().end.x + 1
	verificar(sin_desborde, "las fichas del recorrido no exigen desplazamiento horizontal")
	var proyectos := Juego.resumen_proyectos("restaurante")
	var primero: Dictionary = proyectos[0]
	var objetivos: Array = primero.objetivos
	var fila: Control = panel._filas_proyectos[primero.id]
	verificar(tr(primero.nombre) in textos(fila) and tr(primero.premio) in textos(fila) and "0/%d" % objetivos.size() in textos(fila), "cada proyecto muestra su nombre, progreso real y premio concreto")
	verificar("no el daño parcial" in textos(panel) and not "CONQUISTADO" in panel._estado_destino("restaurante"), "la interfaz explica lo persistente y no confunde visitar con conquistar")
	Juego.registrar_objetivo_proyecto(objetivos[0].id)
	fila = panel._filas_proyectos[primero.id]
	verificar("1/%d" % objetivos.size() in textos(fila) and not Juego.proyecto_completo(primero.id), "un objeto completo actualiza la ficha sin marcar terminado todo el proyecto")
	for objetivo in objetivos:
		Juego.registrar_objetivo_proyecto(objetivo.id)
	verificar(Juego.proyecto_completo(primero.id) and "✓ " + tr(primero.nombre) in textos(panel._filas_proyectos[primero.id]), "un proyecto terminado se distingue sin un proceso por objetivo")
	Juego.registrar_meta_destino()
	verificar(not Juego.coronas_cobradas.has("restaurante") and "faltan proyectos" in panel._estado_destino("restaurante"), "devorar la meta antes del recorrido no se presenta como conquista")
	verificar("DEVORADO" in textos(panel) and "completá los proyectos" in textos(panel), "la gran meta devorada conserva una explicación de lo pendiente")
	Juego.completar_destino()
	verificar("CONQUISTADO" in panel._estado_destino("restaurante") and panel._proyectos_terminados(Juego.resumen_proyectos("restaurante")) == 4, "la corona real, no el porcentaje de la meta, cambia el destino a conquistado")
	verificar(Juego.fundar_colonia(), "la fixture tiene coronas suficientes para fundar")
	verificar(Juego.lugar_actual == "casa" and panel._filas_proyectos.is_empty(), "al fundar sólo la casa queda activa y no se le agregan proyectos")
	verificar("4/4" in textos(panel._tarjetas_destino.restaurante) and Juego.proyecto_completo(primero.id), "los cuatro proyectos históricos siguen hechos aunque el viaje vuelva a estar cerrado")
	verificar(not "CONQUISTADO" in panel._estado_destino("restaurante"), "reconquistar no se anuncia antes de cobrar la corona de la colonia nueva")
	marco.queue_free()
	await get_tree().process_frame


func probar_hud() -> void:
	preparar_restaurante()
	Juego.runs_jugadas = 8
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.radio_actual = 9500
	var hud := run.hud
	var camara_antes := run.camara.position
	hud._actualizar_meta()
	hud._actualizar_estado_recorrido()
	verificar(hud._lbl_meta_titulo.text == "PROYECTO DEL RECORRIDO" and hud._tipo_meta_actual == "proyecto", "el HUD nombra la etapa como proyecto, no como compra ni conquista")
	var actual := run.objetivo_actual()
	verificar(is_instance_valid(actual) and hud._objetivo_paso == actual and hud._boton_paso.visible, "el botón Ver usa el objeto real propuesto por la run")
	hud.mostrar_inspeccion(hud._objeto_para_inspeccion(run.objetivo_mapa))
	verificar(run.objetivo_mapa.nombre in hud._lbl_objetivo.text and hud._objeto_para_inspeccion(run.objetivo_mapa) == run.objetivo_mapa, "mirar otro objeto con el cursor conserva su inspección real, incluso si es la meta canónica")
	hud.mostrar_inspeccion(hud._objeto_para_inspeccion(null))
	verificar(actual.nombre in hud._lbl_objetivo.text and not run.objetivo_mapa.nombre in hud._lbl_objetivo.text, "sin objeto bajo el cursor la columna secundaria detalla el objetivo actual del recorrido")
	verificar(run.camara.position == camara_antes, "refrescar el objetivo nunca mueve la cámara automáticamente")
	var vida := actual.vida
	actual.vida = actual.vida_max * 0.5 # Sólo lectura de UI: no se simula una extracción ni se cobra valor.
	hud._actualizar_meta()
	verificar(not hud._barra_meta.visible and "50% devorado" in hud._lbl_meta_progreso.text and "objetos devorados" in hud._lbl_meta_progreso.text, "el porcentaje discreto reemplaza la barra de salud sin perder el progreso del proyecto")
	actual.vida = vida
	run.feromonas.mantener_en(Vector2.ZERO)
	hud._ver_paso()
	verificar(not run.feromonas.activa and run.camara.position.distance_to(actual.rect_mundo.get_center()) < 1.0, "Ver enfoca el objeto y suelta el llamado, sin comprar ni dañar")
	# Se completa por API del controlador para probar que Ver no reutiliza la
	# referencia vieja entre dos refrescos. No prueba geometría ni recompensas.
	run.recorrido.registrar_destruccion(actual)
	var siguiente := run.objetivo_actual()
	hud._ver_paso()
	verificar(siguiente != actual and hud._objetivo_paso == siguiente and run.camara.position.distance_to(siguiente.rect_mundo.get_center()) < 1.0, "Ver vuelve a resolver el objetivo si el anterior terminó entre refrescos")
	# G y el botón inferior comparten ver_objetivo: con el mouse sostenido
	# deben soltar el llamado antes del salto, igual que Ver en el panel.
	run.camara.centrar()
	run.feromonas.mantener_en(Vector2.ZERO)
	verificar(run.feromonas.activa, "la regresión de G empieza con un llamado realmente activo")
	run.camara.ver_objetivo()
	verificar(not run.feromonas.activa and run.camara.position.distance_to(siguiente.rect_mundo.get_center()) < 1.0, "G suelta las feromonas y enfoca el objetivo actual del recorrido, no la meta canónica anterior")
	Juego.registrar_meta_destino()
	hud._actualizar_estado_recorrido()
	verificar("faltan proyectos" in hud._lbl_meta.text and not "completado" in hud._lbl_meta.text, "el HUD mantiene pendiente el viaje si sólo se devoró la meta canónica")
	verificar(hud._boton_objetivo.text == "Recorrido [G]", "G y su botón identifican el recorrido, no prometen mirar siempre el monumento")
	run.queue_free()
	await get_tree().process_frame
	# Con todos los proyectos históricos hechos, la culminación sigue siendo
	# la pieza canónica real de la colonia nueva, no una ficha genérica vacía.
	preparar_restaurante()
	for objetivo: Dictionary in ProyectosCampana.objetivos_destino("restaurante"):
		Juego.registrar_objetivo_proyecto(objetivo.id)
	var final: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(final)
	final.process_mode = Node.PROCESS_MODE_DISABLED
	final.hud._actualizar_meta()
	final.hud.mostrar_inspeccion(final.hud._objeto_para_inspeccion(null))
	verificar(final.hud._tipo_meta_actual == "objetivo" and final.objetivo_actual() == final.objetivo_mapa and final.objetivo_mapa.nombre in final.hud._lbl_objetivo.text, "al terminar los proyectos, ambas columnas vuelven a la gran meta canónica")
	final.queue_free()
	await get_tree().process_frame


func probar_evoluciones() -> void:
	Juego.reiniciar_estado()
	var panel := PanelCastas.new()
	add_child(panel)
	var probadas := 0
	for id in EvolucionesHormiga.DATOS:
		var datos: Dictionary = EvolucionesHormiga.DATOS[id]
		var proyecto_id: String = datos.get("proyecto", "")
		if proyecto_id == "":
			continue
		probadas += 1
		Juego.reiniciar_estado()
		panel._seleccionar(datos.casta)
		var proyecto := ProyectosCampana.por_id(proyecto_id)
		verificar(tr(proyecto.nombre) in panel._detalle_evolucion.text and "Proyecto pendiente:" in panel._evoluciones[id].tooltip_text, id + ": la evolución explica qué proyecto falta")
		for objetivo: Dictionary in proyecto.objetivos:
			Juego.registrar_objetivo_proyecto(objetivo.id)
		verificar("Proyecto completado:" in panel._evoluciones[id].tooltip_text and panel._evoluciones[id].disabled, id + ": completar el proyecto no reemplaza los requisitos de hormigas y mandíbulas")
		Juego.reclutadas[datos.casta] = int(datos.unidades)
		Juego.niveles.mandibulas = int(datos.mandibulas)
		Juego._cache_stats.clear()
		Juego.actualizar_evoluciones()
		panel._refrescar()
		verificar(not panel._evoluciones[id].disabled and "Proyecto completado:" in panel._evoluciones[id].tooltip_text, id + ": la ficha conserva el proyecto completado al desbloquear la evolución")
	verificar(probadas == 3, "las tres evoluciones tardías tienen requisitos de proyecto visibles")
	verificar(Juego.evoluciones_equipadas.size() <= EvolucionesHormiga.MAX_EQUIPADAS, "las evoluciones nuevas no agregan espacios equipados desde la UI")
	panel.queue_free()
	await get_tree().process_frame
