extends Node
## Máscara persistente y economía: el daño se cobra sólo al retirar material.
const RECT := Rect2(-40, 25, 100, 80)

class ComidaConRetazo extends Comida:
	## Doble de transporte: la región del atlas usa tres píxeles por unidad.
	var region_prueba := Rect2(111, 222, 9, 7)
	func region_bocado() -> Rect2:
		return region_prueba
	func tamano_bocado() -> Vector2:
		return region_prueba.size / 3.0
	func morder_local(dano: float, _pos: Vector2, _lado_max := 6.0) -> float:
		# Este doble aísla transporte/liberación. La extracción física real y
		# su cuantización se prueban con objetos sin doble en porciones_reales.
		if muerta or dano <= 0:
			return 0
		var real := minf(dano, vida)
		vida -= real
		if vida <= 0:
			muerta = true
			destruida.emit(self)
			queue_free()
		return recompensa * real / vida_max * Juego.stat("multiplicador_migas")

var total := 0
var fallas := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	probar_configuracion()
	probar_lados_y_porcion()
	probar_precision()
	probar_aire()
	probar_dieciseis_celdas()
	probar_reconfiguracion()
	await probar_carga_sin_fuente()
	await probar_buche_acotado()
	await probar_economia_pieza()
	await probar_corte_y_barrido()
	Juego.reiniciar_estado()
	print("Mordiscos de material: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)

func nuevo(vida := 80.0) -> MordiscosMaterial:
	var mordiscos := MordiscosMaterial.new()
	mordiscos.configurar(RECT, Vector2i.ONE, [[RECT]], PackedFloat64Array([vida]))
	return mordiscos

func probar_configuracion() -> void:
	var m := nuevo()
	verificar(is_equal_approx(m.vida_celda(0), 80) and is_equal_approx(m.area_total(), RECT.get_area()), "vida y área inicial se reparten sin pérdidas ni duplicación")
	verificar(m.contiene(RECT.get_center()) and not m.contiene(RECT.position - Vector2.ONE), "la representación no agrega material fuera del rectángulo")
	var desde := RECT.position - Vector2(20, 10)
	var cercano := m.material_cercano(desde)
	var paso := RECT.size / Vector2(m.tamano_mascara())
	# La máscara devuelve un punto interior del primer píxel sólido.
	verificar(m.contiene(cercano) and cercano.distance_to(RECT.position) <= paso.length(), "el punto cercano cae en el primer píxel sólido y no en el centro del dibujo")
	verificar(m.punto_celda(0, desde) == cercano and m.punto_celda(-1, RECT.position) == Vector2.INF, "la consulta local ignora celdas inválidas y devuelve material real")

func probar_lados_y_porcion() -> void:
	var m := nuevo()
	var cobrado := 0.0
	var mono := true
	var conservacion := true
	var porciones := true
	var retirados: Array[Vector2] = []
	var posiciones := [RECT.position + Vector2(-20, 10), RECT.position + Vector2(120, 10), RECT.position + Vector2(20, -20), RECT.position + Vector2(20, 100)]
	for i in 20:
		var area_antes := m.area_total()
		var real := m.recortar(0, 3, posiciones[i % posiciones.size()])
		cobrado += real
		var porcion := m.ultima_porcion
		porciones = porciones and real > 0 and porcion.has_area() and RECT.encloses(porcion)
		# Un evento bulk puede quitar muchos píxeles separados. Su muestra es
		# una AABB de diagnóstico, no un retazo sólido para transportar.
		porciones = porciones and area_antes - m.area_total() > 0
		porciones = porciones and area_antes - m.area_total() <= porcion.get_area() + 0.0001
		for p in retirados:
			mono = mono and not m.contiene(p)
		for y in 9:
			for x in 11:
				var p := RECT.position + RECT.size * Vector2((x + 0.37) / 11, (y + 0.31) / 9)
				if not m.contiene(p):
					retirados.append(p)
		conservacion = conservacion and cobrado <= (i + 1) * 3 + 0.000001
		conservacion = conservacion and absf(m.vida_celda(0) - (80 - cobrado)) < 0.000001
		conservacion = conservacion and absf(m.area_total() / RECT.get_area() - m.vida_celda(0) / 80) < 0.000001
	verificar(mono, "el daño de eventos desde lados opuestos nunca repone agujeros anteriores")
	verificar(porciones, "la AABB de un evento queda dentro de la celda y contiene toda el área que retiró")
	verificar(conservacion, "el daño cobrado no supera el aportado y conserva vida y área, incluido el crédito subpíxel")
	m.recortar(0, 10000, RECT.position)
	verificar(m.vida_celda(0) == 0 and m.area_total() == 0 and m.material_cercano(RECT.position) == Vector2.INF, "un evento suficientemente fuerte agota toda la celda sin material fantasma")
	m.recortar(0, 1, RECT.position)
	verificar(not m.ultima_porcion.has_area(), "un recurso agotado no produce una porción nueva")

func probar_precision() -> void:
	var m := nuevo(1)
	var real := 0.0
	var conservado := true
	for i in 1000:
		real += m.recortar(0, 0.000001, RECT.position + Vector2(-1, 10))
		conservado = conservado and real <= (i + 1) * 0.000001 + 0.000000001
	verificar(real > 0 and conservado and absf(m.vida_celda(0) - (1 - real)) < 0.00000001, "mil daños pequeños se acumulan sin cobrar resistencia antes de retirar un píxel")
	verificar(absf(m.area_total() / RECT.get_area() - m.vida_celda(0)) < 0.000001, "la vida restante coincide con el material restante tras el crédito pequeño")
	var area := m.area_total()
	var vida := m.vida_celda(0)
	for dano in [0.0, -1.0, NAN, INF]:
		var retirado := m.recortar(0, dano, RECT.position)
		verificar(retirado == 0 and m.vida_celda(0) == vida and m.area_total() == area and not m.ultima_porcion.has_area(), "un daño no positivo o no finito no altera material ni entrega retazo")
	m.recortar(-1, 1, RECT.position)
	m.recortar(64, 1, RECT.position)
	verificar(m.vida_celda(0) == vida and m.area_total() == area, "una celda inválida no toca el material vecino")

func probar_aire() -> void:
	var m := MordiscosMaterial.new()
	var forma := Rect2(RECT.position + Vector2(2, 4), Vector2(10, 12))
	m.configurar(RECT, Vector2i.ONE, [[forma]], PackedFloat64Array([25]))
	verificar(m.vida_celda(0) == 25 and not m.contiene(RECT.get_center()), "el aire no recibe material ni resistencia")
	verificar(absf(m.area_total() - forma.get_area()) < 0.001, "la máscara inicial conserva solamente el área ocupada")
	m.recortar(0, 5, RECT.end)
	verificar(m.ultima_porcion.has_area() and forma.encloses(m.ultima_porcion), "un evento desde el aire retira sólo material existente")
	m.limpiar_celda(0)
	verificar(m.vida_celda(0) == 0 and m.area_total() == 0 and not m.ultima_porcion.has_area(), "el derrumbe limpia la celda sin inventar otra mordida transportable")
	m.configurar(RECT, Vector2i.ONE, [[]], PackedFloat64Array([0]))
	verificar(m.area_total() == 0 and m.material_cercano(RECT.position) == Vector2.INF, "una celda de aire vacía sigue vacía al reconstruir")

func probar_dieciseis_celdas() -> void:
	var rect := Rect2(-320, 250, 640, 480)
	var formas: Array = []
	var vidas := PackedFloat64Array()
	for y in 4:
		for x in 4:
			formas.append([Rect2(rect.position + Vector2(x, y) * rect.size / 4, rect.size / 4)])
			vidas.append(1 + y * 4 + x)
	var m := MordiscosMaterial.new()
	m.configurar(rect, Vector2i(4, 4), formas, vidas)
	var suma := 0.0
	for i in 16:
		suma += m.vida_celda(i)
	verificar(suma == 136 and is_equal_approx(m.area_total(), rect.get_area()), "dieciséis celdas conservan toda su resistencia y superficie")
	var area_celda := m.area_celda(15)
	var area := m.area_total()
	m.recortar(15, 1000, rect.end)
	var intactas := true
	for i in 15:
		intactas = intactas and m.vida_celda(i) == i + 1
	verificar(intactas and m.vida_celda(15) == 0 and is_equal_approx(m.area_total(), area - area_celda), "agotar la última celda no toca las otras quince")
	verificar(m.punto_celda(15, rect.end) == Vector2.INF and m.punto_celda(14, rect.end) != Vector2.INF, "la elección por celda ignora material agotado sin perder celdas vivas")

func probar_reconfiguracion() -> void:
	var m := nuevo()
	m.recortar(0, 1000, RECT.position)
	var formas: Array = [[RECT]]
	var copia := formas.duplicate(true)
	var vidas := PackedFloat64Array([31])
	m.configurar(RECT, Vector2i.ONE, formas, vidas)
	verificar(m.vida_celda(0) == 31 and is_equal_approx(m.area_total(), RECT.get_area()) and not m.ultima_porcion.has_area(), "reutilizar el helper reinicia vida, máscara y último retazo")
	verificar(formas == copia and vidas[0] == 31, "configurar no modifica geometría ni vida del llamador")
	m.configurar(RECT, Vector2i(8, 8), formas, vidas)
	verificar(m.area_total() == 0 and m.vida_celda(63) == 0, "una grilla fuera de contrato no crea material ni resistencia")

func crear_run() -> Run:
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.colonia._activa = false
	return run

func agregar_doble(run: Run, vida: float, recompensa: float) -> ComidaConRetazo:
	var fuente := ComidaConRetazo.new()
	run.comidas.add_child(fuente)
	var datos: Dictionary = Juego.comidas[0].duplicate()
	datos.vida = vida
	datos.recompensa = recompensa
	fuente.configurar(datos, 417)
	fuente.position = Vector2(-100, -130)
	return fuente

func primera_silla(run: Run) -> PiezaCasa:
	for parte in run.comidas.partes:
		if parte.pieza.get("perfil", "") == "silla_inicial":
			return parte
	return null

func suma_fragmentos(run: Run) -> float:
	var total_valor := 0.0
	for fragmento in run.comidas.fragmentos:
		if is_instance_valid(fragmento) and not fragmento.muerta:
			total_valor += fragmento.recompensa
	return total_valor

func probar_carga_sin_fuente() -> void:
	var run := crear_run()
	var fuente := agregar_doble(run, 1, 21)
	var h := run.colonia._nacer("obrera", fuente.punto_mordida(Vector2.ZERO, run.radio_actual))
	h.comida = fuente
	h._reloj_mordida = 0
	h._velocidad = 400
	h._morder(0.1)
	var esperada := fuente.region_prueba
	verificar(h.estado == Hormiga.Estado.VOLVIENDO and h.carga == 21 and h._retazos == [esperada] and Juego.migas_run == 0, "un bocado letal captura su región por valor y vuelve sin acreditar la carga a distancia")
	await get_tree().process_frame
	verificar(not is_instance_valid(fuente) and h._retazos == [esperada] and h.carga == 21, "el retazo sobrevive cuando la fuente se libera en el siguiente cuadro")
	for i in 240:
		h._process(1.0 / 60)
		await get_tree().process_frame
		if h.carga == 0:
			break
	verificar(h.carga == 0 and h._retazos.is_empty() and Juego.migas_run == 21, "la carga recorre una ruta real y al descargar desaparece su muestra sin doble cobro")
	run.queue_free()
	await get_tree().process_frame

func probar_buche_acotado() -> void:
	var run := crear_run()
	var fuente := agregar_doble(run, 100, 100)
	var h := run.colonia._nacer("obrera", fuente.punto_mordida(Vector2.ZERO, run.radio_actual))
	h.comida = fuente
	h._capacidad = 20
	var hijos := h.get_child_count()
	for i in 7:
		fuente.region_prueba = Rect2(100 + i * 10, 200, 9, 7)
		h._reloj_mordida = 0
		h._morder(0.1)
	verificar(h.carga == 7 and h._retazos.size() == 3 and h.get_child_count() == hijos, "siete bocados conservan su valor con sólo tres muestras y ningún nodo nuevo por mordida")
	verificar(is_equal_approx(h._carga_origen[0], h.carga) and Juego.migas_run == 0, "las muestras son visuales: no sustituyen ni multiplican el desglose económico")
	run.queue_free()
	await get_tree().process_frame

func probar_economia_pieza() -> void:
	var run := crear_run()
	var silla := primera_silla(run)
	silla._preparar_mordiscos()
	var celdas_conservadas := true
	for i in silla.celdas.size():
		celdas_conservadas = celdas_conservadas and is_equal_approx(silla.vidas[i], silla.mordiscos.vida_celda(i))
	verificar(celdas_conservadas, "rasterizar conserva la vida de cada celda, incluidos bordes de menos de dos unidades")
	var posicion := silla.punto_mordida(Vector2.ZERO, run.radio_actual)
	var recompensa := silla.recompensa * Juego.stat("multiplicador_migas")
	var vida_antes := silla.vida
	var retorno := silla.morder_en(silla.vida_max * 0.25, posicion)
	var retirado := vida_antes - silla.vida
	verificar(retirado > 0 and retirado <= silla.vida_max * 0.25 + 0.00001 and is_equal_approx(retorno, recompensa * retirado / silla.vida_max * 0.65) and is_equal_approx(suma_fragmentos(run), recompensa * retirado / silla.vida_max * 0.35) and Juego.migas_run == 0, "el evento conserva el reparto 65%/35% de lo realmente retirado, sin acreditar extracción")
	var hp_visual := 0.0
	for i in silla.celdas.size():
		hp_visual += silla.mordiscos.vida_celda(i)
	if not is_equal_approx(hp_visual, silla.vida):
		print("  DIAG silla parcial: vida=%.12f; helper=%.12f; inicial=%.12f; extraído=%.12f; área=%.12f; celdas=%s" % [silla.vida, hp_visual, silla.vida_max, retirado, silla.mordiscos.area_total(), silla.vidas])
	verificar(is_equal_approx(hp_visual, silla.vida) and silla.celdas.size() <= 16 and silla.mordiscos.area_total() > 0, "la vida visual coincide con la física sin aumentar las dieciséis celdas lógicas")
	var bonus := recompensa * Juego.stat("bonus_destruir")
	retorno += silla.morder_en(silla.vida, posicion)
	verificar(silla.muerta and is_equal_approx(retorno + suma_fragmentos(run), recompensa) and is_equal_approx(Juego.migas_run, bonus), "destruir conserva exactamente toda la extracción y el bonus separado de la carga")
	var restante := 0.0
	for i in silla.celdas.size():
		restante += silla.mordiscos.vida_celda(i)
	if not silla.muerta or restante != 0 or silla.mordiscos.area_total() != 0:
		print("  DIAG silla final: vida=%.12f; helper=%.12f; retorno=%.12f; fragmentos=%.12f; recompensa=%.12f; bonus=%.12f/%.12f; área=%.12f; vivas=%s; celdas=%s" % [silla.vida, restante, retorno, suma_fragmentos(run), recompensa, Juego.migas_run, bonus, silla.mordiscos.area_total(), silla.vivas, silla.vidas])
	verificar(restante == 0 and silla.mordiscos.area_total() == 0, "el último evento elimina toda la máscara sin dejar resistencia visual residual")
	run.queue_free()
	await get_tree().process_frame

func probar_corte_y_barrido() -> void:
	var run := crear_run()
	var silla := primera_silla(run)
	var h := run.colonia._nacer("carpintera", silla.punto_mordida(Vector2.ZERO, run.radio_actual))
	h.comida = silla
	h._corte = true
	h._dano = 2
	h._reloj_mordida = 0
	h._morder(0.1)
	var esperado := silla.recompensa * silla.dano_recibido / silla.vida_max * Juego.stat("multiplicador_migas")
	verificar(h.carga == 0 and h._retazos.is_empty() and is_equal_approx(suma_fragmentos(run), esperado), "Corte continuo deja toda la extracción en montones y no muestra carga que no transporta")
	run.queue_free()
	await get_tree().process_frame
	run = crear_run()
	Juego.niveles.recoleccion_eficiente = 2
	Juego._cache_stats.clear()
	for i in 3:
		run.comidas.soltar_fragmento(Vector2(-100 + i * 10, -130), 20 + i * 10, [1, 3, 0][i])
	var primera := run.comidas.fragmentos[0]
	h = run.colonia._nacer("cargadora", primera.position)
	h._barrido = true
	h._reloj_mordida = 0
	h._velocidad = 400
	h.comida = primera
	h._morder(0.1)
	verificar(h.carga == 90 and h._carga_origen == [40.0, 20.0, 30.0] and run.comidas.fragmentos.is_empty(), "Barrido conserva los tres orígenes y no vuelve a multiplicar el valor de los montones")
	for i in 240:
		h._process(1.0 / 60)
		await get_tree().process_frame
		if h.carga == 0:
			break
	verificar(h.carga == 0 and Juego.migas_run == 90 and run.ingresos == [40.0, 20.0, 30.0] and h._retazos.is_empty(), "la entrega mixta mantiene su valor y desglose, y no deja muestras flotando tras descargar")
	run.queue_free()
	await get_tree().process_frame

func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)
