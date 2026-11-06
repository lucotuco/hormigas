extends Node
## Mordida y regreso reales desde los puestos exactos de muebles de la casa.
## Daño/velocidad de fixture acortan el ensayo; no cambian los CSV ni pagan
## a distancia. Se usa la cola normal de rutas y una porción física por boca.
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	var huella := FileAccess.get_sha256(Juego.RUTA_PARTIDA) if FileAccess.file_exists(Juego.RUTA_PARTIDA) else "ausente"
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1, "excavar": 30}
	Juego._cache_stats.clear()
	seed(9081)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.radio_actual = 12000.0
	var casos: Array[Dictionary] = []
	for parte: PiezaCasa in run.comidas.partes:
		if parte.pieza.tipo not in ["sofa", "sillon", "alacena", "heladera", "cama"]:
			continue
		parte.preparar_material()
		for lado in 4:
			var dir := Vector2.from_angle(PI * lado / 2.0)
			var desde := parte.rect_mundo.get_center() + dir * (parte.rect_mundo.size.length() + 100.0)
			var puesto := parte.punto_trabajo(desde, run.radio_actual, false, lado)
			if puesto == Vector2.INF:
				continue
			var h := run.colonia._nacer("obrera", puesto)
			h.comida = parte
			h.estado = Hormiga.Estado.MORDIENDO
			h._reloj_mordida = 0.0
			h._dano = parte.vida_max
			h._capacidad = 1
			h._velocidad = 1500.0
			h._morder(0.02)
			verificar(h.carga > 0.0 and h.estado == Hormiga.Estado.VOLVIENDO,
				"%s lado%d: una porción real inicia el regreso desde el contacto" % [parte.pieza.tipo, lado])
			casos.append({"h": h, "nombre": "%s lado%d" % [parte.pieza.tipo, lado], "carga": h.carga, "entrego": false, "pos": h.position, "parte": parte})
	verificar(casos.size() == 28, "los siete muebles ofrecen sus 28 puestos: no se omiten silenciosamente los difíciles")
	if casos.size() != 28:
		run.queue_free()
		get_tree().quit(1)
		return
	var saldo := Juego.migas_run
	var seguro := true
	var max_pedidos := 0
	for cuadro in 1600:
		run._reloj += 1.0 / 60.0
		run.cocina.procesar_cambios()
		for caso: Dictionary in casos:
			var h: Hormiga = caso.h
			if caso.entrego:
				continue
			h._process(1.0 / 60.0)
			seguro = seguro and run.cocina.libre(h.position, Cocina.MARGEN - 0.1)
			if h.carga == 0.0:
				caso.entrego = true
				h.detener()
		max_pedidos = maxi(max_pedidos, run.cocina._pedidos_cuadro)
		await get_tree().process_frame
	var suma := 0.0
	for caso: Dictionary in casos:
		var h: Hormiga = caso.h
		suma += float(caso.carga)
		if not caso.entrego:
			var a := run.cocina._celda_cercana(h.position, run.cocina._suelo, false)
			var b := run.cocina._celda_cercana(h.objetivo, run.cocina._suelo, false)
			print("ANCLAJE ", caso.nombre, " a=", a, " b=", b,
				" tramo_directo=", run.cocina.segmento_libre(h.position, h.objetivo),
				" cercanos=", run.cocina._cercanos(Rect2(h.position - Vector2(150,150), Vector2(300,300)), false))
			print("REGRESO ATASCADO ", caso.nombre, " pos=", h.position, " inicio=", caso.pos, " estado=", h.estado,
				" carga=", h.carga, " libre=", run.cocina.libre(h.position, Cocina.MARGEN), " objetivo=", h.objetivo,
				" meta=", h._meta_ruta, " ruta=", h._indice_ruta, "/", h._ruta.size(), " espera=", h._esperando_ruta,
				" fallida=", h._ruta_fallida, " fallidas=", h._entradas_fallidas)
		verificar(caso.entrego, caso.nombre + ": llega físicamente y descarga sin quedar inmóvil con carga")
	verificar(not casos.is_empty() and is_equal_approx(Juego.migas_run - saldo, suma), "todas las porciones se pagan exactamente una vez al llegar")
	verificar(seguro and max_pedidos <= run.cocina.limite_rutas_por_cuadro,
		"las 28 salidas conservan colisiones y el presupuesto compartido de rutas")
	await probar_ida_y_vuelta(run, casos)
	await probar_carga_parcial(run, casos)
	probar_cache_y_limites(run, casos)
	run.queue_free()
	await get_tree().process_frame
	await probar_enjambre()
	var huella_final := FileAccess.get_sha256(Juego.RUTA_PARTIDA) if FileAccess.file_exists(Juego.RUTA_PARTIDA) else "ausente"
	verificar(huella == huella_final, "no se escribe la partida personal")
	print("Regreso desde bordes: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func probar_ida_y_vuelta(run: Run, casos: Array[Dictionary]) -> void:
	# No nace sobre el borde: recorre desde el nido los tres pasillos que la
	# grilla conservadora no representaba. El mueble ya tiene mordidas reales.
	for indice in [0, 5, 6]:
		var caso: Dictionary = casos[indice]
		var parte: PiezaCasa = caso.parte
		var puesto := parte.punto_trabajo(caso.pos, run.radio_actual, false, 3)
		var ida := run.cocina.ruta(Vector2.ZERO, puesto, run.radio_actual)
		var vuelta := run.cocina.ruta(puesto, Vector2.ZERO, run.radio_actual)
		verificar(ruta_segura(run.cocina, Vector2.ZERO, ida) and ruta_segura(run.cocina, puesto, vuelta),
			caso.nombre + ": ambos extremos se conectan con tramos físicamente libres")
		var h := run.colonia._nacer("obrera", Vector2.ZERO)
		h.comida = parte
		h.estado = Hormiga.Estado.YENDO_A_COMIDA
		h.objetivo = puesto
		h._version_objetivo = parte.version_forma
		h._reubicando_frente = true
		h._capacidad = 1
		h._dano = parte.vida_max
		h._velocidad = 1500.0
		var saldo := Juego.migas_run
		var seguro := true
		for cuadro in 1200:
			run._reloj += 1.0 / 60.0
			run.cocina.procesar_cambios()
			h._process(1.0 / 60.0)
			seguro = seguro and run.cocina.libre(h.position, Cocina.MARGEN - 0.1)
			await get_tree().process_frame
			if h._tiempo_descarga > 0.0:
				break
		verificar(h._tiempo_bocado >= 0.0 and h._tiempo_descarga > 0.0 and h.carga == 0.0
			and h.position.length() <= Hormiguero.RADIO_ENTRADA and Juego.migas_run > saldo and seguro,
			caso.nombre + ": sale del nido, llega al frente, muerde y vuelve sin colocarla allí a mano")
		h.detener()


func probar_carga_parcial(run: Run, casos: Array[Dictionary]) -> void:
	for indice in [0, 5, 6, 8, 12, 16]:
		var caso: Dictionary = casos[indice]
		var parte: PiezaCasa = caso.parte
		var puesto := parte.punto_trabajo(caso.pos, run.radio_actual, false, 2)
		var h := run.colonia._nacer("obrera", puesto)
		h.comida = parte
		h.estado = Hormiga.Estado.MORDIENDO
		h._capacidad = 3
		h._porciones_ciclo = 1
		h._reloj_mordida = 0.0
		h._dano = parte.vida_max
		h._velocidad = 1500.0
		h._morder(0.02)
		verificar(h.carga > 0.0 and h.bocados == 1 and h.estado == Hormiga.Estado.MORDIENDO,
			caso.nombre + ": el primer trozo no llena artificialmente un buche de tres")
		# Mantener un llamado real no debe retener a la que ya necesita volver.
		run.feromonas.mantener_en(puesto)
		var saldo := Juego.migas_run
		var seguro := true
		for cuadro in 1200:
			run._reloj += 1.0 / 60.0
			run.cocina.procesar_cambios()
			h._process(1.0 / 60.0)
			seguro = seguro and run.cocina.libre(h.position, Cocina.MARGEN - 0.1)
			await get_tree().process_frame
			if h._tiempo_descarga > 0.0:
				break
		verificar(h._tiempo_descarga > 0.0 and h.carga == 0.0 and Juego.migas_run > saldo and seguro,
			caso.nombre + ": tras varios recortes termina la carga y entrega aun manteniendo feromonas")
		run.feromonas.soltar()
		h.detener()


func ruta_segura(cocina: Cocina, desde: Vector2, ruta: PackedVector2Array, volando := false) -> bool:
	if ruta.is_empty():
		return false
	for punto: Vector2 in ruta:
		if not cocina.segmento_libre(desde, punto, volando):
			return false
		desde = punto
	return true


func probar_cache_y_limites(run: Run, casos: Array[Dictionary]) -> void:
	var cocina := run.cocina
	var origen: Vector2 = casos[0].pos
	cocina.ruta(origen, Vector2.ZERO, run.radio_actual)
	var aciertos := cocina.aciertos_cache_enlace
	var ruta := cocina.ruta(origen, Vector2.ZERO, run.radio_actual)
	verificar(cocina.aciertos_cache_enlace > aciertos and ruta_segura(cocina, origen, ruta),
		"un puesto repetido reutiliza su puente positivo sin perder seguridad")
	verificar(cocina._esquinas_enlace(origen, run.radio_actual, false).size() <= Cocina.MAX_VERTICES_ENLACE
		and cocina.pruebas_enlace_max <= Cocina.MAX_PRUEBAS_ENLACE,
		"el puente mantiene dieciséis vértices y treinta y dos pruebas exactas como máximo")
	cocina._actualizar_radio(run.radio_actual - 10.0)
	verificar(cocina._enlaces_celda.is_empty(), "reducir territorio menos de veinte unidades también invalida los puentes")
	cocina.ruta(origen, Vector2.ZERO, run.radio_actual)
	var parte: PiezaCasa = casos[0].parte
	var formas: Array[Rect2] = []
	formas.assign(cocina._obstaculos[parte.pieza.clave].recortes)
	cocina.recortar_pieza(parte.pieza.clave, formas)
	verificar(cocina._enlaces_celda.is_empty(), "la publicación de colisiones del mueble invalida el puente anterior")
	verificar(cocina._enlazar_celda(parte.rect_mundo.get_center(), cocina._suelo, false, run.radio_actual).is_empty(),
		"un origen dentro del material no se teletransporta al exterior")
	verificar(ruta_segura(cocina, origen, cocina.ruta(origen, Vector2.ZERO, run.radio_actual, true), true),
		"las voladoras conservan sus colisiones propias, sin tratar muebles como paredes")


func probar_enjambre() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "excavar": 30}
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.radio_actual = 12000.0
	# Fixture de transporte, no piloto económico: la carga nace explícitamente
	# en el ensayo. El dinero se permite sólo al llegar físicamente al acceso.
	var entradas: Array[Vector2] = [Vector2(1611, -593), Vector2(-632, 1281), Vector2(-861, 1019)]
	for i in 500:
		var punto: Vector2 = entradas[i % 3]
		if i % 3 == 1:
			punto.x += i * 0.03
		else:
			punto.y += i * 0.03
		var h := run.colonia._nacer("obrera", punto)
		h.carga = 0.125
		h._velocidad = 1500.0
		h._volver()
	var saldo := Juego.migas_run
	var max_pedidos := 0
	var max_cache := 0
	var seguras := true
	var pendientes := 500
	var rutas_certificadas := 0
	for cuadro in 1600:
		run._reloj += 1.0 / 60.0
		run.cocina.procesar_cambios()
		pendientes = 0
		for h: Hormiga in run.colonia.hormigas:
			if h.estado == Hormiga.Estado.QUIETA:
				continue
			var posicion_previa := h.position
			var meta_previa := h._meta_ruta
			h._process(1.0 / 60.0)
			if meta_previa == Vector2.INF and h._meta_ruta != Vector2.INF and not h._ruta.is_empty():
				seguras = seguras and ruta_segura(run.cocina, posicion_previa, h._ruta)
				rutas_certificadas += 1
			seguras = seguras and run.cocina.libre(h.position, Cocina.MARGEN - 0.1)
			if h.carga == 0.0:
				h.detener()
			else:
				pendientes += 1
		max_pedidos = maxi(max_pedidos, run.cocina._pedidos_cuadro)
		max_cache = maxi(max_cache, run.cocina._enlaces_celda.size())
		await get_tree().process_frame
		if pendientes == 0:
			break
	verificar(pendientes == 0 and is_equal_approx(Juego.migas_run - saldo, 62.5),
		"500 cargadas salen de los pasillos finos y entregan exactamente sus 62,5 migas")
	verificar(seguras and max_pedidos <= run.cocina.limite_rutas_por_cuadro,
		"el enjambre no atraviesa muebles ni ejecuta más rutas que el cupo compartido")
	verificar(rutas_certificadas == 500, "se certifican todas las aristas completas de los quinientos regresos, no sólo posiciones muestreadas")
	verificar(max_cache <= Cocina.MAX_CACHE_ENLACES and run.cocina.pruebas_enlace_max <= Cocina.MAX_PRUEBAS_ENLACE,
		"quinientos orígenes distintos no crecen el caché ni las pruebas de conexión sin límite")
	print("ENLACES QA: ", run.cocina.consultas_enlace, " consultas; ", run.cocina.aciertos_cache_enlace,
		" reutilizaciones; ", max_cache, " enlaces retenidos máximo; ", run.cocina.pruebas_enlace_max, " pruebas por enlace máximo")
	run.queue_free()
	await get_tree().process_frame


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)
