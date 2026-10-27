extends Node
## Cursor en movimiento: el caso que no cubría el benchmark de un llamado fijo.
var run: Run
var _cuadro := 0
var _centros: Array[Vector2] = [Vector2(-100, 300), Vector2(900, 300), Vector2(2300, 600), Vector2(1200, 2000), Vector2(3400, 2600), Vector2(5500, 1400)]

func _ready() -> void:
	Juego.guardado_habilitado = false
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	seed(417)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.set_process(false)
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
	get_tree().quit()

func medir(nombre: String, mover: bool, muebles := false) -> void:
	var muestras: Array[float] = []
	var consultas := run.cocina.consultas_ruta
	var busquedas := run.cocina.busquedas_astar
	var previo := Time.get_ticks_usec()
	for i in 240:
		if mover:
			var centro := _centros[(i / 40 as int) % _centros.size()]
			var punto := centro + Vector2(sin(i * 0.11) * 250, cos(i * 0.09) * 200)
			if muebles:
				punto = run.comidas.partes[(i / 12 as int) % run.comidas.partes.size()].position
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
	print("  Rutas: %d consultas / %d búsquedas A* en 240 cuadros" % [run.cocina.consultas_ruta - consultas, run.cocina.busquedas_astar - busquedas])
