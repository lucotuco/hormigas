extends Node
## Regresión física del atajo, no piloto de duración. El caso de desarme
## declara una colonia de prueba con mejoras existentes; jamás cambia HP,
## recompensa, retazos ni daña un objetivo desde el script de la fixture.
const RUN := preload("res://mundo/run.tscn")
const PASO := 1.0 / 60.0
const OBJETIVO := "casa/silla_inicial"
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Engine.time_scale = 1
	var partida := huella(Juego.RUTA_PARTIDA)
	var ajustes := huella(Ajustes.RUTA)
	await probar_inicio_y_metas()
	await probar_desarmado_fisico()
	await probar_cierre()
	await probar_historica()
	verificar(partida == huella(Juego.RUTA_PARTIDA) and ajustes == huella(Ajustes.RUTA),
		"las escenas y la restauración conservan partida y preferencias personales")
	Juego.reiniciar_estado()
	print("Recorrido de casa: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func huella(ruta: String) -> String:
	return FileAccess.get_sha256(ruta) if FileAccess.file_exists(ruta) else "ausente"


func crear() -> Run:
	seed(417)
	var run: Run = RUN.instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	# El desarme usa el preparador normal distribuido. El renderer no es
	# necesario: cabeza, máscara y atlas físico existen también en headless.
	run.eventos._reloj_amenaza = 1e9
	run.eventos._reloj_dorada = 1e9
	return run


func silla_inicial(run: Run) -> PiezaCasa:
	for parte in run.comidas.partes:
		if parte.pieza.get("perfil", "") == "silla_inicial":
			return parte
	return null


func inventario_alimentos(run: Run) -> Dictionary:
	var masa := 0.0
	var valor := 0.0
	var cantidad := 0
	var por_semilla: Dictionary = {}
	for comida in run.comidas.lista:
		masa += comida.vida_max
		valor += comida.recompensa
		cantidad += 1
		por_semilla[comida.semilla_dibujo] = {"masa": comida.vida_max, "valor": comida.recompensa}
	for hallazgo: Dictionary in run.comidas._hallazgos.values():
		masa += float(hallazgo.contenido.vida)
		valor += float(hallazgo.contenido.recompensa)
		# El contenido comparte una fuente ya contabilizada, no otro objeto.
	if not run.comidas._comida_atajo.is_empty():
		var reserva: Dictionary = run.comidas._comida_atajo
		masa += float(reserva.tipo.vida)
		valor += float(reserva.tipo.recompensa)
		cantidad += 1
		por_semilla[reserva.semilla] = {"masa": reserva.tipo.vida, "valor": reserva.tipo.recompensa}
	return {"masa": masa, "valor": valor, "cantidad": cantidad, "por_semilla": por_semilla}


func probar_inicio_y_metas() -> void:
	Juego.reiniciar_estado()
	var antes := Juego.datos_partida()
	var meta := Juego.proxima_meta()
	verificar(meta.id == "mas_obreras" and Juego.stat("hormigas_iniciales") == 1,
		"una sola obrera sugiere primero una segunda trabajadora, no subir una dieta lejana")
	verificar(Juego.datos_partida() == antes, "consultar la próxima compra no compra ni revela ni completa progreso")
	var run := crear()
	var silla := silla_inicial(run)
	verificar(silla != null and not silla.disponible() and not run.cocina.segmento_libre(Vector2.ZERO, PlanoCasa.PREMIO_ATAJO),
		"la silla nativa bloquea el segmento del nido hacia el premio y exige madera")
	verificar(run.comidas._comida_atajo.size() == 2 and not run.comidas._comida_atajo.tipo.is_empty()
		and run.comidas._comida_atajo.tipo.id == "galletita", "hay una galletita nativa reservada, no una copia visible adicional")
	var migas := 0
	var cercanas := 0
	for comida in run.comidas.lista:
		if comida.id == "miga":
			migas += 1
			cercanas += int(comida.has_meta("inicio_casa"))
	verificar(migas == 138 and cercanas == 6, "la entrada redistribuye seis de las mismas 138 migas sin agregar alimentos")
	verificar(run.casa.meta().is_empty(), "la primera hormiga no recibe una promesa de abrir sola la silla o el paquete")
	Juego.niveles = {"mas_obreras": 1}
	Juego._cache_stats.clear()
	var paquete := run.casa.meta()
	verificar(paquete.get("id", "") == "primer_paquete" and is_instance_valid(paquete.get("objetivo")),
		"dos hormigas sugieren un paquete real alcanzable, no una recompensa por mirar el cartel")
	Juego.niveles = {"mas_obreras": 1, "mandibulas": 3, "mordida_rapida": 1, "mordida_madera": 1}
	Juego._cache_stats.clear()
	var sugerida := run.casa.meta()
	verificar(sugerida.get("id", "") == "silla_atajo" and sugerida.get("objetivo") == silla,
		"aprender madera conecta una escena concreta con la silla existente")
	var estado := Juego.datos_partida()
	for i in 20:
		run.casa.meta()
	verificar(Juego.datos_partida() == estado and not silla.muerta and run.comidas._comida_atajo.size() == 2,
		"ver una etapa repetidamente no consume la silla, paga ni libera la comida")
	run.queue_free()
	await get_tree().process_frame


func configurar_colonia_de_prueba() -> void:
	Juego.reiniciar_estado()
	# Capacidad declarada para aislar conservación/IA, no una campaña comprada
	# con ingresos falsos ni una estimación del tiempo de un jugador nuevo.
	Juego.niveles = {"mas_obreras": 23, "mandibulas": 20, "mordida_rapida": 12,
		"mordida_madera": 1, "buche": 10, "patas_largas": 12, "reservas": 12,
		"segundo_aire": 5, "rastro_persistente": 8, "antenas": 1, "pisoton": 8}
	Juego._cache_stats.clear()


func paso(run: Run) -> void:
	run._process(PASO)
	run.cocina.procesar_cambios()
	run.preparador_mordiscos.procesar()
	run.cola_erosion.procesar()
	run.feromonas._process(PASO)
	run.colonia._process(PASO)
	for h in run.colonia.hormigas:
		h._process(PASO)
	# El resto de la escena queda congelado: sin daño ambiental, premios ni
	# amenazas que puedan terminar el mueble por fuera de las trabajadoras.
	for parte in run.comidas.partes.duplicate():
		if is_instance_valid(parte):
			parte._process(PASO)
	run.hud._process(PASO)
	await get_tree().process_frame


func probar_desarmado_fisico() -> void:
	configurar_colonia_de_prueba()
	var run := crear()
	var silla := silla_inicial(run)
	var inicial := inventario_alimentos(run)
	var reservada: Dictionary = run.comidas._comida_atajo.duplicate(true)
	var vida := silla.vida_max
	var valor := silla.recompensa
	var resultado := {"aperturas": 0, "masa_al_abrir": 0.0, "valor_al_abrir": 0.0,
		"contador_al_abrir": 0, "saldo_al_abrir": 0.0, "carga_al_abrir": 0.0,
		"semilla": 0, "premio": null}
	run.comidas.atajo_abierto.connect(func(comida: Comida) -> void:
		resultado.aperturas += 1
		resultado.premio = comida
		var inventario := inventario_alimentos(run)
		resultado.masa_al_abrir = inventario.masa
		resultado.valor_al_abrir = inventario.valor
		resultado.contador_al_abrir = inventario.cantidad
		resultado.saldo_al_abrir = Juego.migas_run
		resultado.semilla = comida.semilla_dibujo
		for h in run.colonia.hormigas:
			resultado.carga_al_abrir += h.carga
	)
	var primer_hueco := false
	for i in 9000:
		if resultado.aperturas > 0 or run.terminada:
			break
		if is_instance_valid(silla) and not silla.muerta:
			run.feromonas.mantener_en(silla.position)
		await paso(run)
		if is_instance_valid(silla) and silla.vida < vida:
			primer_hueco = true
	verificar(primer_hueco and resultado.aperturas == 1 and (not is_instance_valid(silla) or silla.muerta),
		"las hormigas recortan y terminan la silla mediante IA y mordidas físicas, sin daño de fixture")
	if resultado.aperturas == 0:
		run.queue_free()
		await get_tree().process_frame
		return
	verificar(ComponentesProyecto.objetivo_terminado(OBJETIVO, Juego.componentes_proyecto_devorados)
		and run.cocina.segmento_libre(Vector2.ZERO, PlanoCasa.PREMIO_ATAJO),
		"sólo terminar toda la silla conserva su marca y abre el segmento transitable real")
	verificar(is_equal_approx(resultado.masa_al_abrir, inicial.masa)
		and is_equal_approx(resultado.valor_al_abrir, inicial.valor)
		and resultado.contador_al_abrir == inicial.cantidad and resultado.semilla == reservada.semilla,
		"aparecer repone la misma galletita, masa, valor, cantidad y semilla; no crea otro alimento")
	var premio: Comida = resultado.premio
	verificar(is_instance_valid(premio) and premio.position == PlanoCasa.PREMIO_ATAJO
		and is_equal_approx(premio.vida_max, reservada.tipo.vida)
		and is_equal_approx(premio.recompensa, reservada.tipo.recompensa),
		"la comida del camino conserva HP y recompensa del catálogo sin un multiplicador nuevo")
	var carga_madera := 0.0
	for h in run.colonia.hormigas:
		carga_madera += h._carga_origen[1]
	var bonus_normal := valor * Juego.stat("bonus_destruir") * Juego.stat("multiplicador_migas")
	verificar(is_equal_approx(run.ingresos[1] + carga_madera - bonus_normal, valor * Juego.stat("multiplicador_migas")),
		"toda la silla está entre cargas y entregas, más sólo su bonus normal; descubrir el atajo no paga")
	verificar(run.casa.meta().get("id", "") == "galletita_atajo" and run.casa.meta().get("objetivo") == premio,
		"la sugerencia pasa de desarmar la silla a transportar su hallazgo físico")
	var cuenta := Juego.migas_run
	var vida_premio := premio.vida
	for i in 30:
		run.casa.meta()
	verificar(Juego.migas_run == cuenta and premio.vida == vida_premio,
		"leer la nueva meta no come ni cobra la galletita")
	var guardada := Juego.datos_partida()
	run._cerrar()
	run.queue_free()
	await get_tree().process_frame
	Juego.restaurar_partida(guardada)
	var restaurada := crear()
	verificar(silla_inicial(restaurada) == null and restaurada.comidas._comida_atajo.is_empty()
		and restaurada.cocina.segmento_libre(Vector2.ZERO, PlanoCasa.PREMIO_ATAJO),
		"restaurar conserva la silla entera devorada, el paso y un único premio, no daño parcial")
	var saldo_antes := Juego.migas
	Juego.coronas = 1 # Fixture administrativa de retorno, no conquista fingida.
	verificar(Juego.fundar_colonia() and ComponentesProyecto.objetivo_terminado(OBJETIVO, Juego.componentes_proyecto_devorados)
		and Juego.lugar_actual == "casa", "fundar vuelve a casa y conserva sólo la consecuencia realmente terminada")
	verificar(Juego.migas <= saldo_antes, "fundar o conservar el camino no vuelve a pagar la silla ni la comida")
	restaurada.queue_free()
	await get_tree().process_frame


func probar_cierre() -> void:
	configurar_colonia_de_prueba()
	var run := crear()
	var silla := silla_inicial(run)
	var vida := silla.vida
	var reserva: Dictionary = run.comidas._comida_atajo.duplicate(true)
	run._cerrar()
	run.comidas._abrir_atajo(silla)
	verificar(silla.vida == vida and run.comidas._comida_atajo == reserva
		and not ComponentesProyecto.objetivo_terminado(OBJETIVO, Juego.componentes_proyecto_devorados) and run.casa.meta().is_empty(),
		"el cierre no consume silla ni reserva y rechaza aperturas o nuevas sugerencias tardías")
	run.queue_free()
	await get_tree().process_frame


func probar_historica() -> void:
	Juego.reiniciar_estado()
	Juego.restaurar_partida({"version": 10, "destinos": {"casa": true}, "migas": 93.0,
		"niveles": {"mandibulas": 2}})
	var run := crear()
	verificar(Juego.migas == 93 and Juego.nivel_de("mandibulas") == 2 and run.comidas._comida_atajo.is_empty()
		and run.casa.meta().is_empty(), "una casa histórica no exige otra vez la escena ni retiene una nueva galletita")
	Juego.niveles.clear()
	Juego._cache_stats.clear()
	verificar(Juego.proxima_meta().get("id", "") != "mas_obreras", "una casa histórica no vuelve a ofrecer la primera compra aunque no conserve niveles")
	run.queue_free()
	await get_tree().process_frame


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("OK " if ok else "FALLA ", mensaje)
