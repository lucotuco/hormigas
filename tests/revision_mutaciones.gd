extends Node
## Revisión visual de la barra de néctar, el nivel y las cartas de mutación.
## Capturas en .godot/qa/mutaciones_*.png (1920×1080 y 1000×620).
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma(OS.get_environment("IDIOMA") if OS.has_environment("IDIOMA") else "es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Juego.reiniciar_estado()
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	if not Graficos.listo:
		await Graficos.preparado
	EvolucionRun.modo_automatico = "mejor"
	Juego.runs_jugadas = 8
	Juego.sumar_estadistica("niveles_comprados", 30)
	Juego.niveles = {"mas_obreras": 20, "mandibulas": 10, "patas_largas": 4}
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	get_window().size = Vector2i(1920, 1080)
	for i in 240:
		await get_tree().process_frame
	var e := run.evolucion
	EvolucionRun.modo_automatico = "jugador"
	e.nectar = 0.0
	e.sumar_nectar(e.necesario * 0.7)
	await capturar("barra", Vector2i(1920, 1080))
	e.sumar_nectar(e.necesario * 0.31)
	for i in 8:
		await get_tree().process_frame
	await capturar("nivel", Vector2i(1920, 1080))
	e.elegidas = {"mandibulas_sierra": 2, "ojo_certero": 1}
	e._demora_oferta = -1.0
	e._ofrecer()
	# Una oferta fija para revisar las cuatro rarezas a la vez.
	e.oferta = [e.carta(Juego.mutaciones_por_id["mandibulas_sierra"], "comun"),
		e.carta(Juego.mutaciones_por_id["fuerza_enjambre"], "epica"),
		e.carta(Juego.mutaciones_por_id["marea_negra"], "legendaria")]
	e.oferta[0].veces = 2
	e._ui.mostrar(e.oferta)
	for tam: Vector2i in [Vector2i(1920, 1080), Vector2i(1000, 620)]:
		get_window().size = tam
		for i in 30:
			await get_tree().process_frame
		await capturar("cartas", tam)
		var pantalla := get_viewport().get_visible_rect()
		for carta in e._ui._cartas:
			comprobar(pantalla.encloses(carta.get_global_rect()), "carta dentro de pantalla %s" % tam)
	get_window().size = Vector2i(1920, 1080)
	e._ui._elegir(2)
	for i in 40:
		await get_tree().process_frame
	await capturar("despues", Vector2i(1920, 1080))
	comprobar(not get_tree().paused, "elegir despausa")
	run.queue_free()
	await get_tree().process_frame
	print("REVISIÓN MUTACIONES: %d fallas" % fallas)
	get_tree().quit(1 if fallas else 0)


func capturar(nombre: String, tam: Vector2i) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/mutaciones_%s_%dx%d.png" % [nombre, tam.x, tam.y])


func comprobar(ok: bool, texto: String) -> void:
	if not ok:
		fallas += 1
	print(("OK " if ok else "FALLA ") + texto)
