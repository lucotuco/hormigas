extends Node
## Una mordida transporta una porción sólida real, no una miniatura del objeto.
const CAJA := Rect2(-55, -65, 110, 130)
const LADO := 6.0
const EPS := 0.00001

class AlimentoRectangular extends Comida:
	func _preparar_mordiscos() -> void:
		mordiscos = MordiscosMaterial.new()
		mordiscos.configurar(CAJA, Vector2i.ONE, [[CAJA]], PackedFloat64Array([vida_max]))
	func region_bocado() -> Rect2:
		return Rect2(Vector2(300, 300) + _porcion_reciente.position * 3, _porcion_reciente.size * 3) if _porcion_reciente.has_area() else Rect2()

class CajaConRegion extends PiezaCasa:
	func region_bocado() -> Rect2:
		return Rect2(Vector2(600, 600), _porcion_reciente.size * 3) if _porcion_reciente.has_area() else Rect2()

var total := 0
var fallas := 0

func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", detalle)

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	probar_helper_local()
	probar_credito_y_agotamiento()
	await probar_objetos_y_carga()
	await probar_contacto_y_batch()
	await probar_alimentos_reales()
	await probar_alimentos_con_dano_inicial()
	Juego.reiniciar_estado()
	print("Porciones reales: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)

func nuevo_helper(rect := CAJA, vida := 1000.0) -> MordiscosMaterial:
	var m := MordiscosMaterial.new()
	m.configurar(rect, Vector2i.ONE, [[rect]], PackedFloat64Array([vida]))
	return m

func acotada(porcion: Rect2) -> bool:
	return porcion.has_area() and porcion.size.x <= LADO + EPS and porcion.size.y <= LADO + EPS

func muestras(porcion: Rect2) -> Array[Vector2]:
	var puntos: Array[Vector2] = []
	for y in [0.2, 0.5, 0.8]:
		for x in [0.2, 0.5, 0.8]:
			puntos.append(porcion.position + porcion.size * Vector2(x, y))
	return puntos

func probar_helper_local() -> void:
	var m := nuevo_helper()
	var area_inicial := m.area_total()
	var vida_inicial := m.vida_celda(0)
	var hp := m.recortar_local(0, 1.0e6, Vector2(-80, 0), LADO)
	var porcion := m.ultima_porcion
	verificar(hp > 0 and acotada(porcion) and CAJA.encloses(porcion), "un daño enorme sólo arranca una porción sólida de hasta seis unidades por lado")
	verificar(m.area_total() > area_inicial * 0.99 and m.vida_celda(0) > vida_inicial * 0.99, "una sola mordida no borra un cuarto de una caja de 110 × 130")
	verificar(is_equal_approx(area_inicial - m.area_total(), porcion.get_area()), "el área que desaparece es exactamente la porción desprendida")
	verificar(is_equal_approx(hp, vida_inicial * porcion.get_area() / area_inicial) and is_equal_approx(vida_inicial - m.vida_celda(0), hp), "la vida descontada corresponde sólo al área retirada, no al DPS pedido")
	var retiradas: Array[Vector2] = muestras(porcion)
	var mono := true
	var solidas := true
	var contables := true
	var exitos := 1
	var lados: Array[Vector2] = [Vector2(-80, 20), Vector2(80, -20), Vector2(20, -90), Vector2(-20, 90)]
	for i in 99:
		var area_antes := m.area_total()
		var vida_antes := m.vida_celda(0)
		var real := m.recortar_local(0, 1.0e6, lados[i % lados.size()], LADO)
		porcion = m.ultima_porcion
		if real > 0:
			exitos += 1
			solidas = solidas and acotada(porcion) and CAJA.encloses(porcion)
			for p in muestras(porcion):
				solidas = solidas and not m.contiene(p)
				retiradas.append(p)
		contables = contables and absf((area_antes - m.area_total()) - porcion.get_area()) < EPS
		contables = contables and absf((vida_antes - m.vida_celda(0)) - real) < EPS
		contables = contables and absf(real - vida_inicial * porcion.get_area() / area_inicial) < EPS
		for p in retiradas:
			mono = mono and not m.contiene(p)
	verificar(exitos == 100 and solidas, "cien mordidas desde cuatro lados generan cien porciones locales, sin franjas gigantes")
	verificar(mono, "cambiar de lado no repone ninguno de los píxeles ya retirados")
	verificar(contables, "cien mordidas conservan exactamente el área y la vida que transportan")
	verificar(m.area_total() >= area_inicial - 100 * LADO * LADO - EPS, "ni siquiera cien mordidas de DPS enorme pueden retirar más que cien porciones")

func probar_credito_y_agotamiento() -> void:
	var m := nuevo_helper()
	var area := m.area_total()
	var vida := m.vida_celda(0)
	var cobrado := 0.0
	for i in 100:
		cobrado += m.recortar_local(0, 1.0e-10, CAJA.position - Vector2.ONE, LADO)
	verificar(cobrado == 0 and m.area_total() == area and m.vida_celda(0) == vida and not m.ultima_porcion.has_area(), "el daño menor a un píxel no cobra ni borra una porción inexistente")
	var acumulado := 0.0
	var desprendido := 0.0
	var conservacion := true
	for i in 100:
		acumulado += 0.01
		desprendido += m.recortar_local(0, 0.01, CAJA.position - Vector2.ONE, LADO)
		conservacion = conservacion and desprendido <= acumulado + EPS
	verificar(desprendido > 0 and conservacion, "el crédito pequeño se acumula sin retirar más resistencia que el daño total recibido")
	for dano in [0.0, -1.0, NAN, INF]:
		area = m.area_total()
		vida = m.vida_celda(0)
		var real := m.recortar_local(0, dano, CAJA.position, LADO)
		verificar(real == 0 and m.area_total() == area and m.vida_celda(0) == vida and not m.ultima_porcion.has_area(), "daño inválido no repite el retazo anterior ni acredita recursos")
	var entradas_validas := true
	for lado in [0.0, -1.0, NAN, INF]:
		area = m.area_total()
		var real := m.recortar_local(0, 1.0e6, CAJA.position, lado)
		entradas_validas = entradas_validas and real == 0 and m.area_total() == area and not m.ultima_porcion.has_area()
	verificar(entradas_validas, "un tamaño de porción inválido no permite quitar material ni dejar una muestra vieja")
	var chica := nuevo_helper(Rect2(10, 20, 4, 4), 8)
	var real := chica.recortar_local(0, 1.0e6, Vector2(8, 22), LADO)
	verificar(real == 8 and chica.area_total() == 0 and chica.vida_celda(0) == 0, "un objeto realmente menor al bocado sí puede agotarse completo")
	var posterior := chica.recortar_local(0, 1.0e6, Vector2(8, 22), LADO)
	verificar(posterior == 0 and not chica.ultima_porcion.has_area(), "un recurso agotado nunca vuelve a entregar valor ni una muestra vieja")

func crear_run() -> Run:
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.colonia._activa = false
	return run

func crear_caja(run: Run, rect := Rect2(-200, -250, 110, 130), clave := "porciones:caja") -> CajaConRegion:
	var caja := CajaConRegion.new()
	run.comidas.add_child(caja)
	var dibujo := {"tipo": "mesa", "rect": rect, "color": Color("997344")}
	caja.iniciar({"clave": clave, "tipo": "mesa", "rect": rect, "color": dibujo.color, "pared": false, "dibujo": dibujo}, run.cocina)
	return caja

func suma_fragmentos(run: Run) -> float:
	var suma := 0.0
	for f in run.comidas.fragmentos:
		if is_instance_valid(f) and not f.muerta:
			suma += f.recompensa
	return suma

func probar_objetos_y_carga() -> void:
	var run := crear_run()
	var caja := crear_caja(run)
	var hp := caja.vida
	var valor := caja.recompensa * Juego.stat("multiplicador_migas")
	var montones := suma_fragmentos(run)
	var remota := caja.rect_mundo.position - Vector2(30, -10)
	var rechazado := caja.morder_local(1.0e6, remota, LADO)
	verificar(rechazado == 0 and caja.vida == hp and not caja._porcion_reciente.has_area() and suma_fragmentos(run) == montones, "una boca alejada no extrae ni cobra material a distancia")
	var p := caja.rect_mundo.position - Vector2(11, -10)
	var obtenido := caja.morder_local(1.0e6, p, LADO)
	var porcion := caja._porcion_reciente
	verificar(obtenido > 0 and acotada(porcion) and caja.rect_mundo.encloses(porcion) and caja.vida > hp * 0.99, "la pieza real de 110 × 130 conserva casi toda su forma tras una mordida enorme")
	verificar(is_equal_approx(obtenido, valor * (hp - caja.vida) / caja.vida_max) and suma_fragmentos(run) == montones, "la mordida local entrega el 100% de su valor retirado sin fabricar el 35% en restos")
	verificar(Juego.migas_run == 0, "extraer material no acredita ninguna miga hasta transportarlo")
	var h := run.colonia._nacer("obrera", caja.punto_mordida(p, run.radio_actual))
	h.comida = caja
	h._dano = 1.0e6
	h._capacidad = 20
	h.scale = Vector2(3, 2)
	h._reloj_mordida = 0
	h._morder(0.1)
	var tamano := caja.tamano_bocado()
	verificar(h.carga > 0 and h._tamanos_retazos.size() == 1 and h._tamanos_retazos[0].is_equal_approx(tamano), "la hormiga conserva el tamaño real del mismo material que acaba de quitar")
	verificar(tamano.x <= LADO + EPS and tamano.y <= LADO + EPS and not h._retazos.is_empty() and h._retazos[0].size.is_equal_approx(tamano * 3), "el retazo de atlas no determina ni miniaturiza su tamaño en el mundo")
	var escala_consistente := not h._retazos.is_empty()
	if escala_consistente:
		for escala in [Vector2.ONE, Vector2(3, 2), Vector2(0.5, 0.75)]:
			h.scale = escala
			var medido: Vector2 = h._escala_retazo(h._retazos[0]) * h._retazos[0].size * h.global_scale.abs()
			escala_consistente = escala_consistente and medido.is_equal_approx(tamano)
	verificar(escala_consistente, "el tamaño visible del retazo permanece igual al hueco aunque cambie la escala visual de la hormiga")
	var alimento := AlimentoRectangular.new()
	run.comidas.add_child(alimento)
	var datos: Dictionary = Juego.comidas[0].duplicate()
	datos.id = "porciones_prueba"
	datos.vida = 1000.0
	datos.recompensa = 2500.0
	datos.radio = 65.0
	alimento.configurar(datos, 417)
	alimento.position = Vector2(-200, -100)
	alimento.rotation = 0.73
	var inicial := alimento.vida
	var pos := alimento.to_global(CAJA.position - Vector2(2, -10))
	obtenido = alimento.morder_local(1.0e6, pos, LADO)
	verificar(obtenido > 0 and acotada(alimento._porcion_reciente) and alimento.vida > inicial * 0.99, "un alimento rotado también pierde sólo una porción física pequeña")
	verificar(is_equal_approx(obtenido, alimento.recompensa * (inicial - alimento.vida) / alimento.vida_max * Juego.stat("multiplicador_migas")), "comida y mueble pagan únicamente la proporción retirada")
	var anterior := alimento.vida
	obtenido = alimento.morder_local(0, pos, LADO)
	verificar(obtenido == 0 and alimento.vida == anterior and not alimento._porcion_reciente.has_area() and alimento.tamano_bocado() == Vector2.ZERO, "un intento sin material retirado limpia tamaño y porción sin reutilizar la muestra anterior")
	alimento.scale = Vector2(2, 2)
	alimento.rotation = PI * 0.5
	pos = alimento.to_global(CAJA.end + Vector2(2, -10))
	var area_antes := alimento.mordiscos.area_total()
	obtenido = alimento.morder_local(1.0e6, pos, LADO)
	tamano = alimento.tamano_bocado()
	verificar(obtenido > 0 and tamano.x <= LADO + EPS and tamano.y <= LADO + EPS and tamano.is_equal_approx(alimento._porcion_reciente.size * 2) and is_equal_approx(area_antes - alimento.mordiscos.area_total(), alimento._porcion_reciente.get_area()), "un alimento al doble de escala y rotado 90° sigue desprendiendo hasta seis unidades reales por lado")
	run.queue_free()
	await get_tree().process_frame

func probar_contacto_y_batch() -> void:
	var run := crear_run()
	var caja := crear_caja(run, Rect2(-240, -240, 12, 16), "porciones:batch")
	# Registrar la pieza de prueba permite observar una invalidación real de
	# navegación; una clave ausente es ignorada correctamente por Cocina.
	run.cocina._obstaculos[caja.pieza.clave] = caja.pieza
	var version := run.cocina.version
	var forma := caja.version_forma
	var pos := caja.celdas[0].get_center() - Vector2(caja.celdas[0].size.x * 0.5 + 11, 0)
	var valor := caja.morder_local(1.0e6, pos, LADO)
	var diferido := valor > 0 and not caja.muerta and caja._geometria_pendiente and run.cocina.version == version and caja.version_forma == forma
	caja._process(0.13)
	verificar(diferido and not caja._geometria_pendiente and run.cocina.version == version + 1 and caja.version_forma > forma, "una celda retirada agrupa la actualización de navegación y no rehace A* por cada mordida")
	var grande := crear_caja(run, Rect2(-200, -250, 110, 130), "porciones:contacto")
	var boca_anterior := grande.celdas[0].get_center() - Vector2(grande.celdas[0].size.x * 0.5 + 11, 0)
	# Un evento vacía la sección que la hormiga iba a morder. Las secciones
	# vecinas siguen vivas pero ya quedan fuera del alcance de esa boca.
	grande.morder_en(grande.vidas[0], grande.celdas[0].get_center())
	var h := run.colonia._nacer("obrera", boca_anterior)
	h.comida = grande
	h.estado = Hormiga.Estado.MORDIENDO
	h._dano = 1.0e6
	h._reloj_mordida = 0
	var hp := grande.vida
	var bocados := h.bocados
	h._morder(0.1)
	verificar(not grande.alcanza_contacto(boca_anterior) and grande.vida == hp and h.carga == 0 and h.bocados == bocados and h._retazos.is_empty() and h.estado in [Hormiga.Estado.YENDO_A_COMIDA, Hormiga.Estado.EXPLORANDO], "una hormiga frente al hueco busca otro frente sin morder ni cobrar material remoto")
	run.queue_free()
	await get_tree().process_frame

func probar_alimentos_reales() -> void:
	# Las mismas siluetas incluidas que usa el renderer, sin atlas ni azar del bot.
	var siluetas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://datos/siluetas_comidas.json"))
	verificar(siluetas.size() == Juego.comidas.size(), "todos los alimentos del catálogo tienen una silueta física incluida")
	for datos in Juego.comidas:
		var alimento := Comida.new()
		add_child(alimento)
		alimento.configurar(datos, 417)
		alimento._preparar_mordiscos()
		var formas := Graficos.formas_alimento(datos.id)
		var coincide_json: bool = siluetas.has(datos.id) and formas.size() == siluetas.get(datos.id, []).size()
		if coincide_json:
			for i in formas.size():
				var r: Array = siluetas[datos.id][i]
				coincide_json = coincide_json and formas[i] == Rect2(r[0], r[1], r[2], r[3])
		var m := alimento.mordiscos
		verificar(coincide_json and not formas.is_empty() and is_equal_approx(m.vida_celda(0), alimento.vida_max) and m.area_total() > 0, "%s conserva toda su vida sobre su silueta JSON real" % datos.id)
		var cobrado := 0.0
		var conservado := true
		var maximo := m.tamano_mascara().x * m.tamano_mascara().y + 1
		var lados: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
		for i in maximo:
			if alimento.muerta:
				break
			var area := m.area_total()
			var hp := alimento.vida
			var pos := alimento.to_global(lados[i % lados.size()] * (alimento.radio + 2))
			var valor := alimento.morder_local(1.0e6, pos, LADO)
			cobrado += valor
			var porcion := alimento._porcion_reciente
			conservado = conservado and valor > 0 and acotada(porcion)
			conservado = conservado and absf(area - m.area_total() - porcion.get_area()) < EPS
			conservado = conservado and is_equal_approx(alimento.vida, m.vida_celda(0))
			conservado = conservado and is_equal_approx(valor, (hp - alimento.vida) / alimento.vida_max * alimento.recompensa * Juego.stat("multiplicador_migas"))
			if valor <= 0:
				print("  DIAG %s: intento=%d; vida=%.12f; helper=%.12f; área=%.12f; valor=%.12f/%.12f" % [datos.id, i, alimento.vida, m.vida_celda(0), m.area_total(), cobrado, alimento.recompensa])
				break
		verificar(conservado, "%s sólo entrega porciones locales y cobra el área realmente desprendida" % datos.id)
		var agotado := alimento.muerta and m.area_total() == 0 and m.vida_celda(0) == 0 and is_zero_approx(alimento.vida)
		var posterior := alimento.morder_local(1.0e6, alimento.global_position, LADO)
		verificar(agotado and is_equal_approx(cobrado, alimento.recompensa * Juego.stat("multiplicador_migas")) and posterior == 0 and not alimento._porcion_reciente.has_area(), "%s se agota sin vida fantasma, pérdida de valor ni cobro repetido" % datos.id)
		alimento.queue_free()
		await get_tree().process_frame

func probar_alimentos_con_dano_inicial() -> void:
	# Daño de la primera obrera, con la posición fija: el crédito de una
	# mordida menor a un píxel no debe impedir recoger el último pedacito.
	for datos in Juego.comidas:
		if datos.id not in ["miga", "azucar", "cereal", "fideo", "aceituna"]:
			continue
		for lado in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var alimento := Comida.new()
			add_child(alimento)
			alimento.configurar(datos, 417)
			alimento._preparar_mordiscos()
			var m := alimento.mordiscos
			var pos := alimento.to_global(lado * (alimento.radio + 2))
			var cobrado := 0.0
			var conservado := true
			var intentos := ceili(alimento.vida_max) + m.tamano_mascara().x * m.tamano_mascara().y
			for i in intentos:
				if alimento.muerta:
					break
				var antes := m.area_total()
				var valor := alimento.morder_local(1, pos, LADO)
				cobrado += valor
				conservado = conservado and cobrado <= (i + 1) / alimento.vida_max * alimento.recompensa * Juego.stat("multiplicador_migas") + EPS
				conservado = conservado and is_equal_approx(alimento.vida, m.vida_celda(0))
				if valor > 0:
					conservado = conservado and acotada(alimento._porcion_reciente) and absf(antes - m.area_total() - alimento._porcion_reciente.get_area()) < EPS
				else:
					conservado = conservado and antes == m.area_total() and not alimento._porcion_reciente.has_area()
			var agotado := alimento.muerta and m.area_total() == 0 and m.vida_celda(0) == 0 and is_zero_approx(alimento.vida)
			if not agotado:
				print("  DIAG daño1 %s lado%s: vida=%.12f; helper=%.12f; área=%.12f; valor=%.12f/%.12f" % [datos.id, lado, alimento.vida, m.vida_celda(0), m.area_total(), cobrado, alimento.recompensa])
			verificar(conservado and agotado and is_equal_approx(cobrado, alimento.recompensa * Juego.stat("multiplicador_migas")), "%s con daño uno desde %s cobra hasta el último píxel, sin adelantar crédito" % [datos.id, lado])
			alimento.queue_free()
			await get_tree().process_frame
