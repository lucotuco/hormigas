extends Node
## Sólo tienda, renderer real Full HD y VSync desactivado. No simula expediciones.
## Descarta 90 cuadros de preparación y mide 360 por estado del hormiguero.
const CALENTAMIENTO := 90
const MUESTRAS := 360
var tienda: Control

func _ready() -> void:
	Juego.guardado_habilitado = false
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	Juego.usar_idioma("es")
	Juego.reiniciar_estado()
	Engine.time_scale = 1.0
	Engine.max_fps = 0
	if DisplayServer.get_name() == "headless":
		push_error("El perfil del hormiguero necesita renderer real; headless no mide su costo gráfico")
		get_tree().quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_window().size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if not Graficos.listo:
		await Graficos.preparado
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("HORMIGUERO contexto: ventana %s | viewport %s | VSync %d | calentamiento %d | muestras %d" % [get_window().size, get_viewport().get_visible_rect().size, DisplayServer.window_get_vsync_mode(), CALENTAMIENTO, MUESTRAS])
	tienda = preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	await medir("inicial")
	tienda.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	for id in Mundos.ORDEN:
		Juego.lugares_completados[id] = true
		Juego.coronas_cobradas[id] = true
	for id in Juego.REVELABLES:
		Juego.descubiertos[id] = true
	Juego.runs_jugadas = 50
	Juego.migas = 1e15
	for mejora in Juego.mejoras:
		Juego.niveles[mejora.id] = Juego.nivel_maximo(mejora.id)
	Juego._cache_stats.clear()
	tienda = preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	await medir("desarrollado")
	tienda.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	get_tree().quit()

func medir(nombre: String) -> void:
	for i in CALENTAMIENTO:
		await get_tree().process_frame
	var nodos_antes := contar_nodos(tienda)
	var ruta_inicial: Curve2D = tienda._animacion_hormiguero.rutas[0]
	var cuadros := PackedFloat64Array()
	var dibujos := 0.0
	var previo := Time.get_ticks_usec()
	for i in MUESTRAS:
		await get_tree().process_frame
		var ahora := Time.get_ticks_usec()
		cuadros.append((ahora - previo) / 1000.0)
		previo = ahora
		dibujos += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	cuadros.sort()
	var suma := 0.0
	for ms in cuadros:
		suma += ms
	var p95 := ceili(MUESTRAS * .95) - 1
	print("HORMIGUERO %s: media %.2f ms | p95 %.2f ms | peor %.2f ms | drawcalls %.0f" % [nombre, suma / MUESTRAS, cuadros[p95], cuadros[-1], dibujos / MUESTRAS])
	print("  Cotas: %d mejoras | %d rutas | %d hormigas visuales | nodos %d → %d | rutas retenidas %s" % [tienda._nodos_mejoras.size(), tienda._animacion_hormiguero.rutas.size(), mini(22, tienda._animacion_hormiguero.indices_rutas.size() * 2), nodos_antes, contar_nodos(tienda), str(tienda._animacion_hormiguero.rutas[0] == ruta_inicial)])

func contar_nodos(nodo: Node) -> int:
	var total := 1
	for hijo in nodo.get_children():
		total += contar_nodos(hijo)
	return total
