extends Node
## Regresos reales, retiro sin daño, adaptaciones y migración. No toca partidas.
var total := 0
var fallas := 0
const RUN := preload("res://mundo/run.tscn")

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")  # compara textos en español; CI corre con el sistema en inglés
	Sonido.silenciado = true
	seed(713)
	probar_guardado()
	await probar_entradas()
	await probar_entrada_aislada()
	await probar_retiro()
	await probar_destinos()
	await probar_efectos()
	await probar_desglose()
	Juego.reiniciar_estado()
	print("Logística: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)

func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", detalle)

func crear(destino := "casa") -> Run:
	Juego.lugar_actual = destino
	var r: Run = RUN.instantiate()
	add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	r.colonia._activa = false
	return r

func probar_guardado() -> void:
	Juego.reiniciar_estado()
	Juego.restaurar_partida({"version": 5, "migas": 73, "niveles": {"mandibulas": 4}})
	verificar(Juego.migas == 73 and Juego.records_destino.is_empty() and Juego.stat("entradas") == 0, "partidas anteriores conservan mejoras y no inventan récords")
	Juego.registrar_record(100, 0.6)
	Juego.registrar_record(30, 0.2)
	verificar(Juego.records_destino.casa.produccion == 100 and Juego.records_destino.casa.objetivo == 0.6, "los intentos inferiores no borran los mejores resultados")
	Juego.completar_destino()
	verificar(Juego.stat("entradas") == 1, "conquistar casa habilita una entrada permanente")
	var datos: Dictionary = JSON.parse_string(JSON.stringify(Juego.datos_partida()))
	Juego.reiniciar_estado()
	Juego.restaurar_partida(datos)
	verificar(Juego.records_destino.casa.objetivo == 0.6 and Juego.stat("entradas") == 1, "récords y adaptación sobreviven a guardar y cargar")
	verificar("Memoria de la madera" in Juego.oportunidades_jalea(), "la fundación muestra una compra concreta alcanzable")
	Juego.fundar_colonia()
	verificar(Juego.records_destino.casa.produccion == 100 and Juego.stat("entradas") == 1, "fundar conserva récords y adaptaciones")
	Juego.restaurar_partida({"records_destino": {"inventado": {}, "casa": {"produccion": -8, "objetivo": 7}, "museo": "roto"}})
	verificar(Juego.records_destino.size() == 1 and Juego.records_destino.casa == {"produccion": 0.0, "objetivo": 1.0}, "la carga valida destinos y acota los datos nuevos")

func probar_entradas() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"entradas": 5, "mordida_madera": 1}
	Juego._cache_stats.clear()
	var r := crear()
	verificar(r.entradas.puntos == [Vector2.ZERO], "no aparecen accesos fuera del territorio inicial")
	r.radio_actual = 12000
	r.entradas.actualizar()
	verificar(r.entradas.puntos == [Vector2.ZERO] and r.entradas.disponibles() == 5,
		"la mejora habilita cupos pero no coloca entradas automáticamente")
	# Cambio pedido: las posiciones las elige el jugador, no el generador.
	for ambiente in PlanoCasa.ambientes():
		var rect: Rect2 = ambiente.rect
		for x in [0.15, 0.5, 0.85]:
			for y in [0.15, 0.5, 0.85]:
				r.entradas.colocar(rect.position + rect.size * Vector2(x, y))
	verificar(r.entradas.puntos.size() > 2 and r.entradas.puntos.size() <= 6, "el jugador puede colocar sus accesos comprados en piso libre sin superar el cupo")
	var libres := true
	for p in r.entradas.puntos:
		libres = libres and r.cocina.libre(p, Cocina.MARGEN)
	verificar(libres, "ninguna entrada nace dentro de una pared o mueble")
	var entrada: Vector2 = r.entradas.puntos[1]
	var h := r.colonia._nacer("cargadora", entrada + Vector2(50, 0))
	h.carga = 123
	h._material_carga = 1
	h._volver()
	verificar(h.objetivo == entrada, "la cargadora elige la entrega próxima en lugar de cruzar toda la casa")
	verificar(r.entradas.elegir(entrada, {entrada: true}) != entrada, "una entrada sin ruta queda excluida del siguiente intento")
	for i in 300:
		h._process(1.0 / 60)
		await get_tree().process_frame
		if h.carga == 0:
			break
	verificar(h.carga == 0 and Juego.migas_run == 123 and r.ingresos[1] == 123, "recorre la ruta y entrega exactamente una vez en el acceso secundario")
	var c := r.comidas.lista[0]
	h.position = c.position + Vector2(60, 0)
	h.comida = c
	h.estado = Hormiga.Estado.EXPLORANDO
	h._pensar()
	var punto := h.objetivo
	h.position += Vector2(8, 0)
	h._pensar()
	verificar(h.objetivo == punto, "la IA conserva su puesto durante el acercamiento al mismo recurso")
	# Levantar el acceso NO modifica el piso: la ruta vieja seguiría siendo
	# válida y permitía descargar donde ya no había agujero.
	var regreso := r.colonia._nacer("cargadora", entrada + Vector2(50, 0))
	regreso.carga = 13
	regreso._carga_origen.assign([0.0, 5.0, 8.0])
	regreso._material_carga = 3
	regreso.comida = c
	regreso.bocados = 2
	regreso._retazos.append(Rect2(1, 2, 3, 4))
	regreso._tamanos_retazos.append(Vector2(3, 4))
	regreso._origenes_retazos.append(c.position)
	regreso._angulos_retazos.append(0.1)
	regreso._tiempos_retazos.append(0.0)
	regreso._volver()
	verificar(regreso.objetivo == entrada, "el caso de mover empieza con una cargadora regresando al acceso que se levantará")
	regreso._ruta = PackedVector2Array([entrada])
	regreso._meta_ruta = entrada
	regreso._pedido_ruta = entrada
	regreso._indice_ruta = 0
	regreso._espera_ruta = 0.7
	# Un pedido real ya en espera debe conservar su ticket al cambiar la meta.
	r.cocina._cuadro_rutas = Engine.get_process_frames()
	r.cocina._pedidos_cuadro = r.cocina.limite_rutas_por_cuadro
	verificar(not r.cocina.admitir_ruta(regreso) and r.cocina._en_cola.has(regreso.get_instance_id()),
		"la cargadora entra realmente en la cola mientras está agotado el presupuesto")
	var ticket: int = r.cocina._en_cola[regreso.get_instance_id()]
	var otra_entrada := r.entradas.puntos[2]
	var otro := r.colonia._nacer("obrera", otra_entrada + Vector2(10, 0))
	otro.carga = 3
	otro._volver()
	otro._ruta = PackedVector2Array([otra_entrada])
	otro._meta_ruta = otra_entrada
	otro._pedido_ruta = otra_entrada
	var consultas := r.cocina.consultas_ruta
	var ingresos := Juego.migas_run
	verificar(r.entradas.quitar(entrada), "se levanta realmente el acceso aunque su piso y la ruta sigan libres")
	verificar(regreso.objetivo != entrada and r.entradas.puntos.has(regreso.objetivo)
		and regreso._ruta.is_empty() and regreso._meta_ruta == Vector2.INF
		and regreso._pedido_ruta == Vector2.INF and regreso._espera_ruta == 0,
		"levantar reasigna el retorno y descarta el recorrido viejo antes de otro movimiento")
	var nueva_entrada := regreso.objetivo
	verificar(regreso.carga == 13 and regreso._carga_origen == [0.0, 5.0, 8.0]
		and regreso.bocados == 2 and regreso._recuerdo == c
		and regreso._material_carga == 3 and regreso._retazos == [Rect2(1, 2, 3, 4)]
		and regreso._tamanos_retazos == [Vector2(3, 4)] and regreso._origenes_retazos == [c.position]
		and regreso._angulos_retazos == [0.1] and regreso._tiempos_retazos == [0.0],
		"reasignar conserva toda la carga, su desglose, el recuerdo y las muestras físicas")
	verificar(otro.objetivo == otra_entrada and otro._ruta == PackedVector2Array([otra_entrada])
		and otro.carga == 3 and h.objetivo == punto,
		"no se alteran retornos a otros accesos ni hormigas que están recolectando")
	verificar(r.cocina.consultas_ruta == consultas and Juego.migas_run == ingresos,
		"quitar no ejecuta A* en masa ni entrega recursos a distancia")
	regreso.position = entrada
	# Agotar este cuadro obliga a esperar en el hueco eliminado. No puede
	# descargar ahí ni reutilizar la ruta mientras espera el presupuesto normal.
	r.cocina._cuadro_rutas = Engine.get_process_frames()
	r.cocina._pedidos_cuadro = r.cocina.limite_rutas_por_cuadro
	regreso._caminar(0)
	verificar(regreso.carga == 13 and Juego.migas_run == ingresos and regreso._ruta.is_empty(),
		"esperar turno sobre el agujero eliminado no permite una descarga fantasma")
	verificar(r.cocina._en_cola.get(regreso.get_instance_id(), -1) == ticket,
		"cambiar la meta no duplica ni manda al final el ticket real que ya esperaba")
	regreso._velocidad = 1600 # Acelera sólo el viaje de este fixture.
	var max_rutas := 0
	for i in 900:
		await get_tree().process_frame
		regreso._process(1.0 / 60)
		max_rutas = maxi(max_rutas, r.cocina._pedidos_cuadro)
		if regreso.carga == 0:
			break
	verificar(regreso.carga == 0 and is_equal_approx(Juego.migas_run - ingresos, 13)
		and r.entradas.puntos.has(nueva_entrada)
		and regreso.position.distance_to(nueva_entrada) <= Hormiguero.RADIO_ENTRADA
		and max_rutas <= r.cocina.limite_rutas_por_cuadro,
		"la carga llega exactamente una vez a un acceso vigente usando la cola de rutas existente")
	r.queue_free()
	await get_tree().process_frame

func probar_retiro() -> void:
	Juego.reiniciar_estado()
	var r := crear()
	var h := r.colonia._nacer("obrera", Vector2(25, 0))
	h.carga = 12
	var en_camino := r.colonia._nacer("obrera", Vector2(40, 0))
	en_camino.carga = 3
	en_camino._volver()
	en_camino._caminar(0)
	var ruta_previa := en_camino._ruta.duplicate()
	var vacia := r.colonia._nacer()
	var comida := r.comidas.lista[0]
	h.comida = comida
	h.estado = Hormiga.Estado.MORDIENDO
	var vida := comida.vida
	r._iniciar_retirada()
	verificar(not ruta_previa.is_empty() and en_camino._ruta == ruta_previa, "la retirada conserva las rutas de las hormigas que ya estaban volviendo")
	verificar(r.retirando and not r.activa and vacia.estado == Hormiga.Estado.QUIETA, "el cierre detiene nuevas recolectoras y mantiene sólo los regresos")
	for i in 60:
		h._process(1.0 / 60)
		en_camino._process(1.0 / 60)
		r._process(1.0 / 60)
		await get_tree().process_frame
		if r.terminada:
			break
	verificar(r.terminada and Juego.migas == 15 and comida.vida == vida, "la última carga llega sin mordidas nuevas ni doble cobro")
	r._terminar()
	verificar(Juego.runs_jugadas == 1 and Juego.migas == 15, "el cierre es idempotente")
	r.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	r = crear()
	h = r.colonia._nacer()
	h.carga = 99
	r._iniciar_retirada()
	r._process(Juego.stat("retirada") + 0.1)
	verificar(r.terminada and Juego.migas == 0 and r.cargas_pendientes == 99, "una carga inaccesible no bloquea el cierre ni se cobra a distancia")
	r.queue_free()
	await get_tree().process_frame

func probar_entrada_aislada() -> void:
	Juego.reiniciar_estado()
	var r := crear()
	r.radio_actual = 2000
	r.entradas.puntos.assign([Vector2.ZERO, Vector2(-400, 0)])
	# Un acceso está libre pero encerrado: probar el fallo real de A*, no
	# sólo la exclusión matemática de un punto.
	var paredes := [Rect2(-550, -150, 300, 50), Rect2(-550, 100, 300, 50), Rect2(-550, -150, 50, 300), Rect2(-300, -150, 50, 300)]
	for i in paredes.size():
		var rect: Rect2 = paredes[i]
		var clave := "aislamiento:%d" % i
		r.cocina._obstaculos[clave] = {"rect": rect, "pared": true}
		for x in range(floori(rect.position.x / Cocina.SECTOR), floori(rect.end.x / Cocina.SECTOR) + 1):
			for y in range(floori(rect.position.y / Cocina.SECTOR), floori(rect.end.y / Cocina.SECTOR) + 1):
				var sector := Vector2i(x, y)
				if not r.cocina._sectores.has(sector):
					r.cocina._sectores[sector] = []
				r.cocina._sectores[sector].append(clave)
	var h := r.colonia._nacer("obrera", Vector2(-650, 0))
	h.carga = 31
	h._velocidad = 400
	h._volver()
	var rechazo := false
	for i in 600:
		h._process(1.0 / 60)
		rechazo = rechazo or h._entradas_fallidas.has(Vector2(-400, 0))
		await get_tree().process_frame
		if h.carga == 0:
			break
	verificar(rechazo and h.carga == 0 and Juego.migas_run == 31, "si el acceso cercano está aislado vuelve al nido por una ruta real sin perder carga")
	r.queue_free()
	await get_tree().process_frame

func probar_destinos() -> void:
	Juego.reiniciar_estado()
	Juego.lugares_completados = {"restaurante": true, "museo": true, "obelisco": true, "coliseo": true, "eiffel": true}
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var r := crear()
	r.radio_actual = 12000
	r.reglas.tesoro_abierto()
	verificar(r.reglas.festin == 11 and r.reglas.carga_frenesi() == 10, "el restaurante lleva festines prolongados a la casa")
	verificar(r.reglas.cantidad_tesoro() == 4 and is_equal_approx(Juego.stat("corrosion_factor"), 0.3), "museo y Obelisco mejoran hallazgos y corrosión fuera de su destino")
	verificar(Juego.stat("retirada") == 10, "Eiffel extiende las entregas finales en cualquier mapa")
	for parte in r.comidas.partes:
		if parte.pieza.tipo == "mesa":
			r.reglas.parte_devorada(parte)
			break
	verificar(not r.reglas._pendientes.is_empty() and r.reglas._pendientes.size() <= 2, "la adaptación del Coliseo conecta derrumbes con dos vecinos como máximo")
	var presupuesto := r.reglas._marcadas.size()
	r.activa = false
	r.reglas._process(0.2)
	verificar(r.reglas._pendientes.is_empty() and presupuesto <= 24, "el retiro cancela cadenas pendientes con trabajo acotado")
	r.queue_free()
	await get_tree().process_frame

func probar_efectos() -> void:
	Juego.reiniciar_estado()
	var r := crear()
	var pos := r.get_canvas_transform().affine_inverse() * (get_viewport().get_visible_rect().size * 0.5)
	r.efectos.numero(pos, 10, Color.YELLOW)
	r.efectos.numero(pos + Vector2(5, 0), 20, Color.YELLOW)
	verificar(r.efectos._textos.size() == 1 and r.efectos._textos[0].cantidad == 30, "los números cercanos se agrupan sin perder su valor")
	r.efectos._process(0.4)
	r.efectos.numero(pos, 5, Color.YELLOW)
	verificar(r.efectos._textos.size() == 2 and r.efectos._textos[0].vida < 0.55, "un flujo continuo no prolonga indefinidamente el mismo texto")
	for i in 100:
		r.efectos.habilidad(pos, pos + Vector2(20, 0), Color.WHITE)
	verificar(r.efectos._marcas.size() == 1, "cien habilidades simultáneas respetan el enfriamiento visual compartido")
	r.efectos._process(1)
	verificar(r.efectos._marcas.is_empty() and r.efectos._textos.is_empty(), "las señales visuales liberan sus listas al terminar")
	r.queue_free()
	await get_tree().process_frame

func probar_desglose() -> void:
	Juego.reiniciar_estado()
	var r := crear()
	r.comidas.soltar_fragmento(Vector2(-100, 0), 20, 1)
	var pila: FragmentoCasa = r.comidas.fragmentos.back()
	pila.sumar(30, 3)
	var h := r.colonia._nacer("cargadora", pila.position)
	h.comida = pila
	h.estado = Hormiga.Estado.MORDIENDO
	h._reloj_mordida = 0
	h._morder(0.1)
	h._descargar()
	verificar(Juego.migas_run == 50 and r.ingresos[1] == 20 and r.ingresos[2] == 30, "los montones mixtos conservan el origen de cada ingreso hasta la entrega")
	r.registrar_ingreso(1e45, 2)
	verificar(is_finite(r.ingresos[2]) and is_equal_approx(r.ingresos[2], 1e45), "las estadísticas usan precisión de 64 bits para cantidades incrementales grandes")
	r.queue_free()
	await get_tree().process_frame
