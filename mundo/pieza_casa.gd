class_name PiezaCasa
extends Comida
## Hasta 16 celdas lógicas y un solo dibujo enmascarado. Sin cuerpos físicos.
var pieza: Dictionary
var rect_mundo: Rect2
var nivel_requerido := 1
var casa: Cocina
var grilla := Vector2i(3, 4)
var celdas: Array[Rect2] = []
var vidas := PackedFloat64Array()
var vivas: Array[int] = []
var derrumbando := false
var corrosion := 0.0
var _vidas_iniciales := PackedFloat64Array()
var _formas_originales: Array[Rect2] = []
var _formas: Array[Rect2] = []
var _zonas_trabajo: Array[Rect2] = []
var _formas_por_celda: Array = []
var _material_por_celda: Array = []
var _material_original: Array[Rect2] = []
var _limites_celda: Array[Rect2] = []
var _formas_activas_por_celda: Array = []
var _limites_fisicos: Array[Rect2] = []
var _tiene_retroceso := false
var _geometria_pendiente := false
var _zona_geometria := Rect2()
var _reloj_geometria := 0.0
const INTERVALO_GEOMETRIA := 0.12
var _version_material := 0
var _version_contacto := -1
var _pos_contacto := Vector2.INF
var _punto_contacto := Vector2.INF
var _celda_contacto := -1
var _distancias_contacto := PackedFloat64Array()
var _soportes: Array[int] = []
var _rectangular := true
var _celdas_ocupadas := 0
var version_forma := 0
var _cortes: Array[Vector4] = []
var _accesos: Dictionary = {}
var _version_accesos := -1
var etapa := 0
var _por_pisos := false
var _fila_activa := 0
var _mascara: ShaderMaterial
var _sucio := true
var _reloj_dibujo := 0.0
var _reloj_caida := 0.0
var _impacto := Vector2.ZERO
var _tesoro_abierto := false
var _distancia_nido := 0.0
var _tiempo_caida := 0.0
## Daño total recibido en esta run. Lo usa el bot de balance: con vidas enormes,
## restar vida_max - vida pierde precisión.
var dano_recibido := 0.0
## El gran objetivo es un mueble mucho más resistente: su vida se multiplica
## por Mundos.vida_meta(destino). Ver README (bot de balance).
const RECOMPENSA_META := 4.0
const NIVEL_META := 3

func iniciar(datos: Dictionary, cocina: Cocina) -> void:
	pieza = datos
	_por_pisos = datos.get("meta", false) and Juego.lugar_actual == "eiffel"
	casa = cocina
	rect_mundo = datos.rect
	position = rect_mundo.get_center()
	_distancia_nido = Vector2.ZERO.distance_to(Vector2.ZERO.clamp(rect_mundo.position, rect_mundo.end))
	var mat := MaterialesCasa.definir(datos.tipo, rect_mundo, datos.color)
	mat.vida *= float(Mundos.INFO[Juego.lugar_actual].factor)
	mat.recompensa *= float(Mundos.INFO[Juego.lugar_actual].factor)
	# Más trabajo real, no más valor gratuito por endurecer el mobiliario.
	mat.vida *= Juego.stat("resistencia_muebles")
	if datos.get("perfil", "") == "silla_inicial":
		# Una silla cercana permite observar el material nuevo. Resistencia y
		# valor tienen datos independientes: endurecerla no regala más migas.
		mat.vida = Juego.stat("vida_silla_inicial")
		mat.recompensa = Juego.stat("recompensa_silla_inicial")
	if datos.get("meta", false):
		mat.nombre = Mundos.INFO[Juego.lugar_actual].meta
		mat.vida *= Mundos.vida_meta(Juego.lugar_actual)
		mat.recompensa *= RECOMPENSA_META
		# El gran objetivo cierra el destino: pide la dieta completa aunque sea
		# de madera. Si no, se comía apenas se desbloqueaba la madera.
		mat.nivel = maxi(int(mat.nivel), NIVEL_META)
	if datos.get("practica", false):
		mat.nombre = tr("Banquito de cartón")
		mat.vida = 20.0
		mat.recompensa = 180.0
		mat.nivel = 0
	configurar(mat, 1)
	rotation = 0
	nivel_requerido = mat.nivel
	z_index = -4
	if pieza.pared:
		grilla = Vector2i(4, 1) if rect_mundo.size.x > rect_mundo.size.y else Vector2i(1, 4)
	elif rect_mundo.size.x > rect_mundo.size.y * 2.5:
		grilla = Vector2i(4, 2)
	elif datos.get("meta", false):
		grilla = Vector2i(4, 4)
	_formas_originales.assign(SiluetaMueble.rectangulos(datos))
	_material_original.assign(SiluetaMueble.material(datos))
	if _material_original.is_empty():
		_material_original.assign(datos.get("recortes", [rect_mundo]))
	_rectangular = _formas_originales.size() == 1 and _formas_originales[0] == rect_mundo
	var tam := rect_mundo.size / Vector2(grilla)
	for y in grilla.y:
		for x in grilla.x:
			celdas.append(Rect2(rect_mundo.position + Vector2(x, y) * tam, tam))
			var partes: Array[Rect2] = []
			var ocupado := Rect2()
			for forma in _formas_originales:
				var interseccion := forma.intersection(celdas.back())
				if interseccion.has_area():
					partes.append(interseccion)
					ocupado = interseccion if not ocupado.has_area() else ocupado.merge(interseccion)
			_formas_por_celda.append(partes)
			var partes_material: Array[Rect2] = []
			for forma in _material_original:
				var interseccion := forma.intersection(celdas.back())
				if interseccion.has_area():
					partes_material.append(interseccion)
			_material_por_celda.append(partes_material)
			_limites_celda.append(ocupado)
			_formas_activas_por_celda.append(partes.duplicate())
			_limites_fisicos.append(ocupado)
			vidas.append(0)
			_vidas_iniciales.append(0)
			_cortes.append(Vector4(0, 0.5, 0.5, 0))
	# Resistencia proporcional al material, no a cuántas celdas toca una tira.
	# La torre conserva el mismo cuarto por piso, repartido por área de apoyos.
	var areas := PackedFloat64Array()
	areas.resize(celdas.size())
	var area_total := 0.0
	var material_disjunto := not SiluetaMueble.datos_material(datos).is_empty()
	for i in celdas.size():
		if material_disjunto:
			for forma_material: Rect2 in _material_por_celda[i]:
				areas[i] += forma_material.get_area()
		else:
			areas[i] = _area_formas(_material_por_celda[i])
		area_total += areas[i]
	var filas_ocupadas := 0
	for y in grilla.y:
		for x in grilla.x:
			if areas[y * grilla.x + x] > 0:
				filas_ocupadas += 1
				break
	var vida_asignada := 0.0
	var ultima_celda := -1
	for y in grilla.y:
		var area_fila := 0.0
		for x in grilla.x:
			area_fila += areas[y * grilla.x + x]
		for x in grilla.x:
			var i := y * grilla.x + x
			if areas[i] <= 0:
				continue
			vidas[i] = vida_max * areas[i] / area_total if not _por_pisos else vida_max / maxi(1, filas_ocupadas) * areas[i] / area_fila
			_vidas_iniciales[i] = vidas[i]
			vida_asignada += vidas[i]
			ultima_celda = i
			vivas.append(i)
			_cortes[i].x = 1
	if ultima_celda >= 0:
		vidas[ultima_celda] += vida_max - vida_asignada
		_vidas_iniciales[ultima_celda] = vidas[ultima_celda]
	while _cortes.size() < 16:
		_cortes.append(Vector4(0, 0, 0, 0))
	_celdas_ocupadas = vivas.size()
	_reconstruir_formas()
	for esquina in [rect_mundo.position, Vector2(rect_mundo.end.x, rect_mundo.position.y), Vector2(rect_mundo.position.x, rect_mundo.end.y), rect_mundo.end]:
		var mas_cerca := -1
		var menor := INF
		for i in vivas:
			var d := _distancia_celda(i, esquina)
			if d < menor:
				menor = d
				mas_cerca = i
		if mas_cerca >= 0 and not _soportes.has(mas_cerca):
			_soportes.append(mas_cerca)
	_distancia_nido = distancia_a(Vector2.ZERO)
	_mascara = ShaderMaterial.new()
	_mascara.shader = preload("res://mundo/recorte_bocados.gdshader")
	_mascara.set_shader_parameter("tamano", rect_mundo.size)
	_mascara.set_shader_parameter("grilla", grilla)
	_mascara.set_shader_parameter("material_id", nivel_requerido)
	_mascara.set_shader_parameter("cortes", _cortes)
	material = _mascara
	if not pieza.pared:
		if Graficos.listo:
			_preparar_sombra()
		else:
			Graficos.preparado.connect(_preparar_sombra, CONNECT_ONE_SHOT)
	set_process(false)


func _preparar_sombra() -> void:
	Graficos.configurar_sombra(_mascara, pieza.dibujo)
	queue_redraw()


func _area_formas(formas: Array) -> float:
	# Unión por bandas: los perfiles son pequeños y se calcula sólo al crear.
	var ordenadas: Array[Rect2] = []
	var bordes: Array[float] = []
	for forma: Rect2 in formas:
		if not forma.has_area():
			continue
		ordenadas.append(forma)
		bordes.append(forma.position.y)
		bordes.append(forma.end.y)
	if ordenadas.is_empty():
		return 0.0
	if ordenadas.size() == 1:
		return ordenadas[0].get_area()
	ordenadas.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	bordes.sort()
	var area := 0.0
	for banda in range(bordes.size() - 1):
		var y0 := bordes[banda]
		var y1 := bordes[banda + 1]
		if y0 >= y1:
			continue
		var inicio := INF
		var fin := -INF
		for forma: Rect2 in ordenadas:
			if forma.position.y > y0 or forma.end.y < y1:
				continue
			if inicio == INF:
				inicio = forma.position.x
				fin = forma.end.x
			elif forma.position.x <= fin:
				fin = maxf(fin, forma.end.x)
			else:
				area += (fin - inicio) * (y1 - y0)
				inicio = forma.position.x
				fin = forma.end.x
		if inicio != INF:
			area += (fin - inicio) * (y1 - y0)
	return area


func _preparar_mordiscos() -> void:
	# Los muebles intactos no reservan imágenes ni texturas de desgaste.
	mordiscos = MordiscosMaterial.new()
	mordiscos.configurar(rect_mundo, grilla, _material_por_celda, _vidas_iniciales)
	if DisplayServer.get_name() != "headless":
		_mascara.set_shader_parameter("mascara_bocados", mordiscos.textura_mascara())
		_mascara.set_shader_parameter("usar_mascara", true)

func disponible() -> bool:
	return not muerta and not derrumbando and Juego.stat("materiales") >= nivel_requerido

func distancia_a(pos: Vector2) -> float:
	if _rectangular and not _por_pisos and not _tiene_retroceso and vivas.size() == celdas.size():
		return pos.distance_to(pos.clamp(rect_mundo.position, rect_mundo.end))
	var menor := INF
	for r in _zonas_trabajo:
		menor = minf(menor, pos.distance_to(pos.clamp(r.position, r.end)))
	return menor

func contiene_punto(pos: Vector2, margen := 0.0) -> bool:
	for forma in _formas:
		if forma.grow(margen).has_point(pos):
			return true
	return false

func dentro_silueta(pos: Vector2, margen := 0.0) -> bool:
	for forma in _formas_originales:
		if forma.grow(margen).has_point(pos):
			return true
	return false

func material_cercano(pos: Vector2) -> Vector2:
	if mordiscos != null:
		return punto_contacto(pos)
	var mejor := position
	var distancia := INF
	for forma in _zonas_trabajo:
		var punto := pos.clamp(forma.position, forma.end)
		var d := pos.distance_squared_to(punto)
		if d < distancia:
			distancia = d
			mejor = punto
	return mejor

func punto_contacto(pos: Vector2) -> Vector2:
	# Sólo en mordidas/elección de puesto, nunca en el paso de cada hormiga.
	if mordiscos == null:
		_preparar_mordiscos()
	if _version_contacto == _version_material and _pos_contacto == pos:
		return _punto_contacto
	_pos_contacto = pos
	_version_contacto = _version_material
	_punto_contacto = Vector2.INF
	_celda_contacto = -1
	if not mordiscos.aire_exterior(pos):
		return _punto_contacto
	var distancia := INF
	var primera := -1
	var menor_limite := INF
	if _distancias_contacto.size() < celdas.size():
		_distancias_contacto.resize(celdas.size())
	var fila := 0
	if _por_pisos:
		for i in vivas:
			fila = maxi(fila, i / grilla.x as int)
	for i in vivas:
		_distancias_contacto[i] = INF
		if _por_pisos and (i / grilla.x as int) != fila:
			continue
		var limite := mordiscos.limites_celda(i)
		if not limite.has_area():
			continue
		var minima := pos.distance_squared_to(pos.clamp(limite.position, limite.end))
		_distancias_contacto[i] = minima
		if minima < menor_limite:
			menor_limite = minima
			primera = i
	# La consulta exacta arranca por el AABB más cercano. Las restantes sólo
	# atraviesan el árbol si todavía pueden mejorar esa distancia real.
	if primera >= 0:
		_punto_contacto = mordiscos.punto_frontera(primera, pos)
		if _punto_contacto != Vector2.INF:
			distancia = pos.distance_squared_to(_punto_contacto)
			_celda_contacto = primera
	for i in vivas:
		if i == primera or _distancias_contacto[i] >= distancia:
			continue
		var punto := mordiscos.punto_frontera(i, pos)
		if punto == Vector2.INF:
			continue
		var d := pos.distance_squared_to(punto)
		if d < distancia:
			distancia = d
			_punto_contacto = punto
			_celda_contacto = i
	return _punto_contacto

func alcanza_contacto(pos: Vector2) -> bool:
	var punto := punto_contacto(pos)
	return punto != Vector2.INF and pos.distance_squared_to(punto) <= pow(Cocina.MARGEN + 5, 2)

func _distancia_celda(i: int, pos: Vector2) -> float:
	var distancia := INF
	for forma: Rect2 in _formas_activas_por_celda[i]:
		distancia = minf(distancia, pos.distance_squared_to(pos.clamp(forma.position, forma.end)))
	return distancia

func _reconstruir_formas() -> void:
	version_forma += 1
	_formas.clear()
	_zonas_trabajo.clear()
	_fila_activa = 0
	for i in vivas:
		_fila_activa = maxi(_fila_activa, int(i / grilla.x))
		var bordes := 0
		var vecinos := [i - 1 if i % grilla.x > 0 else -1, i + 1 if i % grilla.x < grilla.x - 1 else -1, i - grilla.x, i + grilla.x]
		for lado in 4:
			var vecino: int = vecinos[lado]
			if vecino >= 0 and vecino < vidas.size() and _vidas_iniciales[vecino] > 0 and vidas[vecino] <= 0:
				bordes |= 1 << lado
		_cortes[i].w = bordes
	if vivas.size() == _celdas_ocupadas and not _tiene_retroceso:
		_formas.assign(_formas_originales)
	else:
		for i in vivas:
			_formas.append_array(_formas_activas_por_celda[i])
	if not _por_pisos:
		_zonas_trabajo.assign(_formas)
	else:
		for i in vivas:
			if int(i / grilla.x) == _fila_activa:
				_zonas_trabajo.append_array(_formas_activas_por_celda[i])

func en_territorio(territorio: float) -> bool:
	return _distancia_nido <= territorio - 10

func alcanza_desde(pos: Vector2) -> bool:
	var alcance := Cocina.MARGEN + 5
	# Rechazo conservador antes de recorrer las bandas de una silueta. Incluye
	# ambos bordes: Rect2.has_point excluiría el extremo derecho e inferior.
	if pos.x < rect_mundo.position.x - alcance or pos.x > rect_mundo.end.x + alcance or pos.y < rect_mundo.position.y - alcance or pos.y > rect_mundo.end.y + alcance:
		return false
	return distancia_a(pos) <= alcance

func cupos_trabajo() -> int:
	return clampi(vivas.size() * 2, 4, 32)

func punto_trabajo(desde: Vector2, territorio: float, volando: bool, puesto: int) -> Vector2:
	var base := punto_mordida(desde, territorio, volando)
	if base == Vector2.INF:
		return base
	var normal := base - material_cercano(base)
	var tangente := Vector2(0, 1) if absf(normal.x) > absf(normal.y) else Vector2(1, 0)
	var distribuido := base + tangente * ((puesto % 7) - 3) * 16
	if distribuido.length_squared() < pow(territorio - 6, 2) and alcanza_desde(distribuido) and casa.libre(distribuido, Cocina.MARGEN, volando) and (mordiscos == null or alcanza_contacto(distribuido)):
		return distribuido
	return base

func nombre_etapa() -> String:
	if pieza.get("meta", false) and Juego.lugar_actual == "eiffel":
		return [tr("Base"), tr("Primer piso"), tr("Plataforma"), tr("Cima")][etapa]
	if pieza.tipo == "vitrina":
		return [tr("Cubierta intacta"), tr("Contenido expuesto"), tr("Bastidor roto"), tr("Últimos soportes")][etapa]
	return [tr("Intacto"), tr("Primeras roturas"), tr("Estructura debilitada"), tr("Sin soportes")][etapa]

func siguiente_seccion(pos: Vector2) -> Vector2:
	# Sólo al morder con Corte aserrado: dos recorridos de hasta 16 celdas.
	# Un desplazamiento fijo podía caer otra vez sobre la misma celda del borde.
	var primera := -1
	var menor := INF
	for i in vivas:
		var d := _distancia_celda(i, pos)
		if d < menor:
			primera = i
			menor = d
	if primera < 0:
		return pos
	var punto := pos
	menor = INF
	for i in vivas:
		if i == primera:
			continue
		var d := celdas[i].get_center().distance_squared_to(celdas[primera].get_center())
		if d < menor:
			punto = _formas_por_celda[i][0].get_center()
			menor = d
	return punto

func punto_mordida(desde: Vector2, territorio: float, volando := false) -> Vector2:
	if _version_accesos != casa.version:
		_accesos.clear()
		_version_accesos = casa.version
	var clave := Vector3i(floori(desde.x / 64), floori(desde.y / 64), int(territorio / 20) * 2 + int(volando))
	if _accesos.has(clave):
		var anterior: Vector2 = _accesos[clave]
		if anterior == Vector2.INF or mordiscos == null or alcanza_contacto(anterior):
			return anterior
		_accesos.erase(clave)
	var mejor := Vector2.INF
	var distancia := INF
	for forma in _zonas_trabajo:
		var r := forma.grow(Cocina.MARGEN + 3)
		# Proyectar sobre el material real; expandir también los extremos dejaba
		# un destino diagonal a 15.6 unidades de una mordida que alcanza 13.
		var p := desde.clamp(forma.position, forma.end)
		for punto in [Vector2(r.position.x, p.y), Vector2(r.end.x, p.y), Vector2(p.x, r.position.y), Vector2(p.x, r.end.y)]:
			var d := desde.distance_squared_to(punto)
			if d < distancia and punto.length_squared() < pow(maxf(0, territorio - 6), 2) and casa.libre(punto, Cocina.MARGEN, volando):
				mejor = punto
				distancia = d
	if mordiscos != null and (mejor == Vector2.INF or not alcanza_contacto(mejor)):
		mejor = _puesto_en_frontera(desde, territorio, volando)
	if _accesos.size() >= 64:
		_accesos.clear()
	_accesos[clave] = mejor
	return mejor

func _puesto_en_frontera(desde: Vector2, territorio: float, volando: bool) -> Vector2:
	var mejor := Vector2.INF
	var distancia := INF
	var paso := rect_mundo.size / Vector2(mordiscos.tamano_mascara())
	var territorio_cuadrado := pow(maxf(0, territorio - 6), 2)
	var alcance_cuadrado := pow(Cocina.MARGEN + 5, 2)
	var fila := 0
	if _por_pisos:
		for i in vivas:
			fila = maxi(fila, i / grilla.x as int)
	for i in vivas:
		if _por_pisos and (i / grilla.x as int) != fila:
			continue
		var vivo := mordiscos.limites_celda(i)
		var fisico := _limites_fisicos[i]
		if not vivo.has_area() or not fisico.has_area():
			continue
		# Cuatro consultas acotadas a las hileras extremas. Siempre encuentra
		# el último apoyo del borde; no depende de acertarle con muestras.
		for lado in 4:
			# Cualquier puesto de este lado vive en un segmento exterior fijo.
			# Su proyección es un límite inferior: si ya pierde, no consultar
			# miles de píxeles del borde para llegar a la misma conclusión.
			var minimo := desde.clamp(vivo.position, vivo.end)
			var cercano_nido := Vector2.ZERO.clamp(vivo.position, vivo.end)
			match lado:
				0:
					minimo.x = fisico.position.x - Cocina.MARGEN - 1
					cercano_nido.x = minimo.x
				1:
					minimo.x = fisico.end.x + Cocina.MARGEN + 1
					cercano_nido.x = minimo.x
				2:
					minimo.y = fisico.position.y - Cocina.MARGEN - 1
					cercano_nido.y = minimo.y
				3:
					minimo.y = fisico.end.y + Cocina.MARGEN + 1
					cercano_nido.y = minimo.y
			if desde.distance_squared_to(minimo) >= distancia or cercano_nido.length_squared() >= territorio_cuadrado:
				continue
			var zona := vivo
			match lado:
				0: zona.size.x = minf(paso.x, vivo.size.x)
				1:
					zona.position.x = vivo.end.x - minf(paso.x, vivo.size.x)
					zona.size.x = minf(paso.x, vivo.size.x)
				2: zona.size.y = minf(paso.y, vivo.size.y)
				3:
					zona.position.y = vivo.end.y - minf(paso.y, vivo.size.y)
					zona.size.y = minf(paso.y, vivo.size.y)
			var contacto_borde := mordiscos.punto_en_zona(i, desde, zona)
			if contacto_borde == Vector2.INF:
				continue
			var punto := contacto_borde
			match lado:
				0: punto.x = fisico.position.x - Cocina.MARGEN - 1
				1: punto.x = fisico.end.x + Cocina.MARGEN + 1
				2: punto.y = fisico.position.y - Cocina.MARGEN - 1
				3: punto.y = fisico.end.y + Cocina.MARGEN + 1
			var d := desde.distance_squared_to(punto)
			if d < distancia and punto.length_squared() < territorio_cuadrado and punto.distance_squared_to(contacto_borde) <= alcance_cuadrado and mordiscos.aire_exterior(punto) and casa.libre(punto, Cocina.MARGEN, volando):
				mejor = punto
				distancia = d
	return mejor

func morder(dano: float) -> float:
	var punto := punto_mordida(Vector2.ZERO, get_parent().get_parent().radio_actual)
	return morder_en(dano, punto if punto != Vector2.INF else position)

func morder_en(dano: float, pos: Vector2) -> float:
	# Daño ambiental/bulk: conserva el reparto de escombros de los eventos.
	return _extraer_pieza(dano, pos, 0.0)


func morder_local(dano: float, pos: Vector2, lado_max := 6.0) -> float:
	# Una hormiga sólo desprende una porción pequeña por operación, incluso
	# con mandíbulas enormes. La carga es el material que realmente falta.
	_porcion_reciente = Rect2()
	if not is_finite(lado_max) or lado_max <= 0:
		return 0
	return _extraer_pieza(dano, pos, lado_max)


func morder_veneno(dano: float, origen: Vector2) -> float:
	return _extraer_pieza(dano, origen, -1.0)


func _extraer_pieza(dano: float, pos: Vector2, lado_max: float) -> float:
	_porcion_reciente = Rect2()
	if not disponible() or not is_finite(dano) or dano <= 0 or not pos.is_finite():
		return 0
	if mordiscos == null:
		_preparar_mordiscos()
	if lado_max > 0 and not alcanza_contacto(pos):
		return 0
	if lado_max < 0 and not mordiscos.aire_exterior(pos):
		pos = mordiscos.origen_exterior(vivas[0], pos)
	_impacto = pos
	_porcion_reciente = Rect2()
	var antes := vida
	var presupuesto := minf(dano * (1.0 + Juego.stat("corrosion_factor") if corrosion > 0 else 1.0), vida)
	var agujero := false
	var zona_rotura := Rect2()
	while presupuesto > 0 and not vivas.is_empty():
		var elegida := -1
		var distancia := INF
		var fila := 0
		if lado_max < 0:
			# El mismo nearest exacto que la boca: primero el AABB vivo más
			# cercano y sólo otras celdas que puedan mejorarlo. El veneno no
			# necesita consultar las 16 fronteras en cada medio segundo.
			punto_contacto(pos)
			elegida = _celda_contacto
		elif _por_pisos:
			for viva in vivas:
				fila = maxi(fila, int(viva / grilla.x))
		for i in vivas:
			if lado_max < 0:
				break
			# La torre se desmonta desde abajo. Son las mismas 16 celdas, sin física.
			if _por_pisos:
				if int(i / grilla.x) != fila:
					continue
			if lado_max > 0:
				elegida = _celda_contacto
				break
			var d := _distancia_celda(i, pos)
			if d < distancia:
				distancia = d
				elegida = i
		if elegida < 0:
			break
		var real := minf(presupuesto, vidas[elegida])
		var trabajo := real
		if lado_max > 0:
			real = mordiscos.recortar_local(elegida, presupuesto, pos, lado_max)
		elif lado_max < 0:
			real = mordiscos.recortar_frente(elegida, trabajo, pos)
		else:
			real = mordiscos.recortar(elegida, trabajo, pos)
		presupuesto -= trabajo
		if real <= 0:
			break
		if mordiscos.ultima_porcion.get_area() > _porcion_reciente.get_area():
			_porcion_reciente = mordiscos.ultima_porcion
		vidas[elegida] = mordiscos.vida_celda(elegida)
		vida = maxf(0, vida - real)
		_version_material += 1
		if lado_max != 0:
			_registrar_retroceso(elegida)
		var r := celdas[elegida]
		var ocupado := _limites_celda[elegida]
		var mordida := ((pos - ocupado.position) / ocupado.size).clamp(Vector2.ZERO, Vector2.ONE)
		_cortes[elegida] = Vector4(vidas[elegida] / _vidas_iniciales[elegida], mordida.x, mordida.y, _cortes[elegida].w)
		if vidas[elegida] == 0.0:
			mordiscos.limpiar_celda(elegida)
			vivas.erase(elegida)
			agujero = true
			zona_rotura = r if not zona_rotura.has_area() else zona_rotura.merge(r)
		if lado_max > 0:
			break
	if vivas.is_empty():
		vida = 0
	var extraido := antes - vida
	if extraido <= 0:
		return 0
	dano_recibido += extraido
	var run: Run = get_parent().get_parent()
	var nueva_etapa := clampi(int((1.0 - vida / vida_max) * 4 + 0.00001), 0, 3)
	if nueva_etapa > etapa:
		etapa = nueva_etapa
		run.reglas.etapa_alcanzada(self)
	run.registrar_extraccion(extraido)
	var valor := recompensa * extraido / vida_max * Juego.stat("multiplicador_migas")
	if lado_max <= 0:
		get_parent().soltar_fragmento(pos, valor * 0.35, nivel_requerido)
	if agujero and lado_max <= 0:
		_actualizar_colision(zona_rotura)
	var umbral_tesoro := 0.8 if Juego.lugar_actual == "museo" and pieza.tipo == "vitrina" else 0.5
	if not _tesoro_abierto and vida < vida_max * umbral_tesoro and pieza.tipo in ["alacena", "heladera", "biblioteca", "vitrina"]:
		_tesoro_abierto = true
		get_parent().revelar_tesoro(pos, nivel_requerido)
	_sucio = true
	set_process(true)
	if vivas.is_empty():
		_finalizar()
	elif lado_max == 0 and _pierde_soportes():
		derrumbando = true
		run.registrar_derrumbe()
	return valor if lado_max > 0 else valor * 0.65

func _pierde_soportes() -> bool:
	# No barrer el último tercio del mueble sin que nadie lo coma. Sólo se
	# desprenden los restos finales; la transformación la hacen las mordidas.
	if vida > vida_max * 0.08:
		return false
	if pieza.get("meta", false) and Juego.lugar_actual == "eiffel":
		return _fila_activa == 0
	if vivas.size() <= maxi(1, int(celdas.size() * 0.3)):
		return true
	if pieza.pared:
		return false
	var rotas := 0
	for i in _soportes:
		if vidas[i] <= 0:
			rotas += 1
	return rotas >= 2 and vida < vida_max * 0.55


func region_bocado() -> Rect2:
	if pieza.pared:
		return Graficos.region_porcion("material:pared", _porcion_reciente, rect_mundo)
	return Graficos.region_porcion_mueble(pieza.dibujo, _porcion_reciente)


func origen_bocado() -> Vector2:
	return _porcion_reciente.get_center() if _porcion_reciente.has_area() else position


func tamano_bocado() -> Vector2:
	return _porcion_reciente.size


func _registrar_retroceso(celda: int) -> void:
	var anterior := _limites_fisicos[celda]
	var nuevo := mordiscos.limites_celda(celda).intersection(_limites_celda[celda])
	if anterior == nuevo:
		return
	if not _geometria_pendiente:
		_geometria_pendiente = true
		_reloj_geometria = INTERVALO_GEOMETRIA
	# Se actualiza sólo la franja que puede haberse vuelto transitable.
	var zona := Rect2()
	if not nuevo.has_area():
		zona = anterior
	else:
		if nuevo.position.x > anterior.position.x:
			zona = Rect2(anterior.position, Vector2(nuevo.position.x - anterior.position.x, anterior.size.y))
		if nuevo.end.x < anterior.end.x:
			var tira := Rect2(Vector2(nuevo.end.x, anterior.position.y), Vector2(anterior.end.x - nuevo.end.x, anterior.size.y))
			zona = zona.merge(tira) if zona.has_area() else tira
		if nuevo.position.y > anterior.position.y:
			var tira := Rect2(anterior.position, Vector2(anterior.size.x, nuevo.position.y - anterior.position.y))
			zona = zona.merge(tira) if zona.has_area() else tira
		if nuevo.end.y < anterior.end.y:
			var tira := Rect2(Vector2(anterior.position.x, nuevo.end.y), Vector2(anterior.size.x, anterior.end.y - nuevo.end.y))
			zona = zona.merge(tira) if zona.has_area() else tira
	if zona.has_area():
		_zona_geometria = _zona_geometria.merge(zona) if _zona_geometria.has_area() else zona
	set_process(true)


func _sincronizar_formas_vivas() -> void:
	if mordiscos == null:
		return
	for i in celdas.size():
		var limite := mordiscos.limites_celda(i).intersection(_limites_celda[i])
		if limite == _limites_fisicos[i]:
			continue
		_limites_fisicos[i] = limite
		_tiene_retroceso = true
		var partes: Array[Rect2] = []
		if limite.has_area():
			for original: Rect2 in _formas_por_celda[i]:
				var parte := original.intersection(limite)
				if parte.has_area():
					partes.append(parte)
		_formas_activas_por_celda[i] = partes


func _actualizar_colision(zona := Rect2()) -> void:
	_sincronizar_formas_vivas()
	_reconstruir_formas()
	_accesos.clear()
	_distancia_nido = distancia_a(Vector2.ZERO)
	casa.recortar_pieza(pieza.clave, _formas.duplicate(), zona)
	_geometria_pendiente = false
	_zona_geometria = Rect2()


func _mostrar_veneno() -> void:
	# Varias rojas pueden renovar el efecto entre cuadros de dibujo. Marcar
	# suciedad conserva el límite de la máscara también durante la aplicación.
	_sucio = true


func _actualizar_mascara() -> void:
	_mascara.set_shader_parameter("cortes", _cortes)
	if mordiscos != null:
		mordiscos.actualizar_textura()
	_mascara.set_shader_parameter("corrosion", minf(1, corrosion))
	queue_redraw()


func _process(delta: float) -> void:
	if muerta:
		return
	if not get_parent().get_parent().activa:
		return
	if _geometria_pendiente:
		_reloj_geometria -= delta
		if _reloj_geometria <= 0:
			_actualizar_colision(_zona_geometria)
	if veneno_restante > 0:
		corrosion = maxf(corrosion, 2)
		_procesar_veneno(delta)
		if muerta:
			return
	var antes_corrosion := corrosion > 0
	corrosion = maxf(0, corrosion - delta)
	if antes_corrosion or corrosion > 0:
		_sucio = true
	if derrumbando:
		_tiempo_caida += delta
		rotation = sin(_tiempo_caida * 45) * minf(0.035, _tiempo_caida * 0.1)
		_reloj_caida -= delta
		if _reloj_caida <= 0:
			_reloj_caida = 0.35
			var run: Run = get_parent().get_parent()
			var zona := Rect2()
			for paso in mini(1, vivas.size()):
				var i: int = vivas.back()
				var extraido := vidas[i]
				vida = maxf(0, vida - extraido)
				vidas[i] = 0
				_cortes[i].x = 0
				mordiscos.limpiar_celda(i)
				vivas.pop_back()
				zona = celdas[i] if not zona.has_area() else zona.merge(celdas[i])
				run.registrar_extraccion(extraido)
				get_parent().soltar_fragmento(_impacto, recompensa * extraido / vida_max * Juego.stat("multiplicador_migas"), nivel_requerido)
				if en_territorio(run.radio_actual):
					run.efectos.chispas(celdas[i].get_center(), color, 3)
			_actualizar_colision(zona)
			_sucio = true
			if vivas.is_empty():
				_finalizar()
				return
	_reloj_dibujo -= delta
	if _sucio and _reloj_dibujo <= 0:
		_reloj_dibujo = 0.08
		_sucio = false
		_actualizar_mascara()
	if not _sucio and not _geometria_pendiente and not derrumbando and veneno_restante <= 0 and corrosion <= 0:
		set_process(false)

func _finalizar() -> void:
	if muerta:
		return
	vida = 0
	muerta = true
	destruida.emit(self)
	queue_free()

func _draw() -> void:
	if pieza.is_empty():
		return
	var local := Rect2(-rect_mundo.size * 0.5, rect_mundo.size)
	if pieza.pared:
		DibujoCasa.pared(self, local, false)
		for ventana in PlanoCasa.ventanas():
			var r: Rect2 = rect_mundo.intersection(ventana)
			if r.has_area():
				r.position -= position
				draw_rect(r, Color("bad8d7"))
	else:
		var m: Dictionary = pieza.dibujo.duplicate()
		m.rect = local
		if Graficos.listo:
			Graficos.dibujar_mueble(self, m, true)
		else:
			DibujoCasa.mueble(self, m)
	# Señales estáticas sobre el mismo dibujo y la misma máscara del material.
	# El piso activo cambia sólo cuando se vacía una fila de la torre.
	if _por_pisos and not vivas.is_empty():
		var y := local.position.y + (_fila_activa + 1) * local.size.y / grilla.y - 6
		draw_line(Vector2(local.position.x, y), Vector2(local.end.x, y), Color("e5bd68"), 12)
	if pieza.tipo in ["alacena", "heladera", "biblioteca", "vitrina"] and not _tesoro_abierto:
		var punto := Vector2(local.end.x - 16, local.position.y + 22)
		draw_circle(punto, 11, Color("edcf80"))
		draw_line(punto - Vector2(5, 0), punto + Vector2(5, 0), Color("7a633a"), 3)
	if vida < vida_max:
		var ancho := minf(local.size.x, 240)
		# Las barras quedan fuera de la máscara del cuerpo.
		draw_rect(Rect2(-ancho * 0.5, local.position.y - 22, ancho, 10), Color("373d31"))
		draw_rect(Rect2(-ancho * 0.5, local.position.y - 22, ancho * vida / vida_max, 10), Color("c5d98b"))
		for i in range(1, 4):
			draw_line(Vector2(-ancho * 0.5 + ancho * i / 4, local.position.y - 22), Vector2(-ancho * 0.5 + ancho * i / 4, local.position.y - 12), Color("444b39"), 2)
