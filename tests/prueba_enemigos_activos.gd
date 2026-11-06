extends Node
## Encuentros reales con avance manual del reloj: no mide diversión/FPS ni
## falsea ingresos. Las cargas de muestra ya representan material extraído.
var total := 0
var fallas := 0
var run: Run
var portadora: Hormiga


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Juego.reiniciar_estado()
	probar_datos()
	Juego.reiniciar_estado()
	run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.radio_actual = 9500
	run.eventos._reloj_amenaza = 1e9
	run.eventos._reloj_dorada = 1e9
	portadora = run.colonia._nacer("cargadora", Vector2(80, 0))
	probar_aparicion_y_limites()
	probar_rotacion()
	probar_avispa()
	probar_rival()
	probar_contacto_espaciado()
	probar_costos_y_cierre()
	run.queue_free()
	await get_tree().process_frame
	await probar_llamado_lejano()
	Juego.reiniciar_estado()
	print("Enemigos activos: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("OK " if ok else "FALLA ", mensaje)


func probar_datos() -> void:
	for tipo in ["avispa", "rival"]:
		var datos := Evento.datos_tipo(tipo)
		verificar(not datos.is_empty() and datos.golpes <= 3 and datos.radio > 0
			and datos.velocidad > 0 and datos.aviso >= 1.0 and datos.escape > 0,
			tipo + ": datos CSV completos, pocas pulsaciones y aviso legible")
	verificar(Evento.datos_tipo("arana") == Evento.DATOS.arana,
		"las amenazas propias conservan sus valores anteriores")
	verificar(Eventos.amenazas_simultaneas() == 2, "la presión inicial admite dos grupos, no una cola invisible")
	Juego.lugar_actual = "obelisco"
	verificar(Eventos.amenazas_simultaneas() == 3, "el avance intermedio admite tres grupos")
	Juego.lugar_actual = "eiffel"
	Juego.niveles = {"mas_obreras": 160}
	verificar(Eventos.amenazas_simultaneas() == 4, "el avance alto alcanza cuatro individuos como techo duro")
	var distintos: Dictionary = {}
	var validas := true
	for i in 100:
		var espera := Eventos.espera_entre_amenazas()
		validas = validas and espera >= Eventos.parametro("espera_min") and espera <= Eventos.parametro("espera_max")
		distintos[snappedf(espera, 0.01)] = true
	verificar(validas and distintos.size() > 1, "la cadencia varía dentro del presupuesto declarado")


func probar_llamado_lejano() -> void:
	Juego.reiniciar_estado()
	Juego.lugar_actual = "obelisco"
	var plaza: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(plaza)
	plaza.process_mode = Node.PROCESS_MODE_DISABLED
	plaza.radio_actual = 9500
	# Piso auténtico del cinturón jugable: a9004u del origen. El viejo clamp
	# al70% desplazaba el encuentro más de2000u lejos del trabajo solicitado.
	var llamado := Vector2(7800, 4500)
	plaza.colonia._nacer("obrera", llamado)
	plaza.feromonas.mantener_en(llamado)
	verificar(plaza.feromonas._punto_permitido() and plaza.cocina.libre(llamado, 32)
		and llamado.length() > plaza.radio_actual * 0.9, "la regresión usa un llamado lejano permitido en piso real de la plaza")
	var apariciones := plaza.eventos.aparecer("arana")
	var cerca := false
	if not apariciones.is_empty():
		var e: Evento = apariciones[0]
		cerca = e.position.distance_to(llamado) <= Eventos.parametro("radio_interes_max") + 0.01 \
			and plaza.cocina.libre(e.position, 18) and e.position.length() < plaza.radio_actual
	verificar(cerca, "radio9500: el encuentro queda a280u o menos del llamado lejano, no del70% del territorio")
	plaza._detener_extraccion()
	plaza.queue_free()
	await get_tree().process_frame


func nuevo(tipo: String) -> Evento:
	var candidatos := run.eventos.aparecer(tipo)
	verificar(candidatos.size() > 0, tipo + ": el encuentro encuentra suelo real válido")
	return candidatos[0] if not candidatos.is_empty() else null


func limpiar_amenazas() -> void:
	for e in run.eventos.activos.duplicate():
		e._terminar()


func probar_aparicion_y_limites() -> void:
	var rutas := run.cocina.busquedas_astar
	var arana := nuevo("arana")
	if arana == null:
		return
	verificar(arana.position.length() < run.radio_actual and arana.position.distance_to(portadora.position) <= 281
		and arana.position.distance_to(portadora.position) >= Eventos.parametro("distancia_segura")
		and run.cocina.libre(arana.position, 18),
		"radio9500: la amenaza nace cerca del trabajo, dentro del mapa y con distancia de reacción")
	var posicion := arana.position
	arana._process(0.5)
	verificar(arana.position == posicion and arana.atrapadas == 0 and arana.botin == 0,
		"el aviso de entrada no mueve, roba ni atrapa")
	arana._aviso_restante = 0
	arana.golpear()
	arana._process(Eventos.parametro("pausa_golpe") * 0.5)
	verificar(arana.position == posicion and arana.golpes == arana.golpes_max - 1 and arana._destello > 0,
		"cada clic provoca destello y una pausa física, sin inflar la vida")
	verificar(run.cocina.busquedas_astar == rutas, "aparecer y reaccionar no hacen A* fuera del presupuesto")
	limpiar_amenazas()
	var bandada := run.eventos.aparecer("paloma")
	var rival := run.eventos.aparecer("rival")
	verificar(bandada.size() == 3 and rival.size() == 1 and run.eventos.amenazas_activas() == 4
		and run.eventos.aparecer("avispa").is_empty(), "bandada3 más rival1 llenan exactamente cuatro lugares")
	limpiar_amenazas()
	var e := nuevo("avispa")
	if e == null:
		return
	e.estado = "huyendo"
	e._aviso_restante = 0
	for i in 41:
		e._process(0.1)
	verificar(e.resuelto and run.eventos.amenazas_activas() == 0,
		"a radio9500 el escape libera su lugar en cuatro segundos, no minutos")


func preparar_carga(valor := 37.5) -> void:
	portadora.carga = valor
	portadora.bocados = 1
	portadora._material_carga = 1
	portadora._carga_origen = [0.0, valor, 0.0]
	portadora._retazos.assign([Rect2(1, 1, 4, 4)])
	portadora.estado = Hormiga.Estado.VOLVIENDO
	portadora.position = Vector2(80, 0)
	portadora._ruta = PackedVector2Array()
	portadora._indice_ruta = 0
	portadora._esperando_ruta = false


func probar_rotacion() -> void:
	preparar_carga()
	run.eventos._turno_amenaza = 2
	verificar(run.eventos._proxima_amenaza() == "avispa", "la avispa entra en la rotación cuando existe una carga real")
	portadora._vaciar_carga()
	run.eventos._turno_amenaza = 2
	verificar(run.eventos._proxima_amenaza() == "arana", "sin cargadoras la rotación no inventa una presa")
	run.comidas.soltar_fragmento(Vector2(160, 100), 41, 1)
	run.eventos._turno_amenaza = 3
	verificar(run.eventos._proxima_amenaza() == "rival", "los restos reales habilitan a la saqueadora")


func probar_avispa() -> void:
	preparar_carga()
	var avispa := nuevo("avispa")
	if avispa == null:
		return
	avispa._aviso_restante = 0
	avispa._avispa(0.01)
	var objetivo := avispa._objetivo
	verificar(avispa.estado == "marcando" and objetivo == portadora.position and avispa.botin == 0,
		"la avispa señala la posición exacta antes de atacar")
	portadora.position += Vector2(150, 0)
	avispa._avispa(float(avispa._datos.aviso) + 0.01)
	verificar(avispa.estado == "picando" and avispa._objetivo == objetivo,
		"el aviso queda fijo aunque la cargadora siga naturalmente su ruta")
	avispa._avispa(2.0)
	verificar(avispa.estado == "huyendo" and avispa.botin == 0 and portadora.carga == 37.5,
		"salir del área anunciada evita el robo sin redirigir retornos con feromonas")
	avispa._terminar()
	preparar_carga()
	avispa = nuevo("avispa")
	if avispa == null:
		return
	avispa._aviso_restante = 0
	var cantidad := run.colonia.cantidad()
	var ingreso := Juego.migas_run
	var rutas := run.cocina.busquedas_astar
	avispa._avispa(0.01)
	avispa._avispa(float(avispa._datos.aviso) + 0.01)
	avispa._avispa(2.0)
	verificar(is_equal_approx(avispa.botin, 37.5) and portadora.carga == 0 and portadora.bocados == 0
		and portadora._retazos.is_empty() and portadora._carga_origen == [0.0, 0.0, 0.0],
		"un ataque lleva exactamente la carga, sin muestras u orígenes invisibles")
	verificar(run.colonia.cantidad() == cantidad and portadora.estado == Hormiga.Estado.EXPLORANDO
		and Juego.migas_run == ingreso and run.cocina.busquedas_astar == rutas,
		"robar no mata, no cobra y reanuda navegación normal sin A* inmediato")
	avispa._avispa(0.1)
	verificar(is_equal_approx(avispa.botin, 37.5), "el escape no vuelve a retirar la misma carga")
	verificar_premio_exacto(avispa, ingreso)
	probar_intercepcion_caminando()


func probar_intercepcion_caminando() -> void:
	preparar_carga()
	# Recorrido ya calculado: el aviso sólo lo lee. Se usa la marcha real de
	# Hormiga y su misma velocidad, sin pedir una ruta durante la predicción.
	portadora.position = run.cocina.ajustar_destino(Vector2(-400, 300), run.radio_actual)
	var destino := run.cocina.ajustar_destino(portadora.position + Vector2(-250, 0), run.radio_actual)
	portadora.objetivo = destino
	portadora._ruta = run.cocina.ruta(portadora.position, destino, run.radio_actual)
	portadora._indice_ruta = 0
	portadora._meta_ruta = destino
	portadora._pedido_ruta = destino
	portadora._version_ruta = run.cocina.version
	portadora._espera_ruta = 0
	portadora._velocidad = 95
	var avispa := nuevo("avispa")
	if avispa == null:
		return
	avispa._aviso_restante = 0
	avispa.position = portadora.position + Vector2(120, 0)
	var antes := portadora.position
	var rutas := run.cocina.busquedas_astar
	avispa._avispa(0.01)
	var marca := avispa._objetivo
	verificar(marca.distance_to(antes) > 35 and run.cocina.busquedas_astar == rutas,
		"la marca anticipa el siguiente waypoint cacheado sin recalcular rutas")
	for i in 150:
		portadora._caminar(1.0 / 60.0)
		avispa._avispa(1.0 / 60.0)
		if avispa.estado == "huyendo":
			break
	verificar(avispa.estado == "huyendo" and avispa.botin == 37.5 and portadora.carga == 0
		and avispa._objetivo == marca, "la pasada fija puede alcanzar una cargadora95u/s caminando, no sólo una trabada")
	avispa._terminar()


func probar_rival() -> void:
	var resto: FragmentoCasa = run.comidas.fragmentos[0]
	var rival := nuevo("rival")
	if rival == null:
		return
	var ingreso := Juego.migas_run
	var valor := resto.recompensa
	rival._aviso_restante = 0
	rival._comida = resto
	rival.position = resto.position + Vector2(-resto.radio - 2, 0)
	rival._recolector(0.01)
	verificar(rival.estado == "cargando", "la rival llega hasta el montón y anuncia el robo")
	rival._recolector(float(rival._datos.aviso) - 0.1)
	verificar(not resto.muerta and rival.botin == 0 and Juego.migas_run == ingreso,
		"el montón continúa disponible durante todo el aviso")
	rival._recolector(0.2)
	verificar(resto.muerta and not run.comidas.fragmentos.has(resto) and is_equal_approx(rival.botin, valor)
		and Juego.migas_run == ingreso and rival.estado == "huyendo",
		"un único montón pasa íntegro al botín sin dinero ni bonus de destrucción")
	verificar_premio_exacto(rival, ingreso)
	var vacia := nuevo("rival")
	if vacia != null:
		vacia._aviso_restante = 0
		vacia._recolector(0.1)
		verificar(vacia.estado == "huyendo" and vacia.botin == 0, "sin restos físicos la rival se retira sin fabricar recursos")
		vacia._terminar()


func verificar_premio_exacto(e: Evento, ingreso: float) -> void:
	var base := maxf(ingreso * Juego.stat("botin_eventos"), Eventos.BOTIN_BASE)
	var esperado := base + e.botin
	var victorias := Juego.estadistica("amenazas_vencidas")
	for i in e.golpes_max:
		e.golpear()
	var despues := Juego.migas_run
	verificar(e.resuelto and e.premio_cobrado and is_equal_approx(despues - ingreso, esperado)
		and Juego.estadistica("amenazas_vencidas") == victorias + 1,
		e.tipo + ": ganar devuelve exactamente lo robado más el premio base declarado")
	e.golpear()
	verificar(run.eventos.premiar(e) == 0 and Juego.migas_run == despues,
		e.tipo + ": clics y callbacks repetidos no duplican la recompensa")


func probar_contacto_espaciado() -> void:
	var arana := nuevo("arana")
	if arana == null:
		return
	arana.position = Vector2(3000, 0) # Sin presas cercanas durante los dos segundos.
	arana._aviso_restante = 0
	arana._reloj = 2.0 # El cooldown de captura ya venció: reproduce el caso caro.
	arana._reloj_sensores = 0
	var reinicios := 0
	for i in 120:
		var anterior := arana._reloj_sensores
		arana._process(1.0 / 60.0)
		reinicios += int(arana._reloj_sensores > anterior)
	verificar(reinicios >= 9 and reinicios <= 11 and arana.atrapadas == 0,
		"sin presa tras el cooldown, la araña consulta contacto unas diez veces en120ticks, no cada cuadro")
	arana._terminar()


func probar_costos_y_cierre() -> void:
	portadora._vaciar_carga()
	var avispa := nuevo("avispa")
	if avispa == null:
		return
	avispa._aviso_restante = 0
	var antes := avispa.consultas_objetivos
	for i in 120:
		avispa._avispa(1.0 / 60.0)
	verificar(avispa.consultas_objetivos - antes >= 3 and avispa.consultas_objetivos - antes <= 4,
		"buscar cargadoras se espacia a medio segundo, no recorre la colonia cada cuadro")
	var ingreso := Juego.migas_run
	avispa.botin = 33
	run._detener_extraccion()
	avispa._process(5)
	verificar(avispa.resuelto and run.eventos.activos.is_empty() and not avispa.golpear()
		and run.eventos.premiar(avispa) == 0 and run.eventos.aparecer("rival").is_empty()
		and Juego.migas_run == ingreso, "el silbato cancela ataques, botín, clics y nuevas apariciones sin ingresos tardíos")
