extends Node
## Comparación de decisiones con el mismo presupuesto. No es benchmark de FPS
## ni asegura una estrategia óptima; ambas variantes reciben la misma orden.
func _ready() -> void:
	Juego.guardado_habilitado = false
	Sonido.silenciado = true
	for especialistas in [false, true]:
		Juego.reiniciar_estado()
		seed(417)
		Juego.niveles = {"mandibulas": 8, "buche": 4, "patas_largas": 4, "excavar": 8, "mordida_madera": 1, "reservas": 3}
		Juego._cache_stats.clear()
		Juego.migas = 1200
		if especialistas:
			Juego.comprar_casta("carpintera")
			Juego.comprar_casta("cargadora")
		Juego.comprar_lote("mas_obreras", 0)
		var gastado := 1200 - Juego.migas
		var r: Run = preload("res://mundo/run.tscn").instantiate()
		add_child(r)
		Engine.max_fps = 0
		r.set_process_unhandled_input(false)
		r.feromonas.set_process_unhandled_input(false)
		var reloj := 0.0
		while not r.terminada:
			await get_tree().process_frame
			reloj -= get_process_delta_time()
			if reloj <= 0 and r.activa:
				reloj = 0.3
				var elegida: PiezaCasa
				var distancia := INF
				for p in r.comidas.partes:
					if p.nivel_requerido == 1 and p.disponible() and p.en_territorio(r.radio_actual):
						var d := p.distancia_a(Vector2.ZERO)
						if d < distancia:
							distancia = d
							elegida = p
				if elegida != null:
					r.feromonas.mantener_en(elegida.position)
		print("COMPARACIÓN %s: gasto %.0f/1200 | %d obreras + %d especialistas | %.0f migas | %d partes | %.1f migas/s" % ["equipo mixto" if especialistas else "más obreras", gastado, int(Juego.stat("hormigas_iniciales")), Juego.total_especialistas(), Juego.migas_run, Juego.partes_destruidas_run, r.produccion_run])
		r.queue_free()
		await get_tree().process_frame
	Juego.reiniciar_estado()
	get_tree().quit()
