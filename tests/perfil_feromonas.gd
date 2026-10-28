extends Node
## Cursor en movimiento: el caso que no cubría el benchmark de un llamado fijo.
var run: Run
var _cuadro := 0
var _fallas := 0
var _centros: Array[Vector2] = [Vector2(-100, 300), Vector2(900, 300), Vector2(2300, 600), Vector2(1200, 2000), Vector2(3400, 2600), Vector2(5500, 1400)]

func _ready() -> void:
	Juego.guardado_habilitado = false
	Ajustes.pausar_sin_foco = false
	Juego.usar_idioma("es")  # las verificaciones leen textos en español
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	seed(417)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.set_process(false)
	run.set_process_unhandled_input(false)
	run.feromonas.set_process_unhandled_input(false)
	run.camara.set_process_input(false)
	run.camara.set_process_unhandled_input(false)
	run.colonia.set_process(false)
	run.radio_actual = 9500
	run.niebla.radio = 9500
	run.camara.ver_casa()
	# Separar la preparación inicial del costo de sostener y mover el llamado.
	run.cocina.ruta(Vector2.ZERO, Vector2(6000, 4000), 9500)
	for i in 500:
		var h := run.colonia._nacer()
		var p := Vector2(randf_range(-500, 6200), randf_range(-500, 3900))
		h.position = run.cocina.ajustar_destino(p, 9500)
		h._velocidad = 240
		h._meta_ruta = Vector2.INF
	await medir("sin_llamado", false)
	await medir("cursor_24", true)
	Juego.niveles.rastro_persistente = 10
	Juego.niveles.pisoton = 25
	Juego._cache_stats.clear()
	await medir("cursor_maximo", true)
	# Un mueble bloqueado también debe permitir reunir hormigas sin romperlo.
	await medir("cursor_sobre_muebles", true, true)
	# Son fases consecutivas de estrés, no una comparación controlada con las
	# anteriores: el mundo y la carga de trabajo ya evolucionaron entre medidas.
	# Reunir sólo 64; las otras 436 mantienen su IA y el presupuesto de rutas.
	var suelo := _buscar_suelo()
	if suelo == Vector2.INF:
		push_error("No se encontró suelo libre para medir la recuperación del llamado")
		get_tree().quit(1)
		return
	_preparar_cercanas(suelo)
	await medir("suelo_sin_objetivo_64", true, false, suelo)
	var datos: Dictionary = Juego.comidas[0].duplicate()
	datos.vida = 1000000.0
	run.comidas._crear(datos, suelo, 641)
	var transitoria: Comida = run.comidas.lista.back()
	_preparar_cercanas(suelo)
	await medir("objetivo_agotado_64", true, false, suelo, transitoria)
	get_tree().quit(0 if _fallas == 0 else 1)

func _buscar_suelo() -> Vector2:
	for y in [200, 300, 400, 500]:
		for x in [-500, -400, -300, -200]:
			var punto := Vector2(x, y)
			if run.cocina.libre(punto, 32) and run.comidas.comida_en(punto, run.radio_actual) == null:
				return punto
	return Vector2.INF

func _preparar_cercanas(punto: Vector2) -> void:
	# No intervienen amenazas durante estos dos escenarios de IA. La prueba
	# no mide economía: se descarta la carga sólo de las 64 reubicadas.
	run.eventos.process_mode = Node.PROCESS_MODE_DISABLED
	while run.colonia.cantidad() < 500:
		run.colonia._nacer()
	for i in 64:
		var h := run.colonia.hormigas[i]
		h.comida = null
		h._recuerdo = null
		h.carga = 0
		h._carga_origen.fill(0.0)
		h._material_carga = -1
		h.bocados = 0
		h.estado = Hormiga.Estado.EXPLORANDO
		h.position = punto + Vector2.from_angle(i * TAU / 64.0) * (2 + i % 7)
		h._proxima_busqueda_llamado = 0
		h._comidas_sin_ruta.clear()
		h._elegir_destino_al_azar()
	run.feromonas.mantener_en(punto)
	run.feromonas._actualizar_cercanas()

func medir(nombre: String, mover: bool, muebles := false, fijo := Vector2.INF, agotar: Comida = null) -> void:
	var muestras: Array[float] = []
	var consultas := run.cocina.consultas_ruta
	var busquedas := run.cocina.busquedas_astar
	var cuadros_rutas := 240
	var previo := Time.get_ticks_usec()
	for i in 240:
		if i == 40 and is_instance_valid(agotar):
			# Simular que otra recolectora agota el alimento. No hay input de
			# daño ni clic automático: se conserva el llamado sobre ese lugar.
			agotar.morder(agotar.vida)
			_preparar_cercanas(fijo)
			# La recolocación y la invalidación son preparación, no una muestra.
			previo = Time.get_ticks_usec()
		if i == 40 and fijo != Vector2.INF:
			consultas = run.cocina.consultas_ruta
			busquedas = run.cocina.busquedas_astar
			cuadros_rutas = 200
		if mover:
			var centro := _centros[(i / 40 as int) % _centros.size()]
			var punto := centro + Vector2(sin(i * 0.11) * 250, cos(i * 0.09) * 200)
			if muebles:
				punto = run.comidas.partes[(i / 12 as int) % run.comidas.partes.size()].position
			if fijo != Vector2.INF:
				punto = fijo
			run.feromonas.mantener_en(punto)
		else:
			run.feromonas.soltar()
		await get_tree().process_frame
		var ahora := Time.get_ticks_usec()
		if i >= 40:
			muestras.append((ahora - previo) / 1000.0)
		previo = ahora
		_cuadro += 1
	muestras.sort()
	var suma := 0.0
	for ms in muestras:
		suma += ms
	print("FEROMONAS %s: media %.2f ms | p95 %.2f | peor %.2f | seleccionadas %d" % [nombre, suma / muestras.size(), muestras[189], muestras.back(), run.feromonas.seleccionadas.size()])
	print("  Rutas: %d consultas / %d búsquedas A* en %d cuadros" % [run.cocina.consultas_ruta - consultas, run.cocina.busquedas_astar - busquedas, cuadros_rutas])
	if fijo != Vector2.INF:
		var orden_conservada := run.feromonas.activa and run.feromonas.posicion == fijo and run.feromonas.seleccionadas.size() == 64
		if not orden_conservada or run.colonia.cantidad() != 500:
			_fallas += 1
			push_error("La fase %s no conservó la orden con 64 seleccionadas y 500 hormigas activas" % nombre)
