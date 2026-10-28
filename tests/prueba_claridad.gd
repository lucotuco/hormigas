extends Node
## Vista previa sin mutaciones, decisiones legibles y tutorial sobre madera real.
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
	probar_previa()
	await probar_ventana()
	await probar_pasos()
	await probar_indicador()
	Juego.reiniciar_estado()
	print("Claridad: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)

func preparar_colonia() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mas_obreras": 8, "mandibulas": 10, "mordida_madera": 1, "mordida_resistente": 1}
	Juego.niveles_jalea = {"herencia_madera": 1, "herencia_resistente": 1, "linaje": 1, "despensa": 2, "obreras_reales": 2, "jalea_dano": 2, "jalea_migas": 1}
	Juego.reclutadas = {"veloz": 7, "roja": 4, "reina": 1}
	Juego.lugares_completados = {"casa": true}
	Juego.hitos = {"primer_tesoro": true}
	Juego.migas = 12345
	Juego.migas_colonia = 1.6e6
	Juego.legado = 14
	Juego.jalea = 3
	Juego.coronas = 2
	Juego.decreto = "recolectora"
	Juego._cache_stats.clear()

func probar_previa() -> void:
	for decreto in ["numerosa", "guerrera", "recolectora", "exploradora", "invalido"]:
		preparar_colonia()
		Juego.stat("dano")
		var antes := Juego.datos_partida().duplicate(true)
		var cache := Juego._cache_stats.duplicate(true)
		var previa := Juego.vista_previa_fundar(decreto)
		verificar(Juego.datos_partida() == antes and Juego._cache_stats == cache, "%s: consultar no altera partida, moneda ni caché" % decreto)
		verificar(Juego.fundar_colonia(decreto), "%s: la fundación real es posible" % decreto)
		var iguales: bool = previa.castas == Juego.reclutadas and is_equal_approx(previa.migas, Juego.migas) and previa.jalea == Juego.jalea
		for nombre in previa.stats:
			iguales = iguales and is_equal_approx(previa.stats[nombre], Juego.stat(nombre))
		verificar(iguales, "%s: la vista previa coincide con el arranque real y todas sus herencias" % decreto)
	Juego.reiniciar_estado()
	Juego.migas_colonia = 100000
	var nueva := Juego.vista_previa_fundar("numerosa")
	verificar(int(nueva.stats.materiales) == 0 and nueva.castas.is_empty(), "la previa no compra memorias ni castas con jalea todavía sin gastar")

func probar_ventana() -> void:
	preparar_colonia()
	var ventana := VentanaFundar.new()
	add_child(ventana)
	await get_tree().process_frame
	ventana.elegir("numerosa")
	var numerosa := ventana._lbl_inicio.text
	ventana.elegir("recolectora")
	verificar(numerosa != ventana._lbl_inicio.text and "Dieta inicial:" in numerosa, "cambiar decreto muestra el arranque concreto antes de confirmar")
	verificar(ventana._boton_fundar.is_visible_in_tree(), "la confirmación queda fuera del scroll de detalles")
	ventana.queue_free()
	await get_tree().process_frame
	var panel := PanelCastas.new()
	add_child(panel)
	await get_tree().process_frame
	for id in panel._filas:
		panel._seleccionar(id)
		verificar(not panel._equipo.text.is_empty(), "%s tiene un consejo sobre su conducta y compañeros" % id)
	panel.queue_free()
	await get_tree().process_frame

func probar_pasos() -> void:
	Juego.reiniciar_estado()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	verificar(run.hud._boton_paso.visible and run.hud._objetivo_paso == run.objetivo_practica, "el primer paso permite encontrar el cartón sin dar una orden automática")
	# El tutorial tiene forma de silla, pero no debe dar el premio de madera real.
	run._on_comida_destruida(run.objetivo_practica)
	verificar(not Juego.hitos.has("primera_silla") and run._sillas_devoradas == 0, "el cartón no completa hitos de sillas de madera")
	Juego.niveles.mordida_madera = 1
	Juego._cache_stats.clear()
	run.hud._actualizar_meta()
	verificar(run.hud._lbl_meta_nombre.text == "Tu primera silla de madera" and run.hud._boton_paso.visible, "comprar madera propone una demostración visible antes de la próxima dieta")
	var silla := run.hud._objetivo_paso
	run.feromonas.mantener_en(Vector2.ZERO)
	run.hud._ver_paso()
	verificar(run.camara.position == silla.position and not run.feromonas.activa, "Ver encuadra el mueble sin dañarlo ni dejar feromonas pulsadas")
	run._on_comida_destruida(silla)
	verificar(Juego.hitos.has("primera_silla"), "la silla real sí concede su hito")
	run.hud._actualizar_meta()
	verificar(not run.hud._boton_paso.visible, "el paso no se sigue ofreciendo después de completarlo")
	run.queue_free()
	await get_tree().process_frame

func probar_indicador() -> void:
	Juego.reiniciar_estado()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	var indicador: HUD.IndicadorEventos
	for n in run.hud.get_child(0).get_children():
		if n is HUD.IndicadorEventos:
			indicador = n
	var evento: Evento = run.eventos.aparecer("paloma")[0]
	evento.position = Vector2(900, 900)
	indicador.etiquetas.assign([Rect2(10, 160, 230, 48)])
	indicador._eventos.assign([evento])
	verificar(indicador._has_point(Vector2(40, 180)) and not indicador._has_point(Vector2(500, 400)), "sólo las tarjetas capturan el mouse, no el mapa de fondo")
	run.feromonas.mantener_en(Vector2.ZERO)
	verificar(indicador.enfocar(0) and run.camara.position == evento.position and not run.feromonas.activa, "el aviso encuentra la paloma y libera la orden anterior")
	verificar(not evento.resuelto, "enfocar no espanta ni cobra el evento: hay que interactuar en el mapa")
	evento.resuelto = true
	verificar(not indicador.enfocar(0) and not indicador.enfocar(12), "los indicadores obsoletos no enfocan eventos terminados")
	run.queue_free()
	await get_tree().process_frame
