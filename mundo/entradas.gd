class_name EntradasHormiguero
extends Node2D
## Hasta seis accesos fijos. La selección es O(6) sólo al iniciar un regreso;
## las rutas usan la misma cola de la colonia, nunca otro A* en paralelo.
var run: Run
var puntos: Array[Vector2] = [Vector2.ZERO]
var _candidatas: Array[Dictionary] = []
var _reloj := 0.0
var _escala_visual := 1.0

func iniciar(r: Run) -> void:
	run = r
	z_index = -2
	var alternativas: Array[Dictionary] = []
	for ambiente in PlanoCasa.ambientes():
		var rect: Rect2 = ambiente.rect
		var mejor := Vector2.INF
		for x in [0.15, 0.5, 0.85]:
			for y in [0.15, 0.5, 0.85]:
				var pos := rect.position + rect.size * Vector2(x, y)
				if r.cocina.libre(pos, 40):
					if pos.length_squared() < mejor.length_squared():
						mejor = pos
					if pos.length() > 900:
						alternativas.append({"pos": pos, "nombre": ambiente.nombre})
		if mejor != Vector2.INF and not rect.has_point(Vector2.ZERO):
			_candidatas.append({"pos": mejor, "nombre": ambiente.nombre})
	# Las plazas y salones enormes también necesitan logística. Primero un
	# acceso por ambiente; después puntos separados en los espacios abiertos.
	alternativas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.length_squared() < b.pos.length_squared())
	for alternativa in alternativas:
		if _candidatas.size() >= 6:
			break
		var separada := true
		for candidata in _candidatas:
			if candidata.pos.distance_squared_to(alternativa.pos) < 1100 * 1100:
				separada = false
				break
		if separada:
			_candidatas.append(alternativa)
	_candidatas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.length_squared() < b.pos.length_squared())
	actualizar()

func actualizar() -> void:
	var limite := mini(6, int(Juego.stat("entradas")))
	for candidata in _candidatas:
		if puntos.size() > limite:
			break
		var pos: Vector2 = candidata.pos
		if pos.length() + 40 > run.radio_actual or puntos.has(pos):
			continue
		puntos.append(pos)
		queue_redraw()
		run.hud.mostrar_aviso(tr("Nueva entrada · %s") % tr(candidata.nombre).to_lower())

func elegir(desde: Vector2, excluidas: Dictionary = {}) -> Vector2:
	var mejor := Vector2.ZERO
	var distancia := INF
	for punto in puntos:
		if excluidas.has(punto):
			continue
		var d := desde.distance_squared_to(punto)
		if d < distancia:
			mejor = punto
			distancia = d
	return mejor

func _process(delta: float) -> void:
	_reloj -= delta
	if _reloj <= 0 and is_instance_valid(run):
		_reloj = 0.5
		if run.activa:
			actualizar()
		var zoom := maxf(get_viewport().get_canvas_transform().get_scale().x, 0.01)
		var escala := clampf(0.6 / zoom, 1, 3)
		if absf(escala - _escala_visual) > 0.03:
			_escala_visual = escala
			queue_redraw()

func _draw() -> void:
	for i in range(1, puntos.size()):
		draw_set_transform(puntos[i], 0, Vector2.ONE * _escala_visual)
		var pos := Vector2.ZERO
		draw_circle(pos, 38, Color("ceb477"))
		draw_circle(pos, 26, Color("766041"))
		draw_circle(pos, 14, Color("211b15"))
		draw_arc(pos, 42, 0, TAU, 20, Color("9bb879"), 4)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-42, -52), tr("ENTRADA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("f3e4b9"))
	draw_set_transform(Vector2.ZERO)
