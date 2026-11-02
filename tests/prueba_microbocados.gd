extends Node
## Tandas de hasta tres porciones reales. Ningún bocado aumenta el área de
## su retazo ni reacredita daño al continuar trabajo del mismo frente.
const RECT := Rect2(-520, -380, 110, 130)
const LADO := 6.0
const EPS := 0.000001

class CajaConRegion extends PiezaCasa:
	var emisiones := 0
	var continuaciones := 0
	func morder_local(dano: float, pos: Vector2, lado_max := 6.0) -> float:
		emisiones += 1
		return super.morder_local(dano, pos, lado_max)
	func continuar_bocado(pos: Vector2, lado_max := 6.0) -> float:
		continuaciones += 1
		return super.continuar_bocado(pos, lado_max)
	func region_bocado() -> Rect2:
		return Rect2(Vector2(2000, 2000) + _porcion_reciente.position * 3.0, _porcion_reciente.size * 3.0) if _porcion_reciente.has_area() else Rect2()

var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	probar_credito_explicito()
	for dieta in 4:
		await probar_ciclo(dieta)
	await probar_tres_tamanos_distintos()
	await probar_buche_y_cierre()
	Juego.reiniciar_estado()
	print("Microbocados físicos: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func verificar(condicion: bool, mensaje: String) -> void:
	total += 1
	if not condicion:
		fallas += 1
	print("OK " if condicion else "FALLA ", mensaje)


func probar_credito_explicito() -> void:
	var m := MordiscosMaterial.new()
	var rect := Rect2(-50, -50, 100, 100)
	m.configurar(rect, Vector2i.ONE, [[rect]], PackedFloat64Array([1000.0]))
	var pos := Vector2(-60, 0)
	verificar(m.recortar_local_acreditado(0, pos, LADO) == 0 and not m.ultima_porcion.has_area(),
		"una continuación sin trabajo previo no fabrica material ni una muestra")
	var area := m.area_total()
	var vida := m.vida_celda(0)
	var quitado := m.recortar_local(0, 100.0, pos, LADO)
	var credito := m._credito[0]
	var extra := 0.0
	var area_porciones := m.ultima_porcion.get_area()
	var acotadas := true
	for i in 2:
		var real := m.recortar_local_acreditado(0, pos, LADO)
		extra += real
		area_porciones += m.ultima_porcion.get_area()
		acotadas = acotadas and real > 0 and m.ultima_porcion.size.x <= LADO and m.ultima_porcion.size.y <= LADO
	verificar(acotadas and area_porciones <= 3.0 * LADO * LADO and is_equal_approx(area - m.area_total(), area_porciones),
		"tres operaciones producen tres porciones sólidas acotadas y su suma es exactamente el área ausente")
	verificar(is_equal_approx(vida - m.vida_celda(0), quitado + extra) and is_equal_approx(credito - m._credito[0], extra),
		"las dos continuaciones gastan exactamente HP del crédito original, sin volver a admitir los cien puntos")
	verificar(is_equal_approx(m._credito[0] + quitado + extra, 100.0) and m._credito_erosion[0] == 0,
		"trabajo pendiente más retirado conserva el presupuesto y no usa crédito de corrosión")
	var previo := m.area_total()
	verificar(m.recortar_local(0, 0.0, pos, LADO) == 0 and m.area_total() == previo,
		"morder con daño cero sigue siendo inválido: sólo la API explícita puede continuar crédito")
	var restante := 0.0
	for i in 1000:
		var real := m.recortar_local_acreditado(0, pos, LADO)
		if real <= 0:
			break
		restante += real
	verificar(quitado + extra + restante <= 100.0 + EPS and m.recortar_local_acreditado(0, pos, LADO) == 0,
		"reintentar continuaciones hasta agotar el crédito nunca supera el daño emitido una sola vez")


func crear_run(dieta: int) -> Run:
	Juego.reiniciar_estado()
	for id in ["mordida_madera", "mordida_resistente", "mordida_muros"].slice(0, dieta):
		Juego.niveles[id] = 1
	Juego._cache_stats.clear()
	var r: Run = preload("res://mundo/run.tscn").instantiate()
	r.preparacion_sincrona = true # Se aísla conservación; la cola asíncrona tiene su suite.
	add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	r.colonia._activa = false
	r.radio_actual = 2000.0
	return r


func crear_caja(r: Run) -> CajaConRegion:
	var caja := CajaConRegion.new()
	r.comidas.add_child(caja)
	# Pared rectangular de práctica: cuatro bandas físicas reales y dieta cero.
	# No simula un gran objeto con un atlas diminuto ni inventa masa transportada.
	var dibujo := {"tipo": "mesa", "rect": RECT, "color": Color("997344")}
	caja.iniciar({"clave": "microbocados:fixture", "tipo": "mesa", "rect": RECT,
		"color": dibujo.color, "pared": true, "dibujo": dibujo, "practica": true}, r.cocina)
	caja.preparar_material()
	return caja


func hormiga_en_frente(r: Run, caja: CajaConRegion, capacidad: int) -> Hormiga:
	var h := r.colonia._nacer("obrera", RECT.position + Vector2(-11, 10))
	h.comida = caja
	h.estado = Hormiga.Estado.MORDIENDO
	h._dano = 1000000.0
	h._capacidad = capacidad
	h._reloj_mordida = 0.0
	return h


func probar_ciclo(dieta: int) -> void:
	var r := crear_run(dieta)
	var caja := crear_caja(r)
	var h := hormiga_en_frente(r, caja, 20)
	var esperadas := mini(1 + dieta, int(Juego.stat("porciones_por_ciclo_max")))
	var vida := caja.vida
	var area := caja.mordiscos.area_total()
	h._morder(0.01)
	verificar(h._porciones_ciclo == esperadas and h.bocados == esperadas,
		"dieta %d: un ciclo desprende y cuenta exactamente %d porciones físicas" % [dieta, esperadas])
	verificar(caja.emisiones == 1 and caja.continuaciones == esperadas - 1,
		"dieta %d: se admite daño una vez y como máximo dos continuaciones" % dieta)
	var tamanos_reales := h._tamanos_retazos.size() == esperadas and h._retazos.size() == esperadas
	var suma_area := 0.0
	for i in h._tamanos_retazos.size():
		var tam := h._tamanos_retazos[i]
		suma_area += tam.x * tam.y
		tamanos_reales = tamanos_reales and tam.x <= LADO + EPS and tam.y <= LADO + EPS and h._retazos[i].size.is_equal_approx(tam * 3.0)
	verificar(tamanos_reales and is_equal_approx(area - caja.mordiscos.area_total(), suma_area),
		"dieta %d: cada región se copia antes de la siguiente y las muestras suman exactamente el hueco" % dieta)
	var escala_correcta := tamanos_reales
	for escala: Vector2 in [Vector2.ONE, Vector2(3, 2), Vector2(0.5, 0.75)]:
		h.scale = escala
		for i in h._retazos.size():
			var mundo: Vector2 = h._escala_retazo(h._retazos[i], i) * h._retazos[i].size * h.global_scale.abs()
			escala_correcta = escala_correcta and mundo.is_equal_approx(h._tamanos_retazos[i])
	verificar(escala_correcta, "dieta %d: cada retazo de la tanda conserva su tamaño propio ante tres escalas de hormiga" % dieta)
	var valor := caja.recompensa * (vida - caja.vida) / caja.vida_max * Juego.stat("multiplicador_migas")
	verificar(is_equal_approx(h.carga, valor) and Juego.migas_run == 0,
		"dieta %d: sólo se carga el valor realmente retirado y nada se cobra antes del transporte" % dieta)
	verificar(caja.vida > vida * 0.99 and suma_area <= 108.0 and not caja.muerta,
		"dieta %d: la tanda conserva más del 99%% de una caja110×130, nunca un cuarto gigante" % dieta)
	var cacheadas := h._porciones_ciclo
	Juego.niveles.mordida_muros = 1
	Juego._cache_stats.clear()
	verificar(h._porciones_ciclo == cacheadas, "dieta %d: el número de porciones se copia al nacer, no se consulta por cuadro" % dieta)
	r.queue_free()
	await get_tree().process_frame


func probar_tres_tamanos_distintos() -> void:
	var r := crear_run(3)
	var caja := crear_caja(r)
	var h := hormiga_en_frente(r, caja, 20)
	# 24 píxeles pagan dos retazos de 3×3 y uno menor. Si el dibujo reutiliza
	# el tamaño de la primera/última porción, esta comparación NO puede pasar.
	h._dano = caja.mordiscos._hp_pixel[0] * 24.0
	var hp := caja.vida
	var area := caja.mordiscos.area_total()
	h._morder(0.01)
	var tres := h._retazos.size() == 3 and h._tamanos_retazos.size() == 3
	verificar(tres and h._tamanos_retazos[0] != h._tamanos_retazos[2],
		"un presupuesto físico de24 píxeles produce tres muestras cuya última tiene tamaño distinto")
	var escalas := tres
	var suma_area := 0.0
	for i in h._retazos.size():
		var tam := h._tamanos_retazos[i]
		suma_area += tam.x * tam.y
		for escala: Vector2 in [Vector2.ONE, Vector2(3, 2), Vector2(0.5, 0.75)]:
			h.scale = escala
			var mundo: Vector2 = h._escala_retazo(h._retazos[i], i) * h._retazos[i].size * h.global_scale.abs()
			escalas = escalas and mundo.is_equal_approx(tam)
	verificar(escalas and is_equal_approx(area - caja.mordiscos.area_total(), suma_area),
		"las tres muestras diferentes conservan sus tamaños individuales y su suma coincide con el hueco real")
	verificar(is_equal_approx(hp - caja.vida, h._dano) and is_equal_approx(caja.mordiscos._credito[0], 0.0)
		and is_equal_approx(h.carga, caja.recompensa * (hp - caja.vida) / caja.vida_max * Juego.stat("multiplicador_migas")),
		"las tres muestras distintas agotan exactamente un daño emitido y conservan todo el valor extraído")
	r.queue_free()
	await get_tree().process_frame


func probar_buche_y_cierre() -> void:
	var r := crear_run(3)
	var caja := crear_caja(r)
	var h := hormiga_en_frente(r, caja, 2)
	h._morder(0.01)
	verificar(h.bocados == 2 and h._retazos.size() == 2 and caja.continuaciones == 1 and h.estado == Hormiga.Estado.VOLVIENDO,
		"un buche con dos lugares corta la tanda antes de la tercera porción y vuelve con sus dos muestras")
	var hp := caja.vida
	var area := caja.mordiscos.area_total()
	r._extraccion_cerrada = true
	verificar(caja.continuar_bocado(h.position, LADO) == 0 and caja.vida == hp and caja.mordiscos.area_total() == area,
		"el corte de expedición también bloquea las continuaciones con crédito pendiente")
	r.queue_free()
	await get_tree().process_frame
	var pobre := crear_run(3)
	var dura := crear_caja(pobre)
	var obrera := hormiga_en_frente(pobre, dura, 20)
	obrera._dano = 0.000000000001
	obrera._morder(0.01)
	verificar(obrera.bocados == 0 and obrera.carga == 0 and dura.emisiones == 1 and dura.continuaciones == 0 and obrera._retazos.is_empty(),
		"sin crédito suficiente para un píxel no se ejecutan dos operaciones gratuitas ni se llena el buche")
	pobre.queue_free()
	await get_tree().process_frame
