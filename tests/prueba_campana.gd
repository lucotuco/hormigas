extends Node
var total := 0
var fallas := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")  # las verificaciones leen textos en español
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	seed(71)
	verificar(Juego.destino_desbloqueado("casa") and not Juego.destino_desbloqueado("restaurante"), "la campaña empieza en casa sin saltarse destinos")
	verificar(not Juego.elegir_destino("eiffel"), "no se selecciona un destino bloqueado")
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	for id in Mundos.ORDEN:
		var run := crear_run()
		var meta := run.objetivo_mapa
		verificar(meta != null and meta.nombre == Mundos.INFO[id].meta, "%s tiene un gran objetivo propio" % id)
		verificar(run.cocina.libre(Vector2.ZERO, Cocina.MARGEN), "%s deja libre la salida de la colonia" % id)
		var punto := meta.punto_mordida(Vector2.ZERO, 9500)
		var ruta := run.cocina.ruta(Vector2.ZERO, punto, 9500)
		var segura := punto != Vector2.INF and not ruta.is_empty()
		var anterior := Vector2.ZERO
		for p in ruta:
			segura = segura and run.cocina.segmento_libre(anterior, p)
			anterior = p
		verificar(segura, "%s tiene una ruta transitable hasta su objetivo" % id)
		var coronas := Juego.coronas
		meta.morder(meta.vida + 1)
		verificar(run.objetivo_completado and Juego.lugares_completados.has(id) and Juego.coronas == coronas + int(Mundos.INFO[id].coronas), "%s entrega coronas una sola vez" % id)
		var titulo: String = run.hud._lbl_cartel_titulo.text
		var esperado: String = "conquistó el mundo" if id == Mundos.ORDEN.back() else "conquistado"
		var detalle: String = run.hud._lbl_cartel_detalle.text
		verificar(run.hud._cartel.visible and esperado in titulo and Mundos.INFO[id].nombre in detalle and "corona" in detalle, "%s: el derrumbe muestra el cartel de conquista (%s)" % [id, titulo])
		verificar(run.camara._manual and run.camara.position.distance_to(meta.rect_mundo.get_center()) < 1.0, "%s: la cámara mira el derrumbe" % id)
		verificar(is_equal_approx(Engine.time_scale, 1.0), "%s: sin pantalla no hay cámara lenta" % id)
		var idx := Mundos.ORDEN.find(id)
		if idx + 1 < Mundos.ORDEN.size():
			verificar(Juego.elegir_destino(Mundos.ORDEN[idx + 1]), "el gran objetivo abre el siguiente destino")
		run.queue_free()
		await get_tree().process_frame
	var guardado: Dictionary = JSON.parse_string(JSON.stringify(Juego.datos_partida()))
	Juego.reiniciar_estado()
	Juego.restaurar_partida(guardado)
	verificar(Juego.lugar_actual == "eiffel" and Juego.lugares_completados.size() == 6 and Juego.coronas == 21, "la campaña completa y las coronas sobreviven al guardado")
	# Repetir un destino ya cobrado no vuelve a dar coronas (antes se podían farmear).
	verificar(Juego.elegir_destino("casa"), "se puede volver a un destino conquistado")
	var repetida := crear_run()
	repetida.objetivo_mapa.morder(repetida.objetivo_mapa.vida + 1)
	verificar(repetida.objetivo_completado and Juego.coronas == 21, "repetir un destino ya cobrado no da coronas otra vez")
	repetida.queue_free()
	await get_tree().process_frame
	Juego.elegir_destino("eiffel")
	# Una partida anterior a coronas_cobradas no puede volver a cobrar lo ya completado.
	var vieja: Dictionary = guardado.duplicate(true)
	vieja.erase("coronas_cobradas")
	Juego.reiniciar_estado()
	Juego.restaurar_partida(vieja)
	verificar(Juego.coronas_cobradas.size() == 6 and Juego.coronas == 21, "las partidas anteriores toman lo completado como ya cobrado")
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	Juego.migas = 9999
	Juego.reclutadas.carpintera = 3
	var esperada := Juego.jalea_por_fundar()
	verificar(esperada == Juego.coronas * Juego.JALEA_POR_CORONA + Juego.detalle_fundar().migas, "la jalea por fundar suma coronas y migas de la colonia")
	verificar(Juego.fundar_colonia() and Juego.legado == esperada and Juego.jalea == esperada and Juego.coronas == 0 and Juego.migas == 0 and Juego.niveles.is_empty() and Juego.reclutadas.is_empty(), "fundar reinicia economía y reclutas a cambio de jalea real")
	verificar(Juego.lugares_completados.size() == 6 and Juego.hitos.has("primer_monumento") and Juego.lugar_actual == "casa" and not Juego.destino_desbloqueado("eiffel"), "fundar conserva historial e hitos, pero la nueva colonia vuelve a conquistar su recorrido")
	verificar(is_equal_approx(Juego.stat("dano"), 1.0 + Juego.legado * Juego.BONUS_LEGADO) and not Juego.fundar_colonia(), "la jalea ganada mejora el daño y no se puede cobrar dos veces")
	Juego.migas = 1000
	var previa := Juego.stat_tras_comprar("mandibulas")
	Juego.comprar("mandibulas")
	verificar(is_equal_approx(previa, Juego.stat("dano")), "la vista previa incorpora el legado correctamente")
	# Después de fundar, cada gran objetivo vuelve a pagar sus coronas una vez.
	Juego.niveles["mordida_madera"] = 1
	Juego.niveles["mordida_resistente"] = 1
	Juego.niveles["mordida_muros"] = 1
	Juego._cache_stats.clear()
	Juego.elegir_destino("casa")
	var nueva := crear_run()
	nueva.objetivo_mapa.morder(nueva.objetivo_mapa.vida + 1)
	verificar(Juego.coronas == 1, "una colonia nueva vuelve a cobrar las coronas de la casa")
	nueva.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var run := crear_run()
	var silla: PiezaCasa = run.comidas.partes[6]
	var n := silla.vivas.size()
	var valor := silla.morder_en(silla.vida_max * 0.1, Vector2(170, -90))
	verificar(not silla.muerta and silla.vivas.size() < n and valor > 0 and run.comidas.fragmentos.size() > 0, "una mordida localizada quita un pedazo y deja fragmentos sin borrar la silla")
	var ultimo := silla.vivas.size()
	var sin_soportes := 0
	while not silla.derrumbando and not silla.muerta and sin_soportes < 20:
		silla.morder_en(silla.vida_max * 0.08, Vector2(170, -90))
		sin_soportes += 1
	verificar(silla.derrumbando and not silla.muerta and silla.vivas.size() <= ultimo, "perder soportes inicia un derrumbe y no una desaparición instantánea")
	for i in 20:
		if silla.muerta:
			break
		silla._process(0.1)
	verificar(silla.muerta and Juego.hitos.has("primer_derrumbe") and Juego.hitos.has("primera_silla"), "el derrumbe termina por etapas y concede hitos permanentes")
	var frag: FragmentoCasa = run.comidas.fragmentos[0]
	verificar(RolesHormiga.afinidad("cargadora", frag) > RolesHormiga.afinidad("obrera", frag), "las cargadoras prefieren retirar fragmentos")
	verificar(RolesHormiga.dano("carpintera", 1) > RolesHormiga.dano("obrera", 1) and RolesHormiga.dano("demoledora", 3) > RolesHormiga.dano("carpintera", 3), "cada especialista destaca en su propio material")
	run.comidas.soltar_fragmento(Vector2(-100, 200), 100, 3)
	var pesado: FragmentoCasa = run.comidas.fragmentos.back()
	verificar(RolesHormiga.afinidad("voladora", pesado) == 0 and RolesHormiga.afinidad("cargadora", pesado) > 0, "las voladoras no levantan restos pesados")
	var valor_total := 0.0
	for f in run.comidas.fragmentos:
		valor_total += f.recompensa
	for i in 500:
		run.comidas.soltar_fragmento(Vector2(-600 + (i % 20) * 40, 1900 + int(i / 20) * 35), 2, i % 3 + 1)
	var nuevo_total := 0.0
	for f in run.comidas.fragmentos:
		nuevo_total += f.recompensa
	verificar(run.comidas.fragmentos.size() <= Comidas.MAX_FRAGMENTOS and is_equal_approx(nuevo_total - valor_total, 1000), "el tope de fragmentos conserva el valor sin multiplicar nodos")
	var tesoros := run.comidas.lista.size()
	run.comidas.revelar_tesoro(Vector2(-100, 100), 1)
	verificar(run.comidas.lista.size() == tesoros + 3 and Juego.hitos.has("primer_tesoro"), "abrir un mueble revela alimentos y un hito de olfato")
	verificar(not Juego.revelado("frenesi"), "el frenesí todavía no aparece en la primera run")
	Juego.runs_jugadas = 2  # el frenesí se revela desde la segunda run
	for i in 20:
		run.depositar(1)
	verificar(run.frenesi_restante == 6 and run.factor_ritmo() == 1.5, "los depósitos activan seis segundos de frenesí")
	run._process(6.1)
	verificar(run.frenesi_restante == 0 and run.factor_ritmo() == 1, "el frenesí termina sin modificar las stats base")
	run.hud._cambiar_prioridad("muebles")
	verificar(Juego.prioridad == "muebles" and run.hud._prioridades.muebles.button_pressed, "la prioridad se puede cambiar desde la interfaz")
	for c in run.comidas.lista + run.comidas.fragmentos:
		c.muerta = true
		run.comidas._on_destruida(c)
		c.queue_free()
	var punto := Vector2(540, -20)
	run.comidas._crear(Juego.comidas[0], Vector2(525, -20), 5)
	var elegido := run.comidas.buscar_cercana(punto, 100, 9500, {}, "carpintera")
	verificar(elegido is PiezaCasa, "priorizar muebles cambia de verdad el objetivo de búsqueda")
	Juego.prioridad = "alimentos"
	elegido = run.comidas.buscar_cercana(punto, 100, 9500, {}, "carpintera")
	verificar(elegido != null and not elegido is PiezaCasa, "priorizar alimentos permite cambiar de estrategia")
	var h := run.colonia._nacer("carpintera", Vector2(-400, -400))
	h.comida = run.comidas.partes[6]
	h.estado = Hormiga.Estado.MORDIENDO
	h._reloj_mordida = 0
	var vida_lejana := h.comida.vida
	h._morder(1)
	verificar(h.comida.vida == vida_lejana and h.carga == 0 and h.estado == Hormiga.Estado.YENDO_A_COMIDA, "las mordidas no dañan a distancia cuando cambia el borde")
	var heladera: PiezaCasa
	for p in run.comidas.partes:
		if p.pieza.tipo == "heladera":
			heladera = p
	heladera.aplicar_veneno(2, 3, run)
	heladera._process(0.1)
	var resistencia := heladera.vida
	heladera.morder_en(10, heladera.rect_mundo.position)
	verificar(is_equal_approx(resistencia - heladera.vida, 12), "la corrosión de una roja mejora 20% los ataques del grupo")
	Juego.niveles.recoleccion_eficiente = 5
	Juego._cache_stats.clear()
	run.comidas.soltar_fragmento(Vector2(-150, 300), 100, 1)
	var pila: FragmentoCasa = run.comidas.fragmentos.back()
	var saldo := Juego.migas_run
	verificar(pila.morder(1) == 100 and Juego.migas_run == saldo, "recoger fragmentos no duplica multiplicadores ni bonus de destrucción")
	run.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	Juego.migas = 100000
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	tienda._cambiar_pestana("viajes")
	verificar(tienda._panel_viajes.visible and not tienda._cuerpo_mejoras.visible, "la tienda permite explorar los seis destinos")
	tienda._cambiar_pestana("legado")
	verificar(tienda._panel_legado.visible and not tienda._panel_viajes.visible, "la tienda muestra hitos y legado por separado")
	tienda.queue_free()
	await get_tree().process_frame
	print("Campaña, pedazos y roles: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)

func crear_run() -> Run:
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.radio_actual = 9500
	return run

func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)
