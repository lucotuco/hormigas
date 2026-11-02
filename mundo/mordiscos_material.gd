class_name MordiscosMaterial
extends RefCounted
## Material rasterizado una vez por recurso, independiente del renderer.
## La máscara R8 sólo pierde píxeles. La navegación conserva sus 16 celdas.
## Una mordida local retira un único rectángulo sólido, nunca una franja global.
const MAX_CELDAS := 16
const MAX_LADO_MASCARA := 2048
const PASO_MAXIMO := 2.0
const LADO_BLOQUE := 8
static var _morton_x := PackedInt32Array()
static var _morton_y := PackedInt32Array()
static var _bits_por_byte := PackedByteArray()

var ultima_porcion := Rect2()
var _rect_mundo := Rect2()
var _grilla := Vector2i.ONE
var _cantidad_celdas := 0
var _ancho := 0
var _alto := 0
var _ancho_celda := 0
var _alto_celda := 0
var _paso := Vector2.ONE
var _area_pixel := 1.0
var _pixeles := PackedByteArray()
var _iniciales := PackedInt32Array()
var _vivos := PackedInt32Array()
var _vidas_iniciales := PackedFloat64Array()
var _hp_pixel := PackedFloat64Array()
var _credito := PackedFloat64Array()
## El trabajo ambiental en espera nunca llena el buche de otra hormiga.
var _credito_erosion := PackedFloat64Array()
var ultimo_trabajo_erosion := 0.0
var ultimo_trabajo_frente := 0.0
var _cursores_bulk := PackedInt32Array()
var _aire_bloques := PackedByteArray()
var _aire_bits := PackedInt64Array()
var _cola_aire: Array[int] = []
var _frontera_bits := PackedInt64Array()
var _frontera_arbol := PackedInt32Array()
var _frontera_celdas := PackedInt32Array()
var _deltas_frontera := PackedInt32Array()
var _frontera_sucia := PackedByteArray()
var _bloques_frontera: Array[int] = []
var _cantidad_vivos := 0
var _filas_vivas := PackedInt32Array()
var _columnas_vivas := PackedInt32Array()
var _limites_pixels: Array[Rect2i] = []
var _limites_sucios := PackedByteArray()
var tiempo_configuracion_usec := 0
var configuracion_lista := false
var max_unidad_configuracion_usec := 0
enum Preparacion { INACTIVA, RESERVA, HOJAS, RASTER, ARBOL, DATOS, AIRE_RESERVA, AIRE_BORDE, AIRE_SEMILLAS, AIRE_FLOOD, FRONTERA, FINAL }
var _prep_etapa := Preparacion.INACTIVA
var _prep_rect := Rect2()
var _prep_grilla := Vector2i.ONE
var _prep_formas: Array = []
var _prep_vidas := PackedFloat64Array()
var _prep_cursor := 0
var _prep_celda := 0
var _prep_raster := 0
var _prep_forma := 0
var _prep_banda := 0
var _prep_rectangulos: Array[Rect2i] = []
var _prep_bordes: Array[int] = []
var _prep_regiones: Array[Rect2i] = []
var _prep_region := 0
var _prep_tesela := Vector2i.ZERO

## Un árbol de bloques 8×8 acelera el contacto sin recorrer la superficie.
## A 2048² necesita como máximo 87381 contadores, no un nodo por píxel.
var _columnas_bloques := 0
var _filas_bloques := 0
var _lado_arbol := 1
var _arbol := PackedInt32Array()
var _hojas := PackedInt32Array()
var _deltas_bloque := PackedInt32Array()
var _bloques_tocados: Array[int] = []

## Espacio de consulta reutilizado: no hay arrays temporales por búsqueda.
var _consulta_desde := Vector2.ZERO
var _consulta_pixel := Vector2.ZERO
var _consulta_x0 := 0
var _consulta_y0 := 0
var _consulta_x1 := 0
var _consulta_y1 := 0
var _mejor_pixel := -1
var _mejor_distancia := INF
var _consulta_frontera := false

var _imagen: Image
var _textura: ImageTexture
var _textura_sucia := false


func configurar(rect_mundo: Rect2, grilla: Vector2i, formas_por_celda: Array, vidas_por_celda: PackedFloat64Array) -> void:
	var inicio_configuracion := Time.get_ticks_usec()
	cancelar_configuracion()
	_reservar_configuracion(rect_mundo, grilla)
	if _cantidad_celdas <= 0:
		return
	_preparar_arbol()
	for celda in _cantidad_celdas:
		if celda >= formas_por_celda.size() or celda >= vidas_por_celda.size() or vidas_por_celda[celda] <= 0:
			continue
		_rasterizar_celda(celda, formas_por_celda[celda])
		_vivos[celda] = _iniciales[celda]
		_cantidad_vivos += _vivos[celda]
		if _vivos[celda] > 0:
			_vidas_iniciales[celda] = vidas_por_celda[celda]
			_hp_pixel[celda] = vidas_por_celda[celda] / _vivos[celda]
	for nodo in range(_arbol.size() - 1, 0, -1):
		_arbol[(nodo - 1) / 4 as int] += _arbol[nodo]
	_pixeles = _imagen.get_data()
	_preparar_aire_exterior()
	_textura_sucia = true

	configuracion_lista = true
	tiempo_configuracion_usec = Time.get_ticks_usec() - inicio_configuracion


func _reservar_configuracion(rect_mundo: Rect2, grilla: Vector2i) -> void:
	tiempo_configuracion_usec = 0
	max_unidad_configuracion_usec = 0
	configuracion_lista = false
	ultima_porcion = Rect2()
	_rect_mundo = rect_mundo
	_grilla = grilla
	_cantidad_celdas = 0
	_ancho = 0
	_alto = 0
	_cantidad_vivos = 0
	_pixeles = PackedByteArray()
	_imagen = null
	_textura = null
	_textura_sucia = false
	if not rect_mundo.has_area() or not rect_mundo.position.is_finite() or not rect_mundo.size.is_finite() or grilla.x <= 0 or grilla.y <= 0 or grilla.x * grilla.y > MAX_CELDAS:
		return
	_cantidad_celdas = grilla.x * grilla.y
	# Las migas de radio cinco usan como máximo un píxel por unidad.
	# Las piezas grandes usan dos, salvo el límite absoluto de 2048 por eje.
	var paso_objetivo := minf(PASO_MAXIMO, maxf(0.25, minf(rect_mundo.size.x, rect_mundo.size.y) / 10.0))
	_ancho_celda = clampi(ceili(rect_mundo.size.x / grilla.x / paso_objetivo), 1, MAX_LADO_MASCARA / grilla.x as int)
	_alto_celda = clampi(ceili(rect_mundo.size.y / grilla.y / paso_objetivo), 1, MAX_LADO_MASCARA / grilla.y as int)
	_ancho = _ancho_celda * grilla.x
	_alto = _alto_celda * grilla.y
	_paso = rect_mundo.size / Vector2(_ancho, _alto)
	_area_pixel = float(_paso.x) * float(_paso.y)
	# El relleno inicial corre en código nativo. No visitar millones de píxeles
	# en GDScript al primer golpe de una torre o de un mueble grande.
	_imagen = Image.create(_ancho, _alto, false, Image.FORMAT_R8)
	_imagen.fill(Color.BLACK)
	_iniciales.resize(_cantidad_celdas)
	_iniciales.fill(0)
	_vivos.resize(_cantidad_celdas)
	_vivos.fill(0)
	_vidas_iniciales.resize(_cantidad_celdas)
	_vidas_iniciales.fill(0)
	_hp_pixel.resize(_cantidad_celdas)
	_hp_pixel.fill(0)
	_credito.resize(_cantidad_celdas)
	_credito.fill(0)
	_credito_erosion.resize(_cantidad_celdas)
	_credito_erosion.fill(0)
	_cursores_bulk.resize(_cantidad_celdas)
	_cursores_bulk.fill(0)
	_filas_vivas.resize(_cantidad_celdas * _alto_celda)
	_filas_vivas.fill(0)
	_columnas_vivas.resize(_cantidad_celdas * _ancho_celda)
	_columnas_vivas.fill(0)
	_limites_pixels.resize(_cantidad_celdas)
	_limites_pixels.fill(Rect2i())
	_limites_sucios.resize(_cantidad_celdas)
	_limites_sucios.fill(0)


## La cola retiene este objeto en privado; no publica estados intermedios.
func iniciar_configuracion(rect_mundo: Rect2, grilla: Vector2i, formas_por_celda: Array, vidas_por_celda: PackedFloat64Array) -> void:
	cancelar_configuracion()
	configuracion_lista = false
	_prep_rect = rect_mundo
	_prep_grilla = grilla
	_prep_formas = formas_por_celda.duplicate(true)
	_prep_vidas = vidas_por_celda.duplicate()
	_prep_cursor = 0
	_prep_celda = 0
	_prep_raster = 0
	_prep_etapa = Preparacion.RESERVA


func cancelar_configuracion() -> void:
	_prep_etapa = Preparacion.INACTIVA
	_prep_formas.clear()
	_prep_vidas = PackedFloat64Array()
	_prep_rectangulos.clear()
	_prep_bordes.clear()
	_prep_regiones.clear()


func avanzar_configuracion(unidades := 1) -> bool:
	for unidad in maxi(0, unidades):
		if _prep_etapa == Preparacion.INACTIVA:
			break
		var inicio := Time.get_ticks_usec()
		_avanzar_configuracion_unidad()
		var tiempo := Time.get_ticks_usec() - inicio
		tiempo_configuracion_usec += tiempo
		max_unidad_configuracion_usec = maxi(max_unidad_configuracion_usec, tiempo)
	return configuracion_lista


func _avanzar_configuracion_unidad() -> void:
	match _prep_etapa:
		Preparacion.RESERVA:
			_reservar_configuracion(_prep_rect, _prep_grilla)
			if _cantidad_celdas <= 0:
				_prep_etapa = Preparacion.FINAL
				return
			_reservar_arbol()
			_prep_etapa = Preparacion.HOJAS
		Preparacion.HOJAS:
			var base := (_lado_arbol * _lado_arbol - 1) / 3 as int
			var fin := mini(_prep_cursor + 256, _hojas.size())
			while _prep_cursor < fin:
				_hojas[_prep_cursor] = base + _morton_x[_prep_cursor % _columnas_bloques] + _morton_y[_prep_cursor / _columnas_bloques as int]
				_prep_cursor += 1
			if _prep_cursor == _hojas.size():
				_prep_etapa = Preparacion.RASTER
		Preparacion.RASTER:
			_avanzar_raster()
		Preparacion.ARBOL:
			var fin := maxi(0, _prep_cursor - 256)
			while _prep_cursor > fin:
				_arbol[(_prep_cursor - 1) / 4 as int] += _arbol[_prep_cursor]
				_prep_cursor -= 1
			if _prep_cursor == 0:
				_prep_etapa = Preparacion.DATOS
		Preparacion.DATOS:
			_pixeles = _imagen.get_data()
			_prep_etapa = Preparacion.AIRE_RESERVA
		Preparacion.AIRE_RESERVA:
			_reservar_aire_exterior()
			_prep_cursor = 0
			_prep_etapa = Preparacion.AIRE_BORDE
		Preparacion.AIRE_BORDE:
			var fin := mini(_ancho + _alto, _prep_cursor + 64)
			while _prep_cursor < fin:
				if _prep_cursor < _ancho:
					_marcar_frontera(_prep_cursor, 0)
					_marcar_frontera(_prep_cursor, _alto - 1)
				else:
					_marcar_frontera(0, _prep_cursor - _ancho)
					_marcar_frontera(_ancho - 1, _prep_cursor - _ancho)
				_prep_cursor += 1
			if _prep_cursor == _ancho + _alto:
				_prep_cursor = 0
				_prep_etapa = Preparacion.AIRE_SEMILLAS
		Preparacion.AIRE_SEMILLAS:
			var fin := mini(_columnas_bloques + _filas_bloques, _prep_cursor + 16)
			while _prep_cursor < fin:
				if _prep_cursor < _columnas_bloques:
					_visitar_bloque_aire(_prep_cursor, 0, 2)
					_visitar_bloque_aire(_prep_cursor, _filas_bloques - 1, 3)
				else:
					_visitar_bloque_aire(0, _prep_cursor - _columnas_bloques, 0)
					_visitar_bloque_aire(_columnas_bloques - 1, _prep_cursor - _columnas_bloques, 1)
				_prep_cursor += 1
			if _prep_cursor == _columnas_bloques + _filas_bloques:
				_prep_cursor = 0
				_prep_etapa = Preparacion.AIRE_FLOOD
		Preparacion.AIRE_FLOOD:
			for entrada in 16:
				if _prep_cursor >= _cola_aire.size():
					_cola_aire.clear()
					_prep_cursor = 0
					_prep_etapa = Preparacion.FRONTERA
					break
				_propagar_entrada(_cola_aire[_prep_cursor])
				_prep_cursor += 1
		Preparacion.FRONTERA:
			var fin := mini(_bloques_frontera.size(), _prep_cursor + 16)
			while _prep_cursor < fin:
				_aplicar_bloque_frontera(_bloques_frontera[_prep_cursor])
				_prep_cursor += 1
			if _prep_cursor == _bloques_frontera.size():
				_bloques_frontera.clear()
				_prep_etapa = Preparacion.FINAL
		Preparacion.FINAL:
			_textura_sucia = _cantidad_celdas > 0

			configuracion_lista = true
			cancelar_configuracion()


func _avanzar_raster() -> void:
	if _prep_celda >= _cantidad_celdas:
		_prep_cursor = _arbol.size() - 1
		_prep_etapa = Preparacion.ARBOL
		return
	if _prep_celda >= _prep_formas.size() or _prep_celda >= _prep_vidas.size() or _prep_vidas[_prep_celda] <= 0:
		_prep_celda += 1
		return
	if _prep_raster == 0:
		_prep_rectangulos.clear()
		_prep_bordes.clear()
		_prep_forma = 0
		_prep_raster = 1
	if _prep_raster == 1:
		var formas: Array = _prep_formas[_prep_celda]
		var fin := mini(formas.size(), _prep_forma + 32)
		var cx0 := (_prep_celda % _grilla.x) * _ancho_celda
		var cy0 := (_prep_celda / _grilla.x as int) * _alto_celda
		while _prep_forma < fin:
			var forma: Rect2 = formas[_prep_forma]
			_prep_forma += 1
			var parte := forma.intersection(_rect_mundo)
			if not parte.has_area():
				continue
			var x0 := clampi(floori((parte.position.x - _rect_mundo.position.x) / _paso.x + 0.000001), cx0, cx0 + _ancho_celda)
			var y0 := clampi(floori((parte.position.y - _rect_mundo.position.y) / _paso.y + 0.000001), cy0, cy0 + _alto_celda)
			var x1 := clampi(ceili((parte.end.x - _rect_mundo.position.x) / _paso.x - 0.000001), cx0, cx0 + _ancho_celda)
			var y1 := clampi(ceili((parte.end.y - _rect_mundo.position.y) / _paso.y - 0.000001), cy0, cy0 + _alto_celda)
			if x0 < x1 and y0 < y1:
				_prep_rectangulos.append(Rect2i(x0, y0, x1 - x0, y1 - y0))
				_prep_bordes.append(y0)
				_prep_bordes.append(y1)
		if _prep_forma == formas.size():
			_prep_raster = 2
		return
	if _prep_raster == 2:
		_ordenar_rectangulos(_prep_rectangulos)
		_prep_bordes.sort()
		_prep_banda = 0
		_prep_raster = 3
		return
	if _prep_raster == 3:
		_prep_regiones.clear()
		if _prep_banda >= _prep_bordes.size() - 1:
			_vivos[_prep_celda] = _iniciales[_prep_celda]
			_cantidad_vivos += _vivos[_prep_celda]
			if _vivos[_prep_celda] > 0:
				_vidas_iniciales[_prep_celda] = _prep_vidas[_prep_celda]
				_hp_pixel[_prep_celda] = _prep_vidas[_prep_celda] / _vivos[_prep_celda]
			_prep_celda += 1
			_prep_raster = 0
			return
		var y0 := _prep_bordes[_prep_banda]
		_prep_banda += 1
		var y1 := _prep_bordes[_prep_banda]
		if y0 >= y1:
			return
		var inicio := -1
		var fin := -1
		for rect: Rect2i in _prep_rectangulos:
			if rect.position.y > y0 or rect.end.y < y1:
				continue
			if inicio < 0:
				inicio = rect.position.x
				fin = rect.end.x
			elif rect.position.x <= fin:
				fin = maxi(fin, rect.end.x)
			else:
				_prep_regiones.append(Rect2i(inicio, y0, fin - inicio, y1 - y0))
				inicio = rect.position.x
				fin = rect.end.x
		if inicio >= 0:
			_prep_regiones.append(Rect2i(inicio, y0, fin - inicio, y1 - y0))
		_prep_region = 0
		_prep_tesela = _prep_regiones[0].position if not _prep_regiones.is_empty() else Vector2i.ZERO
		_prep_raster = 4
		return
	if _prep_region >= _prep_regiones.size():
		_prep_raster = 3
		return
	var region := _prep_regiones[_prep_region]
	var tamano := Vector2i(mini(32, region.end.x - _prep_tesela.x), mini(32, region.end.y - _prep_tesela.y))
	_rellenar_region(_prep_celda, Rect2i(_prep_tesela, tamano))
	_prep_tesela.x += tamano.x
	if _prep_tesela.x >= region.end.x:
		_prep_tesela.x = region.position.x
		_prep_tesela.y += tamano.y
	if _prep_tesela.y >= region.end.y:
		_prep_region += 1
		if _prep_region < _prep_regiones.size():
			_prep_tesela = _prep_regiones[_prep_region].position


func recortar_local(celda: int, dano: float, pos: Vector2, lado_max: float) -> float:
	ultima_porcion = Rect2()
	if not _entrada_valida(celda, dano, pos) or lado_max <= 0 or not is_finite(lado_max):
		return 0.0
	if not aire_exterior(pos):
		return 0.0
	# No desaparece HP subpíxel: se trabaja hasta desprender material entero.
	_credito[celda] = minf(vida_celda(celda), _credito[celda] + dano)
	return _extraer_frente(celda, pos, lado_max)


## Continuación explícita: retira otra porción del trabajo YA admitido. No
## acepta daño ni toca el crédito de corrosión; una llamada vacía no paga.
func recortar_local_acreditado(celda: int, pos: Vector2, lado_max: float) -> float:
	ultima_porcion = Rect2()
	if not _posicion_valida(celda, pos) or lado_max <= 0 or not is_finite(lado_max) or not aire_exterior(pos):
		return 0.0
	return _extraer_frente(celda, pos, lado_max)


func _extraer_frente(celda: int, pos: Vector2, lado_max: float, erosion := false) -> float:
	var disponibles := _pixeles_pagables(celda, erosion)
	if disponibles <= 0:
		return 0.0
	var limite_x := mini(_ancho_celda, floori(lado_max / _paso.x + 0.000001))
	var limite_y := mini(_alto_celda, floori(lado_max / _paso.y + 0.000001))
	if limite_x <= 0 or limite_y <= 0:
		return 0.0
	var semilla := _buscar_pixel(celda, pos, Rect2(), true)
	if semilla < 0 or not _contacto_visible(semilla, pos):
		return 0.0
	var sx := semilla % _ancho
	var sy := semilla / _ancho as int
	var limite_vivo := _limites_pixels[celda]
	var area_limite := limite_vivo.size.x * limite_vivo.size.y
	if limite_vivo.size.x <= limite_x and limite_vivo.size.y <= limite_y and area_limite == _vivos[celda] and area_limite <= disponibles:
		# Una pieza chica completa no debe dividirse por elegir como semilla
		# el centro de un borde. El conteo demuestra que el AABB es sólido.
		_borrar_rectangulo(celda, limite_vivo, Vector2i(sx, sy))
		ultima_porcion = _rect_pixels(limite_vivo)
		var completo := area_limite * _hp_pixel[celda]
		_descontar_credito(celda, completo, erosion)
		return completo
	var cx0 := (celda % _grilla.x) * _ancho_celda
	var cy0 := (celda / _grilla.x as int) * _alto_celda
	var cx1 := cx0 + _ancho_celda
	var cy1 := cy0 + _alto_celda
	var centro := _rect_pixel(sx, sy).get_center()
	var preferido_x := 1 if pos.x <= centro.x else -1
	var preferido_y := 1 if pos.y <= centro.y else -1
	var mejor := Rect2i(sx, sy, 1, 1)
	var mejor_area := 1
	var maximo := mini(disponibles, limite_x * limite_y)
	# Cuatro esquinas posibles; como máximo 4×ceil(lado/paso)² lecturas.
	# Todas las filas de la porción son sólidas, incluso alrededor de huecos.
	for orientacion in 4:
		var dx := preferido_x if (orientacion & 1) == 0 else -preferido_x
		var dy := preferido_y if (orientacion & 2) == 0 else -preferido_y
		var ancho_valido := limite_x
		for fila in limite_y:
			var y := sy + fila * dy
			if y < cy0 or y >= cy1:
				break
			var ancho_fila := 0
			for columna in ancho_valido:
				var x := sx + columna * dx
				if x < cx0 or x >= cx1 or _pixeles[y * _ancho + x] == 0:
					break
				ancho_fila += 1
			ancho_valido = mini(ancho_valido, ancho_fila)
			if ancho_valido <= 0:
				break
			var alto := fila + 1
			var ancho := mini(ancho_valido, disponibles / alto as int)
			var area := ancho * alto
			if area > mejor_area:
				mejor_area = area
				mejor = Rect2i(mini(sx, sx + (ancho - 1) * dx), mini(sy, y), ancho, alto)
			if mejor_area >= maximo:
				break
		if mejor_area >= maximo:
			break
	_borrar_rectangulo(celda, mejor, Vector2i(sx, sy))
	ultima_porcion = _rect_pixels(mejor)
	var retirado := mejor_area * _hp_pixel[celda]
	_descontar_credito(celda, retirado, erosion)
	return retirado


func _descontar_credito(celda: int, cantidad: float, erosion: bool) -> void:
	if erosion:
		_credito_erosion[celda] = maxf(0, _credito_erosion[celda] - cantidad)
	else:
		_credito[celda] = maxf(0, _credito[celda] - cantidad)


## Una sola porción por servicio de la cola; reanudar con daño0 no reacredita.
func recortar_frente_paso(celda: int, dano: float, pos: Vector2, lado_max := 16.0) -> float:
	ultima_porcion = Rect2()
	ultimo_trabajo_erosion = 0
	if not configuracion_lista or celda < 0 or celda >= _cantidad_celdas or _vivos[celda] <= 0 or dano < 0 or not is_finite(dano) or not pos.is_finite() or lado_max <= 0 or not is_finite(lado_max):
		return 0
	var credito := minf(vida_celda(celda), _credito_erosion[celda] + dano)
	ultimo_trabajo_erosion = maxf(0, credito - _credito_erosion[celda])
	_credito_erosion[celda] = credito
	var origen := pos if aire_exterior(pos) else origen_exterior(celda, pos)
	return _extraer_frente(celda, origen, lado_max, true)


func erosion_pagable(celda: int) -> bool:
	return celda >= 0 and celda < _cantidad_celdas and _vivos[celda] > 0 and _pixeles_pagables(celda, true) > 0


func recortar(celda: int, dano: float, pos: Vector2) -> float:
	## Compatibilidad de eventos: no impone el tamaño de la mandíbula.
	return recortar_bulk(celda, dano, pos)


func recortar_bulk(celda: int, dano: float, pos: Vector2) -> float:
	ultima_porcion = Rect2()
	if not _entrada_valida(celda, dano, pos):
		return 0.0
	_credito[celda] = minf(vida_celda(celda), _credito[celda] + dano)
	var pendientes := _pixeles_pagables(celda)
	if pendientes <= 0:
		return 0.0
	if pendientes >= _vivos[celda]:
		# El golpe letal sigue siendo lineal, sin miles de búsquedas por píxel.
		var porcion := limites_celda(celda)
		var retirado := vida_celda(celda)
		limpiar_celda(celda)
		ultima_porcion = porcion
		return retirado
	return _recortar_frente_acreditado(celda, pos, 16.0)


func recortar_frente(celda: int, dano: float, pos: Vector2, lado_max := 16.0) -> float:
	## Corrosión: ni un presupuesto letal saltea la frontera exterior.
	ultima_porcion = Rect2()
	ultimo_trabajo_frente = 0
	if not _entrada_valida(celda, dano, pos) or lado_max <= 0 or not is_finite(lado_max):
		return 0.0
	var credito := minf(vida_celda(celda), _credito[celda] + dano)
	ultimo_trabajo_frente = maxf(0, credito - _credito[celda])
	_credito[celda] = credito
	return _recortar_frente_acreditado(celda, pos, lado_max)


func _recortar_frente_acreditado(celda: int, pos: Vector2, lado_max: float) -> float:
	# Corrosión/eventos parciales avanzan por un frente exterior consistente,
	# no por un cursor que empezaba en la esquina de una celda interior.
	var retirado := 0.0
	var porcion_total := Rect2()
	var origen := pos if aire_exterior(pos) else origen_exterior(celda, pos)
	while _pixeles_pagables(celda) > 0:
		var parte := _extraer_frente(celda, origen, lado_max)
		if parte <= 0:
			break
		retirado += parte
		porcion_total = ultima_porcion if not porcion_total.has_area() else porcion_total.merge(ultima_porcion)
	# Diagnóstico del daño ambiental, no un retazo transportable: abarca
	# TODO lo retirado por esta operación, aunque haya varias porciones.
	ultima_porcion = porcion_total
	return retirado


func limpiar_celda(celda: int) -> void:
	ultima_porcion = Rect2()
	if not configuracion_lista or celda < 0 or celda >= _cantidad_celdas or _vivos[celda] <= 0:
		return
	var origen := Vector2i((celda % _grilla.x) * _ancho_celda, (celda / _grilla.x as int) * _alto_celda)
	_borrar_rectangulo(celda, Rect2i(origen, Vector2i(_ancho_celda, _alto_celda)))
	_credito[celda] = 0
	_credito_erosion[celda] = 0


func vida_celda(celda: int) -> float:
	if not configuracion_lista or celda < 0 or celda >= _cantidad_celdas or _iniciales[celda] <= 0:
		return 0.0
	return _vidas_iniciales[celda] * (float(_vivos[celda]) / _iniciales[celda])


func area_celda(celda: int) -> float:
	return _vivos[celda] * _area_pixel if configuracion_lista and celda >= 0 and celda < _cantidad_celdas else 0.0


func area_total() -> float:
	return _cantidad_vivos * _area_pixel if configuracion_lista else 0.0


func limites_celda(celda: int) -> Rect2:
	## Conservador: las cavidades siguen sólidas hasta vaciar una hilera.
	## Consulta O(1); los contadores se mantienen solamente al retirar material.
	if not configuracion_lista or celda < 0 or celda >= _cantidad_celdas or _vivos[celda] <= 0:
		return Rect2()
	return _rect_pixels(_limites_pixels[celda])


func contiene(pos: Vector2) -> bool:
	if not configuracion_lista or _ancho <= 0 or not pos.is_finite() or not _rect_mundo.has_point(pos):
		return false
	var p := (pos - _rect_mundo.position) / _paso
	var x := clampi(floori(p.x), 0, _ancho - 1)
	var y := clampi(floori(p.y), 0, _alto - 1)
	return _pixeles[y * _ancho + x] != 0


func punto_celda(celda: int, pos: Vector2) -> Vector2:
	var pixel := _buscar_pixel(celda, pos)
	if pixel < 0:
		return Vector2.INF
	var rect := _rect_pixel(pixel % _ancho, pixel / _ancho as int)
	# El resultado pertenece al material, no al extremo abierto de Rect2.
	return pos.clamp(rect.position + _paso * 0.0001, rect.end - _paso * 0.0001)


func punto_frontera(celda: int, pos: Vector2) -> Vector2:
	if not aire_exterior(pos):
		return Vector2.INF
	var pixel := _buscar_pixel(celda, pos, Rect2(), true)
	if pixel < 0 or not _contacto_visible(pixel, pos):
		return Vector2.INF
	var rect := _rect_pixel(pixel % _ancho, pixel / _ancho as int)
	return pos.clamp(rect.position + _paso * 0.0001, rect.end - _paso * 0.0001)


func _contacto_visible(pixel: int, desde: Vector2) -> bool:
	# DDA sólo por intento de extracción/contacto. El primer material sobre
	# el segmento debe ser la frontera elegida, no una celda oculta detrás.
	var destino := _rect_pixel(pixel % _ancho, pixel / _ancho as int).get_center()
	var origen := (desde - _rect_mundo.position) / _paso
	var fin := (destino - _rect_mundo.position) / _paso
	var direccion := fin - origen
	var entrada := 0.0
	var salida := 1.0
	for eje in 2:
		if absf(direccion[eje]) < 0.0000001:
			if origen[eje] < 0 or origen[eje] > (_ancho if eje == 0 else _alto):
				return false
			continue
		var a := -origen[eje] / direccion[eje]
		var b := (float(_ancho if eje == 0 else _alto) - origen[eje]) / direccion[eje]
		entrada = maxf(entrada, minf(a, b))
		salida = minf(salida, maxf(a, b))
	if entrada > salida:
		return false
	var p := origen + direccion * minf(1.0, entrada + 0.0000001)
	var x := clampi(floori(p.x), 0, _ancho - 1)
	var y := clampi(floori(p.y), 0, _alto - 1)
	var dx := 1 if direccion.x > 0 else -1
	var dy := 1 if direccion.y > 0 else -1
	var delta_x := absf(1.0 / direccion.x) if absf(direccion.x) > 0.0000001 else INF
	var delta_y := absf(1.0 / direccion.y) if absf(direccion.y) > 0.0000001 else INF
	var proximo_x := (float(x + 1 if dx > 0 else x) - origen.x) / direccion.x if delta_x != INF else INF
	var proximo_y := (float(y + 1 if dy > 0 else y) - origen.y) / direccion.y if delta_y != INF else INF
	for paso in _ancho + _alto + 1:
		if x < 0 or y < 0 or x >= _ancho or y >= _alto:
			return false
		var actual := y * _ancho + x
		if _pixeles[actual] != 0:
			return actual == pixel
		if proximo_x < proximo_y:
			x += dx
			proximo_x += delta_x
		else:
			y += dy
			proximo_y += delta_y
	return false


func origen_exterior(celda: int, desde: Vector2) -> Vector2:
	var limite := limites_celda(celda)
	if not limite.has_area():
		return Vector2.INF
	# Fuera del rectángulo global, no sólo fuera de la celda lógica elegida.
	var candidatos: Array[Vector2] = [
		Vector2(_rect_mundo.position.x - _paso.x, clampf(desde.y, limite.position.y, limite.end.y)),
		Vector2(_rect_mundo.end.x + _paso.x, clampf(desde.y, limite.position.y, limite.end.y)),
		Vector2(clampf(desde.x, limite.position.x, limite.end.x), _rect_mundo.position.y - _paso.y),
		Vector2(clampf(desde.x, limite.position.x, limite.end.x), _rect_mundo.end.y + _paso.y)]
	var mejor := candidatos[0]
	for candidato in candidatos:
		if desde.distance_squared_to(candidato) < desde.distance_squared_to(mejor):
			mejor = candidato
	return mejor


func punto_en_zona(celda: int, pos: Vector2, zona: Rect2) -> Vector2:
	## Consulta de frontera al elegir puesto: el árbol descarta el resto.
	if not zona.has_area():
		return Vector2.INF
	var pixel := _buscar_pixel(celda, pos, zona)
	if pixel < 0:
		return Vector2.INF
	var rect := _rect_pixel(pixel % _ancho, pixel / _ancho as int)
	return pos.clamp(rect.position + _paso * 0.0001, rect.end - _paso * 0.0001)


func material_cercano(pos: Vector2) -> Vector2:
	var mejor := Vector2.INF
	var menor := INF
	for celda in _cantidad_celdas:
		var punto := punto_celda(celda, pos)
		if punto == Vector2.INF:
			continue
		var distancia := pos.distance_squared_to(punto)
		if distancia < menor:
			menor = distancia
			mejor = punto
	return mejor


func textura_mascara() -> Texture2D:
	if not configuracion_lista or _ancho <= 0 or _alto <= 0:
		return null
	if _textura == null:
		_imagen.set_data(_ancho, _alto, false, Image.FORMAT_R8, _pixeles)
		_textura = ImageTexture.create_from_image(_imagen)
		_textura_sucia = false
	return _textura


func actualizar_textura() -> void:
	## El dueño agrupa esta llamada a 12,5 Hz; cero uploads si no hubo cortes.
	if not _textura_sucia or _textura == null:
		return
	_imagen.set_data(_ancho, _alto, false, Image.FORMAT_R8, _pixeles)
	_textura.update(_imagen)
	_textura_sucia = false


func bytes_mascara_cpu() -> int:
	return _pixeles.size()


func tamano_mascara() -> Vector2i:
	return Vector2i(_ancho, _alto)


func aire_exterior(pos: Vector2) -> bool:
	if not configuracion_lista or not pos.is_finite() or _ancho <= 0:
		return false
	if not _rect_mundo.has_point(pos):
		return true
	var p := (pos - _rect_mundo.position) / _paso
	return _aire_conocido(clampi(floori(p.x), 0, _ancho - 1), clampi(floori(p.y), 0, _alto - 1))


func _aire_conocido(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= _ancho or y >= _alto:
		return true
	if _pixeles[y * _ancho + x] != 0:
		return false
	var bloque := (y / LADO_BLOQUE as int) * _columnas_bloques + (x / LADO_BLOQUE as int)
	return _aire_bloques[bloque] != 0 or (_aire_bits[bloque] & (1 << ((y % LADO_BLOQUE) * LADO_BLOQUE + x % LADO_BLOQUE))) != 0


func _frontera_exterior(x: int, y: int) -> bool:
	return _aire_conocido(x - 1, y) or _aire_conocido(x + 1, y) or _aire_conocido(x, y - 1) or _aire_conocido(x, y + 1)


func _preparar_aire_exterior() -> void:
	_reservar_aire_exterior()
	for x in _ancho:
		_marcar_frontera(x, 0)
		_marcar_frontera(x, _alto - 1)
	for y in _alto:
		_marcar_frontera(0, y)
		_marcar_frontera(_ancho - 1, y)
	for x in _columnas_bloques:
		_visitar_bloque_aire(x, 0, 2)
		_visitar_bloque_aire(x, _filas_bloques - 1, 3)
	for y in _filas_bloques:
		_visitar_bloque_aire(0, y, 0)
		_visitar_bloque_aire(_columnas_bloques - 1, y, 1)
	_propagar_aire()


func _reservar_aire_exterior() -> void:
	_aire_bloques.resize(_hojas.size())
	_aire_bloques.fill(0)
	_aire_bits.resize(_hojas.size())
	_aire_bits.fill(0)
	_frontera_bits.resize(_hojas.size())
	_frontera_bits.fill(0)
	_frontera_arbol.resize(_arbol.size())
	_frontera_arbol.fill(0)
	_frontera_celdas.resize(_cantidad_celdas)
	_frontera_celdas.fill(0)
	_deltas_frontera.resize(_hojas.size())
	_deltas_frontera.fill(0)
	_frontera_sucia.resize(_hojas.size())
	_frontera_sucia.fill(0)
	_bloques_frontera.clear()
	_cola_aire.clear()


func _marcar_aire(x: int, y: int) -> void:
	if x < 0 or y < 0 or x >= _ancho or y >= _alto or _pixeles[y * _ancho + x] != 0:
		return
	var bloque := (y / LADO_BLOQUE as int) * _columnas_bloques + (x / LADO_BLOQUE as int)
	if _aire_bloques[bloque] != 0:
		return
	if _arbol[_hojas[bloque]] == 0:
		_aire_bloques[bloque] = 1
		_cola_aire.append(-bloque - 1)
		return
	var bit := 1 << ((y % LADO_BLOQUE) * LADO_BLOQUE + x % LADO_BLOQUE)
	if (_aire_bits[bloque] & bit) == 0:
		_aire_bits[bloque] |= bit
		_cola_aire.append(y * _ancho + x)


func _visitar_bloque_aire(bx: int, by: int, lado: int) -> void:
	if bx < 0 or by < 0 or bx >= _columnas_bloques or by >= _filas_bloques:
		return
	var bloque := by * _columnas_bloques + bx
	if _aire_bloques[bloque] != 0:
		return
	if _arbol[_hojas[bloque]] == 0:
		_aire_bloques[bloque] = 1
		_cola_aire.append(-bloque - 1)
		return
	var x0 := bx * LADO_BLOQUE
	var y0 := by * LADO_BLOQUE
	var x1 := mini(x0 + LADO_BLOQUE, _ancho)
	var y1 := mini(y0 + LADO_BLOQUE, _alto)
	# El conteo exacto del árbol demuestra que ningún píxel puede recibir
	# aire. Evitar ocho llamadas por lado también durante la preparación.
	if _arbol[_hojas[bloque]] == (x1 - x0) * (y1 - y0):
		return
	if lado <= 1:
		var x := x0 if lado == 0 else x1 - 1
		for y in range(y0, y1):
			_marcar_aire(x, y)
	else:
		var y := y0 if lado == 2 else y1 - 1
		for x in range(x0, x1):
			_marcar_aire(x, y)


func _propagar_aire() -> void:
	# Cada píxel parcial/bloque vacío se descubre una sola vez en toda la vida
	# del recurso. Un bocado sólo propaga aire recién abierto, nunca por frame.
	var cursor := 0
	while cursor < _cola_aire.size():
		_propagar_entrada(_cola_aire[cursor])
		cursor += 1
	_cola_aire.clear()
	_aplicar_frontera()


func _propagar_entrada(entrada: int) -> void:
	if entrada < 0:
		var bloque := -entrada - 1
		var bx := bloque % _columnas_bloques
		var by := bloque / _columnas_bloques as int
		_visitar_bloque_aire(bx - 1, by, 1)
		_visitar_bloque_aire(bx + 1, by, 0)
		_visitar_bloque_aire(bx, by - 1, 3)
		_visitar_bloque_aire(bx, by + 1, 2)
		var x0 := bx * LADO_BLOQUE
		var y0 := by * LADO_BLOQUE
		var x1 := mini(x0 + LADO_BLOQUE, _ancho)
		var y1 := mini(y0 + LADO_BLOQUE, _alto)
		# Entre bloques vacíos no puede haber material. Misma conectividad
		# y orden que el flood síncrono, interrumpible después de cada entrada.
		if bx > 0 and _arbol[_hojas[bloque - 1]] > 0:
			for y in range(y0, y1):
				_marcar_frontera(x0 - 1, y)
		if bx + 1 < _columnas_bloques and _arbol[_hojas[bloque + 1]] > 0:
			for y in range(y0, y1):
				_marcar_frontera(x1, y)
		if by > 0 and _arbol[_hojas[bloque - _columnas_bloques]] > 0:
			for x in range(x0, x1):
				_marcar_frontera(x, y0 - 1)
		if by + 1 < _filas_bloques and _arbol[_hojas[bloque + _columnas_bloques]] > 0:
			for x in range(x0, x1):
				_marcar_frontera(x, y1)
	else:
		var x := entrada % _ancho
		var y := entrada / _ancho as int
		_marcar_aire(x - 1, y)
		_marcar_aire(x + 1, y)
		_marcar_aire(x, y - 1)
		_marcar_aire(x, y + 1)
		_marcar_frontera(x - 1, y)
		_marcar_frontera(x + 1, y)
		_marcar_frontera(x, y - 1)
		_marcar_frontera(x, y + 1)


func _marcar_frontera(x: int, y: int) -> void:
	if x < 0 or y < 0 or x >= _ancho or y >= _alto or _pixeles[y * _ancho + x] == 0:
		return
	var bloque := (y / LADO_BLOQUE as int) * _columnas_bloques + (x / LADO_BLOQUE as int)
	var bit := 1 << ((y % LADO_BLOQUE) * LADO_BLOQUE + x % LADO_BLOQUE)
	if (_frontera_bits[bloque] & bit) != 0:
		return
	_frontera_bits[bloque] |= bit
	_frontera_celdas[(y / _alto_celda as int) * _grilla.x + (x / _ancho_celda as int)] += 1
	if _frontera_sucia[bloque] == 0:
		_frontera_sucia[bloque] = 1
		_bloques_frontera.append(bloque)
	_deltas_frontera[bloque] += 1


func _aplicar_frontera() -> void:
	for bloque in _bloques_frontera:
		_aplicar_bloque_frontera(bloque)
	_bloques_frontera.clear()


func _aplicar_bloque_frontera(bloque: int) -> void:
	var delta := _deltas_frontera[bloque]
	_deltas_frontera[bloque] = 0
	_frontera_sucia[bloque] = 0
	var nodo := _hojas[bloque]
	while true:
		_frontera_arbol[nodo] += delta
		if nodo == 0:
			break
		nodo = (nodo - 1) / 4 as int


func _entrada_valida(celda: int, dano: float, pos: Vector2) -> bool:
	return _posicion_valida(celda, pos) and dano > 0 and is_finite(dano)


func _posicion_valida(celda: int, pos: Vector2) -> bool:
	return configuracion_lista and celda >= 0 and celda < _cantidad_celdas and _vivos[celda] > 0 and pos.is_finite()


func _pixeles_pagables(celda: int, erosion := false) -> int:
	# La tolerancia es relativa al tamaño del píxel, nunca un HP absoluto.
	var cociente := (_credito_erosion[celda] if erosion else _credito[celda]) / _hp_pixel[celda]
	return mini(_vivos[celda], floori(cociente + minf(0.000001, absf(cociente) * 0.0000000001)))


func _rect_pixel(x: int, y: int) -> Rect2:
	return Rect2(_rect_mundo.position + Vector2(x, y) * _paso, _paso)


func _rect_pixels(rect: Rect2i) -> Rect2:
	return Rect2(_rect_mundo.position + Vector2(rect.position) * _paso, Vector2(rect.size) * _paso)


func _borrar_rectangulo(celda: int, rect: Rect2i, semilla := Vector2i(-1, -1)) -> void:
	var frentes: Array[int] = []
	if semilla.x >= 0 and rect.size.x * rect.size.y >= 32:
		# _extraer_frente ya demostró que TODO este rectángulo está sólido.
		# Sólo agrupar su mantenimiento: mismos píxeles, semilla y flood.
		_borrar_solido(celda, rect)
	else:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if _pixeles[y * _ancho + x] != 0:
					if semilla.x < 0 and _frontera_exterior(x, y):
						frentes.append(y * _ancho + x)
					_borrar_pixel(celda, x, y)
	_aplicar_bloques()
	_actualizar_limites(celda)
	if semilla.x >= 0:
		_marcar_aire(semilla.x, semilla.y)
	else:
		for indice in frentes:
			_marcar_aire(indice % _ancho, indice / _ancho as int)
	_propagar_aire()


func _borrar_solido(celda: int, rect: Rect2i) -> void:
	var area := rect.size.x * rect.size.y
	_vivos[celda] -= area
	_cantidad_vivos -= area
	var fila_base := celda * _alto_celda - (celda / _grilla.x as int) * _alto_celda
	var columna_base := celda * _ancho_celda - (celda % _grilla.x) * _ancho_celda
	for y in range(rect.position.y, rect.end.y):
		_filas_vivas[fila_base + y] -= rect.size.x
		if _filas_vivas[fila_base + y] == 0:
			_limites_sucios[celda] = 1
		var indice := y * _ancho + rect.position.x
		var fin := indice + rect.size.x
		while indice + 8 <= fin:
			_pixeles.encode_u64(indice, 0)
			indice += 8
		while indice < fin:
			_pixeles[indice] = 0
			indice += 1
	for x in range(rect.position.x, rect.end.x):
		_columnas_vivas[columna_base + x] -= rect.size.y
		if _columnas_vivas[columna_base + x] == 0:
			_limites_sucios[celda] = 1
	for by in range(rect.position.y / LADO_BLOQUE as int, (rect.end.y - 1) / LADO_BLOQUE as int + 1):
		var y0 := maxi(rect.position.y, by * LADO_BLOQUE)
		var y1 := mini(rect.end.y, (by + 1) * LADO_BLOQUE)
		for bx in range(rect.position.x / LADO_BLOQUE as int, (rect.end.x - 1) / LADO_BLOQUE as int + 1):
			var x0 := maxi(rect.position.x, bx * LADO_BLOQUE)
			var ancho := mini(rect.end.x, (bx + 1) * LADO_BLOQUE) - x0
			var bloque := by * _columnas_bloques + bx
			var fila_bits := ((1 << ancho) - 1) << (x0 % LADO_BLOQUE)
			var mascara := 0
			var frontera_retirada := 0
			for y in range(y0, y1):
				var desplazamiento := (y % LADO_BLOQUE) * LADO_BLOQUE
				mascara |= fila_bits << desplazamiento
				frontera_retirada += _bits_por_byte[(_frontera_bits[bloque] >> desplazamiento) & fila_bits]
			if frontera_retirada > 0:
				_frontera_bits[bloque] &= ~mascara
				_frontera_celdas[celda] -= frontera_retirada
				if _frontera_sucia[bloque] == 0:
					_frontera_sucia[bloque] = 1
					_bloques_frontera.append(bloque)
				_deltas_frontera[bloque] -= frontera_retirada
			if _deltas_bloque[bloque] == 0:
				_bloques_tocados.append(bloque)
			_deltas_bloque[bloque] += ancho * (y1 - y0)
	_textura_sucia = true


func _borrar_pixel(celda: int, x: int, y: int) -> void:
	_pixeles[y * _ancho + x] = 0
	_vivos[celda] -= 1
	_cantidad_vivos -= 1
	var fila := celda * _alto_celda + y - (celda / _grilla.x as int) * _alto_celda
	var columna := celda * _ancho_celda + x - (celda % _grilla.x) * _ancho_celda
	_filas_vivas[fila] -= 1
	_columnas_vivas[columna] -= 1
	if _filas_vivas[fila] == 0 or _columnas_vivas[columna] == 0:
		_limites_sucios[celda] = 1
	var bloque := (y / LADO_BLOQUE as int) * _columnas_bloques + (x / LADO_BLOQUE as int)
	var bit := 1 << ((y % LADO_BLOQUE) * LADO_BLOQUE + x % LADO_BLOQUE)
	if (_frontera_bits[bloque] & bit) != 0:
		_frontera_bits[bloque] &= ~bit
		_frontera_celdas[celda] -= 1
		if _frontera_sucia[bloque] == 0:
			_frontera_sucia[bloque] = 1
			_bloques_frontera.append(bloque)
		_deltas_frontera[bloque] -= 1
	if _deltas_bloque[bloque] == 0:
		_bloques_tocados.append(bloque)
	_deltas_bloque[bloque] += 1
	_textura_sucia = true


func _actualizar_limites(celda: int) -> void:
	if _limites_sucios[celda] == 0:
		return
	_limites_sucios[celda] = 0
	if _vivos[celda] <= 0:
		_limites_pixels[celda] = Rect2i()
		return
	var limite := _limites_pixels[celda]
	var x0 := limite.position.x
	var y0 := limite.position.y
	var x1 := limite.end.x
	var y1 := limite.end.y
	var origen_x := (celda % _grilla.x) * _ancho_celda
	var origen_y := (celda / _grilla.x as int) * _alto_celda
	var columna_base := celda * _ancho_celda - origen_x
	var fila_base := celda * _alto_celda - origen_y
	# Cada extremo sólo avanza; una hilera ya descartada no vuelve a recorrerse.
	while x0 < x1 and _columnas_vivas[columna_base + x0] == 0:
		x0 += 1
	while x1 > x0 and _columnas_vivas[columna_base + x1 - 1] == 0:
		x1 -= 1
	while y0 < y1 and _filas_vivas[fila_base + y0] == 0:
		y0 += 1
	while y1 > y0 and _filas_vivas[fila_base + y1 - 1] == 0:
		y1 -= 1
	_limites_pixels[celda] = Rect2i(x0, y0, x1 - x0, y1 - y0)


func _rasterizar_celda(celda: int, formas: Array) -> void:
	var cx0 := (celda % _grilla.x) * _ancho_celda
	var cy0 := (celda / _grilla.x as int) * _alto_celda
	var rectangulos: Array[Rect2i] = []
	var bordes_y: Array[int] = []
	for forma: Rect2 in formas:
		var parte := forma.intersection(_rect_mundo)
		if not parte.has_area():
			continue
		# Conservar toda forma con área, incluso una banda más fina que un
		# píxel: perderla descartaría también la resistencia de su celda.
		var x0 := clampi(floori((parte.position.x - _rect_mundo.position.x) / _paso.x + 0.000001), cx0, cx0 + _ancho_celda)
		var y0 := clampi(floori((parte.position.y - _rect_mundo.position.y) / _paso.y + 0.000001), cy0, cy0 + _alto_celda)
		var x1 := clampi(ceili((parte.end.x - _rect_mundo.position.x) / _paso.x - 0.000001), cx0, cx0 + _ancho_celda)
		var y1 := clampi(ceili((parte.end.y - _rect_mundo.position.y) / _paso.y - 0.000001), cy0, cy0 + _alto_celda)
		if x0 >= x1 or y0 >= y1:
			continue
		rectangulos.append(Rect2i(x0, y0, x1 - x0, y1 - y0))
		bordes_y.append(y0)
		bordes_y.append(y1)
	if rectangulos.is_empty():
		return
	if rectangulos.size() == 1:
		_rellenar_region(celda, rectangulos[0])
		return
	# Unión exacta por bandas, incluso si el llamador entrega formas solapadas.
	# El trabajo depende de las formas/bordes, nunca del área del mueble.
	_ordenar_rectangulos(rectangulos)
	bordes_y.sort()
	for banda in range(bordes_y.size() - 1):
		var y0 := bordes_y[banda]
		var y1 := bordes_y[banda + 1]
		if y0 >= y1:
			continue
		var inicio := -1
		var fin := -1
		for rect: Rect2i in rectangulos:
			if rect.position.y > y0 or rect.end.y < y1:
				continue
			if inicio < 0:
				inicio = rect.position.x
				fin = rect.end.x
			elif rect.position.x <= fin:
				fin = maxi(fin, rect.end.x)
			else:
				_rellenar_region(celda, Rect2i(inicio, y0, fin - inicio, y1 - y0))
				inicio = rect.position.x
				fin = rect.end.x
		if inicio >= 0:
			_rellenar_region(celda, Rect2i(inicio, y0, fin - inicio, y1 - y0))


func _ordenar_rectangulos(rectangulos: Array[Rect2i]) -> void:
	rectangulos.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.position.x < b.position.x)


func _rellenar_region(celda: int, rect: Rect2i) -> void:
	_imagen.fill_rect(rect, Color.WHITE)
	_iniciales[celda] += rect.size.x * rect.size.y
	_limites_pixels[celda] = _limites_pixels[celda].merge(rect) if _limites_pixels[celda].has_area() else rect
	var origen_x := (celda % _grilla.x) * _ancho_celda
	var origen_y := (celda / _grilla.x as int) * _alto_celda
	var fila_base := celda * _alto_celda - origen_y
	var columna_base := celda * _ancho_celda - origen_x
	for y in range(rect.position.y, rect.end.y):
		_filas_vivas[fila_base + y] += rect.size.x
	for x in range(rect.position.x, rect.end.x):
		_columnas_vivas[columna_base + x] += rect.size.y
	var bx0 := rect.position.x / LADO_BLOQUE as int
	var by0 := rect.position.y / LADO_BLOQUE as int
	var bx1 := (rect.end.x - 1) / LADO_BLOQUE as int
	var by1 := (rect.end.y - 1) / LADO_BLOQUE as int
	for by in range(by0, by1 + 1):
		var alto := mini(rect.end.y, (by + 1) * LADO_BLOQUE) - maxi(rect.position.y, by * LADO_BLOQUE)
		for bx in range(bx0, bx1 + 1):
			var ancho := mini(rect.end.x, (bx + 1) * LADO_BLOQUE) - maxi(rect.position.x, bx * LADO_BLOQUE)
			_arbol[_hojas[by * _columnas_bloques + bx]] += ancho * alto


func _aplicar_bloques() -> void:
	for bloque in _bloques_tocados:
		var delta := _deltas_bloque[bloque]
		var nodo := _hojas[bloque]
		while true:
			_arbol[nodo] -= delta
			if nodo == 0:
				break
			nodo = (nodo - 1) / 4 as int
		_deltas_bloque[bloque] = 0
	_bloques_tocados.clear()


func _preparar_arbol() -> void:
	_reservar_arbol()
	var base_hojas := (_lado_arbol * _lado_arbol - 1) / 3 as int
	for y in _filas_bloques:
		var fila := y * _columnas_bloques
		var base_fila := base_hojas + _morton_y[y]
		for x in _columnas_bloques:
			_hojas[fila + x] = base_fila + _morton_x[x]


func _reservar_arbol() -> void:
	_columnas_bloques = ceili(float(_ancho) / LADO_BLOQUE)
	_filas_bloques = ceili(float(_alto) / LADO_BLOQUE)
	_lado_arbol = 1
	while _lado_arbol < maxi(_columnas_bloques, _filas_bloques):
		_lado_arbol *= 2
	_arbol.resize((_lado_arbol * _lado_arbol * 4 - 1) / 3 as int)
	_arbol.fill(0)
	_hojas.resize(_columnas_bloques * _filas_bloques)
	_deltas_bloque.resize(_hojas.size())
	_deltas_bloque.fill(0)
	_bloques_tocados.clear()
	if _morton_x.is_empty():
		_preparar_codigos_morton()


static func _preparar_codigos_morton() -> void:
	# 2048 / 8 = 256 posiciones: basta intercalar los ocho bits inferiores.
	# Son dos tablas compartidas de 1 KiB, no ocho pasos por cada hoja/mueble.
	var cantidad := MAX_LADO_MASCARA / LADO_BLOQUE as int
	_morton_x.resize(cantidad)
	_morton_y.resize(cantidad)
	_bits_por_byte.resize(256)
	_bits_por_byte[0] = 0
	for i in cantidad:
		var codigo := i
		codigo = (codigo | (codigo << 4)) & 0x0f0f
		codigo = (codigo | (codigo << 2)) & 0x3333
		codigo = (codigo | (codigo << 1)) & 0x5555
		_morton_x[i] = codigo
		_morton_y[i] = codigo << 1
		_bits_por_byte[i] = _bits_por_byte[i >> 1] + (i & 1)


func _buscar_pixel(celda: int, pos: Vector2, zona := Rect2(), solo_frontera := false) -> int:
	if not configuracion_lista or celda < 0 or celda >= _cantidad_celdas or _vivos[celda] <= 0 or not pos.is_finite():
		return -1
	if solo_frontera and _frontera_celdas[celda] <= 0:
		return -1
	_consulta_desde = pos
	_consulta_pixel = (pos - _rect_mundo.position) / _paso
	_consulta_frontera = solo_frontera
	_consulta_x0 = (celda % _grilla.x) * _ancho_celda
	_consulta_y0 = (celda / _grilla.x as int) * _alto_celda
	_consulta_x1 = _consulta_x0 + _ancho_celda
	_consulta_y1 = _consulta_y0 + _alto_celda
	if zona.has_area():
		_consulta_x0 = maxi(_consulta_x0, floori((zona.position.x - _rect_mundo.position.x) / _paso.x + 0.000001))
		_consulta_y0 = maxi(_consulta_y0, floori((zona.position.y - _rect_mundo.position.y) / _paso.y + 0.000001))
		_consulta_x1 = mini(_consulta_x1, ceili((zona.end.x - _rect_mundo.position.x) / _paso.x - 0.000001))
		_consulta_y1 = mini(_consulta_y1, ceili((zona.end.y - _rect_mundo.position.y) / _paso.y - 0.000001))
		if _consulta_x0 >= _consulta_x1 or _consulta_y0 >= _consulta_y1:
			return -1
	_mejor_pixel = -1
	_mejor_distancia = INF
	_buscar_nodo(0, 0, 0, _lado_arbol)
	return _mejor_pixel


func _buscar_nodo(nodo: int, bx: int, by: int, lado: int) -> void:
	if _arbol[nodo] <= 0 or (_consulta_frontera and _frontera_arbol[nodo] <= 0):
		return
	var x0 := maxi(bx * LADO_BLOQUE, _consulta_x0)
	var y0 := maxi(by * LADO_BLOQUE, _consulta_y0)
	var x1 := mini((bx + lado) * LADO_BLOQUE, _consulta_x1)
	var y1 := mini((by + lado) * LADO_BLOQUE, _consulta_y1)
	if x0 >= x1 or y0 >= y1:
		return
	var desde := _rect_mundo.position + Vector2(x0, y0) * _paso
	var hasta := _rect_mundo.position + Vector2(x1, y1) * _paso
	if _consulta_desde.distance_squared_to(_consulta_desde.clamp(desde, hasta)) >= _mejor_distancia:
		return
	if lado == 1:
		var frontera := _frontera_bits[by * _columnas_bloques + bx] if _consulta_frontera else 0
		# El píxel proyectado logra el límite inferior del bloque. Si es
		# material consultable, ninguna de sus otras63 posiciones mejora esto.
		var sx := clampi(floori(_consulta_pixel.x), x0, x1 - 1)
		var sy := clampi(floori(_consulta_pixel.y), y0, y1 - 1)
		var semilla := sy * _ancho + sx
		if _pixeles[semilla] != 0 and (not _consulta_frontera or (frontera & (1 << ((sy % LADO_BLOQUE) * LADO_BLOQUE + sx % LADO_BLOQUE))) != 0):
			_mejor_distancia = _consulta_desde.distance_squared_to(_consulta_desde.clamp(desde, hasta))
			_mejor_pixel = semilla
			return
		for y in range(y0, y1):
			for x in range(x0, x1):
				var indice := y * _ancho + x
				if _pixeles[indice] == 0:
					continue
				if _consulta_frontera and (frontera & (1 << ((y % LADO_BLOQUE) * LADO_BLOQUE + x % LADO_BLOQUE))) == 0:
					continue
				var rect := _rect_pixel(x, y)
				var distancia := _consulta_desde.distance_squared_to(_consulta_desde.clamp(rect.position, rect.end))
				if distancia < _mejor_distancia:
					_mejor_distancia = distancia
					_mejor_pixel = indice
		return
	var mitad := lado / 2 as int
	var centro := _rect_mundo.position + Vector2((bx + mitad) * LADO_BLOQUE, (by + mitad) * LADO_BLOQUE) * _paso
	var preferido := (1 if _consulta_desde.x >= centro.x else 0) + (2 if _consulta_desde.y >= centro.y else 0)
	for orden in 4:
		var cuadrante := preferido ^ orden
		_buscar_nodo(nodo * 4 + 1 + cuadrante, bx + (cuadrante % 2) * mitad, by + (cuadrante / 2 as int) * mitad, mitad)
