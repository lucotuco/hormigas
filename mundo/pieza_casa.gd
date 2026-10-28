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
var _vida_celda := 1.0
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
	_vida_celda = vida_max / (grilla.x * grilla.y)
	var tam := rect_mundo.size / Vector2(grilla)
	for y in grilla.y:
		for x in grilla.x:
			celdas.append(Rect2(rect_mundo.position + Vector2(x, y) * tam, tam))
			vidas.append(_vida_celda)
			vivas.append(vivas.size())
			_cortes.append(Vector4(1, 0.5, 0.5, 0))
	while _cortes.size() < 16:
		_cortes.append(Vector4(0, 0, 0, 0))
	_fila_activa = grilla.y - 1
	_distancia_nido = distancia_a(Vector2.ZERO)
	_mascara = ShaderMaterial.new()
	_mascara.shader = preload("res://mundo/recorte_pieza.gdshader")
	_mascara.set_shader_parameter("tamano", rect_mundo.size)
	_mascara.set_shader_parameter("grilla", grilla)
	_mascara.set_shader_parameter("material_id", nivel_requerido)
	_mascara.set_shader_parameter("cortes", _cortes)
	material = _mascara
	set_process(false)

func disponible() -> bool:
	return not muerta and not derrumbando and Juego.stat("materiales") >= nivel_requerido

func distancia_a(pos: Vector2) -> float:
	if not _por_pisos and vivas.size() == celdas.size():
		return pos.distance_to(pos.clamp(rect_mundo.position, rect_mundo.end))
	var menor := INF
	for i in vivas:
		if _por_pisos and int(i / grilla.x) != _fila_activa:
			continue
		var r := celdas[i]
		menor = minf(menor, pos.distance_to(pos.clamp(r.position, r.end)))
	return menor

func contiene_punto(pos: Vector2, margen := 0.0) -> bool:
	for i in vivas:
		if celdas[i].grow(margen).has_point(pos):
			return true
	return false

func en_territorio(territorio: float) -> bool:
	return _distancia_nido <= territorio - 10

func alcanza_desde(pos: Vector2) -> bool:
	return distancia_a(pos) <= Cocina.MARGEN + 5

func cupos_trabajo() -> int:
	return clampi(vivas.size() * 2, 4, 32)

func punto_trabajo(desde: Vector2, territorio: float, volando: bool, puesto: int) -> Vector2:
	var base := punto_mordida(desde, territorio, volando)
	if base == Vector2.INF:
		return base
	var normal := base - base.clamp(rect_mundo.position, rect_mundo.end)
	var tangente := Vector2(0, 1) if absf(normal.x) > absf(normal.y) else Vector2(1, 0)
	var distribuido := base + tangente * ((puesto % 7) - 3) * 16
	if distribuido.length_squared() < pow(territorio - 6, 2) and alcanza_desde(distribuido) and casa.libre(distribuido, Cocina.MARGEN, volando):
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
		var r := celdas[i]
		var d := pos.distance_squared_to(pos.clamp(r.position, r.end))
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
			punto = celdas[i].get_center()
			menor = d
	return punto

func punto_mordida(desde: Vector2, territorio: float, volando := false) -> Vector2:
	if _version_accesos != casa.version:
		_accesos.clear()
		_version_accesos = casa.version
	var clave := Vector3i(floori(desde.x / 64), floori(desde.y / 64), int(territorio / 20) * 2 + int(volando))
	if _accesos.has(clave):
		return _accesos[clave]
	var mejor := Vector2.INF
	var distancia := INF
	for i in vivas:
		if _por_pisos and int(i / grilla.x) != _fila_activa:
			continue
		var r := celdas[i].grow(Cocina.MARGEN + 3)
		# Proyectar sobre el material real; expandir también los extremos dejaba
		# un destino diagonal a 15.6 unidades de una mordida que alcanza 13.
		var p := desde.clamp(celdas[i].position, celdas[i].end)
		for punto in [Vector2(r.position.x, p.y), Vector2(r.end.x, p.y), Vector2(p.x, r.position.y), Vector2(p.x, r.end.y)]:
			var d := desde.distance_squared_to(punto)
			if d < distancia and punto.length_squared() < pow(maxf(0, territorio - 6), 2) and casa.libre(punto, Cocina.MARGEN, volando):
				mejor = punto
				distancia = d
	if _accesos.size() >= 64:
		_accesos.clear()
	_accesos[clave] = mejor
	return mejor

func morder(dano: float) -> float:
	var punto := punto_mordida(Vector2.ZERO, get_parent().get_parent().radio_actual)
	return morder_en(dano, punto if punto != Vector2.INF else position)

func morder_en(dano: float, pos: Vector2) -> float:
	if not disponible() or dano <= 0:
		return 0
	_impacto = pos
	var antes := vida
	var presupuesto := minf(dano * (1.0 + Juego.stat("corrosion_factor") if corrosion > 0 else 1.0), vida)
	dano_recibido += presupuesto
	var agujero := false
	var zona_rotura := Rect2()
	while presupuesto > 0.001 and not vivas.is_empty():
		var elegida := vivas[0]
		var distancia := INF
		var fila := 0
		if _por_pisos:
			for viva in vivas:
				fila = maxi(fila, int(viva / grilla.x))
		for i in vivas:
			# La torre se desmonta desde abajo. Son las mismas 16 celdas, sin física.
			if _por_pisos:
				if int(i / grilla.x) != fila:
					continue
			var r := celdas[i]
			var d := pos.distance_squared_to(pos.clamp(r.position, r.end))
			if d < distancia:
				distancia = d
				elegida = i
		var real := minf(presupuesto, vidas[elegida])
		vidas[elegida] = maxf(0, vidas[elegida] - real)
		presupuesto -= real
		vida = maxf(0, vida - real)
		var r := celdas[elegida]
		var mordida := ((pos - r.position) / r.size).clamp(Vector2.ZERO, Vector2.ONE)
		_cortes[elegida] = Vector4(vidas[elegida] / _vida_celda, mordida.x, mordida.y, 0)
		if vidas[elegida] <= 0.001:
			vivas.erase(elegida)
			agujero = true
			zona_rotura = r if not zona_rotura.has_area() else zona_rotura.merge(r)
	if vida <= 0.01:
		vida = 0
		for i in vivas:
			vidas[i] = 0
			_cortes[i].x = 0
		vivas.clear()
		agujero = true
	var extraido := antes - vida
	var run: Run = get_parent().get_parent()
	var nueva_etapa := clampi(int((1.0 - vida / vida_max) * 4 + 0.00001), 0, 3)
	if nueva_etapa > etapa:
		etapa = nueva_etapa
		run.reglas.etapa_alcanzada(self)
	run.registrar_extraccion(extraido)
	var valor := recompensa * extraido / vida_max * Juego.stat("multiplicador_migas")
	get_parent().soltar_fragmento(pos, valor * 0.35, nivel_requerido)
	if agujero:
		_actualizar_colision(zona_rotura)
	var umbral_tesoro := 0.8 if Juego.lugar_actual == "museo" and pieza.tipo == "vitrina" else 0.5
	if not _tesoro_abierto and vida < vida_max * umbral_tesoro and pieza.tipo in ["alacena", "heladera", "biblioteca", "vitrina"]:
		_tesoro_abierto = true
		get_parent().revelar_tesoro(pos, nivel_requerido)
	_sucio = true
	set_process(true)
	if vivas.is_empty():
		_finalizar()
	elif _pierde_soportes():
		derrumbando = true
		run.registrar_derrumbe()
	return valor * 0.65

func _pierde_soportes() -> bool:
	if pieza.get("meta", false) and Juego.lugar_actual == "eiffel":
		return vivas.size() <= grilla.x
	if vivas.size() <= maxi(1, int(celdas.size() * 0.3)):
		return true
	if pieza.pared:
		return false
	var rotas := 0
	for i in [0, grilla.x - 1, (grilla.y - 1) * grilla.x, celdas.size() - 1]:
		if vidas[i] <= 0:
			rotas += 1
	return rotas >= 2 and vida < vida_max * 0.55

func _actualizar_colision(zona := Rect2()) -> void:
	var rects: Array[Rect2] = []
	_fila_activa = 0
	for i in vivas:
		rects.append(celdas[i])
		_fila_activa = maxi(_fila_activa, int(i / grilla.x))
	_accesos.clear()
	_distancia_nido = distancia_a(Vector2.ZERO)
	casa.recortar_pieza(pieza.clave, rects, zona)

func _process(delta: float) -> void:
	if muerta:
		return
	if not get_parent().get_parent().activa:
		return
	if veneno_restante > 0:
		corrosion = maxf(corrosion, 2)
		super._process(delta)
	var antes_corrosion := corrosion > 0
	corrosion = maxf(0, corrosion - delta)
	if antes_corrosion or corrosion > 0:
		_sucio = true
	if derrumbando:
		_tiempo_caida += delta
		rotation = sin(_tiempo_caida * 45) * minf(0.035, _tiempo_caida * 0.1)
		_reloj_caida -= delta
		if _reloj_caida <= 0:
			_reloj_caida = 0.09
			var run: Run = get_parent().get_parent()
			var zona := Rect2()
			for paso in mini(2, vivas.size()):
				var i: int = vivas.back()
				var extraido := vidas[i]
				vida = maxf(0, vida - extraido)
				vidas[i] = 0
				_cortes[i].x = 0
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
		_mascara.set_shader_parameter("cortes", _cortes)
		_mascara.set_shader_parameter("corrosion", minf(1, corrosion))
		queue_redraw()
	if not _sucio and not derrumbando and veneno_restante <= 0 and corrosion <= 0:
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
		DibujoCasa.pared(self, local)
		for ventana in PlanoCasa.ventanas():
			var r: Rect2 = rect_mundo.intersection(ventana)
			if r.has_area():
				r.position -= position
				draw_rect(r, Color("bad8d7"))
	else:
		var m: Dictionary = pieza.dibujo.duplicate()
		m.rect = local
		if Graficos.listo:
			Graficos.dibujar_mueble(self, m)
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
