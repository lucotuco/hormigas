extends Node
## El árbol de ocupación debe responder lo mismo que barrer sus píxeles.
## El notch de la mesa es un fixture blanco sintético: no simula una mordida,
## no concede recursos y conserva a propósito el AABB de la celda comestible.
const RECT := Rect2(-32, -24, 64, 48)
const CONSULTAS := 160
const EPS := 0.000001
var total := 0
var fallas := 0


func _init() -> void:
	Juego.guardado_habilitado = false


func _ready() -> void:
	var huellas := huellas_guardados()
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	probar_consultas_por_pixel()
	probar_fila_vacia()
	await probar_cavidad_mesa()
	await probar_poda_del_ultimo_pixel()
	verificar(huellas_guardados() == huellas, "la geometría de prueba no modifica partida ni ajustes personales")
	Juego.reiniciar_estado()
	print("Geometría del material: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func crear_material(formas: Array[Rect2]) -> MordiscosMaterial:
	var por_celda: Array = []
	var vidas := PackedFloat64Array()
	var grilla := Vector2i(2, 2)
	var tam := RECT.size / Vector2(grilla)
	for y in grilla.y:
		for x in grilla.x:
			var limite := Rect2(RECT.position + Vector2(x, y) * tam, tam)
			var partes: Array[Rect2] = []
			for forma: Rect2 in formas:
				var interseccion := forma.intersection(limite)
				if interseccion.has_area():
					partes.append(interseccion)
			por_celda.append(partes)
			vidas.append(100.0 if not partes.is_empty() else 0.0)
	var material := MordiscosMaterial.new()
	material.configurar(RECT, grilla, por_celda, vidas)
	return material


func probar_consultas_por_pixel() -> void:
	var siluetas: Array[Array] = [
		[RECT],
		[Rect2(-32, -24, 10, 48), Rect2(-22, 14, 54, 10), Rect2(12, -14, 10, 8)],
		[Rect2(-32, -24, 64, 8), Rect2(-32, 16, 64, 8), Rect2(-32, -16, 8, 32), Rect2(24, -16, 8, 32)],
	]
	for indice in siluetas.size():
		var formas: Array[Rect2] = []
		formas.assign(siluetas[indice])
		var material := crear_material(formas)
		comparar_consultas(material, "silueta%d intacta" % indice)
		comparar_cercania(material, "silueta%d intacta" % indice)
		var retirado := 0.0
		for celda in material._cantidad_celdas:
			if material.vida_celda(celda) <= 0.0:
				continue
			var origen := material.origen_exterior(celda, RECT.position - Vector2(10, 0))
			retirado += material.recortar_bulk(celda, material.vida_celda(celda) * 0.08, origen)
		verificar(retirado > 0.0, "silueta%d: un recorte bulk de fixture retira material antes de volver a consultar" % indice)
		comparar_consultas(material, "silueta%d recortada" % indice)
		comparar_cercania(material, "silueta%d recortada" % indice)
		for celda in material._cantidad_celdas:
			material.limpiar_celda(celda)
		verificar(material.area_total() == 0.0
			and not material.intersecta_rect(RECT.grow(100))
			and not material.intersecta_segmento(RECT.position - Vector2.ONE, RECT.end + Vector2.ONE, 8.0)
			and material.punto_material(Vector2.ZERO) == Vector2.INF
			and material.punto_material(Vector2.ZERO, 0) == Vector2.INF
			and material.punto_material(Vector2.ZERO, 1) == Vector2.INF,
			"silueta%d: vaciar el último píxel elimina también la colisión del árbol" % indice)


func comparar_cercania(material: MordiscosMaterial, nombre: String) -> void:
	var azar := RandomNumberGenerator.new()
	azar.seed = 33841
	var posiciones: Array[Vector2] = [Vector2.ZERO, RECT.position, RECT.end,
		Vector2(0, RECT.position.y), Vector2(0, RECT.end.y),
		Vector2(RECT.position.x, 0), Vector2(RECT.end.x, 0),
		RECT.position - Vector2.ONE * 20.0, RECT.end + Vector2.ONE * 20.0,
		Vector2(-24, 0), Vector2(24, 0)]
	for i in 64:
		posiciones.append(Vector2(azar.randi_range(-80, 80), azar.randi_range(-64, 64)) * 0.5)
	# La referencia obtiene la distancia geométrica cerrada. El helper devuelve
	# un punto apenas interior al píxel ganador: sólo se tolera ese inset,
	# no elegir otra celda ni una fila diferente para resolver un empate.
	var tolerancia := material._paso.length() * 0.0002 + EPS
	for fila: int in [-1, 0, 1]:
		var desacuerdos := 0
		for posicion: Vector2 in posiciones:
			var esperado := referencia_material_cercano(material, posicion, fila)
			var actual := material.punto_material(posicion, fila)
			var correcto := actual == Vector2.INF and esperado == Vector2.INF
			if actual != Vector2.INF and esperado != Vector2.INF:
				correcto = material.contiene(actual)
				correcto = correcto and absf(posicion.distance_to(actual) - posicion.distance_to(esperado)) <= tolerancia
				if fila >= 0:
					var inicio_y := material._rect_mundo.position.y + fila * material._alto_celda * material._paso.y
					var fin_y := inicio_y + material._alto_celda * material._paso.y
					correcto = correcto and actual.y >= inicio_y and actual.y < fin_y
			if not correcto:
				desacuerdos += 1
				if desacuerdos <= 2:
					print("DIAG NEAREST ", nombre, " fila=", fila, " desde=", posicion,
						" árbol=", actual, " píxeles=", esperado)
		verificar(desacuerdos == 0, "%s: %d nearest en fila %d coinciden con la distancia mínima por píxel" % [nombre, posiciones.size(), fila])


func probar_fila_vacia() -> void:
	var material := crear_material([Rect2(RECT.position, Vector2(RECT.size.x, 12))])
	verificar(material._grilla == Vector2i(2, 2) and material.area_total() > 0.0,
		"el caso de nearest por fila usa cuatro celdas y conserva material en la fila superior")
	comparar_cercania(material, "fila inferior vacía")
	verificar(material.punto_material(Vector2.ZERO) != Vector2.INF
		and material.punto_material(Vector2.ZERO, 0) != Vector2.INF
		and material.punto_material(Vector2.ZERO, 1) == Vector2.INF
		and material.punto_material(Vector2.ZERO, material._grilla.y) == Vector2.INF,
		"una fila vacía o fuera de rango devuelve INF sin reutilizar el nearest global")


## Referencia nearest sin árbol: recorre cada píxel de la fila solicitada,
## proyecta sobre su rectángulo y conserva la menor distancia geométrica.
func referencia_material_cercano(material: MordiscosMaterial, posicion: Vector2, fila := -1) -> Vector2:
	if fila >= material._grilla.y:
		return Vector2.INF
	var y0 := 0 if fila < 0 else fila * material._alto_celda
	var y1 := material._alto if fila < 0 else (fila + 1) * material._alto_celda
	var mejor := Vector2.INF
	var menor := INF
	for y in range(y0, y1):
		for x in material._ancho:
			if material._pixeles[y * material._ancho + x] == 0:
				continue
			var inicio := material._rect_mundo.position + Vector2(x, y) * material._paso
			var candidato := posicion.clamp(inicio, inicio + material._paso)
			var distancia := posicion.distance_squared_to(candidato)
			if distancia < menor:
				menor = distancia
				mejor = candidato
	return mejor


func comparar_consultas(material: MordiscosMaterial, nombre: String) -> void:
	var azar := RandomNumberGenerator.new()
	azar.seed = 4833
	var rectangulos: Array[Rect2] = [RECT, RECT.grow(8), Rect2(RECT.end, Vector2.ZERO),
		Rect2(RECT.position, Vector2.ZERO), Rect2(Vector2.ZERO, Vector2.ZERO),
		Rect2(RECT.position - Vector2(4, 0), Vector2(4, 48)),
		Rect2(Vector2(32, -24), Vector2(4, 48)), Rect2(Vector2(-2, -2), Vector2(4, 4))]
	for i in CONSULTAS:
		var pos := Vector2(azar.randi_range(-44, 44), azar.randi_range(-36, 36)) * 0.75
		var tam := Vector2(azar.randi_range(0, 28), azar.randi_range(0, 24)) * 0.5
		rectangulos.append(Rect2(pos, tam))
	var desacuerdos_rect := 0
	for rect: Rect2 in rectangulos:
		var esperado := referencia_rect(material, rect)
		var actual := material.intersecta_rect(rect)
		if esperado != actual:
			desacuerdos_rect += 1
			if desacuerdos_rect <= 2:
				print("DIAG RECT ", nombre, " ", rect, " árbol=", actual, " píxeles=", esperado)
	verificar(desacuerdos_rect == 0, "%s: %d rectángulos y puntos coinciden con el barrido de píxeles" % [nombre, rectangulos.size()])
	var segmentos: Array[Array] = [
		[Vector2(-45, 0), Vector2(45, 0)], [Vector2(0, -35), Vector2(0, 35)],
		[Vector2(-45, -35), Vector2(45, 35)], [Vector2(45, -35), Vector2(-45, 35)],
		[RECT.position, RECT.position], [RECT.end, RECT.end],
		[Vector2(-40, -24), Vector2(40, -24)], [Vector2(-40, 24), Vector2(40, 24)],
		[Vector2.ZERO, Vector2.ZERO], [Vector2(-40, -32), Vector2(40, -32)],
	]
	for i in CONSULTAS:
		segmentos.append([Vector2(azar.randi_range(-44, 44), azar.randi_range(-36, 36)),
			Vector2(azar.randi_range(-44, 44), azar.randi_range(-36, 36))])
	var desacuerdos_segmento := 0
	for segmento: Array in segmentos:
		for margen: float in [0.0, 2.5, Cocina.MARGEN]:
			var esperado := referencia_segmento(material, segmento[0], segmento[1], margen)
			var actual := material.intersecta_segmento(segmento[0], segmento[1], margen)
			if esperado != actual:
				desacuerdos_segmento += 1
				if desacuerdos_segmento <= 2:
					print("DIAG SEGMENTO ", nombre, " ", segmento, " margen=", margen, " árbol=", actual, " píxeles=", esperado)
	verificar(desacuerdos_segmento == 0, "%s: %d segmentos con margen 0, 2,5 y 8 coinciden con cada píxel vivo" % [nombre, segmentos.size()])


## Referencia lenta deliberada: no usa el árbol ni los helpers de colisión.
func referencia_rect(material: MordiscosMaterial, zona: Rect2) -> bool:
	if not zona.has_area():
		if not material._rect_mundo.has_point(zona.position):
			return false
		var p := (zona.position - material._rect_mundo.position) / material._paso
		var x := floori(p.x)
		var y := floori(p.y)
		return material._pixeles[y * material._ancho + x] != 0
	var rango := rango_referencia(material, zona.position, zona.end)
	for y in range(rango.position.y, rango.end.y):
		for x in range(rango.position.x, rango.end.x):
			if material._pixeles[y * material._ancho + x] == 0:
				continue
			var pixel := Rect2(material._rect_mundo.position + Vector2(x, y) * material._paso, material._paso)
			if pixel.intersects(zona):
				return true
	return false


func referencia_segmento(material: MordiscosMaterial, desde: Vector2, hasta: Vector2, margen: float) -> bool:
	var rango := rango_referencia(material, desde.min(hasta) - Vector2.ONE * margen,
		desde.max(hasta) + Vector2.ONE * margen)
	for y in range(rango.position.y, rango.end.y):
		for x in range(rango.position.x, rango.end.x):
			if material._pixeles[y * material._ancho + x] == 0:
				continue
			var pixel := Rect2(material._rect_mundo.position + Vector2(x, y) * material._paso, material._paso).grow(margen)
			if referencia_corta_rect(desde, hasta, pixel):
				return true
	return false


## Poda AABB de referencia, sin árbol ni contadores. El píxel extra permite
## contactos exactos sobre cualquiera de los bordes del barrido cerrado.
func rango_referencia(material: MordiscosMaterial, desde: Vector2, hasta: Vector2) -> Rect2i:
	var a := (desde - material._rect_mundo.position) / material._paso
	var b := (hasta - material._rect_mundo.position) / material._paso
	var x0 := clampi(floori(a.x) - 1, 0, material._ancho)
	var y0 := clampi(floori(a.y) - 1, 0, material._alto)
	var x1 := clampi(ceili(b.x) + 1, 0, material._ancho)
	var y1 := clampi(ceili(b.y) + 1, 0, material._alto)
	return Rect2i(x0, y0, maxi(0, x1 - x0), maxi(0, y1 - y0))


func referencia_corta_rect(desde: Vector2, hasta: Vector2, rect: Rect2) -> bool:
	if dentro_cerrado(desde, rect) or dentro_cerrado(hasta, rect):
		return true
	var esquinas: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		if segmentos_se_cruzan(desde, hasta, esquinas[i], esquinas[(i + 1) % 4]):
			return true
	return false


func dentro_cerrado(punto: Vector2, rect: Rect2) -> bool:
	return punto.x >= rect.position.x and punto.y >= rect.position.y and punto.x <= rect.end.x and punto.y <= rect.end.y


func segmentos_se_cruzan(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab := b - a
	var cd := d - c
	var ac := c - a
	var denominador := ab.cross(cd)
	if absf(denominador) > EPS:
		var t := ac.cross(cd) / denominador
		var u := ac.cross(ab) / denominador
		return t >= -EPS and t <= 1.0 + EPS and u >= -EPS and u <= 1.0 + EPS
	if absf(ac.cross(ab)) > EPS:
		return false
	# Colineales: comparar intervalos proyectados, incluidos contactos exactos.
	return maxf(minf(a.x, b.x), minf(c.x, d.x)) <= minf(maxf(a.x, b.x), maxf(c.x, d.x)) + EPS \
		and maxf(minf(a.y, b.y), minf(c.y, d.y)) <= minf(maxf(a.y, b.y), maxf(c.y, d.y)) + EPS


func probar_cavidad_mesa() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1, "excavar": 30}
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.colonia._activa = false
	run.radio_actual = 12000.0
	var mesa := run.objetivo_mapa
	verificar(is_instance_valid(mesa) and mesa.pieza.tipo == "mesa_comedor",
		"se usa la gran mesa familiar real de la casa, no un rectángulo de navegación inventado")
	mesa.preparar_material()
	# Normalizar una sola vez las bandas analíticas contra el raster recién
	# preparado; la aserción posterior aísla el notch, no ese redondeo inicial.
	mesa._actualizar_colision()
	var material := mesa.mordiscos
	var celda := mesa.grilla.x # Primera columna de la segunda fila, lejos de las esquinas exteriores.
	var limite: Rect2i = material._limites_pixels[celda]
	var alto := mini(60, limite.size.y - 12)
	var ancho := mini(70, limite.size.x / 2 as int)
	var recorte := Rect2i(limite.position + Vector2i(0, (limite.size.y - alto) / 2 as int), Vector2i(ancho, alto))
	var zona := Rect2(material._rect_mundo.position + Vector2(recorte.position) * material._paso,
		Vector2(recorte.size) * material._paso)
	var interior := Vector2(zona.position.x + minf(40.0, zona.size.x * 0.35), zona.get_center().y)
	var exterior := Vector2(zona.position.x - Cocina.CELDA * 3.0, interior.y)
	var restante := zona.end + Vector2(24, 0)
	var aabb_antes := material.limites_celda(celda)
	var fisico_antes: Rect2 = mesa._limites_fisicos[celda]
	var formas_antes := mesa._formas.duplicate()
	var area_antes := material.area_total()
	var saldo := Juego.migas_run
	var anterior := mesa.punto_mordida(interior, run.radio_actual)
	run.cocina._actualizar_radio(run.radio_actual)
	var celda_grilla := Vector2i((interior / Cocina.CELDA).floor())
	verificar(material.contiene(interior) and not run.cocina.libre(interior, Cocina.MARGEN)
		and run.cocina._suelo.is_point_solid(celda_grilla),
		"antes del fixture, máscara, margen y rejilla bloquean la porción que se va a retirar")
	var zoom_previo := run.camara.zoom
	run.camara.zoom = Vector2.ONE * 4.0
	run.camara.force_update_scroll()
	run.feromonas.mantener_en(interior)
	verificar(is_equal_approx(run.feromonas.radio_visual(), 20.0)
		and run.feromonas.objetivo_comida == mesa
		and run.feromonas._ids_area.has(mesa.get_instance_id()),
		"antes de retirar el material, mantener sobre la mesa selecciona ese objeto con radio veinte al zoom cuatro")
	# Notch sintético conectado al exterior: la eliminación genérica visita
	# píxeles vivos, sin suponer que el rectángulo de arte está completamente
	# sólido. No usa daño de hormiga ni pretende medir el tamaño de un bocado.
	material._borrar_rectangulo(celda, recorte)
	mesa.vidas[celda] = material.vida_celda(celda)
	mesa.vida = 0.0
	for hp: float in mesa.vidas:
		mesa.vida += hp
	mesa._version_material += 1
	mesa._registrar_retroceso(celda, zona)
	verificar(material.limites_celda(celda) == aabb_antes and mesa._geometria_pendiente,
		"un hueco conectado puede retirar material e invalidar geometría sin achicar el AABB de su celda")
	mesa._process(0.2)
	while not run.cocina._cambios.is_empty():
		run.cocina.procesar_cambios(384)
	verificar(material.area_total() < area_antes and not material.contiene(interior)
		and material.aire_exterior(interior) and material.limites_celda(celda) == aabb_antes
		and mesa._limites_fisicos[celda] == fisico_antes and mesa._formas == formas_antes,
		"el notch queda vacío y conectado en la máscara R8 aunque todas las bandas gruesas sigan iguales")
	probar_llamado_retenido(run, mesa, interior, exterior, restante)
	run.camara.zoom = zoom_previo
	run.camara.force_update_scroll()
	verificar(run.cocina._obstaculos[mesa.pieza.clave].get("material_vivo") == material
		and run.cocina.libre(interior, Cocina.MARGEN)
		and run.cocina.segmento_libre(exterior, interior)
		and not run.cocina._suelo.is_point_solid(celda_grilla),
		"Cocina comparte la máscara: abre el hueco con margen ocho y publica la celda transitable")
	verificar(material.intersecta_rect(Rect2(restante - Vector2.ONE * 4, Vector2.ONE * 8))
		and not run.cocina.libre(restante, Cocina.MARGEN)
		and not run.cocina.segmento_libre(exterior, restante),
		"el material contiguo conservado sigue bloqueando el cuerpo y el segmento; no se libera toda la celda")
	var puesto := mesa.punto_mordida(interior, run.radio_actual)
	verificar(puesto != Vector2.INF and puesto.x > aabb_antes.position.x + 20.0
		and mesa.alcanza_contacto(puesto) and run.cocina.libre(puesto, Cocina.MARGEN)
		and puesto != anterior,
		"el puesto se actualiza hacia una frontera interior real, no hacia la cara original del AABB")
	var ruta := run.cocina.ruta(exterior, interior, run.radio_actual)
	var ruta_puesto := run.cocina.ruta(exterior, puesto, run.radio_actual) if puesto != Vector2.INF else PackedVector2Array()
	verificar(ruta_segura(run.cocina, exterior, ruta) and ruta_segura(run.cocina, exterior, ruta_puesto),
		"se puede recorrer el hueco hasta su interior y su nuevo frente sin cruzar el material restante")
	var franjas: Array[Rect2] = [zona.grow(-9.0), Rect2(restante - Vector2.ONE * 4, Vector2.ONE * 8)]
	var equivalentes := true
	for franja: Rect2 in franjas:
		equivalentes = equivalentes and material.intersecta_rect(franja) == referencia_rect(material, franja)
	for par: Array in [[exterior, interior], [exterior, restante]]:
		equivalentes = equivalentes and material.intersecta_segmento(par[0], par[1], Cocina.MARGEN) == referencia_segmento(material, par[0], par[1], Cocina.MARGEN)
	verificar(equivalentes and Juego.migas_run == saldo,
		"las consultas del notch real coinciden con píxeles y su preparación sintética nunca paga migas")
	probar_reparto_en_frente(run, mesa, celda, recorte, zona)
	run.queue_free()
	await get_tree().process_frame


func probar_poda_del_ultimo_pixel() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "excavar": 30}
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.colonia._activa = false
	run.radio_actual = 12000.0
	var mesa: PiezaCasa
	for parte: PiezaCasa in run.comidas.partes:
		if parte.pieza.tipo == "mesa" and parte.rect_mundo == Rect2(400, 160, 700, 440):
			mesa = parte
			break
	verificar(is_instance_valid(mesa), "la regresión de poda usa la mesa normal de 700×440, no el gran objetivo")
	if not is_instance_valid(mesa):
		run.queue_free()
		await get_tree().process_frame
		return
	mesa.preparar_material()
	var material := mesa.mordiscos
	var desde := Vector2(1107.3, 140)
	var hasta := Vector2(1107.3, 620)
	var barrido := Rect2(desde.min(hasta), (hasta - desde).abs()).grow(Cocina.MARGEN)
	var descriptor: Dictionary = run.cocina._obstaculos[mesa.pieza.clave]
	var perfil: Rect2 = descriptor.get("_limite_recortes", descriptor.rect)
	# El perfil analítico termina cerca de x1098,58. La máscara cubre el
	# último píxel entero hasta x1100; este barrido empieza en x1099,3.
	# Descartarlo por el perfil sin padding omitiría una colisión verdadera.
	verificar(descriptor.get("material_vivo") == material
		and not perfil.intersects(barrido, true)
		and perfil.grow(MordiscosMaterial.PASO_MAXIMO).intersects(barrido, true),
		"el segmento reproduce la franja rasterizada que queda fuera de la poda analítica sin padding")
	verificar(run.cocina.libre(desde, Cocina.MARGEN) and run.cocina.libre(hasta, Cocina.MARGEN),
		"ambos extremos están libres: la colisión debe detectarse durante el segmento, no por su destino")
	var referencia := referencia_segmento(material, desde, hasta, Cocina.MARGEN)
	var referencia_inversa := referencia_segmento(material, hasta, desde, Cocina.MARGEN)
	verificar(referencia and referencia_inversa and material.intersecta_segmento(desde, hasta, Cocina.MARGEN)
		and material.intersecta_segmento(hasta, desde, Cocina.MARGEN),
		"el barrido por píxeles y el árbol coinciden sobre el último píxel en ambos sentidos")
	verificar(not run.cocina.segmento_libre(desde, hasta)
		and not run.cocina.segmento_libre(hasta, desde),
		"la poda incluye el último píxel y Cocina rechaza el segmento completo en ambos sentidos")
	var lejano_desde := Vector2(1110.5, 140)
	var lejano_hasta := Vector2(1110.5, 620)
	verificar(not referencia_segmento(material, lejano_desde, lejano_hasta, Cocina.MARGEN)
		and not material.intersecta_segmento(lejano_desde, lejano_hasta, Cocina.MARGEN)
		and run.cocina.segmento_libre(lejano_desde, lejano_hasta),
		"el padding sólo amplía la poda: el árbol sigue dejando pasar un segmento realmente fuera del material")
	run.queue_free()
	await get_tree().process_frame


func probar_llamado_retenido(run: Run, mesa: PiezaCasa, interior: Vector2, exterior: Vector2, restante: Vector2) -> void:
	var llamado := run.feromonas
	var id_mesa := mesa.get_instance_id()
	verificar(not mesa.contiene_punto(interior) and mesa.distancia_a(interior) > llamado.radio_visual()
		and run.comidas.comida_en(interior, run.radio_actual) == null,
		"el cursor quedó en un hueco sin recurso y el frente vivo está fuera de las veinte unidades del círculo")
	llamado._actualizar_cercanas()
	verificar(llamado.activa and llamado.objetivo_comida == mesa
		and llamado._ids_area.has(id_mesa) and llamado._comidas_area.has(mesa),
		"sostener el mismo clic conserva la mesa y su elegibilidad aunque crezca el hueco bajo el cursor")
	var h := run.colonia._nacer("obrera", interior)
	llamado._actualizar_cercanas()
	h._pensar()
	verificar(h.comida == mesa and h.estado == Hormiga.Estado.YENDO_A_COMIDA,
		"la obrera busca el frente que retrocedió en vez de quedar siguiendo el centro vacío del llamado")
	h.detener()
	# Elegir piso libre y sin alimento evita confundir abandonar la huella con
	# un reemplazo explícito por alguna comida nativa distribuida al azar.
	var piso := Vector2.INF
	for i in 12:
		var candidato := exterior - Vector2(i * 16.0, 0)
		if (not mesa.rect_mundo.has_point(candidato) and run.cocina.libre(candidato, Cocina.MARGEN)
			and run.comidas.comida_en(candidato, run.radio_actual) == null):
			piso = candidato
			break
	verificar(piso != Vector2.INF, "hay piso libre fuera de la huella original para abandonar la orden retenida")
	if piso != Vector2.INF:
		llamado.mantener_en(piso)
		llamado._actualizar_cercanas()
		verificar(llamado.objetivo_comida == null and not llamado._ids_area.has(id_mesa),
			"mover el cursor fuera de la huella de la mesa elimina el objetivo retenido")
	# Volver a material vivo y regresar al mismo hueco establece otra vez una
	# orden retenida. Una miga real creada allí debe poder reemplazarla.
	llamado.mantener_en(restante)
	llamado._actualizar_cercanas()
	llamado.mantener_en(interior)
	llamado._actualizar_cercanas()
	verificar(llamado.objetivo_comida == mesa, "se puede volver a fijar la mesa y mantenerla al recorrer su hueco")
	var tipo := run.comidas._tipo_comida("miga").duplicate(true)
	var otra := run.comidas._crear(tipo, interior, 911)
	llamado._actualizar_cercanas()
	verificar(llamado.objetivo_comida == otra and llamado._ids_area.has(otra.get_instance_id())
		and not llamado._ids_area.has(id_mesa),
		"un recurso explícito bajo el cursor reemplaza la mesa retenida; la orden no queda pegada para siempre")
	llamado.soltar()
	verificar(not llamado.activa and llamado.objetivo_comida == null and llamado._ids_area.is_empty()
		and llamado._comidas_area.is_empty(),
		"soltar borra tanto el objetivo retenido como sus candidatas compartidas")


func probar_reparto_en_frente(run: Run, mesa: PiezaCasa, celda: int, notch: Rect2i, zona: Rect2) -> void:
	var material := mesa.mordiscos
	# Otro ajuste blanco del fixture: dos pequeños escalones de 6–8 unidades
	# retroceden la pared del notch, salvo un apoyo central angosto. Desplazar
	# todos los puestos sobre una recta ahora deja algunos fuera de alcance.
	var avance := maxi(1, ceili(6.0 / material._paso.x))
	var medio_y := notch.position.y + (notch.size.y / 2 as int)
	var apoyo := maxi(1, ceili(4.0 / material._paso.y))
	var superior := Rect2i(notch.end.x, notch.position.y, avance, medio_y - apoyo - notch.position.y)
	var inferior := Rect2i(notch.end.x, medio_y + apoyo, avance, notch.end.y - medio_y - apoyo)
	material._borrar_rectangulo(celda, superior)
	material._borrar_rectangulo(celda, inferior)
	mesa.vidas[celda] = material.vida_celda(celda)
	mesa.vida = 0.0
	for hp: float in mesa.vidas:
		mesa.vida += hp
	mesa._version_material += 1
	mesa._registrar_retroceso(celda, zona.grow(material._paso.x * avance))
	mesa._process(0.2)
	while not run.cocina._cambios.is_empty():
		run.cocina.procesar_cambios(384)
	var desde := Vector2(zona.end.x - 30.0, zona.get_center().y)
	var base := mesa.punto_mordida(desde, run.radio_actual)
	var directo := base + Vector2(0, 32)
	verificar(base != Vector2.INF and run.cocina.libre(directo, Cocina.MARGEN)
		and not mesa.alcanza_contacto(directo),
		"el frente escalonado reproduce un puesto desplazado libre pero demasiado lejos del material")
	var distintos: Array[Vector2] = []
	var seguros := true
	var puestos: Array[Vector2] = []
	for i in 7:
		var punto := mesa.punto_trabajo(desde, run.radio_actual, false, i)
		puestos.append(punto)
		var limite := absf((i - 3) * 16.0) + 32.0
		seguros = seguros and punto != Vector2.INF and punto.length_squared() < pow(run.radio_actual - 6.0, 2)
		seguros = seguros and run.cocina.libre(punto, Cocina.MARGEN) and mesa.alcanza_contacto(punto)
		seguros = seguros and punto.distance_squared_to(base) <= limite * limite + 0.001
		var repetido := false
		for anterior: Vector2 in distintos:
			if anterior.distance_squared_to(punto) < 16.0:
				repetido = true
				break
		if not repetido:
			distintos.append(punto)
	verificar(distintos.size() >= 4 and seguros,
		"siete puestos sobre la mesa recortada conservan al menos cuatro posiciones separadas, próximas y con contacto real")
	verificar(puestos[5].distance_squared_to(base) > 16.0 and puestos[5] != directo,
		"el puesto sin contacto se proyecta al nuevo frente en vez de devolver a todas las hormigas a la base")
	if distintos.size() < 4 or not seguros:
		print("DIAG REPARTO base=", base, " directo=", directo, " puestos=", puestos, " distintos=", distintos.size())


func ruta_segura(cocina: Cocina, desde: Vector2, ruta: PackedVector2Array) -> bool:
	if ruta.is_empty():
		return false
	for punto: Vector2 in ruta:
		if not cocina.segmento_libre(desde, punto):
			return false
		desde = punto
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
