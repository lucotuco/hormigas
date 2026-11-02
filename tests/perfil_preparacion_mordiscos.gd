extends Node
## Primer contacto gráfico aislado. No representa FPS con500hormigas ni horas
## de campaña. Ejecutar solo y sin headless para medir también publicación R8.


func _ready() -> void:
	Juego.guardado_habilitado = false
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	get_tree().paused = false
	get_window().size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	assert(DisplayServer.get_name() != "headless", "Este perfil necesita el renderizador real")
	if not Graficos.listo:
		await Graficos.preparado
	for destino in ["coliseo", "eiffel"]:
		await medir(destino)
	get_tree().quit()


func medir(destino: String) -> void:
	Juego.reiniciar_estado()
	Juego.lugar_actual = destino
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var r: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(r)
	r.set_process(false)
	r.colonia.set_process(false)
	r.eventos.set_process(false)
	r.camara.set_process(false)
	var objetivo: PiezaCasa
	for parte: PiezaCasa in r.comidas.partes:
		if parte.pieza.get("meta", false):
			objetivo = parte
			break
	assert(objetivo != null and objetivo.mordiscos == null, "El objetivo debe empezar intacto y sin máscara preparada")
	r.camara.position = objetivo.rect_mundo.get_center()
	r.camara.zoom = Vector2.ONE * 0.3
	r.camara.force_update_scroll()
	for i in 90:
		await get_tree().process_frame
	var referencia := MordiscosMaterial.new()
	var inicio := Time.get_ticks_usec()
	referencia.configurar(objetivo.rect_mundo, objetivo.grilla, objetivo._material_por_celda, objetivo.vidas)
	var tiempo_sync := Time.get_ticks_usec() - inicio
	await get_tree().process_frame
	var desde := objetivo.rect_mundo.position + Vector2(-4, objetivo.rect_mundo.size.y * 0.5)
	inicio = Time.get_ticks_usec()
	objetivo.punto_contacto(desde)
	var solicitud := Time.get_ticks_usec() - inicio
	var tiempos: Array[float] = []
	var antes := Time.get_ticks_usec()
	for i in 1200:
		await get_tree().process_frame
		var ahora := Time.get_ticks_usec()
		tiempos.append((ahora - antes) / 1000.0)
		antes = ahora
		if objetivo.mordiscos != null:
			break
	assert(objetivo.mordiscos != null and objetivo.mordiscos.configuracion_lista, "La preparación debe terminar sin un fallback síncrono")
	assert(objetivo.mordiscos._pixeles == referencia._pixeles and objetivo.mordiscos._aire_bits == referencia._aire_bits and objetivo.mordiscos._frontera_arbol == referencia._frontera_arbol, "La preparación gráfica debe conservar material, aire y frontera")
	tiempo(tiempos, "%s/%s %s" % [destino, objetivo.pieza.tipo, objetivo.rect_mundo.size], tiempo_sync, solicitud, r.preparador_mordiscos, objetivo.mordiscos.tiempo_configuracion_usec)
	r.queue_free()
	await get_tree().process_frame


func tiempo(tiempos: Array[float], destino: String, sincrono: int, solicitud: int, preparador: PreparadorMordiscos, cpu: int) -> void:
	var suma := 0.0
	for ms in tiempos:
		suma += ms
	tiempos.sort()
	var p95 := tiempos[mini(tiempos.size() - 1, floori(tiempos.size() * 0.95))]
	print("PREPARACIÓN %s: sync %.3fms | solicitud %.3fms | %d cuadros | latencia %.3fms | CPUprep %.3fms | media %.3fms | p95 %.3fms | peor %.3fms | unidad %.3fms | servicio %.3fms | publicar %.3fms | material idéntico" % [destino, sincrono / 1000.0, solicitud / 1000.0, tiempos.size(), suma, cpu / 1000.0, suma / tiempos.size(), p95, tiempos.back(), preparador.max_unidad_usec / 1000.0, preparador.max_servicio_usec / 1000.0, preparador.max_publicacion_usec / 1000.0])
