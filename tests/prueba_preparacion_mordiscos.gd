extends Node
## Equivalencia lógica exacta y ciclo de vida; no mide FPS.
class Expedicion extends Node:
	var terminada := false

class Receptor extends Node:
	var mascara: MordiscosMaterial
	var recibidas := 0
	var canceladas := 0
	func _recibir_mordiscos(material_listo: MordiscosMaterial) -> void:
		mascara = material_listo
		recibidas += 1
	func _cancelar_preparacion() -> void:
		canceladas += 1

var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	var existia := FileAccess.file_exists(Juego.RUTA_PARTIDA)
	var huella := hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) if existia else 0
	probar_geometrias()
	probar_catalogo()
	await probar_cola()
	await probar_cierre_run_real()
	var intacta := FileAccess.file_exists(Juego.RUTA_PARTIDA) == existia
	if existia:
		intacta = intacta and hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) == huella
	verificar(not Juego.guardado_habilitado and intacta, "preparar máscaras de prueba no altera la partida personal")
	print("Preparación incremental: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func repartir(rect: Rect2, grilla: Vector2i, formas: Array) -> Array:
	var resultado: Array = []
	var tam := rect.size / Vector2(grilla)
	for y in grilla.y:
		for x in grilla.x:
			var celda := Rect2(rect.position + Vector2(x, y) * tam, tam)
			var partes: Array[Rect2] = []
			for forma: Rect2 in formas:
				var interseccion := celda.intersection(forma)
				if interseccion.has_area():
					partes.append(interseccion)
			resultado.append(partes)
	return resultado


func completar(m: MordiscosMaterial, unidades := 1) -> int:
	var llamadas := 0
	while not m.configuracion_lista and llamadas < 100000:
		m.avanzar_configuracion(unidades)
		llamadas += 1
	return llamadas


func mismos(a: MordiscosMaterial, b: MordiscosMaterial) -> bool:
	for campo in ["_pixeles", "_iniciales", "_vivos", "_vidas_iniciales", "_hp_pixel", "_arbol", "_hojas", "_filas_vivas", "_columnas_vivas", "_limites_pixels", "_aire_bloques", "_aire_bits", "_frontera_bits", "_frontera_arbol", "_frontera_celdas", "_credito", "_credito_erosion"]:
		if a.get(campo) != b.get(campo):
			return false
	return a.area_total() == b.area_total() and a._cantidad_vivos == b._cantidad_vivos


func comparar(nombre: String, rect: Rect2, grilla: Vector2i, formas: Array, restaurada := false) -> void:
	var por_celda := repartir(rect, grilla, formas)
	var vidas := PackedFloat64Array()
	for celda in por_celda.size():
		vidas.append(100.0 + celda if not por_celda[celda].is_empty() and (not restaurada or celda % 5 != 0) else 0.0)
	var referencia := MordiscosMaterial.new()
	referencia.configurar(rect, grilla, por_celda, vidas)
	var m := MordiscosMaterial.new()
	m.iniciar_configuracion(rect, grilla, por_celda, vidas)
	var sin_publicar := not m.configuracion_lista and m.area_total() == 0 and m.recortar_local(0, 1000, rect.position - Vector2.ONE, 6) == 0
	var llamadas := completar(m)
	verificar(sin_publicar and llamadas > 1 and llamadas < 100000 and mismos(m, referencia), nombre + ": misma máscara, árboles, aire, límites y HP sin publicación parcial")
	var equivalente := true
	var origenes: Array[Vector2] = [Vector2(rect.position.x - 2, rect.get_center().y), Vector2(rect.end.x + 2, rect.get_center().y), Vector2(rect.get_center().x, rect.position.y - 2), Vector2(rect.get_center().x, rect.end.y + 2)]
	for i in 16:
		var celda := i % vidas.size()
		var real := m.recortar_local(celda, 37.25, origenes[i % 4], 6)
		var esperado := referencia.recortar_local(celda, 37.25, origenes[i % 4], 6)
		equivalente = equivalente and real == esperado and m.ultima_porcion == referencia.ultima_porcion and mismos(m, referencia)
	verificar(equivalente, nombre + ": las mordidas posteriores conservan exactamente masa, crédito, payload y conectividad")


func probar_geometrias() -> void:
	comparar("sólido", Rect2(0, 0, 64, 64), Vector2i.ONE, [Rect2(0, 0, 64, 64)])
	var cerrada := [Rect2(16, 16, 96, 16), Rect2(16, 96, 96, 16), Rect2(16, 32, 16, 64), Rect2(96, 32, 16, 64)]
	comparar("cavidad cerrada", Rect2(0, 0, 128, 128), Vector2i(3, 4), cerrada)
	cerrada.pop_back()
	comparar("cavidad abierta", Rect2(0, 0, 128, 128), Vector2i(3, 4), cerrada)
	comparar("solapamientos y bandas subpíxel", Rect2(-21, 7, 150, 126), Vector2i(3, 4), [Rect2(-21, 7, 74, 126), Rect2(40, 15, 66, 91), Rect2(105, 7, 0.03, 126)])
	comparar("componentes restaurados", Rect2(-21, -17, 150, 126), Vector2i(3, 4), [Rect2(-21, -17, 150, 126)], true)
	comparar("máximo2048 y bloques desalineados", Rect2(-200, -300, 4096, 4096), Vector2i(3, 4), [Rect2(-200, -300, 4096, 4096)])
	var m := MordiscosMaterial.new()
	m.iniciar_configuracion(Rect2(0, 0, 500, 500), Vector2i.ONE, [[Rect2(0, 0, 500, 500)]], PackedFloat64Array([100]))
	m.avanzar_configuracion(5)
	m.cancelar_configuracion()
	verificar(not m.avanzar_configuracion(100000) and m.area_total() == 0 and m.textura_mascara() == null, "cancelar una preparación no publica ni permite comer una máscara parcial")


func probar_catalogo() -> void:
	var datos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://datos/siluetas_muebles.json"))
	for clave: String in datos:
		var rect := Rect2(-13, 7, 110, 130)
		var formas: Array[Rect2] = []
		for zona: Array in datos[clave].formas:
			formas.append(Rect2(rect.position + Vector2(zona[0], zona[1]) * rect.size, Vector2(zona[2], zona[3]) * rect.size))
		comparar(clave, rect, Vector2i(3, 4), formas)
	verificar(datos.size() >= 59, "la comparación incluye todos los acabados y orientaciones reales, sin sombras")


func probar_cola() -> void:
	var r := Expedicion.new()
	add_child(r)
	var cola := PreparadorMordiscos.new()
	r.add_child(cola)
	cola.iniciar(r)
	cola.set_process(false)
	var a := Receptor.new()
	var b := Receptor.new()
	r.add_child(a)
	r.add_child(b)
	var rect := Rect2(0, 0, 128, 128)
	var primera := cola.solicitar(a, rect, Vector2i.ONE, [[rect]], PackedFloat64Array([100]))
	cola.solicitar(b, rect, Vector2i.ONE, [[rect]], PackedFloat64Array([100]))
	verificar(primera and not cola.solicitar(a, rect, Vector2i.ONE, [[rect]], PackedFloat64Array([100])) and a.mascara == null and cola.cantidad_pendientes() == 2, "solicitar es idempotente y no prepara ni publica dentro de la llamada")
	cola.procesar(1000000, 2)
	verificar(cola.unidades_ultimo_cuadro == 2 and a.mascara == null and b.mascara == null and cola._trabajos[a.get_instance_id()].mascara._prep_etapa == cola._trabajos[b.get_instance_id()].mascara._prep_etapa, "dos unidades se reparten entre dos recursos, sin presupuesto por hormiga")
	get_tree().paused = true
	cola.procesar(1000000, 20)
	verificar(cola.unidades_ultimo_cuadro == 0 and cola.cantidad_pendientes() == 2, "pausar conserva las preparaciones sin avanzar ni cancelarlas")
	get_tree().paused = false
	var servicios := 0
	while cola.tiene_pendientes() and servicios < 10000:
		cola.procesar(1000000, 2)
		servicios += 1
	verificar(servicios < 10000 and a.recibidas == 1 and b.recibidas == 1 and a.mascara.configuracion_lista and mismos(a.mascara, b.mascara) and cola.max_unidades_cuadro == 2, "la cola publica una sola vez el estado completo y respeta su límite global hasta terminar")
	var necesario := Receptor.new()
	var consultado := Receptor.new()
	r.add_child(necesario)
	r.add_child(consultado)
	cola.solicitar(necesario, rect, Vector2i.ONE, [[rect]], PackedFloat64Array([100]))
	cola.solicitar(consultado, rect, Vector2i.ONE, [[rect]], PackedFloat64Array([100]))
	cola.conservar_propietarios([necesario.get_instance_id()])
	verificar(cola.cantidad_pendientes() == 1 and necesario.canceladas == 0 and consultado.canceladas == 1 and consultado.mascara == null, "al cerrar se cancela sólo el precalentado sin trabajo, sin publicar material parcial")
	cola.iniciar_cierre()
	servicios = 0
	while cola.tiene_pendientes() and servicios < 10000:
		cola.procesar(1000000, 2)
		servicios += 1
	verificar(servicios < 10000 and necesario.recibidas == 1 and consultado.recibidas == 0, "la barrera termina únicamente las máscaras necesarias para trabajo ya emitido")
	var liberado := Receptor.new()
	r.add_child(liberado)
	cola.solicitar(liberado, rect, Vector2i.ONE, [[rect]], PackedFloat64Array([100]))
	liberado.queue_free()
	await get_tree().process_frame
	cola.procesar(1000000, 1)
	verificar(not cola.tiene_pendientes() and cola.terminadas == 3, "una referencia débil liberada no publica ni conserva una tarea huérfana")
	cola.solicitar(a, rect, Vector2i.ONE, [[rect]], PackedFloat64Array([100]))
	cola.iniciar_cierre()
	cola.procesar(1000000, 1)
	cola.cancelar()
	cola.procesar(1000000, 100000)
	verificar(not cola.tiene_pendientes() and a.recibidas == 1 and not cola.solicitar(b, rect, Vector2i.ONE, [[rect]], PackedFloat64Array([100])), "cancelar la expedición libera las tareas sin callbacks tardíos ni reapertura")
	r.queue_free()
	await get_tree().process_frame


func probar_cierre_run_real() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var r: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	var p := PiezaCasa.new()
	r.comidas.add_child(p)
	var datos := {"clave": "preparacion:cierre", "tipo": "mesada", "rect": Rect2(-850, -800, 400, 300), "color": Color.GRAY, "pared": false}
	datos.dibujo = datos.duplicate(true)
	p.iniciar(datos, r.cocina)
	var consultada := Comida.new()
	consultada._usar_cache = false
	r.comidas.add_child(consultada)
	consultada.configurar({"id": "preparacion_fixture", "nombre": "Comida de prueba", "forma": "miga", "color": Color.BROWN, "vida": 100, "recompensa": 10, "radio": 24}, 1)
	p.preparar_material()
	consultada.preparar_material()
	var pendiente := p.vida_max * 0.2
	r.cola_erosion.encolar(p, pendiente, p.rect_mundo.position + Vector2(-4, 50))
	verificar(not r.preparacion_sincrona and p.mordiscos == null and p.material_preparandose() and consultada.material_preparandose() and p.vida == p.vida_max and Juego.migas_run == 0, "Run real conserva HP y saldo mientras la primera máscara y el veneno están pendientes")
	r._iniciar_retirada()
	verificar(r.cerrando_erosion and not r.retirando and r.preparador_mordiscos.cantidad_pendientes() == 1 and p.material_preparandose() and not consultada.material_preparandose() and consultada.mordiscos == null, "cerrar conserva sólo la máscara necesaria y cancela el precalentado sin trabajo")
	var pasos := 0
	while r.cerrando_erosion and pasos < 2000:
		r.preparador_mordiscos.procesar(1000000, 16)
		r.cola_erosion.procesar(1000000, 4)
		r._process(0.01)
		pasos += 1
		await get_tree().process_frame
	var conservado := p.mordiscos != null
	if conservado:
		var credito := 0.0
		for valor in p.mordiscos._credito_erosion:
			credito += valor
		conservado = is_equal_approx(p.vida_max - p.vida + credito, pendiente)
	verificar(pasos < 2000 and pasos > 1 and not r.cerrando_erosion and r.retirando and conservado and Juego.migas_run > 0, "la barrera publica, liquida sólo el material real y continúa la retirada sin perder trabajo emitido")
	verificar(consultada.mordiscos == null and consultada.vida == consultada.vida_max and r.tiempo_espera_erosion > 0 and not r.preparador_mordiscos.tiene_pendientes(), "la espera se contabiliza y no prepara ni cobra el alimento solamente consultado")
	r.queue_free()
	await get_tree().process_frame


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", detalle)
