extends Node
## Primer rebirth con una fixture de casa conquistada: decisiones con siete
## de jalea, sin regalar mejoras ni hacer daño manual. La fórmula paga el saldo.
## No calibra la campaña: simula sólo la primera expedición de cada arranque.
const RUN := preload("res://mundo/run.tscn")
const SALDO_COMPARADO := 7
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Engine.max_fps = 0
	Engine.time_scale = 1.0
	Juego.reiniciar_estado()
	var primera := await medir_expedicion()
	verificar(primera.dieta == 0 and not primera.silla, "el primer arranque no permite desarmar madera antes de aprenderla")
	verificar(primera.obreras == 1 and primera.migas > 0, "una sola obrera extrae y transporta recursos sin daño por clic")
	var cantidad_inicial := int(Juego.stats_base.hormigas_iniciales)
	var dano_inicial := float(Juego.stats_base.dano)
	preparar_primera_fundacion()
	comprar_barato()
	var barata := await medir_expedicion()
	verificar(barata.dieta == 0 and not barata.silla, "gastar sólo en lo más barato no inventa una dieta heredada")
	verificar(barata.obreras > cantidad_inicial and barata.dano > dano_inicial and barata.migas > primera.migas, "incluso sin atajo, el legado y las compras hacen más fuerte el retorno")
	var plan_jalea: Array[String] = ["herencia_madera", "obreras_reales", "jalea_dano"]
	var vista := preparar_primera_fundacion(plan_jalea)
	var gastado: int = vista.costo_jalea
	for id in plan_jalea:
		verificar(Juego.nivel_jalea(id) == 1, "el plan confirmado compra una sola vez %s" % id)
	verificar(Juego.jalea == SALDO_COMPARADO - gastado and Juego.legado == SALDO_COMPARADO, "el plan descuenta cada precio y gastar no reduce el legado")
	verificar(Juego.migas == 0 and Juego.reclutadas.is_empty() and Juego.nivel_de("mandibulas") == 0, "el plan no regala migas, especialistas ni mejoras de la colonia anterior")
	var plan := await medir_expedicion()
	verificar(plan.dieta == 1 and plan.primer_corte >= 0 and plan.madera_transportada > 0, "la cuadrilla de regreso ya recorta madera y la transporta en la primera expedición")
	verificar(plan.obreras > cantidad_inicial and plan.dano > dano_inicial, "el retorno conserva crecimiento medible aunque se priorice el atajo")
	verificar(plan.migas > primera.migas and plan.madera_transportada > 0, "el plan cobra madera realmente transportada y supera al arranque desde cero")
	verificar(plan.migas_antes == 0 and plan.pendiente >= 0, "las ganancias sólo aparecen durante la expedición; las cargas pendientes no se acreditan")
	preparar_primera_fundacion(["herencia_madera"], 7)
	verificar(Juego.jalea == 4 and Juego.nivel_jalea("obreras_reales") == 0, "con siete de jalea se puede elegir sólo memoria sin comprar una cuadrilla oculta")
	var memoria := await medir_expedicion()
	verificar(memoria.dieta == 1 and memoria.dano_silla > 0 and memoria.madera_transportada > 0, "el plan accesible de memoria sola ya muerde y transporta madera en el primer regreso, aunque no quite una celda completa")
	await probar_partida_vieja()
	print("ARRANQUE DESDE CERO: %s" % JSON.stringify(primera))
	print("RETORNO COMPRA BARATA: %s" % JSON.stringify(barata))
	print("RETORNO PLAN CUADRILLA, SIETE DE JALEA: %s" % JSON.stringify(plan))
	print("RETORNO SÓLO MEMORIA, SIETE DE JALEA: %s" % JSON.stringify(memoria))
	Juego.reiniciar_estado()
	print("Primera fundación y retorno: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func preparar_primera_fundacion(compras: Array[String] = [], saldo := SALDO_COMPARADO) -> Dictionary:
	Juego.reiniciar_estado()
	# Fixture de una casa terminada: la fórmula vigente aporta 3 por la corona
	# y el resto por las migas acumuladas. Se obtiene el saldo fundando por API.
	Juego.migas_colonia = pow(maxi(0, saldo - 3), 4) * Juego.DIVISOR_JALEA_MIGAS
	Juego.completar_destino()
	var vista := Juego.vista_previa_fundar("numerosa", compras)
	verificar(Juego.jalea_por_fundar() == saldo and Juego.fundar_colonia("numerosa", compras), "una primera casa conquistada funda con el saldo previsto de %d jalea" % saldo)
	verificar(Juego.lugar_actual == "casa" and not Juego.destino_desbloqueado("restaurante") and Juego.lugares_completados.has("casa"), "se vuelve a casa sin perder la conquista histórica ni saltar la reconquista")
	verificar(vista.plan_valido and Juego.jalea == vista.jalea and Juego.stat("materiales") == vista.stats.materiales and Juego.stat("hormigas_iniciales") == vista.stats.hormigas_iniciales, "confirmar respeta exactamente el saldo, las dietas y las obreras de la vista previa")
	return vista


func comprar_barato() -> void:
	for vuelta in 100:
		var elegida := ""
		var precio := 1 << 62
		for nodo in Juego.nodos_jalea:
			if Juego.puede_comprar_jalea(nodo.id) and Juego.costo_jalea(nodo.id) < precio:
				elegida = nodo.id
				precio = Juego.costo_jalea(nodo.id)
		if elegida == "":
			return
		Juego.comprar_jalea(elegida)


func medir_expedicion() -> Dictionary:
	seed(417)
	var migas_antes := Juego.migas
	var r: Run = RUN.instantiate()
	add_child(r)
	r.set_process_unhandled_input(false)
	r.feromonas.set_process_unhandled_input(false)
	var silla: PiezaCasa
	for parte in r.comidas.partes:
		if parte.pieza.get("perfil", "") == "silla_inicial":
			silla = parte
	var resultado := {"migas_antes": migas_antes, "obreras": int(Juego.stat("hormigas_iniciales")), "dano": Juego.stat("dano"), "dieta": int(Juego.stat("materiales")), "duracion": r.duracion_total, "silla": false, "tiempo_silla": -1.0, "primer_corte": -1.0, "carton": false, "madera_transportada": 0.0, "dano_silla": 0.0}
	var bonus_muebles := [0.0]
	r.comidas.comida_destruida.connect(func(comida):
		if comida is PiezaCasa:
			if comida.nivel_requerido < 3:
				bonus_muebles[0] += comida.recompensa * Juego.stat("bonus_destruir") * Juego.stat("multiplicador_migas")
			if comida.pieza.get("practica", false):
				resultado.carton = true
	)
	var reloj := 0.0
	while not r.terminada:
		await get_tree().process_frame
		if not resultado.silla and (not is_instance_valid(silla) or silla.muerta):
			resultado.silla = true
			resultado.tiempo_silla = r.tiempo_jugado
		elif is_instance_valid(silla) and resultado.primer_corte < 0 and silla.mordiscos != null and silla.vida < silla.vida_max:
			resultado.primer_corte = r.tiempo_jugado
		reloj -= get_process_delta_time()
		if reloj > 0 or not r.activa or r.retirando:
			continue
		reloj = 0.5
		if is_instance_valid(silla) and silla.disponible():
			# Se prueba la memoria de madera directamente, no terminar primero
			# el cartón gigante. El cursor señala el recurso, no su acceso externo.
			r.feromonas.mantener_en(silla.position)
		else:
			r.feromonas.soltar()
	resultado.migas = Juego.migas_run
	if is_instance_valid(silla):
		resultado.dano_silla = silla.dano_recibido
	resultado.pendiente = r.cargas_pendientes
	resultado.madera_transportada = maxf(0, r.ingresos[1] - bonus_muebles[0])
	r.queue_free()
	await get_tree().process_frame
	return resultado


func probar_partida_vieja() -> void:
	Juego.reiniciar_estado()
	Juego.restaurar_partida({"version": 6, "runs_jugadas": 21, "fundaciones": 1, "legado": 10, "jalea": 2,
		"destinos": {"casa": true}, "coronas_cobradas": {}, "lugar": "casa", "decreto": "numerosa",
		"niveles": {"mordida_madera": 1}, "niveles_jalea": {"herencia_madera": 1, "obreras_reales": 1, "jalea_dano": 1, "jalea_migas": 1}})
	verificar(Juego.stat("materiales") == 1 and Juego.jalea == 2 and Juego.legado == 10, "una partida anterior conserva memoria, saldo y legado sin campos nuevos obligatorios")
	var r: Run = RUN.instantiate()
	add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	var silla_disponible := false
	for parte in r.comidas.partes:
		if parte.pieza.get("perfil", "") == "silla_inicial":
			silla_disponible = parte.disponible()
	verificar(silla_disponible and Juego.stat("entradas") >= 1 and r.entradas.puntos.has(Vector2.ZERO), "el arranque antiguo conserva madera y su acceso permanente, que abre al alcanzar otro ambiente")
	r.queue_free()
	await get_tree().process_frame


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)
