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
	var anterior := await medir_silla(base.vida * Juego.stat("resistencia_muebles"), base.recompensa)
	var inicial := await medir_silla(vida_nueva, valor_nuevo)
	Juego.stats_base.vida_silla_inicial = vida_nueva
	Juego.stats_base.recompensa_silla_inicial = valor_nuevo
	Juego.reiniciar_estado()
	verificar(valor_nuevo == 420 and vida_nueva == 280 and valor_nuevo < base.recompensa, "la primera silla duplica su resistencia anterior sin subir la recompensa total")
	verificar(inicial.primer_corte >= 0 and inicial.primer_corte < 30, "ocho obreras compradas con Mandíbulas 4 muestran un primer recorte antes de treinta segundos")
	verificar(inicial.parcial, "el primer retazo deja el resto de la silla visible, sin borrar una celda entera")
	verificar(inicial.dano > 0 and inicial.vida_a_cinco >= vida_nueva * 0.5, "la silla recibe daño transportable y conserva al menos media estructura tras cinco segundos de trabajo")
	verificar(inicial.entrega_madera > 0 and inicial.primera_entrega < 20, "la madera extraída se transporta y entrega pronto; no se acredita al llamar")
	verificar(inicial.primer_corte >= 0 and (anterior.primer_corte < 0 or inicial.primer_corte <= anterior.primer_corte + Juego.stat("intervalo_mordida")), "la silla inicial permite un primer bocado legible sin exigir que una sola hormiga borre una celda")
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
	var normal_base := MaterialesCasa.definir(normal.pieza.tipo, normal.rect_mundo, normal.color)
	verificar(normal.pieza.tipo == "silla" and is_equal_approx(normal.vida_max, normal_base.vida * Juego.stat("resistencia_muebles")) and run.objetivo_mapa.nivel_requerido == 3, "las demás sillas reciben una sola vez el aumento común de resistencia y la meta exige paredes")
	verificar(is_equal_approx(normal.recompensa, normal_base.recompensa), "el aumento de resistencia de los muebles no multiplica su recompensa")
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
	# Escenario de ocho trabajadoras después de siete niveles comprados, no el
	# arranque real de una sola obrera. El bot mide cuándo se alcanza madera.
	Juego.niveles = {"mas_obreras": 7, "mandibulas": 4, "mordida_madera": 1}
	Juego._cache_stats.clear()
	seed(417)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.set_process_unhandled_input(false)
	run.feromonas.set_process_unhandled_input(false)
	var silla := primera_silla(run)
	var medicion := {"vida": vida_silla, "valor": valor_silla, "primer_corte": -1.0, "primera_entrega": -1.0, "desarmada": false, "tiempo_desarmada": -1.0, "entrega_madera": 0.0, "parcial": false, "dano": 0.0, "vida_restante": vida_silla, "vida_a_cinco": -1.0}
	# La señal se emite antes de queue_free: conservar el estado terminal aquí,
	# no intentar recuperarlo al final si la silla terminó durante la expedición.
	silla.destruida.connect(func(pieza):
		medicion.dano = pieza.dano_recibido
		medicion.vida_restante = pieza.vida
		medicion.desarmada = true
		medicion.tiempo_desarmada = run.tiempo_jugado
		run.feromonas.soltar()
	)
	var reloj := 0.0
	while not run.terminada:
		await get_tree().process_frame
		if is_instance_valid(silla):
			medicion.dano = silla.dano_recibido
			medicion.vida_restante = silla.vida
		if medicion.vida_a_cinco < 0 and run.tiempo_jugado >= 5:
			medicion.vida_a_cinco = silla.vida if is_instance_valid(silla) else 0.0
		if is_instance_valid(silla) and not silla.muerta:
			reloj -= get_process_delta_time()
			if reloj <= 0 and run.activa and not run.retirando:
				reloj = 0.25
				run.feromonas.mantener_en(silla.position)
			if medicion.primer_corte < 0 and silla.mordiscos != null and silla.vida < silla.vida_max:
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
