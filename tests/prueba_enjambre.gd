extends Node
## IA cooperativa, evoluciones y reglas de destino, sin tocar el guardado.
var total := 0
var fallas := 0
const RUN := preload("res://mundo/run.tscn")

func _ready() -> void:
	Juego.guardado_habilitado = false
	Sonido.silenciado = true
	seed(417)
	probar_guardado()
	await probar_trabajo()
	await probar_habilidades()
	await probar_destinos()
	await probar_tutorial()
	Juego.reiniciar_estado()
	print("Enjambre: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)

func crear(destino := "casa") -> Run:
	Juego.lugar_actual = destino
	var r: Run = RUN.instantiate()
	add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	r.radio_actual = 12000
	return r

func verificar(ok: bool, texto: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", texto)

func probar_guardado() -> void:
	Juego.reiniciar_estado()
	Juego.restaurar_partida({"version": 4, "migas": 123, "niveles": {"pisada": 3, "mandibulas": 8}, "reclutadas": {"carpintera": 1, "roja": 3, "cargadora": 3, "reina": 1}})
	verificar(Juego.migas == 123 and Juego.nivel_de("pisada") == 3, "la migración conserva compras antiguas y migas")
	verificar(Juego.evoluciones_desbloqueadas.size() == 4 and Juego.evoluciones_equipadas.size() == 2, "los requisitos desbloquean cuatro variantes pero sólo equipan dos")
	var saldo := Juego.migas
	verificar(not Juego.alternar_evolucion("barrido"), "no permite una tercera evolución simultánea")
	verificar(Juego.alternar_evolucion("corte") and Juego.alternar_evolucion("barrido") and Juego.migas == saldo, "cambiar el equipo es gratuito y no borra compras")
	var datos: Dictionary = JSON.parse_string(JSON.stringify(Juego.datos_partida()))
	Juego.reiniciar_estado()
	Juego.restaurar_partida(datos)
	verificar(Juego.evolucion_activa("barrido") and not Juego.evolucion_activa("corte"), "el equipo elegido sobrevive al guardado")
	Juego.coronas = 1
	verificar(Juego.fundar_colonia() and Juego.evoluciones_desbloqueadas.size() == 4 and Juego.evolucion_activa("barrido"), "fundar conserva los desbloqueos y el equipo elegido")
	Juego.restaurar_partida({"evoluciones": {"corte": true, "inventada": true}, "equipadas": ["corte", "corte", "inventada"]})
	verificar(Juego.evoluciones_equipadas == ["corte"] and Juego.evoluciones_desbloqueadas.size() == 1, "al cargar valida IDs y descarta duplicados")

func probar_trabajo() -> void:
	Juego.reiniciar_estado()
	var r := crear()
	var c: Comida = r.comidas.lista[0]
	var a := r.colonia._nacer()
	var b := r.colonia._nacer()
	a.comida = c
	a.comida = c
	b.comida = c
	verificar(c.trabajadoras == 2, "una reserva se cuenta una sola vez por hormiga")
	a.detener()
	verificar(c.trabajadoras == 1, "detener libera su puesto de trabajo")
	r.colonia.hormigas.erase(b)
	b.queue_free()
	await get_tree().process_frame
	verificar(c.trabajadoras == 0, "eliminar la hormiga también libera su puesto")
	c.trabajadoras = c.cupos_trabajo()
	verificar(r.comidas.buscar_cercana(c.position, 1, r.radio_actual, {}, "obrera") != c, "la búsqueda automática no satura una miga ocupada")
	c.trabajadoras = 0
	r.colonia.avistar(c)
	r.colonia.avistar(c)
	verificar(r.colonia._hallazgos.size() == 1 and r.colonia.trabajo_conocido(c.position + Vector2(200, 0), "obrera", {}) == c, "comparte un hallazgo más allá del olfato local, sin duplicarlo")
	c.trabajadoras = c.cupos_trabajo()
	verificar(r.colonia.trabajo_conocido(c.position, "obrera", {}) == null, "la memoria compartida respeta los puestos ocupados")
	c.trabajadoras = 0
	r.feromonas.mantener_en(c.position)
	a.estado = Hormiga.Estado.EXPLORANDO
	a.carga = 0
	r.feromonas._actualizar_cercanas()
	a._pensar()
	verificar(a.comida == c and a.estado in [Hormiga.Estado.SIGUIENDO, Hormiga.Estado.MORDIENDO], "el llamado toma prioridad sobre el trabajo automático")
	r.feromonas.soltar()
	verificar(not r.feromonas.llama_a(a) and r.feromonas.seleccionadas.is_empty(), "soltar borra la orden y su selección")
	Juego.niveles.mordida_madera = 1
	Juego._cache_stats.clear()
	var silla: PiezaCasa = r.comidas.partes[6]
	a.position = silla.rect_mundo.position - Vector2(100, 100)
	a.comida = silla
	a.estado = Hormiga.Estado.YENDO_A_COMIDA
	a._pensar()
	var puesto := a.objetivo
	a.position += Vector2(30, 30)
	r.cocina.version += 1 # Simular la apertura de una pieza lejana.
	a._pensar()
	verificar(a.objetivo == puesto, "abrir otra pieza no cambia el frente de una hormiga que ya se acerca a trabajar")
	silla.derrumbando = true
	a.estado = Hormiga.Estado.MORDIENDO
	a.carga = 0
	a._morder(0.1)
	verificar(a.comida == null and silla.trabajadoras == 0 and a.estado == Hormiga.Estado.EXPLORANDO, "un mueble que entra en derrumbe libera el puesto sin mordidas ni regresos vacíos")
	r.queue_free()
	await get_tree().process_frame

func probar_habilidades() -> void:
	Juego.reiniciar_estado()
	Juego.evoluciones_desbloqueadas = {"camada": true, "barrido": true, "corte": true, "contagio": true}
	Juego.evoluciones_equipadas.assign(["camada", "barrido"])
	var r := crear()
	var reina := r.colonia._nacer("reina")
	reina._velocidad = 0
	reina._process(6.01)
	verificar(r.colonia.minis_nacidas == 3 and reina._evolucion >= 1, "Camada real despliega tres minis y cambia el aspecto")
	reina._process(120)
	verificar(reina._minis_creadas == Hormiga.LIMITE_MINIS_REINA, "la evolución conserva el límite por reina")
	var cargadora := r.colonia._nacer("cargadora")
	for i in 3:
		r.comidas.soltar_fragmento(Vector2(-150 + i * 12, -100), 10 + i, 0)
	# Separar montones del mismo sector para ejercer la habilidad, no el apilado.
	for i in 2:
		var f := FragmentoCasa.new()
		r.comidas.add_child(f)
		f.iniciar(Vector2(-140 + i * 10, -100), 7 + i, 0)
		f.destruida.connect(r.comidas._on_destruida)
		r.comidas.fragmentos.append(f)
		r.comidas._indexar(f)
	var primero := r.comidas.fragmentos[0]
	cargadora.position = primero.position
	cargadora.comida = primero
	cargadora._reloj_mordida = 0
	cargadora._morder(0.1)
	verificar(is_equal_approx(cargadora.carga, 48.0) and r.comidas.fragmentos.is_empty(), "Barrido recoge tres montones conservando todo su valor")
	r.queue_free()
	await get_tree().process_frame
	Juego.evoluciones_equipadas.assign(["contagio", "corte"])
	Juego.niveles.mordida_madera = 1
	Juego._cache_stats.clear()
	r = crear()
	var roja := r.colonia._nacer("roja")
	# El escenario de contagio debe aislar sus tres objetivos; la decoración
	# del mapa puede poner otras migas dentro del mismo radio.
	r.comidas._indice.clear()
	var cercanas: Array[Comida] = []
	for i in 3:
		var datos: Dictionary = Juego.comidas[0].duplicate()
		datos.vida = 100
		r.comidas._crear(datos, Vector2(-70 + i * 15, 0), i)
		cercanas.append(r.comidas.lista.back())
	# El contagio parte de una mordida legítima en el borde del primer recurso.
	roja.position = cercanas[0].punto_mordida(Vector2.ZERO, r.radio_actual)
	roja.comida = cercanas[0]
	roja._reloj_mordida = 0
	roja._morder(0.1)
	var infectadas := 0
	for c in cercanas:
		if c.veneno_restante > 0:
			infectadas += 1
	verificar(infectadas >= 2 and roja._reloj_habilidad == 1.5, "Nube corrosiva contagia con enfriamiento")
	var carpintera := r.colonia._nacer("carpintera")
	var silla: PiezaCasa
	for p in r.comidas.partes:
		if p.pieza.tipo == "silla" and not p.pieza.get("practica", false):
			silla = p
			break
	carpintera.position = silla.punto_mordida(Vector2.ZERO, r.radio_actual)
	carpintera.comida = silla
	carpintera._dano = 2
	carpintera._reloj_mordida = 0
	if silla.mordiscos == null:
		silla._preparar_mordiscos()
	var area_antes := silla.mordiscos.area_total()
	var vida_antes := silla.vida
	var saldo_antes := Juego.migas_run
	carpintera._morder(0.1)
	var tocadas := 0
	for i in silla.vidas.size():
		if silla.vidas[i] < silla._vidas_iniciales[i]:
			tocadas += 1
	verificar(tocadas == 1 and silla.dano_recibido > 0 and silla.dano_recibido <= 2 * RolesHormiga.dano("carpintera", 1) and is_equal_approx(vida_antes - silla.vida, silla.dano_recibido), "Corte aserrado trabaja una sola sección por tick y sólo descuenta el material desprendido")
	var porcion := silla._porcion_reciente
	verificar(porcion.has_area() and porcion.size.x <= 6.0001 and porcion.size.y <= 6.0001 and is_equal_approx(area_antes - silla.mordiscos.area_total(), porcion.get_area()), "el corte evolucionado sigue siendo una única porción local de hasta seis unidades por lado")
	var acumulado := 0.0
	for f in r.comidas.fragmentos:
		acumulado += f.recompensa
	var esperado := silla.recompensa * silla.dano_recibido / silla.vida_max * Juego.stat("multiplicador_migas")
	verificar(carpintera.carga == 0 and carpintera.bocados == 0 and Juego.migas_run == saldo_antes and is_equal_approx(acumulado, esperado), "Corte continuo deja exactamente toda la extracción para las transportadoras, sin acreditar migas antes de entregarla")
	r.queue_free()
	await get_tree().process_frame

func probar_destinos() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var r := crear("restaurante")
	r.reglas.tesoro_abierto()
	verificar(r.reglas.festin == 8 and r.reglas.carga_frenesi() == 10, "el restaurante carga frenesí al doble tras un hallazgo")
	r.reglas._process(8.1)
	verificar(r.reglas.carga_frenesi() == 5, "el festín termina sin un proceso permanente")
	r.queue_free()
	await get_tree().process_frame
	r = crear("museo")
	var vitrina: PiezaCasa
	for p in r.comidas.partes:
		if p.pieza.tipo == "vitrina" and not p.pieza.get("meta", false):
			vitrina = p
			break
	vitrina.morder_en(vitrina.vida_max * 0.21, vitrina.rect_mundo.position)
	verificar(vitrina._tesoro_abierto and r.comidas._tesoros == 5, "la vitrina abre su contenido al perder un 20% y revela cinco alimentos")
	r.queue_free()
	await get_tree().process_frame
	r = crear("obelisco")
	r.objetivo_mapa.etapa = 2
	verificar(is_equal_approx(r.reglas.factor_dano(r.objetivo_mapa), 1.3), "el Obelisco debilitado recibe más daño por etapa")
	r.queue_free()
	await get_tree().process_frame
	r = crear("coliseo")
	var arco: PiezaCasa
	for p in r.comidas.partes:
		if p.pieza.tipo == "arco" and not p.pieza.get("meta", false):
			arco = p
			break
	r.reglas.parte_devorada(arco)
	verificar(r.reglas._pendientes.size() > 0 and r.reglas._pendientes.size() <= 2, "el dominó encola hasta dos vecinos, sin cascada recursiva")
	var objetivo: PiezaCasa = r.reglas._pendientes[0].parte
	var vida := objetivo.vida
	r.reglas._process(0.2)
	verificar(objetivo.vida < vida and r.reglas.eventos > 0, "el dominó daña al vecino en un turno acotado")
	r.queue_free()
	await get_tree().process_frame
	r = crear("eiffel")
	var torre := r.objetivo_mapa
	var punto := torre.punto_mordida(torre.rect_mundo.position - Vector2(50, 0), r.radio_actual)
	verificar(punto != Vector2.INF and torre.alcanza_desde(punto) and punto.y >= torre.celdas[12].position.y - 13, "la ruta llega realmente al piso inferior de la torre")
	torre.morder_en(torre.vida_max * 0.25, punto)
	var arriba_intacto := true
	for i in 12:
		arriba_intacto = arriba_intacto and is_equal_approx(torre.vidas[i], torre._vidas_iniciales[i])
	verificar(arriba_intacto and torre._fila_activa == 2 and torre.etapa == 1, "la base desaparece primero y habilita el piso siguiente")
	if not arriba_intacto or torre._fila_activa != 2 or torre.etapa != 1:
		print("TORRE ", torre.vidas, " fila ", torre._fila_activa, " etapa ", torre.etapa)
	r.queue_free()
	await get_tree().process_frame

func probar_tutorial() -> void:
	Juego.reiniciar_estado()
	seed(417)
	var r := crear()
	r.radio_actual = Juego.stat("radio_territorio")
	r.colonia._process(3)
	r.colonia.set_process(false)
	# Esta prueba aísla el trabajo conjunto de ocho obreras; el arranque real
	# con una sola y sus primeras compras se cubren en prueba_arranque_solitario.
	while r.colonia.cantidad() < 8:
		r.colonia._nacer()
	var banquito := r.objetivo_practica
	var inicio := banquito.vida
	var recompensa := banquito.recompensa * Juego.stat("multiplicador_migas")
	var cierre := {"veces": 0, "vida": -1.0, "celdas": -1, "area": -1.0}
	banquito.destruida.connect(func(p: PiezaCasa) -> void:
		# Capturar dentro de la señal: nunca consultar un nodo ya liberado.
		cierre.veces += 1
		cierre.vida = p.vida
		cierre.celdas = p.vivas.size()
		cierre.area = p.mordiscos.area_total()
	)
	# Aislar el recurso real sin moverlo, crear comida ni alterar su valor:
	# así depósitos + cargas + suelo se comparan sólo con este cartón.
	r.comidas._indice.clear()
	r.comidas._indexar(banquito)
	r.colonia._hallazgos.clear()
	banquito._preparar_mordiscos()
	var area_inicial := banquito.mordiscos.area_total()
	var obrera: Hormiga = r.colonia.hormigas[0]
	# Una mordida controlada verifica tamaño/masa; después el viaje y las
	# siguientes mordidas los ejecuta la IA, sin teletransportar ni descargar.
	obrera.position = banquito.punto_mordida(Vector2.ZERO, r.radio_actual)
	obrera.comida = banquito
	obrera._reloj_mordida = 0
	obrera._morder(0.1)
	var primera_porcion := banquito._porcion_reciente
	var primer_dano := banquito.dano_recibido
	verificar(inicio == 20 and banquito.rect_mundo.size == Vector2(110, 130) and banquito.recompensa == 180, "el cartón conserva su tamaño de proyecto grande, resistencia y recompensa, sin achicarlo para el fixture")
	verificar(primera_porcion.has_area() and primera_porcion.size.x <= 6.0001 and primera_porcion.size.y <= 6.0001 and is_equal_approx(area_inicial - banquito.mordiscos.area_total(), primera_porcion.get_area()), "la primera mordida sólo retira una porción visible pequeña y el hueco pierde exactamente esa área")
	verificar(primer_dano > 0 and is_equal_approx(obrera.carga, recompensa * primer_dano / inicio) and Juego.migas_run == 0 and r.comidas.fragmentos.is_empty(), "la obrera carga el cien por ciento del material que falta, sin cobrarlo antes de volver ni inventar restos")
	verificar(not banquito.derrumbando and not Juego.hitos.has("primer_derrumbe"), "una mordida pequeña no derrumba el cartón ni concede un hito anticipado")
	r.process_mode = Node.PROCESS_MODE_INHERIT
	r.set_process(false)
	r.feromonas.mantener_en(banquito.position)
	for i in 2400:
		await get_tree().process_frame
		if not is_instance_valid(banquito) or banquito.muerta:
			break
	var persiste := is_instance_valid(banquito) and not banquito.muerta
	verificar(persiste, "el cartón grande sigue siendo un proyecto después de cuarenta segundos con ocho obreras, no desaparece de golpe")
	if not persiste:
		r.queue_free()
		await get_tree().process_frame
		return
	verificar(banquito.dano_recibido > primer_dano and banquito.vida < inicio and banquito.vida > 0 and not banquito.derrumbando, "el enjambre amplía el desgaste durante los viajes y el resto del cartón persiste")
	var cargas := 0.0
	for h in r.colonia.hormigas:
		cargas += h.carga
	var suelo := 0.0
	for f in r.comidas.fragmentos:
		suelo += f.recompensa
	var extraido := recompensa * banquito.dano_recibido / inicio
	verificar(Juego.migas_run > 0 and is_equal_approx(Juego.migas_run + cargas + suelo, extraido), "las entregas reales, lo que sigue en viaje y el suelo conservan exactamente el valor extraído del cartón")
	verificar(cierre.veces == 0 and not Juego.hitos.has("primer_derrumbe"), "desgastar y transportar no cuentan como completar el cartón ni como provocar un derrumbe")
	var alimento := r.comidas.lista[0]
	var vida_antes := alimento.vida
	r.pisar(alimento.position)
	verificar(alimento.vida == vida_antes, "el clic manual no daña comida; sólo interactúa con eventos")
	# Lifecycle separado, NO una medición de la IA: el bulk ambiental prepara
	# sólo el último 4%; la caída debe retirar los restos y emitir destruida.
	r.process_mode = Node.PROCESS_MODE_DISABLED
	var saldo_antes := Juego.migas_run
	var valor_bulk := banquito.morder_en(banquito.vida - inicio * 0.04, banquito.position)
	verificar(banquito.derrumbando and not banquito.muerta and banquito.vida > 0 and banquito.vida <= inicio * 0.08, "el fixture bulk sólo habilita el derrumbe cuando quedan restos finales, sin completar todavía el objeto")
	for i in 16:
		if not is_instance_valid(banquito) or banquito.muerta:
			break
		banquito._process(0.36)
	verificar(cierre.veces == 1 and cierre.vida == 0 and cierre.celdas == 0 and cierre.area == 0 and Juego.partes_destruidas_run == 1 and Juego.hitos.has("primer_derrumbe"), "el lifecycle completo del cartón emite una sola destrucción y conserva el premio permanente de un derrumbe real")
	suelo = 0.0
	for f in r.comidas.fragmentos:
		suelo += f.recompensa
	var bonus := recompensa * Juego.stat("bonus_destruir")
	verificar(is_equal_approx(Juego.migas_run - saldo_antes, bonus) and is_equal_approx(saldo_antes + cargas + suelo + valor_bulk, recompensa), "el cierre bulk conserva todo el material entre entregas, cargas, retorno y escombros, con un único bonus separado")
	r.queue_free()
	await get_tree().process_frame
