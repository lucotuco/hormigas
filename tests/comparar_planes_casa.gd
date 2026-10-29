extends Node
## Diagnóstico de especialización, no benchmark gráfico ni test de victoria.
## Compara el mismo presupuesto y órdenes en tres semillas. Las diferencias
## de admisión temporal de rutas impiden tratarlo como una predicción humana.
const PRESUPUESTO := 2400.0
const SEMILLAS := [417, 418, 419]
const PLANES := ["obreras", "corte", "corte_barrido"]
const RUN := preload("res://mundo/run.tscn")


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Engine.max_fps = 0
	Engine.time_scale = 1.0
	var resultados: Array[Dictionary] = []
	for semilla in SEMILLAS:
		for plan in PLANES:
			var dato: Dictionary = await medir(plan, semilla)
			resultados.append(dato)
			print("PLAN CASA %s" % JSON.stringify(dato))
	for plan in PLANES:
		var produccion := 0.0
		var madera := 0.0
		var piezas := 0.0
		for dato in resultados:
			if dato.plan == plan:
				produccion += dato.produccion / SEMILLAS.size()
				madera += dato.ingresos[1] / SEMILLAS.size()
				piezas += float(dato.piezas) / SEMILLAS.size()
		print("PROMEDIO CASA %s: %.1f migas/s · %.0f ingresos de muebles (incluyen bonus) · %.1f piezas" % [plan, produccion, madera, piezas])
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	var archivo := FileAccess.open("res://.godot/qa/comparar_planes_casa.json", FileAccess.WRITE)
	archivo.store_string(JSON.stringify({"paso": 1.0 / 60.0, "escala_tiempo": 1, "presupuesto": PRESUPUESTO, "resultados": resultados}, "\t"))
	Juego.reiniciar_estado()
	get_tree().quit()


func medir(plan: String, semilla: int) -> Dictionary:
	Juego.reiniciar_estado()
	seed(semilla)
	Juego.niveles = {"mandibulas": 8, "buche": 4, "patas_largas": 4, "excavar": 8, "mordida_madera": 1, "reservas": 3}
	Juego._cache_stats.clear()
	Juego.migas = PRESUPUESTO
	if plan != "obreras":
		Juego.comprar_casta("carpintera")
		Juego.comprar_castas_lote("cargadora", 3 if plan == "corte_barrido" else 1)
	Juego.comprar_lote("mas_obreras", 0)
	var dato := {"plan": plan, "semilla": semilla, "presupuesto": PRESUPUESTO, "gasto": PRESUPUESTO - Juego.migas,
		"obreras": int(Juego.stat("hormigas_iniciales")), "especialistas": Juego.reclutadas.duplicate(), "evoluciones": Juego.evoluciones_equipadas.duplicate()}
	var r: Run = RUN.instantiate()
	add_child(r)
	r.set_process_unhandled_input(false)
	r.feromonas.set_process_unhandled_input(false)
	var reloj := 0.0
	while not r.terminada:
		await get_tree().process_frame
		reloj -= get_process_delta_time()
		if reloj > 0 or not r.activa or r.retirando:
			continue
		reloj = 0.5
		var elegida: PiezaCasa
		var distancia := INF
		for parte in r.comidas.partes:
			if parte.nivel_requerido != 1 or not parte.disponible() or not parte.en_territorio(r.radio_actual):
				continue
			var punto := parte.punto_mordida(Vector2.ZERO, r.radio_actual)
			if punto != Vector2.INF and punto.length_squared() < distancia:
				distancia = punto.length_squared()
				elegida = parte
		if elegida != null:
			r.feromonas.mantener_en(elegida.punto_mordida(Vector2.ZERO, r.radio_actual))
		else:
			r.feromonas.soltar()
	dato.migas = Juego.migas_run
	dato.ingresos = r.ingresos.duplicate()
	dato.piezas = Juego.partes_destruidas_run
	dato.produccion = r.produccion_run
	dato.pendiente = r.cargas_pendientes
	dato.duracion = r.tiempo_jugado + r.tiempo_retirada
	r.queue_free()
	await get_tree().process_frame
	return dato
