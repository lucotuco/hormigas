class_name EmpaquetadoAtlas
extends RefCounted
## MaxRects sin rotación: conserva los ejes del dibujo, sus UV y su material.
## Sólo calcula coordenadas al arrancar; no reserva imágenes ni texturas.
const ANCHO := 2048
const ALTO_MAXIMO := 8192
const MARGEN := 4
const SEPARACION := MARGEN * 2
const PASO_ALTO := 64


## Cada entrada contiene clave, rect, escala y escala_base. Las posiciones
## devueltas apuntan al primer texel visible, DESPUÉS del margen de cuatro.
## En un fallo no se publica un atlas parcial: medidas y posiciones vacías.
static func calcular(pendientes: Array[Dictionary], con_detalle: bool) -> Dictionary:
	var inicio := Time.get_ticks_usec()
	var elementos: Array[Dictionary] = []
	var claves := {}
	for pendiente: Dictionary in pendientes:
		var clave := String(pendiente.clave)
		var rect: Rect2 = pendiente.rect
		var escala: float = pendiente.escala if con_detalle else pendiente.escala_base
		if claves.has(clave):
			return _fallo("Clave duplicada: " + clave, inicio)
		if not rect.has_area() or not rect.size.is_finite() or not is_finite(escala) or escala <= 0.0:
			return _fallo("Medidas inválidas: " + clave, inicio)
		var tamano := Vector2i((rect.size * escala).ceil())
		var reserva := tamano + Vector2i.ONE * SEPARACION
		if reserva.x > ANCHO or reserva.y > ALTO_MAXIMO:
			return _fallo("La región supera el atlas: " + clave, inicio)
		claves[clave] = true
		elementos.append({"clave": clave, "reserva": reserva})
	var mejor: Dictionary = {}
	# Diferentes órdenes cuestan sólo CPU de arranque. Elegir el mejor evita
	# que una pieza larga condene a todos los sprites a dejar una franja vacía.
	for criterio: String in ["area", "lado", "alto"]:
		var ordenados := _ordenar(elementos, criterio)
		var resultado := _empaquetar(ordenados)
		if not resultado.exito:
			continue
		if mejor.is_empty() or resultado.medidas.y < mejor.medidas.y \
			or (resultado.medidas.y == mejor.medidas.y and resultado.alto_usado < mejor.alto_usado):
			mejor = resultado
			mejor.criterio = criterio
	if mejor.is_empty():
		return _fallo("No entra el catálogo completo en el atlas", inicio)
	mejor.tiempo_usec = Time.get_ticks_usec() - inicio
	return mejor


static func _ordenar(elementos: Array[Dictionary], criterio: String) -> Array[Dictionary]:
	var ordenados: Array[Dictionary] = []
	ordenados.assign(elementos)
	ordenados.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: Vector2i = a.reserva
		var tb: Vector2i = b.reserva
		var area_a := ta.x * ta.y
		var area_b := tb.x * tb.y
		var lado_a := maxi(ta.x, ta.y)
		var lado_b := maxi(tb.x, tb.y)
		var primero_a := area_a
		var primero_b := area_b
		if criterio == "lado":
			primero_a = lado_a
			primero_b = lado_b
		elif criterio == "alto":
			primero_a = ta.y
			primero_b = tb.y
		if primero_a != primero_b:
			return primero_a > primero_b
		if area_a != area_b:
			return area_a > area_b
		if lado_a != lado_b:
			return lado_a > lado_b
		if ta.y != tb.y:
			return ta.y > tb.y
		if ta.x != tb.x:
			return ta.x > tb.x
		return String(a.clave) < String(b.clave))
	return ordenados


static func _empaquetar(elementos: Array[Dictionary]) -> Dictionary:
	var libres: Array[Rect2i] = [Rect2i(0, 0, ANCHO, ALTO_MAXIMO)]
	var posiciones := {}
	var alto_usado := SEPARACION
	for elemento: Dictionary in elementos:
		var tamano: Vector2i = elemento.reserva
		var indice := _buscar_hueco(libres, tamano)
		if indice < 0:
			return {"exito": false}
		var ocupado := Rect2i(libres[indice].position, tamano)
		posiciones[elemento.clave] = ocupado.position + Vector2i.ONE * MARGEN
		alto_usado = maxi(alto_usado, ocupado.end.y)
		libres = _dividir(libres, ocupado)
	var alto := ceili(alto_usado / float(PASO_ALTO)) * PASO_ALTO
	return {"exito": true, "error": "", "medidas": Vector2i(ANCHO, alto),
		"posiciones": posiciones, "alto_usado": alto_usado}


static func _buscar_hueco(libres: Array[Rect2i], tamano: Vector2i) -> int:
	var mejor := -1
	var mejor_corto := 2147483647
	var mejor_largo := 2147483647
	var mejor_posicion := Vector2i(ANCHO, ALTO_MAXIMO)
	for i in libres.size():
		var libre := libres[i]
		if libre.size.x < tamano.x or libre.size.y < tamano.y:
			continue
		var resto := libre.size - tamano
		var corto := mini(resto.x, resto.y)
		var largo := maxi(resto.x, resto.y)
		# Empates estables de arriba a abajo y de izquierda a derecha. No
		# depender de claves de Dictionary ni del orden de asignación de nodos.
		if corto < mejor_corto or (corto == mejor_corto and largo < mejor_largo) \
			or (corto == mejor_corto and largo == mejor_largo and libre.position.y < mejor_posicion.y) \
			or (corto == mejor_corto and largo == mejor_largo and libre.position.y == mejor_posicion.y and libre.position.x < mejor_posicion.x):
			mejor = i
			mejor_corto = corto
			mejor_largo = largo
			mejor_posicion = libre.position
	return mejor


static func _dividir(libres: Array[Rect2i], ocupado: Rect2i) -> Array[Rect2i]:
	var conservados: Array[Rect2i] = []
	var candidatos: Array[Rect2i] = []
	for libre: Rect2i in libres:
		if not libre.intersects(ocupado):
			conservados.append(libre)
			continue
		# Los libres pueden solaparse entre sí: representan todas las
		# extensiones posibles, no una teselación que pierda esquinas útiles.
		if ocupado.position.x > libre.position.x:
			candidatos.append(Rect2i(libre.position, Vector2i(ocupado.position.x - libre.position.x, libre.size.y)))
		if ocupado.end.x < libre.end.x:
			candidatos.append(Rect2i(ocupado.end.x, libre.position.y, libre.end.x - ocupado.end.x, libre.size.y))
		if ocupado.position.y > libre.position.y:
			candidatos.append(Rect2i(libre.position, Vector2i(libre.size.x, ocupado.position.y - libre.position.y)))
		if ocupado.end.y < libre.end.y:
			candidatos.append(Rect2i(libre.position.x, ocupado.end.y, libre.size.x, libre.end.y - ocupado.end.y))
	var nuevos: Array[Rect2i] = []
	for candidato: Rect2i in candidatos:
		var contenido := false
		for libre: Rect2i in conservados:
			if libre.encloses(candidato):
				contenido = true
				break
		if contenido:
			continue
		var i := 0
		while i < nuevos.size():
			if nuevos[i].encloses(candidato):
				contenido = true
				break
			if candidato.encloses(nuevos[i]):
				nuevos.remove_at(i)
			else:
				i += 1
		if not contenido:
			nuevos.append(candidato)
	# Los conservados ya estaban podados antes de este corte. Un candidato
	# es subconjunto de un libre anterior: no puede contener un conservado
	# sin que ese mismo conservado ya hubiese estado contenido antes.
	conservados.append_array(nuevos)
	return conservados


static func _fallo(mensaje: String, inicio: int) -> Dictionary:
	return {"exito": false, "error": mensaje, "medidas": Vector2i.ZERO,
		"posiciones": {}, "alto_usado": 0, "criterio": "", "tiempo_usec": Time.get_ticks_usec() - inicio}
