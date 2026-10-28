extends Node
## Render real: 500 hormigas, entradas y adaptaciones en los seis destinos.
func _ready() -> void:
	Juego.guardado_habilitado = false
	Ajustes.pausar_sin_foco = false
	get_tree().paused = false
	Sonido.silenciado = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for destino in Mundos.ORDEN:
		Juego.reiniciar_estado()
		seed(827)
		Juego.lugar_actual = destino
		for id in Mundos.ORDEN:
			Juego.lugares_completados[id] = true
		Juego.niveles = {"entradas": 5, "mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1, "excavar": 30, "rastro_persistente": 10, "pisoton": 10}
		Juego._cache_stats.clear()
		var r: Run = preload("res://mundo/run.tscn").instantiate()
		add_child(r)
		Engine.max_fps = 0
		r.set_process(false)
		r.set_process_unhandled_input(false)
		r.colonia.set_process(false)
		r.feromonas.set_process_unhandled_input(false)
		r.camara.set_process(false)
		r.camara.set_process_input(false)
		r.camara.set_process_unhandled_input(false)
		r.camara.zoom = Vector2.ONE * 0.28
		r.camara.position = Vector2(1200, 700)
		r.camara.force_update_scroll()
		for i in 500:
			var origen := r.entradas.puntos[i % r.entradas.puntos.size()]
			var h := r.colonia._nacer(["obrera", "carpintera", "cargadora", "roja", "voladora", "demoledora"][i % 6], origen)
			h._velocidad = 300
			h._dano = 20
			h._capacidad = 6
			h._olfato = 180
			h._corte = h.casta == "carpintera"
			h._barrido = h.casta == "cargadora"
		for i in 90:
			await get_tree().process_frame
		var tiempos: Array[float] = []
		var antes := Time.get_ticks_usec()
		var max_pedidos := 0
		for i in 360:
			if i % 30 == 0:
				r.feromonas.mantener_en(Vector2(450 + sin(i * 0.04) * 400, 150))
			await get_tree().process_frame
			var ahora := Time.get_ticks_usec()
			tiempos.append((ahora - antes) / 1000.0)
			antes = ahora
			max_pedidos = maxi(max_pedidos, r.cocina._pedidos_cuadro)
		tiempos.sort()
		assert(not get_tree().paused and r.colonia.cantidad() == 500 and r.cocina.consultas_ruta > 0, "El benchmark requiere 500 hormigas activas y navegación real")
		var media := 0.0
		for ms in tiempos:
			media += ms
		print("LOGÍSTICA CORTE %s: %.2f ms media | %.2f p95 | %.2f peor | entradas %d | rutas/cuadro máx %d | migas %s" % [destino, media / tiempos.size(), tiempos[341], tiempos.back(), r.entradas.puntos.size() - 1, max_pedidos, Juego.formatear(Juego.migas_run)])
		r.queue_free()
		await get_tree().process_frame
	get_tree().quit()
