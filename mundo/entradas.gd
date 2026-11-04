class_name EntradasHormiguero
extends Node2D
## El nido, hasta seis accesos manuales y uno adelantado por proyecto: ocho
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
var _normales := 0
var _id_proyecto := ""
var _nombre_proyecto := ""
var _ancla_proyecto := Vector2.INF
var _version_busqueda := -1
var _radio_busqueda := -1.0
var _puntos_busqueda := -1
var _reloj := 0.0
var _escala_visual := 1.0
## Reintenta las posiciones pendientes sólo al cambiar territorio, cupos o
## geometría. El layout completo vive en Juego; _manuales sólo son las activas.
var _repuestas := false
var _manuales: Array[Vector2] = []
var _version_repuesta := -1
var _radio_repuesto := -1.0
var _cupos_repuestos := -1
var _indice_reubicacion := -1
var _mostrar_guardadas := false

func iniciar(r: Run) -> void:
	run = r
	z_index = -2
	_preparar_proyecto()
	actualizar()

func actualizar() -> void:
	if not is_instance_valid(run) or not run.activa:
		return
	# Primero se recupera lo elegido por el jugador. El premio de proyecto
	# busca un desvío si su ancla coincide con una de esas entradas guardadas.
	_reponer_guardadas()
	_actualizar_proyecto()


## Vuelve a poner donde estaban las entradas que el jugador ya colocó. Si una
## quedó inválida (territorio más chico, menos cupos) se saltea sin moverla.
func _reponer_guardadas() -> void:
	var cupos := clampi(int(Juego.stat("entradas")), 0, MAX_NORMALES)
	if _repuestas and _version_repuesta == run.cocina.version and is_equal_approx(_radio_repuesto, run.radio_actual) and _cupos_repuestos == cupos:
		return
	_repuestas = true
	_version_repuesta = run.cocina.version
	_radio_repuesto = run.radio_actual
	_cupos_repuestos = cupos
	var agregadas := false
	for pos in Juego.entradas_de(Juego.lugar_actual):
		# Levantar una entrada reserva su cupo hasta colocarla o cancelar.
		# No activar otra histórica en medio de ese movimiento explícito.
		if disponibles() <= int(_indice_reubicacion >= 0):
			break
		if _manuales.has(pos):
			continue
		if puede_colocar(pos):
			puntos.append(pos)
			_manuales.append(pos)
			_normales += 1
			agregadas = true
	if agregadas:
		queue_redraw()


func hay_guardadas() -> bool:
	return not Juego.entradas_colocadas.get(Juego.lugar_actual, []).is_empty()


func mostrar_guardadas(mostrar: bool) -> void:
	if _mostrar_guardadas != mostrar:
		_mostrar_guardadas = mostrar
		queue_redraw()


func cancelar_reubicacion() -> void:
	if _indice_reubicacion >= 0:
		_indice_reubicacion = -1
		_repuestas = false
	mostrar_guardadas(false)


func disponibles() -> int:
	return maxi(0, clampi(int(Juego.stat("entradas")), 0, MAX_NORMALES) - _normales)


func puede_colocar(pos: Vector2) -> bool:
	if not is_instance_valid(run) or not run.activa or run.terminada or disponibles() <= 0 or not pos.is_finite():
		return false
	var guardadas := Juego.entradas_de(Juego.lugar_actual)
	# Una histórica inactiva también reserva su lugar entre las seis. Para
	# cambiarla hay que levantar ESA posición, nunca sobrescribir otra oculta.
	if guardadas.size() >= MAX_NORMALES and not guardadas.has(pos):
		return false
	if pos.length() + MARGEN_ACCESO > run.radio_actual or not run.cocina.libre(pos, MARGEN_ACCESO):
		return false
	for punto in puntos:
		if punto.distance_squared_to(pos) < 96.0 * 96.0:
			return false
	return true


## Usa exactamente el piso elegido: nunca cambia una ruta de regreso previa.
func colocar(pos: Vector2) -> bool:
	if not puede_colocar(pos):
		return false
	puntos.append(pos)
	_manuales.append(pos)
	_normales += 1
	var guardadas := Juego.entradas_de(Juego.lugar_actual)
	if not guardadas.has(pos):
		# Conservar su prioridad al moverla: una entrada primera no termina
		# detrás de cinco históricas que la colonia todavía no puede activar.
		if _indice_reubicacion >= 0:
			guardadas.insert(mini(_indice_reubicacion, guardadas.size()), pos)
		else:
			guardadas.append(pos)
		Juego.guardar_entradas(Juego.lugar_actual, guardadas)
	_indice_reubicacion = -1
	queue_redraw()
	return true


## Incluye las históricas inactivas, visibles tenues durante el modo N: así
## se puede liberar/mover un slot aunque ninguna entrada haya podido reponerse.
func manual_en(pos: Vector2) -> Vector2:
	for punto in Juego.entradas_de(Juego.lugar_actual):
		if punto.distance_squared_to(pos) <= MARGEN_ACCESO * MARGEN_ACCESO * 1.5:
			return punto
	return Vector2.INF


func puede_levantar(pos: Vector2) -> bool:
	var punto := manual_en(pos)
	# Una activa devuelve su cupo. Una histórica inactiva no lo devuelve:
	# no ofrecer moverla si la colonia no podría colocar su reemplazo.
	return punto != Vector2.INF and (_manuales.has(punto) or disponibles() > int(_indice_reubicacion >= 0))


## Levanta una entrada manual para moverla: libera su cupo y la olvida.
## Las hormigas que volvían hacia una activa reciben un nuevo destino real.
func quitar(pos: Vector2) -> bool:
	var punto := manual_en(pos)
	if punto == Vector2.INF or not puede_levantar(pos):
		return false
	var guardadas := Juego.entradas_de(Juego.lugar_actual)
	_indice_reubicacion = guardadas.find(punto)
	guardadas.remove_at(_indice_reubicacion)
	Juego.guardar_entradas(Juego.lugar_actual, guardadas)
	if _manuales.has(punto):
		_manuales.erase(punto)
		puntos.erase(punto)
		_normales -= 1
		# Primero deja de ser un destino válido; después se reasignan sólo
		# sus retornos, sin ejecutar A* fuera de la cola presupuestada normal.
		run.colonia.reasignar_entrada_quitada(punto)
	queue_redraw()
	return true


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
	if _mostrar_guardadas:
		for punto in Juego.entradas_de(Juego.lugar_actual):
			if _manuales.has(punto):
				continue
			# Se distinguen de las bocas activas y sólo aparecen al editar.
			# Conservan su radio de selección real, aunque estén fuera del alcance.
			draw_circle(punto, MARGEN_ACCESO, Color(Color("ceb477"), 0.09))
			draw_arc(punto, MARGEN_ACCESO, 0, TAU, 24, Color(Color("ceb477"), 0.55), 2.0)
