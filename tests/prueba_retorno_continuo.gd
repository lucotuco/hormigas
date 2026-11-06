extends Node
## Una portadora no necesita quedarse parada al invertir el viaje: el prefijo
## que acaba de caminar ya es seguro. La cola sigue presupuestando la ruta nueva.
## El regreso no inyecta carga/ruta: salen del viaje y la mordida reales.
## Otro fixture explícito retiene una ruta vieja para probar cambios de puesto.
const DELTA := 1.0 / 60.0
var total := 0
var fallas := 0


func _init() -> void:
	Juego.guardado_habilitado = false


func _ready() -> void:
	var huellas := huellas_guardados()
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	seed(7503)
	probar_guardas_sinteticas()
	await probar_vuelta_sin_pausa()
	await probar_puesto_cercano_retenido()
	verificar(huellas_guardados() == huellas, "el retorno continuo no escribe la partida ni los ajustes")
	Juego.reiniciar_estado()
	print("Retorno continuo: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func probar_vuelta_sin_pausa() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "excavar": 30}
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true # Fixture de navegación, no perfil de preparación.
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.colonia._activa = false
	run.radio_actual = 12000.0
	var mesa: PiezaCasa
	for parte: PiezaCasa in run.comidas.partes:
		if parte.pieza.tipo == "mesa":
			mesa = parte
			break
	verificar(mesa != null and mesa.preparar_material(), "el fixture usa el material de la mesa real de la cocina")
	if mesa == null or mesa.mordiscos == null:
		run.queue_free()
		await get_tree().process_frame
		return
	var puesto := mesa.punto_trabajo(Vector2.ZERO, run.radio_actual, false, 3)
	verificar(puesto.is_finite() and mesa.alcanza_contacto(puesto)
		and run.cocina.libre(puesto, Cocina.MARGEN), "el destino de ida toca material real y conserva el margen de navegación")
	if not puesto.is_finite():
		run.queue_free()
		await get_tree().process_frame
		return
	var h := run.colonia._nacer("obrera", Vector2.ZERO)
	h.comida = mesa
	h.estado = Hormiga.Estado.YENDO_A_COMIDA
	h.objetivo = puesto
	h._version_objetivo = mesa.version_forma
	h._reubicando_frente = true
	h._capacidad = 1
	h._porciones_ciclo = 1
	h._dano = mesa.vida_max
	h._velocidad = 1200.0 # Sólo acorta el transporte del fixture; no toca el balance.
	var ruta_ida := PackedVector2Array()
	var segura := run.cocina.libre(h.position, Cocina.MARGEN - 0.1)
	for cuadro in 600:
		if h.estado == Hormiga.Estado.MORDIENDO:
			break
		run._reloj += DELTA
		h._caminar(DELTA)
		if ruta_ida.is_empty() and not h._ruta.is_empty():
			ruta_ida = h._ruta.duplicate()
		segura = segura and run.cocina.libre(h.position, Cocina.MARGEN - 0.1)
		await get_tree().process_frame
	verificar(h.estado == Hormiga.Estado.MORDIENDO and h.comida == mesa
		and mesa.alcanza_contacto(h.position) and h.carga == 0.0 and segura and not ruta_ida.is_empty(),
		"la obrera recorre la ida normal desde la entrada, sin aparecer sobre el mueble ni llevar carga forzada")
	if h.estado != Hormiga.Estado.MORDIENDO or ruta_ida.is_empty():
		print("DIAG ida: pos=", h.position, " objetivo=", h.objetivo,
			" estado=", h.estado, " ruta=", h._indice_ruta, "/", h._ruta.size())
		run.queue_free()
		await get_tree().process_frame
		return
	# Sólo incluir los nodos que realmente atravesó, no la punta que podría
	# quedar adelante al entrar en alcance. La última posición tampoco se fuerza.
	var recorrido := PackedVector2Array([Vector2.ZERO])
	for i in mini(h._indice_ruta, ruta_ida.size()):
		if not recorrido[-1].is_equal_approx(ruta_ida[i]):
			recorrido.append(ruta_ida[i])
	if not recorrido[-1].is_equal_approx(h.position):
		recorrido.append(h.position)
	verificar(recorrido.size() >= 2 and recorrido_seguro(run.cocina, recorrido),
		"el prefijo observado contiene únicamente segmentos transitables que ya caminó")
	var antes := h.position
	var saldo := Juego.migas_run
	var vida := mesa.vida
	h._reloj_mordida = 0.0
	h._morder(DELTA)
	var carga_real := h.carga
	verificar(carga_real > 0.0 and h.bocados == 1 and h.estado == Hormiga.Estado.VOLVIENDO
		and h.comida == null and h._recuerdo == mesa and mesa.vida < vida
		and h.position == antes and Juego.migas_run == saldo,
		"una mordida real llena el buche de uno y cambia de sentido sin acreditar ni teletransportar la carga")
	if carga_real <= 0.0 or h.estado != Hormiga.Estado.VOLVIENDO:
		run.queue_free()
		await get_tree().process_frame
		return
	# Bloquear justamente este cuadro: admitir_ruta no debe reiniciar el
	# presupuesto al consultar Engine.get_process_frames(). No hay await acá.
	run.cocina._cuadro_rutas = Engine.get_process_frames()
	run.cocina._pedidos_cuadro = run.cocina.limite_rutas_por_cuadro
	run.cocina._tiempo_rutas_cuadro = 0
	var consultas := run.cocina.consultas_ruta
	var pedidos := run.cocina._pedidos_cuadro
	var esperada := retroceder_por_recorrido(recorrido, h._velocidad * DELTA)
	h._caminar(DELTA)
	verificar(h.position.distance_to(antes) > 0.01 and h.position.distance_to(esperada) < 0.01,
		"con la cola cerrada ya avanza por el prefijo seguro de ida en sentido inverso, sin pausa cargada")
	verificar(run.cocina.consultas_ruta == consultas and run.cocina._pedidos_cuadro == pedidos
		and run.cocina._tiempo_rutas_cuadro == 0 and h._esperando_ruta,
		"reutilizar ese tramo no consulta A*, no saltea la espera ni aumenta el presupuesto de rutas")
	verificar(run.cocina.libre(h.position, Cocina.MARGEN - 0.1)
		and run.cocina.segmento_libre(antes, h.position) and h.carga == carga_real
		and Juego.migas_run == saldo and mesa.vida < vida,
		"el primer paso de regreso sigue sobre piso libre con la misma porción, sin cobrar a distancia")
	# Mantener cerrados varios cuadros: no alcanza con conservar una única
	# pose de salida. La referencia independiente recorre la polilínea entera,
	# incluyendo los giros reales de la ida si el plano los necesitó.
	var distancia_total := longitud_recorrido(recorrido)
	var paso := h._velocidad * DELTA
	var cuadros_bloqueados := mini(60, maxi(2, floori((distancia_total - Hormiguero.RADIO_ENTRADA - paso) / paso)))
	var continuo := true
	var sin_rutas := true
	var misma_carga := true
	for cuadro in range(1, cuadros_bloqueados):
		await get_tree().process_frame
		run._reloj += DELTA
		run.cocina._cuadro_rutas = Engine.get_process_frames()
		run.cocina._pedidos_cuadro = pedidos
		run.cocina._tiempo_rutas_cuadro = 0
		var previa := h.position
		h._caminar(DELTA)
		esperada = retroceder_por_recorrido(recorrido, paso * (cuadro + 1))
		continuo = continuo and h.position.distance_to(previa) > 0.01 and h.position.distance_to(esperada) < 0.01
		sin_rutas = sin_rutas and run.cocina.consultas_ruta == consultas and run.cocina._pedidos_cuadro == pedidos \
			and run.cocina._tiempo_rutas_cuadro == 0 and h._esperando_ruta
		misma_carga = misma_carga and h.carga == carga_real and h.estado == Hormiga.Estado.VOLVIENDO \
			and Juego.migas_run == saldo
		segura = segura and run.cocina.libre(h.position, Cocina.MARGEN - 0.1)
	verificar(continuo and cuadros_bloqueados >= 2,
		"durante %d cuadros cerrados desanda exactamente el prefijo observado sin volver a frenarse" % cuadros_bloqueados)
	verificar(sin_rutas and misma_carga and segura,
		"la espera prolongada conserva cola, presupuesto, colisión y valor de la misma porción")
	var primera_esquina := distancia_hasta_primera_esquina(recorrido)
	verificar(primera_esquina == INF or (paso * cuadros_bloqueados > primera_esquina and continuo),
		"si la ida dobló una esquina, la cruza también en reversa sin atajar por una diagonal ni pedir otra ruta")
	# Al volver el turno normal debe poder reemplazar el prefijo y completar
	# la entrega real. No basta con haber mostrado un paso visual de salida.
	run.retirando = true
	for cuadro in 600:
		if h.carga == 0.0:
			break
		await get_tree().process_frame
		run._reloj += DELTA
		h._caminar(DELTA)
		segura = segura and run.cocina.libre(h.position, Cocina.MARGEN - 0.1)
	verificar(h.carga == 0.0 and h.estado == Hormiga.Estado.QUIETA
		and h.position.length() <= Hormiguero.RADIO_ENTRADA and segura
		and is_equal_approx(Juego.migas_run - saldo, carga_real),
		"tras recuperar turno llega físicamente al nido y acredita exactamente una entrega")
	run.queue_free()
	await get_tree().process_frame


func probar_guardas_sinteticas() -> void:
	# Fixture puro y explícitamente sintético: prueba la selección del prefijo,
	# no simula un viaje ni otorga carga, daño, vida, economía o un mapa falso.
	var h := Hormiga.new()
	var ida := PackedVector2Array([Vector2(80, 0), Vector2(80, 100), Vector2(160, 100)])
	h._origen_ruta = Vector2.ZERO
	h._ruta = ida.duplicate()
	h._indice_ruta = 2
	h.position = Vector2(120, 100)
	var posicion := h.position
	var esperada := PackedVector2Array([Vector2(80, 100), Vector2(80, 0), Vector2.ZERO])
	verificar(h._invertir_tramo_recorrido() == esperada and h._ruta == ida
		and h._indice_ruta == 2 and h.position == posicion,
		"fixture sintético: una ida parcial devuelve sólo los dos nodos ya recorridos y su origen, sin mutarlos")
	h._ruta = PackedVector2Array()
	verificar(h._invertir_tramo_recorrido().is_empty(), "fixture sintético: no inventa un prefijo si no había ruta")
	h._ruta = ida.duplicate()
	h._origen_ruta = Vector2.INF
	verificar(h._invertir_tramo_recorrido().is_empty(), "fixture sintético: un origen no finito descarta el prefijo")
	h._origen_ruta = Vector2.ZERO
	h._ruta_fallida = true
	verificar(h._invertir_tramo_recorrido().is_empty(), "fixture sintético: una ruta fallida no se convierte en un regreso presuntamente seguro")
	h._ruta_fallida = false
	h.position = Vector2(120, 120)
	verificar(h._invertir_tramo_recorrido().is_empty(), "fixture sintético: reposicionarse fuera del último segmento impide reutilizarlo")
	h.position = Vector2(200, 100)
	verificar(h._invertir_tramo_recorrido().is_empty(), "fixture sintético: estar sobre la prolongación de la recta no equivale a haber recorrido el segmento")
	h.position = Vector2(40, 0)
	h._indice_ruta = 0
	verificar(h._invertir_tramo_recorrido() == PackedVector2Array([Vector2.ZERO]),
		"fixture sintético: antes del primer nodo sólo vuelve al origen, sin visitar esquinas futuras")
	h.position = ida[-1]
	h._indice_ruta = ida.size()
	verificar(h._invertir_tramo_recorrido() == esperada,
		"fixture sintético: llegar al final invierte el recorrido sin repetir la posición actual")
	h._ruta = PackedVector2Array([Vector2.ZERO, Vector2(80, 0), Vector2(80, 100)])
	h._indice_ruta = 2
	h.position = Vector2(80, 50)
	verificar(h._invertir_tramo_recorrido() == PackedVector2Array([Vector2(80, 0), Vector2.ZERO]),
		"fixture sintético: el origen duplicado en la ruta se conserva una sola vez en el regreso")
	h.free()


func probar_puesto_cercano_retenido() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.colonia._activa = false
	run.radio_actual = 12000.0
	var mesa: PiezaCasa
	for parte: PiezaCasa in run.comidas.partes:
		if parte.pieza.tipo == "mesa_comedor":
			mesa = parte
			break
	verificar(mesa != null and mesa.preparar_material(),
		"puesto cercano: la ruta retenida se prueba contra la mesa real del comedor")
	if mesa == null or mesa.mordiscos == null:
		run.queue_free()
		await get_tree().process_frame
		return
	var desde := Vector2(mesa.rect_mundo.position.x - 160.0, mesa.rect_mundo.get_center().y)
	var puesto := mesa.punto_mordida(desde, run.radio_actual)
	var nuevo := puesto + Vector2(0, 2)
	var inicio := puesto + Vector2(-2, 0)
	var valido := puesto.is_finite() and mesa.alcanza_contacto(puesto) and mesa.alcanza_contacto(nuevo) \
		and run.cocina.libre(nuevo, Cocina.MARGEN) and run.cocina.segmento_libre(inicio, puesto) \
		and run.cocina.segmento_libre(puesto, nuevo)
	verificar(valido,
		"puesto cercano: P y P+2u tangentes son apoyos reales unidos por segmentos seguros")
	if not valido:
		run.queue_free()
		await get_tree().process_frame
		return
	var h := run.colonia._nacer("obrera", inicio)
	h.comida = mesa
	h.estado = Hormiga.Estado.YENDO_A_COMIDA
	h._version_objetivo = mesa.version_forma
	h._velocidad = 120.0 # Un cuadro alcanza exactamente el extremo viejo.
	h.objetivo = nuevo
	# Fixture de integración explícito: simula una ruta vigente cuyo destino
	# acaba de desplazarse dos unidades, menos que el umbral anterior de4u.
	# Ambos segmentos se certificaron contra la navegación real, no un mapa falso.
	h._ruta = PackedVector2Array([puesto])
	h._origen_ruta = inicio
	h._indice_ruta = 0
	h._meta_ruta = puesto
	h._pedido_ruta = puesto
	h._version_ruta = run.cocina.version
	h._ruta_fallida = false
	h._espera_ruta = 0.0
	var vida := mesa.vida
	var saldo := Juego.migas_run
	run.cocina._cuadro_rutas = Engine.get_process_frames()
	run.cocina._pedidos_cuadro = run.cocina.limite_rutas_por_cuadro
	run.cocina._tiempo_rutas_cuadro = 0
	var consultas := run.cocina.consultas_ruta
	h._caminar(DELTA)
	verificar(h.position.is_equal_approx(puesto) and h.comida == mesa \
		and h.estado == Hormiga.Estado.YENDO_A_COMIDA and h.objetivo == nuevo and h._esperando_ruta,
		"puesto cercano: llega al extremo viejo sin masticar ni olvidar el objetivo nuevo mientras espera turno")
	h._caminar(DELTA)
	verificar(h.position.is_equal_approx(puesto) and h.comida == mesa \
		and h.estado == Hormiga.Estado.YENDO_A_COMIDA and h.objetivo == nuevo and h._esperando_ruta,
		"puesto cercano: agotar la ruta vieja no abandona la comida con la nueva ruta todavía en cola")
	verificar(run.cocina.consultas_ruta == consultas \
		and run.cocina._pedidos_cuadro == run.cocina.limite_rutas_por_cuadro \
		and run.cocina._tiempo_rutas_cuadro == 0 and run.cocina._en_cola.size() == 1 \
		and run.cocina._en_cola.has(h.get_instance_id()) \
		and run.cocina._cola_rutas.size() - run.cocina._inicio_cola == 1,
		"puesto cercano: dos intentos cerrados conservan un único ticket y no consultan ni saltean el presupuesto")
	var llego := false
	var apoyo_correcto := false
	var seguro := true
	for cuadro in 180:
		await get_tree().process_frame # Liberar el presupuesto por su reloj normal.
		run._reloj += DELTA
		h._caminar(DELTA)
		seguro = seguro and run.cocina.libre(h.position, Cocina.MARGEN - 0.1)
		if h.estado == Hormiga.Estado.MORDIENDO:
			llego = true
			apoyo_correcto = h.position.distance_squared_to(nuevo) <= 0.0625 \
				and h.objetivo == nuevo and mesa.alcanza_contacto(h.position)
			break
	verificar(llego and apoyo_correcto and seguro and h.comida == mesa,
		"puesto cercano: tras recuperar turno alcanza P+2u antes de empezar a masticar")
	verificar(run.cocina.consultas_ruta == consultas + 1 and mesa.vida == vida \
		and h.carga == 0.0 and Juego.migas_run == saldo,
		"puesto cercano: completa un único reemplazo de ruta sin daño, carga ni pagos anticipados")
	if not llego or not apoyo_correcto:
		print("DIAG PUESTO CERCANO pos=", h.position, " viejo=", puesto, " nuevo=", nuevo,
			" estado=", h.estado, " objetivo=", h.objetivo, " meta=", h._meta_ruta,
			" ruta=", h._indice_ruta, "/", h._ruta.size(), " esperando=", h._esperando_ruta,
			" consultas=", run.cocina.consultas_ruta - consultas)
	run.queue_free()
	await get_tree().process_frame


func longitud_recorrido(recorrido: PackedVector2Array) -> float:
	var longitud := 0.0
	for i in range(1, recorrido.size()):
		longitud += recorrido[i - 1].distance_to(recorrido[i])
	return longitud


func distancia_hasta_primera_esquina(recorrido: PackedVector2Array) -> float:
	var distancia := 0.0
	for i in range(recorrido.size() - 2, 0, -1):
		distancia += recorrido[i + 1].distance_to(recorrido[i])
		var llegada := (recorrido[i] - recorrido[i + 1]).normalized()
		var salida := (recorrido[i - 1] - recorrido[i]).normalized()
		if llegada.dot(salida) < 0.999:
			return distancia
	return INF


func retroceder_por_recorrido(recorrido: PackedVector2Array, distancia: float) -> Vector2:
	var actual := recorrido[-1]
	for i in range(recorrido.size() - 2, -1, -1):
		var tramo := actual.distance_to(recorrido[i])
		if tramo > distancia:
			return actual.move_toward(recorrido[i], distancia)
		actual = recorrido[i]
		distancia -= tramo
	return actual


func recorrido_seguro(cocina: Cocina, recorrido: PackedVector2Array) -> bool:
	for i in range(1, recorrido.size()):
		if not cocina.segmento_libre(recorrido[i - 1], recorrido[i]):
			return false
	return true


func huellas_guardados() -> Dictionary:
	var huellas := {}
	for ruta: String in [Juego.RUTA_PARTIDA, Ajustes.RUTA]:
		huellas[ruta] = FileAccess.get_sha256(ruta) if FileAccess.file_exists(ruta) else "ausente"
	return huellas


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)
