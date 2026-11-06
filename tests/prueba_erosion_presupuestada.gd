extends Node
## Conservación y ciclo de vida de erosión compartida, no medición de FPS.
const RUN := preload("res://mundo/run.tscn")
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	var existia := FileAccess.file_exists(Juego.RUTA_PARTIDA)
	var huella := hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) if existia else 0
	probar_credito_separado()
	probar_admision_con_credito_previo()
	await probar_turnos_y_duracion()
	await probar_pieza_y_valor()
	await probar_frentes_reales()
	await probar_origen_aparcado_real()
	await probar_barrera()
	await probar_limpieza_al_drenar()
	await probar_referencias_y_cancelacion()
	Juego.reiniciar_estado()
	var intacta := FileAccess.file_exists(Juego.RUTA_PARTIDA) == existia
	if existia:
		intacta = intacta and hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) == huella
	verificar(not Juego.guardado_habilitado and intacta, "la erosión de prueba no altera la partida personal")
	print("Erosión presupuestada: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func crear_run() -> Run:
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var r: Run = RUN.instantiate()
	r.preparacion_sincrona = true # Aísla el presupuesto de erosión de la preparación.
	add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	return r


func comida(r: Run, vida := 10000.0, valor := 1000.0, radio := 32.0) -> Comida:
	var c := Comida.new()
	c._usar_cache = false
	r.comidas.add_child(c)
	c.configurar({"id": "erosion_fixture", "nombre": "Comida de prueba", "forma": "miga", "color": Color.BROWN, "vida": vida, "recompensa": valor, "radio": radio}, 1)
	c.rotation = 0
	c.position = Vector2(-700, 400)
	r.comidas.lista.append(c)
	c.destruida.connect(r.comidas._on_destruida)
	return c


func drenar(r: Run, max_pasos := 1) -> int:
	var vueltas := 0
	while r.cola_erosion.tiene_pendientes() and vueltas < 12000:
		r.cola_erosion.procesar(100000000, max_pasos)
		vueltas += 1
	return vueltas


func credito(m: MordiscosMaterial) -> float:
	var suma := 0.0
	for valor in m._credito_erosion:
		suma += valor
	return suma


## Referencia síncrona LOCAL, independiente de la cola y su reparto de turnos.
## No usa el antiguo recortar_frente(), que podía seguir por toda la pieza.
func pasos_locales(objetivo: Comida, dano: float, origen: Vector2) -> Dictionary:
	var pendiente := dano
	var valor := 0.0
	var pasos := 0
	var cancelado := 0.0
	while pasos < 12000:
		pasos += 1
		var extraido := objetivo.erosion_paso(pendiente, origen)
		var admitido := clampf(objetivo.trabajo_erosion_admitido, 0.0, pendiente)
		pendiente = maxf(0.0, pendiente - admitido)
		valor += extraido
		if objetivo.muerta or objetivo.erosion_zona_agotada:
			cancelado = pendiente
			break
		if pendiente <= 0.0 and not objetivo.erosion_continua:
			break
		if admitido == 0.0 and extraido == 0.0 and not objetivo.erosion_continua:
			break # Contacto tapado: se conserva como pendiente, no se proyecta.
	objetivo.terminar_tramo_erosion()
	return {"valor": valor, "pendiente": pendiente, "cancelado": cancelado, "pasos": pasos}


func solo_recorta_zonas(m: MordiscosMaterial, antes: PackedByteArray, zonas: Array[Rect2]) -> bool:
	if antes.size() != m._pixeles.size():
		return false
	for indice in antes.size():
		if antes[indice] == m._pixeles[indice]:
			continue
		if antes[indice] == 0 or m._pixeles[indice] != 0:
			return false
		var pixel := m._rect_pixel(indice % m._ancho, indice / m._ancho as int)
		var dentro := false
		for zona: Rect2 in zonas:
			if zona.has_area() and zona.grow(0.0001).encloses(pixel):
				dentro = true
				break
		if not dentro:
			return false
	return true


func probar_credito_separado() -> void:
	var rect := Rect2(0, 0, 64, 64)
	var m := MordiscosMaterial.new()
	var referencia := MordiscosMaterial.new()
	m.configurar(rect, Vector2i.ONE, [[rect]], PackedFloat64Array([4096]))
	referencia.configurar(rect, Vector2i.ONE, [[rect]], PackedFloat64Array([4096]))
	var desde := Vector2(-2, 32)
	var zona := m.zona_erosion(desde)
	var antes := m._pixeles.duplicate()
	# El cuerpo es sólido y tiene 1HP/unidad²: el resultado esperado es TODA
	# la intersección geométrica con la mancha, y nada de la cara opuesta.
	var esperado := zona.get_area()
	var zona_pixels := Rect2i(Vector2i((zona.position - rect.position) / referencia._paso), Vector2i(zona.size / referencia._paso))
	referencia._borrar_rectangulo(0, zona_pixels)
	var real := m.recortar_frente_paso(0, 1000, desde)
	verificar(real > 0 and real < esperado and m.ultima_porcion.size.x <= 16 and m.ultima_porcion.size.y <= 16, "un servicio sólo retira una porción16u, no todo el trabajo de veneno")
	var despues := m.area_total()
	verificar(m.recortar_local(0, 0.1, desde, 6) == 0 and m.area_total() == despues and credito(m) > 0, "una hormiga no puede llevarse el crédito ambiental todavía pendiente")
	var pasos := 1
	while m.erosion_pagable(0) and not m.zona_erosion_agotada and pasos < 1000:
		real += m.recortar_frente_paso(0, 0, desde)
		pasos += 1
	verificar(real == esperado and m._pixeles == referencia._pixeles and m._arbol == referencia._arbol
		and m._frontera_arbol == referencia._frontera_arbol and m.zona_erosion_agotada,
		"reanudar con daño0 retira exactamente la mancha geométrica, no el resto de la celda")
	verificar(solo_recorta_zonas(m, antes, [zona]) and is_equal_approx(real + credito(m) + m.trabajo_erosion_descartado, 1000),
		"no desaparecen caras lejanas: todo el trabajo sigue como material retirado, crédito o descarte explícito")
	var agotada := m._pixeles.duplicate()
	verificar(m.recortar_frente_paso(0, 1000, desde) == 0 and m._pixeles == agotada
		and m.zona_erosion_agotada and m.ultimo_trabajo_erosion == 0,
		"una mancha agotada termina sin admitir daño nuevo ni inventar otro pago")
	verificar(is_equal_approx(m._credito[0], 0.1), "el crédito de mordida se mantiene separado del crédito de erosión")
	var residuo := credito(m)
	verificar(residuo > 0.0 and m.recortar_frente_paso(0, 0, Vector2(66, 32)) == 0
		and credito(m) == 0.0 and is_equal_approx(m.trabajo_erosion_descartado, residuo)
		and m._pixeles == agotada,
		"otro contacto no hereda trabajo viejo: el residuo se contabiliza y no viaja a la cara opuesta")


func probar_admision_con_credito_previo() -> void:
	var m := MordiscosMaterial.new()
	var referencia := MordiscosMaterial.new()
	var rect := Rect2(0, 0, 20, 10)
	var formas := [[Rect2(0, 0, 10, 10)], [Rect2(10, 0, 10, 10)]]
	m.configurar(rect, Vector2i(2, 1), formas, PackedFloat64Array([10, 10]))
	referencia.configurar(rect, Vector2i(2, 1), formas, PackedFloat64Array([10, 10]))
	var ancla := Vector2(-2, 5)
	var zona := m.zona_erosion(ancla)
	var antes := m._pixeles.duplicate()
	# Referencia geométrica independiente del selector y del crédito: son
	# 10×10 píxeles de la izquierda y 4×10 de la derecha, a0,1HP por píxel.
	for celda in 2:
		var interseccion := zona.intersection(Rect2(celda * 10, 0, 10, 10))
		var inicio := Vector2i((interseccion.position - rect.position) / referencia._paso)
		var tamano := Vector2i(interseccion.size / referencia._paso)
		referencia._borrar_rectangulo(celda, Rect2i(inicio, tamano))
	m.recortar_frente_paso(0, 0.03, ancla)
	var retirado := m.recortar_frente_paso(0, 15, ancla)
	var admitido := m.ultimo_trabajo_erosion
	retirado += m.recortar_frente_paso(1, 15 - admitido, ancla)
	# La semilla está a media altura: una sola porción puede dejar la otra
	# mitad de la franja, aunque el trabajo ya esté pagado. Continuarla no
	# vuelve a admitir daño y mantiene la cota de16u por servicio.
	var continuaciones := 0
	var porciones_acotadas := m.ultima_porcion.size.x <= 16 and m.ultima_porcion.size.y <= 16
	var sin_reacreditar := true
	while m.erosion_pagable(1) and not m.zona_erosion_agotada and continuaciones < 16:
		var extraido := m.recortar_frente_paso(1, 0, ancla)
		continuaciones += 1
		porciones_acotadas = porciones_acotadas and m.ultima_porcion.size.x <= 16 and m.ultima_porcion.size.y <= 16
		sin_reacreditar = sin_reacreditar and m.ultimo_trabajo_erosion == 0
		retirado += extraido
		if extraido == 0:
			break
	verificar(is_equal_approx(admitido, 9.97)
		and sin_reacreditar and is_equal_approx(retirado + credito(m) + m.trabajo_erosion_descartado, 15.03),
		"saturar una celda con crédito previo admite9,97; el resto pasa a otra celda de la misma mancha sin perder HP")
	var correcto := is_equal_approx(retirado, 14.0) and is_equal_approx(credito(m), 1.03) \
		and continuaciones > 0 and continuaciones < 16 and porciones_acotadas and m.zona_erosion_agotada \
		and m._pixeles == referencia._pixeles and m._arbol == referencia._arbol \
		and m._frontera_arbol == referencia._frontera_arbol and solo_recorta_zonas(m, antes, [zona])
	verificar(correcto,
		"el trabajo que cruza dos celdas sigue limitado al área de la mancha, sin comerse su lado lejano")
	if not correcto:
		print("  DIAG DOS CELDAS zona=", zona, " retirado=", retirado, " credito=", m._credito_erosion,
			" continuaciones=", continuaciones, " agotada=", m.zona_erosion_agotada,
			" ultima_porcion=", m.ultima_porcion, " mascara_igual=", m._pixeles == referencia._pixeles)


func probar_turnos_y_duracion() -> void:
	var r := crear_run()
	var a := comida(r)
	var b := comida(r)
	var desde := a.position + Vector2(-34, 0)
	r.cola_erosion.encolar(a, 4000, desde)
	r.cola_erosion.encolar(b, 4000, desde)
	verificar(a.vida == a.vida_max and b.vida == b.vida_max and Juego.migas_run == 0, "encolar trabajo no quita HP ni cobra recursos")
	r.cola_erosion.procesar(100000000, 2)
	verificar(a.vida < a.vida_max and b.vida < b.vida_max and r.cola_erosion.operaciones_ultimo_cuadro == 2 and r.cola_erosion.tiene_pendientes(), "dos turnos reparten una porción a cada recurso sin vaciar el primero")
	drenar(r)
	verificar(r.cola_erosion.max_operaciones_cuadro <= 2 and not r.cola_erosion.tiene_pendientes(), "el límite determinista por servicio se respeta hasta terminar")
	r.queue_free()
	await get_tree().process_frame
	r = crear_run()
	var c := comida(r)
	c.aplicar_veneno(1600, 1.25, r, c.position + Vector2(-34, 0))
	c._procesar_veneno(0.5)
	c.aplicar_veneno(100, c.veneno_restante, r, c.position + Vector2(34, 0))
	c._procesar_veneno(0.5)
	c._procesar_veneno(0.25)
	verificar(c.veneno_restante == 0 and c._veneno_dps == 0 and r.cola_erosion.tiene_pendientes() and c.vida == c.vida_max, "el veneno expira sin perder los ticks y la cola continúa después")
	var vueltas := drenar(r)
	var retirado := c.vida_max - c.vida
	var conservado := retirado + credito(c.mordiscos) + c.mordiscos.trabajo_erosion_descartado + r.cola_erosion.trabajo_cancelado_zona
	verificar(vueltas > 1 and is_equal_approx(conservado, 2000) and is_equal_approx(r.cola_erosion.trabajo_emitido, 2000),
		"duración1,25s y renovación débil conservan DPS1600: retirado, crédito, descarte y trabajo cancelado suman lo emitido")
	verificar(is_equal_approx(Juego.migas_run, retirado / c.vida_max * c.recompensa * Juego.stat("multiplicador_migas")), "sólo el material efectivamente retirado se acredita una vez")
	verificar(not r.cola_erosion.encolar(c, INF, c.position) and not r.cola_erosion.encolar(c, 1, Vector2.INF), "valores no finitos no crean trabajos ni ingresos")
	r.queue_free()
	await get_tree().process_frame


func pieza(r: Run, clave: String) -> PiezaCasa:
	var p := PiezaCasa.new()
	r.comidas.add_child(p)
	var datos := {"clave": clave, "tipo": "mesada", "rect": Rect2(-850, -800, 260, 200), "color": Color.GRAY, "pared": false}
	datos.dibujo = datos.duplicate(true)
	p.iniciar(datos, r.cocina)
	r.comidas.partes.append(p)
	p.destruida.connect(r.comidas._on_destruida)
	return p


func valor_fragmentos(r: Run) -> float:
	var valor := 0.0
	for f in r.comidas.fragmentos:
		if is_instance_valid(f) and not f.muerta:
			valor += f.recompensa
	return valor


func probar_pieza_y_valor() -> void:
	var r := crear_run()
	var p := pieza(r, "erosion:pieza")
	var referencia := pieza(r, "erosion:referencia")
	var desde := p.rect_mundo.position + Vector2(-2, 40)
	p.preparar_material()
	var antes := p.mordiscos._pixeles.duplicate()
	var zona := p.mordiscos.zona_erosion(desde)
	var referencia_local := pasos_locales(referencia, 1000, desde)
	var fragmentos_previos := valor_fragmentos(r)
	var saldo := Juego.migas_run
	r.cola_erosion.encolar(p, 1000, desde)
	drenar(r)
	verificar(is_equal_approx(p.vida, referencia.vida) and p.mordiscos._pixeles == referencia.mordiscos._pixeles
		and p.mordiscos._arbol == referencia.mordiscos._arbol and p.mordiscos._frontera_arbol == referencia.mordiscos._frontera_arbol
		and solo_recorta_zonas(p.mordiscos, antes, [zona]),
		"una pieza presupuestada conserva HP, máscara y frontera de la referencia local sin cortar fuera de su mancha")
	var valor_real := p.recompensa * (p.vida_max - p.vida) / p.vida_max * Juego.stat("multiplicador_migas")
	verificar(is_equal_approx(Juego.migas_run - saldo, referencia_local.valor) and is_equal_approx(Juego.migas_run - saldo, valor_real * 0.65), "el65% ambiental se cobra únicamente por la extracción real")
	verificar(is_equal_approx(valor_fragmentos(r) - fragmentos_previos, valor_real * 0.35), "el35% restante queda transportable sin duplicar recursos")
	r.queue_free()
	await get_tree().process_frame


func pieza_real(r: Run, datos: Dictionary) -> PiezaCasa:
	var copia := datos.duplicate(true)
	# Las dos referencias no escriben progreso de campaña ni restauran
	# componentes del mismo proyecto: se compara únicamente la erosión.
	for campo in ["objetivo_proyecto", "proyecto_id", "proyecto_vida"]:
		copia.erase(campo)
	var p := PiezaCasa.new()
	r.comidas.add_child(p)
	p.iniciar(copia, r.cocina)
	return p


func probar_frentes_reales() -> void:
	for destino in ["museo", "eiffel"]:
		var r := crear_run_destino(destino)
		var vistos: Dictionary = {}
		for datos: Dictionary in MaterialesCasa.piezas():
			if datos.tipo not in ["biblioteca", "anfora", "torre"] or vistos.has(datos.tipo):
				continue
			vistos[datos.tipo] = true
			var rect: Rect2 = datos.rect
			var centro := rect.get_center()
			var origenes: Array[Vector2] = [Vector2(rect.position.x - 4, centro.y), Vector2(rect.end.x + 4, centro.y), Vector2(centro.x, rect.position.y - 4)]
			for lado in origenes.size():
				# Cada comparación aísla una mancha fresca. El caso siguiente
				# conserva aparte la interacción de orígenes tapados/aparcados.
				var p := pieza_real(r, datos)
				var referencia := pieza_real(r, datos)
				p.preparar_material()
				var antes := p.mordiscos._pixeles.duplicate()
				var zona := p.mordiscos.zona_erosion(origenes[lado])
				var dano := p.vida_max * 0.27
				pasos_locales(referencia, dano, origenes[lado])
				r.cola_erosion.encolar(p, dano, origenes[lado])
				drenar(r)
				var igual := is_equal_approx(p.vida, referencia.vida) and p.mordiscos._pixeles == referencia.mordiscos._pixeles and p.mordiscos._arbol == referencia.mordiscos._arbol and p.mordiscos._frontera_arbol == referencia.mordiscos._frontera_arbol
				verificar(igual and not r.cola_erosion.tiene_pendientes() and solo_recorta_zonas(p.mordiscos, antes, [zona]),
					"%s/%s lado%d: referencia local exacta y ningún píxel retirado fuera del ancla" % [destino, datos.tipo, lado])
				p.queue_free()
				referencia.queue_free()
		r.queue_free()
		await get_tree().process_frame


func probar_origen_aparcado_real() -> void:
	var r := crear_run_destino("eiffel")
	var datos_torre: Dictionary = {}
	for datos: Dictionary in MaterialesCasa.piezas():
		if datos.tipo == "torre" and datos.get("meta", false):
			datos_torre = datos
			break
	verificar(not datos_torre.is_empty(), "el origen aparcado usa la torre real del destino Eiffel")
	if datos_torre.is_empty():
		r.queue_free()
		await get_tree().process_frame
		return
	var p := pieza_real(r, datos_torre)
	var referencia := pieza_real(r, datos_torre)
	var preparadas := p.preparar_material() and referencia.preparar_material()
	verificar(preparadas and p._por_pisos and not p._material_original.is_empty(), "la torre fresca conserva su material real y el desmontaje por pisos")
	if not preparadas or not p._por_pisos or p._material_original.is_empty():
		r.queue_free()
		await get_tree().process_frame
		return
	# El porcentaje consumido desde un lateral no garantiza quedar aparcado:
	# un calado nuevo puede habilitar otro soporte. Elegir los dos orígenes
	# sobre la geometría fresca y comprobar expresamente contacto y oclusión.
	var mas_alta: Rect2 = p._material_original[0]
	for forma: Rect2 in p._material_original:
		if forma.position.y < mas_alta.position.y:
			mas_alta = forma
	var fila := 0
	for i in p.vivas:
		fila = maxi(fila, i / p.grilla.x as int)
	var limite_derecho := Rect2()
	var celda_derecha := -1
	for i in p.vivas:
		if (i / p.grilla.x as int) != fila:
			continue
		var limite := p.mordiscos.limites_celda(i)
		if limite.has_area() and (not limite_derecho.has_area() or limite.end.x > limite_derecho.end.x):
			limite_derecho = limite
			celda_derecha = i
	# El extremo del AABB puede estar muy lejos de su fila central en un
	# apoyo inclinado. Elegir una cara de un píxel vivo de la columna más
	# externa, no el centro vacío de esa caja. La lectura es independiente
	# de punto_contacto(), cuya respuesta se verifica después.
	var pixel_apoyo := Rect2()
	if celda_derecha >= 0:
		var limites: Rect2i = p.mordiscos._limites_pixels[celda_derecha]
		var x := limites.end.x - 1
		var distancia_fila := INF
		for y in range(limites.position.y, limites.end.y):
			if p.mordiscos._pixeles[y * p.mordiscos._ancho + x] == 0:
				continue
			var pixel := p.mordiscos._rect_pixel(x, y)
			var distancia := absf(pixel.get_center().y - limite_derecho.get_center().y)
			if distancia < distancia_fila:
				distancia_fila = distancia
				pixel_apoyo = pixel
	# Anclas junto al material REAL, no al margen transparente del sprite:
	# las dos manchas contienen píxeles, aunque la primera tenga piso tapado.
	var bloqueado := Vector2(mas_alta.get_center().x, mas_alta.position.y - 4)
	var accesible := Vector2(pixel_apoyo.end.x + 4, pixel_apoyo.get_center().y) if pixel_apoyo.has_area() else Vector2.INF
	var contacto := p.punto_contacto(accesible) if accesible.is_finite() else Vector2.INF
	var zona_accesible := p.mordiscos.zona_erosion(accesible) if accesible.is_finite() else Rect2()
	var origenes_validos := pixel_apoyo.has_area() and p.mordiscos.aire_exterior(bloqueado) \
		and p.mordiscos.aire_exterior(accesible) and p.punto_contacto(bloqueado) == Vector2.INF \
		and contacto.is_finite() and accesible.distance_to(contacto) <= 5.0 \
		and zona_accesible.grow(0.001).has_point(contacto) \
		and p.mordiscos.intersecta_rect(p.mordiscos.zona_erosion(bloqueado), true) \
		and p.mordiscos.intersecta_rect(zona_accesible, true)
	verificar(origenes_validos, "el pico ocluye el origen superior y el soporte inferior tiene contacto desde la derecha")
	if not origenes_validos:
		print("  DIAG APARCADO superior=", bloqueado, " contacto=", p.punto_contacto(bloqueado),
			" derecha=", accesible, " contacto=", contacto, " pixel_apoyo=", pixel_apoyo,
			" celda=", celda_derecha, " zona=", zona_accesible)
		r.queue_free()
		await get_tree().process_frame
		return
	var dano := p.vida_max * 0.01
	var antes := p.vida
	var pagado := Juego.migas_run
	var pixeles := p.mordiscos._pixeles.duplicate()
	pasos_locales(referencia, dano, bloqueado)
	var encolado := r.cola_erosion.encolar(p, dano, bloqueado)
	drenar(r)
	verificar(encolado and r.cola_erosion._latentes.has(p.get_instance_id())
		and not r.cola_erosion.tiene_pendientes() and p.vida == antes
		and p.mordiscos._pixeles == pixeles and Juego.migas_run == pagado,
		"un origen realmente ocluido queda aparcado sin retirar material ni acreditar recursos")
	pasos_locales(referencia, dano, accesible)
	encolado = r.cola_erosion.encolar(p, dano, accesible)
	drenar(r)
	verificar(encolado and p.vida < antes, "un origen superior aparcado no bloquea el veneno nuevo sobre el soporte derecho")
	var igual := is_equal_approx(p.vida, referencia.vida) and p.mordiscos._pixeles == referencia.mordiscos._pixeles \
		and p.mordiscos._arbol == referencia.mordiscos._arbol and p.mordiscos._frontera_arbol == referencia.mordiscos._frontera_arbol
	verificar(igual and not r.cola_erosion.tiene_pendientes(), "despertar otro origen conserva HP, máscara y frontera exactas de los pasos locales")
	verificar(r.cola_erosion._latentes.has(p.get_instance_id()), "el origen superior sigue aparcado mientras el soporte derecho sí pierde material")
	antes = p.vida
	pagado = Juego.migas_run
	r._iniciar_retirada()
	verificar(r.retirando and not r.cerrando_erosion and p.vida == antes and Juego.migas_run == pagado
		and not r.cola_erosion.tiene_pendientes() and r.cola_erosion._latentes.is_empty(),
		"el trabajo aparcado no bloquea el cierre, no extrae material y se cancela sin convertirse en recursos")
	r.queue_free()
	await get_tree().process_frame


func crear_run_destino(destino: String) -> Run:
	Juego.reiniciar_estado()
	Juego.lugar_actual = destino
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var r: Run = RUN.instantiate()
	r.preparacion_sincrona = true
	add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	return r


func probar_barrera() -> void:
	# Cambio pedido: el silbato cancela trabajo no extraído; ya no existe una
	# fase posterior que destruya objetos o acredite veneno pendiente.
	var r := crear_run()
	var c := comida(r, 1000000, 1000, 100)
	c.aplicar_veneno(1000000, 10, r, c.position + Vector2(-102, 0))
	c._procesar_veneno(0.2)
	r.cola_erosion.encolar(c, 200000, c.position + Vector2(-102, 0))
	var restante := r.tiempo_restante
	var jugado := r.tiempo_jugado
	var cargando := r.colonia._nacer("obrera", Vector2(200, 0))
	cargando.carga = 1 # Carga previa al silbato, sin mover el fixture detenido.
	r._iniciar_retirada()
	verificar(not r.cerrando_erosion and not r.activa and r.retirando and not r.terminada and c.veneno_restante == 0, "cerrar pasa inmediatamente a últimas entregas y corta el veneno")
	verificar(not r.cola_erosion.tiene_pendientes() and not get_tree().paused, "el trabajo ambiental pendiente se descarta sin pausar el árbol")
	r._process(0.25)
	verificar(r.tiempo_restante == restante and r.tiempo_jugado == jugado and r.tiempo_espera_erosion == 0, "no hay tiempo extra de extracción ni espera de corrosión")
	r.cola_erosion.procesar(100000000, 1)
	verificar(c.vida == c.vida_max and Juego.migas_run == 0, "la cola no retira ni paga una primera porción después del silbato")
	drenar(r)
	await get_tree().process_frame
	verificar(not r.cerrando_erosion and c.vida == c.vida_max and Juego.migas_run == 0, "volver a procesar no resucita trabajo descartado")
	var pagado := Juego.migas_run
	r._iniciar_retirada()
	verificar(Juego.migas_run == pagado and r.retirando, "repetir la retirada no duplica pagos ni cierres")
	r.queue_free()
	await get_tree().process_frame
	r = crear_run()
	c = comida(r)
	c.aplicar_veneno(0.1, 1, r, c.position + Vector2(-34, 0))
	c._procesar_veneno(0.2)
	r._cerrar()
	drenar(r)
	await get_tree().process_frame
	verificar(r.terminada and not r.cerrando_erosion and Juego.migas_run == 0 and c.vida == c.vida_max, "un residuo subpíxel cierra sin espera infinita ni recursos inventados")
	var runs := Juego.runs_jugadas
	r._cerrar()
	verificar(Juego.runs_jugadas == runs, "el cierre sin drenaje cobra la expedición una sola vez")
	r.queue_free()
	await get_tree().process_frame


func probar_referencias_y_cancelacion() -> void:
	var r := crear_run()
	var c := comida(r)
	r.cola_erosion.encolar(c, 4000, c.position + Vector2(-34, 0))
	c.morder(c.vida_max * 2)
	var pagado := Juego.migas_run
	drenar(r)
	verificar(not r.cola_erosion.tiene_pendientes() and Juego.migas_run == pagado, "si otra extracción destruye el objetivo la cola no paga su material otra vez")
	var liberada := comida(r)
	r.cola_erosion.encolar(liberada, 4000, liberada.position + Vector2(-34, 0))
	liberada.queue_free()
	await get_tree().process_frame
	drenar(r)
	verificar(not r.cola_erosion.tiene_pendientes() and Juego.migas_run == pagado, "una referencia liberada se descarta sin acceso inválido ni cobro")
	var pendiente := comida(r)
	r.cola_erosion.encolar(pendiente, 4000, pendiente.position + Vector2(-34, 0))
	r.queue_free()
	await get_tree().process_frame
	verificar(Juego.migas_run == pagado, "destruir la escena cancela trabajo sin convertir crédito en ingreso")


func probar_limpieza_al_drenar() -> void:
	for bloqueo in ["ninguno", "fragmentos y tesoro", "botin", "cadena", "colonia perdida", "cierre forzado"]:
		var r := crear_run()
		# Escenario unitario explícito: un recurso final, no una campaña vaciada
		# por daño de prueba ni una medición de producción.
		for grupo in [r.comidas.lista, r.comidas.partes, r.comidas.fragmentos]:
			for recurso in grupo:
				recurso.queue_free()
			grupo.clear()
		r.comidas._indice.clear()
		r.comidas._pilas.clear()
		r._hubo_objetivos = true
		r._colonia_operativa = true
		r.colonia._por_salir = 0
		r.tiempo_restante = 0
		var c := comida(r, 1000, 10)
		c.position = Vector2(70, 0)
		if bloqueo == "fragmentos y tesoro":
			r.comidas.soltar_fragmento(Vector2(160, 0), 10, 1)
			var alijo := comida(r, 1000, 10)
			alijo.position = Vector2(120, 0)
		elif bloqueo == "botin":
			var evento := Evento.new()
			evento.visible = false
			evento.tipo = "paloma"
			evento.run = r
			evento.botin = 10
			r.eventos.add_child(evento)
			r.eventos.activos.append(evento)
		elif bloqueo == "cadena":
			r.reglas._pendientes.append({})
		elif bloqueo == "colonia perdida":
			r.colonia_perdida = true
		r.cola_erosion.encolar(c, c.vida_max, c.position + Vector2(-34, 0))
		if bloqueo == "cierre forzado":
			r._cerrar()
		else:
			r._iniciar_retirada()
		r._process(0.3)
		var instante := r.tiempo_jugado
		drenar(r)
		await get_tree().process_frame
		await get_tree().process_frame
		verificar(not r.limpieza_lograda and not r.limpieza_registrada and c.vida == c.vida_max and instante == 0,
			bloqueo + ": la última comida no extraída queda intacta y no inventa limpieza al cerrar")
		r.queue_free()
		await get_tree().process_frame


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", detalle)
