extends Node
## Diagnóstico reproducible de autonomía. No mide FPS ni acredita recursos.
## Etapas sintéticas para aislar conducta, no partidas previstas de jugadores.
const ETAPAS := {
	"inicio": {},
	"carton": {"mas_obreras": 2, "mandibulas": 2, "pisada": 2},
	"madera": {"mas_obreras": 6, "mandibulas": 4, "pisada": 4, "mordida_madera": 1, "patas_largas": 3, "buche": 2, "excavar": 2},
	"resistentes": {"mas_obreras": 18, "mandibulas": 15, "pisada": 15, "mordida_madera": 1, "mordida_resistente": 1, "patas_largas": 9, "buche": 5, "excavar": 8, "antenas": 5, "entradas": 2},
	"muros": {"mas_obreras": 25, "mandibulas": 22, "pisada": 22, "mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1, "patas_largas": 12, "buche": 8, "excavar": 13, "antenas": 7, "entradas": 3},
}

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Engine.max_fps = 0
	Engine.time_scale = 1
	for etapa: String in ETAPAS:
		for llamado in [false, true]:
			await medir(etapa, llamado)
	Juego.reiniciar_estado()
	get_tree().quit()

func medir(etapa: String, llamado: bool) -> void:
	Juego.reiniciar_estado()
	Juego.niveles = ETAPAS[etapa].duplicate()
	Juego._cache_stats.clear()
	seed(407)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.eventos.process_mode = Node.PROCESS_MODE_DISABLED
	run.feromonas.set_process_unhandled_input(false)
	var orden: Comida = run.objetivo_practica
	var punto := orden.position
	var muestra := 0.0
	var estados := [0, 0, 0, 0, 0, 0]
	var muestras := 0
	var quietas := 0
	var metas: Dictionary = {}
	var posiciones: Dictionary = {}
	var cambios := 0
	while not run.terminada:
		await get_tree().process_frame
		if llamado and run.activa and run.tiempo_jugado < 12:
			run.feromonas.mantener_en(punto)
		else:
			run.feromonas.soltar()
		muestra -= get_process_delta_time()
		if muestra > 0 or not run.activa or run.tiempo_jugado < 2:
			continue
		muestra = 1
		for h in run.colonia.hormigas:
			estados[h.estado] += 1
			muestras += 1
			var id := h.get_instance_id()
			var movio: bool = posiciones.has(id) and h.position.distance_squared_to(posiciones[id]) > 16
			if posiciones.has(id) and not movio and h.estado not in [Hormiga.Estado.MORDIENDO, Hormiga.Estado.QUIETA] and not (h.estado == Hormiga.Estado.SIGUIENDO and h.position.distance_squared_to(h.objetivo) < 400):
				quietas += 1
			var meta: int = h.comida.get_instance_id() if is_instance_valid(h.comida) else 0
			if metas.has(id) and metas[id] != meta:
				cambios += 1
			metas[id] = meta
			posiciones[id] = h.position
	print("AUTONOMIA %s %s: %s" % [etapa, "tras_llamado" if llamado else "sin_orden", JSON.stringify({"migas": Juego.migas_run, "ingresos": run.ingresos, "muestras": muestras, "estados": estados, "quietas": quietas, "cambios": cambios, "rutas": run.cocina.consultas_ruta, "astar": run.cocina.busquedas_astar})])
	run.queue_free()
	await get_tree().process_frame
