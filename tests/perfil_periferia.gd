extends Node
## Perfil gráfico, no prueba headless ni medición de economía.
## Dos fases consecutivas por destino: 200 cuadros de calentamiento y 360
## medidos. Incluye la IA de las 500, la cocina, la escala/visibilidad normal
## de la colonia y el paisaje en H. Sólo se detienen reloj/retiro y nacimientos.
## El atlas y el horneado inicial de navegación quedan fuera de la medición.
const CANTIDAD := 500
const CALENTAMIENTO := 200
const MEDICION := 360
const SEMILLA := 827
const RADIO := 12000.0
const TIPOS := ["obrera", "carpintera", "cargadora", "roja", "voladora", "demoledora"]
const CENTROS := [
	Vector2(-1070, 1670), Vector2(-1750, 1100),
	Vector2(3720, -980), Vector2(4000, -1500),
	Vector2(7020, 2100), Vector2(7550, 2900),
	Vector2(1150, 4620), Vector2(4100, 4900),
]

var run: Run
var _fallas := 0


func _init() -> void:
	Juego.guardado_habilitado = false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		_fallar("Perfil de periferia requiere renderer real; headless no mide FPS.")
		get_tree().quit(1)
		return
	Ajustes.pausar_sin_foco = false
	get_tree().paused = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not get_viewport().get_visible_rect().size.is_equal_approx(Vector2(1920, 1080)):
		_fallar("Ejecutá el perfil con --resolution 1920x1080: requiere el lienzo Full HD exacto.")
		get_tree().quit(1)
		return
	if not Graficos.listo or Graficos.textura == null:
		_fallar("El renderer debe terminar el atlas antes de medir.")
		get_tree().quit(1)
		return
	var atlas_mib := Graficos.textura.get_width() * Graficos.textura.get_height() * 4 / 1048576.0
	print("PERIFERIA CONFIG renderer %s | 1920x1080 | semilla %d | %d hormigas | 6 rutas/cuadro | %d warm + %d medición" % [RenderingServer.get_current_rendering_method(), SEMILLA, CANTIDAD, CALENTAMIENTO, MEDICION])
	print("ATLAS %dx%d | %.2f MiB RGBA8 | %d regiones (recurso compartido, no por destino)" % [Graficos.textura.get_width(), Graficos.textura.get_height(), atlas_mib, Graficos.regiones.size()])
	var destinos: Array = Mundos.ORDEN.duplicate()
	var solo := OS.get_environment("PERFIL_DESTINO")
	if not solo.is_empty():
		if not solo in Mundos.ORDEN:
			_fallar("PERFIL_DESTINO no corresponde a un destino conocido.")
			get_tree().quit(1)
			return
		destinos = [solo]
	for destino in destinos:
		if not _preparar(destino):
			break
		await _medir(destino, "H_sin_llamado", false)
		await _medir(destino, "H_llamado_puertas_y_patio", true)
		print("  COTAS %s: restos %d/%d | partículas %d/%d | textos %d/%d" % [destino, run.comidas.fragmentos.size(), Comidas.MAX_FRAGMENTOS, run.efectos._particulas.size(), Efectos.MAX_PARTICULAS, run.efectos._textos.size(), Efectos.MAX_TEXTOS])
		run.queue_free()
		await get_tree().process_frame
	print("Perfil de periferia: %d fallas. Las fases son consecutivas, no una comparación A/B." % _fallas)
	get_tree().quit(1 if _fallas else 0)


func _preparar(destino: String) -> bool:
	Juego.reiniciar_estado()
	seed(SEMILLA)
	Juego.lugar_actual = destino
	for id in Mundos.ORDEN:
		Juego.lugares_completados[id] = true
	Juego.niveles = {"entradas": 5, "mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1, "excavar": 30, "rastro_persistente": 10, "pisoton": 25}
	Juego._cache_stats.clear()
	run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	# La expedición no termina mientras se perfila. Las hormigas, cocina,
	# comida, destrucción, fragmentos, HUD y visibilidad siguen procesando.
	run.set_process(false)
	run.set_process_unhandled_input(false)
	run.feromonas.set_process_unhandled_input(false)
	run.camara.set_process_input(false)
	run.camara.set_process_unhandled_input(false)
	run.radio_actual = RADIO
	run.niebla.radio = RADIO
	# Evitar únicamente la escena de coronación/cámara lenta si comen la meta;
	# su material y destrucción siguen activos, sin cambiar vida ni recompensa.
	run.objetivo_completado = true
	run.colonia._por_salir = 0
	run.colonia._cola_castas.clear()
	run.colonia._intervalo_cria = 0.0
	run.camara.ver_casa()
	run.cocina.limite_rutas_por_cuadro = 6
	var destino_preparacion := run.cocina.ajustar_destino(Vector2(7450, 2000), RADIO)
	if destino_preparacion == Vector2.INF or run.cocina.ruta(Vector2.ZERO, destino_preparacion, RADIO).is_empty():
		_fallar(destino + ": no se pudo preparar una ruta real hacia la periferia.")
		run.queue_free()
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMILLA
	var exteriores := 0
	for i in CANTIDAD:
		var exterior := i % 2 == 0
		var pos := _posicion_inicial(rng, exterior)
		if pos == Vector2.INF:
			_fallar(destino + ": no se encontraron 500 posiciones válidas para distribuir la colonia.")
			run.queue_free()
			return false
		var h := run.colonia._nacer(TIPOS[i % TIPOS.size()], pos)
		h._velocidad = 300
		h._dano = 20
		h._capacidad = 6
		h._olfato = 180
		h._corte = h.casta == "carpintera"
		h._barrido = h.casta == "cargadora"
		h._elegir_destino_al_azar()
		exteriores += int(exterior)
	run.colonia._actualizar_escala()
	print("  DISTRIBUCIÓN %s: %d interiores + %d periferia, IA y cocina activas, H = zoom %.4f" % [destino, CANTIDAD - exteriores, exteriores, run.camara.zoom.x])
	return true


func _posicion_inicial(rng: RandomNumberGenerator, exterior: bool) -> Vector2:
	var r := PlanoCasa.limites().grow(-75) if exterior else PlanoCasa.LIMITES.grow(-90)
	for intento in 200:
		var pos := r.position + r.size * Vector2(rng.randf(), rng.randf())
		if exterior and PlanoCasa.LIMITES.has_point(pos):
			continue
		if pos.length() < RADIO - 40 and run.cocina.libre(pos, 24):
			return pos
	return Vector2.INF


func _medir(destino: String, fase: String, llamar: bool) -> void:
	var muestras: Array[float] = []
	var consultas := 0
	var astar := 0
	var max_pedidos := 0
	var dibujos := 0.0
	var seleccionadas := 0
	var anterior := Time.get_ticks_usec()
	for i in CALENTAMIENTO + MEDICION:
		if i == CALENTAMIENTO:
			consultas = run.cocina.consultas_ruta
			astar = run.cocina.busquedas_astar
			anterior = Time.get_ticks_usec()
		if llamar:
			var centro: Vector2 = CENTROS[(i / 60 as int) % CENTROS.size()]
			var destino_llamado := centro + Vector2(sin(i * 0.11) * 100, cos(i * 0.09) * 90)
			run.feromonas.mantener_en(destino_llamado)
		else:
			run.feromonas.soltar()
		await get_tree().process_frame
		var ahora := Time.get_ticks_usec()
		if i >= CALENTAMIENTO:
			muestras.append((ahora - anterior) / 1000.0)
			dibujos += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			max_pedidos = maxi(max_pedidos, run.cocina._pedidos_cuadro)
			seleccionadas = maxi(seleccionadas, run.feromonas.seleccionadas.size())
		anterior = ahora
	muestras.sort()
	var suma := 0.0
	for ms in muestras:
		suma += ms
	var consultas_reales := run.cocina.consultas_ruta - consultas
	var astar_real := run.cocina.busquedas_astar - astar
	var activas := 0
	var exteriores := 0
	for h in run.colonia.hormigas:
		if h.is_processing() and h.estado != Hormiga.Estado.QUIETA:
			activas += 1
		if not PlanoCasa.LIMITES.has_point(h.position):
			exteriores += 1
	print("PERIFERIA %s %s: media %.2f ms | p95 %.2f | peor %.2f | dibujos %.0f | hormigas %d/%d | seleccionadas máx %d" % [destino, fase, suma / muestras.size(), muestras[ceili(muestras.size() * 0.95) - 1], muestras.back(), dibujos / muestras.size(), activas, CANTIDAD, seleccionadas])
	print("  RUTAS %d consultas / %d A* en %d cuadros | pedidos/cuadro máx %d/6" % [consultas_reales, astar_real, MEDICION, max_pedidos])
	print("  DISTRIBUCIÓN AL CIERRE %d interiores + %d periferia" % [CANTIDAD - exteriores, exteriores])
	if get_tree().paused or not run.activa or not run.cocina.is_processing() or not run.colonia.is_processing() or run.colonia.cantidad() != CANTIDAD or activas != CANTIDAD:
		_fallar(destino + " " + fase + ": la medición requiere las 500 IA activas, colonia y cocina sin pausa.")
	if max_pedidos > 6 or consultas_reales <= 0:
		_fallar(destino + " " + fase + ": la navegación no respetó el presupuesto real o no tuvo actividad.")
	if not is_equal_approx(Engine.time_scale, 1.0):
		_fallar(destino + " " + fase + ": la simulación no mantuvo su paso normal.")
	if llamar and seleccionadas != 64:
		_fallar(destino + " " + fase + ": la fase de feromonas no mantuvo el llamado máximo.")


func _fallar(mensaje: String) -> void:
	_fallas += 1
	push_error(mensaje)
