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
var _mascara: ShaderMaterial
var _sucio := true
var _reloj_dibujo := 0.0
var _reloj_caida := 0.0
var _impacto := Vector2.ZERO
var _tesoro_abierto := false
var _distancia_nido := 0.0
var _tiempo_caida := 0.0
## El gran objetivo es un mueble mucho más resistente: su vida se multiplica
## por Mundos.vida_meta(destino). Ver README (bot de balance).
const RECOMPENSA_META := 4.0
const NIVEL_META := 3

func iniciar(datos: Dictionary, cocina: Cocina) -> void:
	pieza = datos
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
	_mascara = ShaderMaterial.new()
	_mascara.shader = preload("res://mundo/recorte_pieza.gdshader")
	_mascara.set_shader_parameter("tamano", rect_mundo.size)
	_mascara.set_shader_parameter("grilla", grilla)
	_mascara.set_shader_parameter("cortes", _cortes)
	material = _mascara
	set_process(false)

func disponible() -> bool:
	return not muerta and not derrumbando and Juego.stat("materiales") >= nivel_requerido

func distancia_a(pos: Vector2) -> float:
	if vivas.size() == celdas.size():
		return pos.distance_to(pos.clamp(rect_mundo.position, rect_mundo.end))
	var menor := INF
	for i in vivas:
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
	var presupuesto := minf(dano * (1.2 if corrosion > 0 else 1.0), vida)
	var agujero := false
	var zona_rotura := Rect2()
	while presupuesto > 0.001 and not vivas.is_empty():
		var elegida := vivas[0]
		var distancia := INF
		for i in vivas:
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
	run.registrar_extraccion(extraido)
	var valor := recompensa * extraido / vida_max * Juego.stat("multiplicador_migas")
	get_parent().soltar_fragmento(pos, valor * 0.35, nivel_requerido)
	if agujero:
		_actualizar_colision(zona_rotura)
	if not _tesoro_abierto and vida < vida_max * 0.5 and pieza.tipo in ["alacena", "heladera", "biblioteca", "vitrina"]:
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
	for i in vivas:
		rects.append(celdas[i])
	_accesos.clear()
	_distancia_nido = distancia_a(Vector2.ZERO)
	casa.recortar_pieza(pieza.clave, rects, zona)

func _process(delta: float) -> void:
	if muerta:
		return
	if veneno_restante > 0:
		corrosion = maxf(corrosion, 2)
		super._process(delta)
	corrosion = maxf(0, corrosion - delta)
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
	if vida < vida_max:
		var ancho := minf(local.size.x, 240)
		# Las barras quedan fuera de la máscara del cuerpo.
		draw_rect(Rect2(-ancho * 0.5, local.position.y - 22, ancho, 10), Color("373d31"))
		draw_rect(Rect2(-ancho * 0.5, local.position.y - 22, ancho * vida / vida_max, 10), Color("c5d98b"))
