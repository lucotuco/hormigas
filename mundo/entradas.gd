class_name EntradasHormiguero
extends Node2D
## El nido, hasta seis accesos normales y uno adelantado por proyecto: ocho
## puntos como máximo. Elegir sigue siendo O(8), sólo al iniciar un regreso.
## Las rutas usan la cola de la colonia, nunca otro A* en paralelo.
const MAX_NORMALES := 6
const MARGEN_ACCESO := 40.0
## Búsqueda local acotada; no proyecta hacia otro ambiente ni usa A*.
const DESVIOS_PROYECTO := [Vector2.ZERO,
	Vector2(96, 0), Vector2(-96, 0), Vector2(0, 96), Vector2(0, -96),
	Vector2(96, 96), Vector2(-96, 96), Vector2(96, -96), Vector2(-96, -96),
	Vector2(192, 0), Vector2(-192, 0), Vector2(0, 192), Vector2(0, -192),
	Vector2(192, 192), Vector2(-192, 192), Vector2(192, -192), Vector2(-192, -192),
	Vector2(288, 0), Vector2(-288, 0), Vector2(0, 288), Vector2(0, -288)]
var run: Run
var puntos: Array[Vector2] = [Vector2.ZERO]
var punto_proyecto := Vector2.INF
var _candidatas: Array[Dictionary] = []
var _normales := 0
var _id_proyecto := ""
var _nombre_proyecto := ""
var _ancla_proyecto := Vector2.INF
var _version_busqueda := -1
var _radio_busqueda := -1.0
var _puntos_busqueda := -1
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
	_preparar_proyecto()
	actualizar()

func actualizar() -> void:
	var limite := clampi(int(Juego.stat("entradas")), 0, MAX_NORMALES)
	for candidata in _candidatas:
		if _normales >= limite:
			break
		var pos: Vector2 = candidata.pos
		if pos.length() + MARGEN_ACCESO > run.radio_actual or puntos.has(pos):
			continue
		puntos.append(pos)
		_normales += 1
		queue_redraw()
		run.hud.mostrar_aviso(tr("Nueva entrada · %s") % tr(candidata.nombre).to_lower())
	_actualizar_proyecto()


## Ancla estable del último objeto declarado, no del orden en que se comió.
## Usa el rectángulo original aunque el objetivo ya no exista al cargar.
func _preparar_proyecto() -> void:
	for proyecto in ProyectosCampana.del_destino(Juego.lugar_actual):
		if int(proyecto.entrada) != 1 or proyecto.objetivos.is_empty():
			continue
		var ultimo: Dictionary = proyecto.objetivos.back()
		for mueble: Dictionary in Mundos.plano(Juego.lugar_actual).muebles:
			var rect: Rect2 = mueble.rect
			if mueble.tipo == ultimo.tipo and rect.position.distance_squared_to(ultimo.pos) < 0.01:
				_id_proyecto = proyecto.id
				_nombre_proyecto = proyecto.nombre
				_ancla_proyecto = rect.get_center()
				return
		# Sólo puede haber un premio logístico por destino. Si sus datos fueran
		# inválidos no se inventa una entrada en otro proyecto o en el origen.
		return


func _actualizar_proyecto() -> void:
	if punto_proyecto != Vector2.INF or _id_proyecto.is_empty() or _ancla_proyecto == Vector2.INF:
		return
	if not Juego.proyecto_completo(_id_proyecto) or _ancla_proyecto.length() + MARGEN_ACCESO > run.radio_actual:
		return
	# Un hueco bloqueado se reconsidera sólo si cambia geometría, territorio
	# o accesos. Después de resolverlo jamás se mueve, ni al abrir otra ruta.
	if _version_busqueda == run.cocina.version and is_equal_approx(_radio_busqueda, run.radio_actual) and _puntos_busqueda == puntos.size():
		return
	_version_busqueda = run.cocina.version
	_radio_busqueda = run.radio_actual
	_puntos_busqueda = puntos.size()
	for desvio: Vector2 in DESVIOS_PROYECTO:
		var pos := _ancla_proyecto + desvio
		if pos.length() + MARGEN_ACCESO > run.radio_actual or not run.cocina.libre(pos, MARGEN_ACCESO):
			continue
		var separada := true
		# Reservar también candidatas normales futuras: el proyecto no consume
		# uno de los seis espacios comprados si se revela antes que ellos.
		for candidata in _candidatas:
			if pos.distance_squared_to(candidata.pos) < 96.0 * 96.0:
				separada = false
				break
		if not separada:
			continue
		for punto in puntos:
			if pos.distance_squared_to(punto) < 96.0 * 96.0:
				separada = false
				break
		if not separada:
			continue
		punto_proyecto = pos
		puntos.append(pos)
		queue_redraw()
		run.hud.mostrar_aviso(tr("Nueva entrada · %s") % tr(_nombre_proyecto).to_lower())
		return

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
