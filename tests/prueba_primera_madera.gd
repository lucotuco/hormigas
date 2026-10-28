extends Node
## La primera dieta debe cambiar el mapa en la expedición siguiente. Compara
## la silla anterior y el perfil inicial con la misma colonia y la misma orden.
var total := 0
var fallas := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Engine.max_fps = 0
	Engine.time_scale = 1.0
	var vida_nueva: float = Juego.stats_base.vida_silla_inicial
	var valor_nuevo: float = Juego.stats_base.recompensa_silla_inicial
	await probar_alcance_y_guardado(vida_nueva, valor_nuevo)
	var base := MaterialesCasa.definir("silla", PlanoCasa.MUEBLES[6].rect, PlanoCasa.MUEBLES[6].color)
	var anterior := await medir_silla(base.vida, base.recompensa)
	var inicial := await medir_silla(vida_nueva, valor_nuevo)
	Juego.stats_base.vida_silla_inicial = vida_nueva
	Juego.stats_base.recompensa_silla_inicial = valor_nuevo
	Juego.reiniciar_estado()
	verificar(is_equal_approx(valor_nuevo / vida_nueva, base.recompensa / base.vida) and valor_nuevo < base.recompensa, "la silla inicial conserva el valor por daño y paga menos que la anterior")
	verificar(inicial.primer_corte >= 0 and inicial.primer_corte < 15, "ocho obreras con Mandíbulas 4 quitan una sección de madera en los primeros quince segundos")
	verificar(inicial.parcial, "la primera sección deja el resto de la silla visible antes del derrumbe")
	verificar(inicial.desarmada and inicial.tiempo_desarmada < 40, "la orden sostenida permite desarmar la primera silla dentro de una expedición inicial")
	verificar(inicial.entrega_madera > 0 and inicial.primera_entrega < 20, "la madera extraída se transporta y entrega pronto; no se acredita al llamar")
	verificar(not anterior.desarmada or inicial.tiempo_desarmada < anterior.tiempo_desarmada, "la misma colonia muestra el desbloqueo antes que con la silla de resistencia anterior")
	print("MADERA CONTROL: %s" % JSON.stringify(anterior))
	print("MADERA INICIAL: %s" % JSON.stringify(inicial))
	print("Primera madera: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)

func probar_alcance_y_guardado(vida_nueva: float, valor_nuevo: float) -> void:
	Juego.reiniciar_estado()
	var run := crear_run()
	var silla := primera_silla(run)
	verificar(silla.nivel_requerido == 1 and not silla.disponible(), "la silla inicial sigue bloqueada hasta comprar madera")
	verificar(silla.en_territorio(Juego.stat("radio_territorio")), "la primera silla ya está al alcance del territorio inicial")
	var normal := run.comidas.partes[7]
	verificar(normal.pieza.tipo == "silla" and normal.vida_max >= 700 and run.objetivo_mapa.nivel_requerido == 3, "las demás sillas y el requisito del gran objetivo mantienen su escala")
	verificar(is_equal_approx(silla.vida_max, vida_nueva) and is_equal_approx(silla.recompensa, valor_nuevo), "el perfil de la silla usa los valores del CSV")
	var perfiles := 0
	for parte in run.comidas.partes:
		if parte.pieza.get("perfil", "") == "silla_inicial":
			perfiles += 1
	verificar(perfiles == 1 and run.objetivo_practica.nivel_requerido == 0 and is_equal_approx(run.objetivo_practica.vida_max, 20), "el perfil pertenece a una sola silla y no cambia el tutorial de cartón")
	run.queue_free()
	await get_tree().process_frame
	# No se agrega estado persistente: las partidas anteriores sólo traían dietas.
	Juego.reiniciar_estado()
	Juego.restaurar_partida({"runs_jugadas": 8, "niveles": {"mandibulas": 4, "mordida_madera": 1}})
	run = crear_run()
	silla = primera_silla(run)
	verificar(silla.disponible() and is_equal_approx(silla.vida_max, vida_nueva), "una partida vieja conserva madera y recibe la silla inicial sin migrar campos")
	var punto := silla.punto_mordida(Vector2.ZERO, run.radio_actual)
	verificar(punto != Vector2.INF and not run.cocina.ruta(Vector2.ZERO, punto, run.radio_actual).is_empty(), "la silla tiene un borde alcanzable desde el nido")
	run.queue_free()
	await get_tree().process_frame
	Juego.lugar_actual = "restaurante"
	run = crear_run()
	var perfil_filtrado := true
	for parte in run.comidas.partes:
		perfil_filtrado = perfil_filtrado and parte.pieza.get("perfil", "") == ""
	verificar(perfil_filtrado, "los muebles de otros destinos nunca heredan el perfil inicial de la casa")
	run.queue_free()
	await get_tree().process_frame

func medir_silla(vida_silla: float, valor_silla: float) -> Dictionary:
	Juego.reiniciar_estado()
	Juego.stats_base.vida_silla_inicial = vida_silla
	Juego.stats_base.recompensa_silla_inicial = valor_silla
	Juego.niveles = {"mandibulas": 4, "mordida_madera": 1}
	Juego._cache_stats.clear()
	seed(417)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.set_process_unhandled_input(false)
	run.feromonas.set_process_unhandled_input(false)
	var silla := primera_silla(run)
	var secciones := silla.vivas.size()
	var medicion := {"vida": vida_silla, "valor": valor_silla, "primer_corte": -1.0, "primera_entrega": -1.0, "desarmada": false, "tiempo_desarmada": -1.0, "entrega_madera": 0.0, "parcial": false}
	var reloj := 0.0
	while not run.terminada:
		await get_tree().process_frame
		if is_instance_valid(silla) and not silla.muerta:
			reloj -= get_process_delta_time()
			if reloj <= 0 and run.activa and not run.retirando:
				reloj = 0.25
				run.feromonas.mantener_en(silla.position)
			if medicion.primer_corte < 0 and silla.vivas.size() < secciones:
				medicion.primer_corte = run.tiempo_jugado
				medicion.parcial = silla.vida > 0 and not silla.derrumbando
		elif not medicion.desarmada:
			medicion.desarmada = true
			medicion.tiempo_desarmada = run.tiempo_jugado
			run.feromonas.soltar()
		if medicion.primera_entrega < 0 and run.ingresos[1] > 0:
			medicion.primera_entrega = run.tiempo_jugado
	medicion.entrega_madera = run.ingresos[1]
	run.queue_free()
	await get_tree().process_frame
	return medicion

func crear_run() -> Run:
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	return run

func primera_silla(run: Run) -> PiezaCasa:
	for parte in run.comidas.partes:
		if parte.pieza.clave == "mueble:6":
			return parte
	return null

func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)
