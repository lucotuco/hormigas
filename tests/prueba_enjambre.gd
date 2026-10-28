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
	roja.position = cercanas[0].position
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
	carpintera._morder(0.1)
	var tocadas := 0
	for vida in silla.vidas:
		if vida < silla._vida_celda:
			tocadas += 1
	verificar(tocadas == 2 and is_equal_approx(silla.dano_recibido, 2 * RolesHormiga.dano("carpintera", 1)), "Corte aserrado reparte el daño entre dos secciones sin multiplicarlo")
	var acumulado := 0.0
	for f in r.comidas.fragmentos:
		acumulado += f.recompensa
	var esperado := silla.recompensa * silla.dano_recibido / silla.vida_max * Juego.stat("multiplicador_migas")
	verificar(carpintera.carga == 0 and carpintera.bocados == 0 and is_equal_approx(acumulado, esperado), "Corte continuo deja exactamente toda la extracción para las transportadoras")
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
		arriba_intacto = arriba_intacto and is_equal_approx(torre.vidas[i], torre._vida_celda)
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
	r.process_mode = Node.PROCESS_MODE_INHERIT
	r.set_process(false)
	r.colonia._process(3)
	r.colonia.set_process(false)
	var banquito := r.objetivo_practica
	var inicio := banquito.vida
	r.feromonas.mantener_en(banquito.position)
	for i in 2400:
		await get_tree().process_frame
		if not is_instance_valid(banquito) or banquito.muerta:
			break
	verificar(not is_instance_valid(banquito) or banquito.muerta, "ocho obreras iniciales desmontan el tutorial en menos de 40 segundos")
	if is_instance_valid(banquito) and not banquito.muerta:
		print("TUTORIAL vida ", banquito.vida, " seleccion ", r.feromonas.objetivo_comida, " territorio ", r.radio_actual)
		for h in r.colonia.hormigas:
			print("  H ", h.position, " estado ", h.estado, " meta ", h.objetivo, " ruta ", h._ruta_fallida, " espera ", h._esperando_ruta, " carga ", h.carga)
	verificar(inicio == 20 and Juego.hitos.has("primer_derrumbe"), "el tutorial enseña roturas y un derrumbe con premio permanente")
	verificar(not r.has_method("pisar"), "la extracción depende de las hormigas, nunca de clics")
	r.queue_free()
	await get_tree().process_frame
