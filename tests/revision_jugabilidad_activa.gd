extends Node
var fallas := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Juego.reiniciar_estado()
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	if not Graficos.listo:
		await Graficos.preparado
	Juego.runs_jugadas = 12
	Juego.niveles = {"mas_obreras": 20, "mordida_madera": 1, "mandibulas": 15, "buche": 4, "excavar": 8, "entradas": 2}
	Juego._cache_stats.clear()
	Juego.sumar_estadistica("migas_totales", 250)
	for hito in ["primera_silla", "primer_tesoro", "primer_derrumbe"]:
		Juego.obtener_hito(hito)
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	for tam: Vector2i in [Vector2i(1920, 1080), Vector2i(1000, 620)]:
		get_window().size = tam
		tienda._corte_tierra.encuadrar(Rect2(420, 700, 950, 650), false, 1.1)
		await capturar("hormiguero", tam)
	tienda.queue_free()
	await get_tree().process_frame
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.poderes.carga_entregas = run.poderes.entregas_necesarias()
	for tam: Vector2i in [Vector2i(1920, 1080), Vector2i(1000, 620)]:
		get_window().size = tam
		run.hud._actualizar_poderes()
		await capturar("controles", tam)
		var pantalla := get_viewport().get_visible_rect()
		for boton in [run.hud._boton_entrada, run.hud._boton_rafaga]:
			comprobar(pantalla.encloses(boton.get_global_rect()), "poderes dentro de pantalla %s" % tam)
		comprobar(run.hud._boton_rafaga.disabled == false, "Ráfaga cargada disponible en %s" % tam)
	get_window().size = Vector2i(1920, 1080)
	run.iniciar_colocacion_entrada()
	await capturar("colocacion", Vector2i(1920, 1080))
	run.cancelar_colocacion_entrada()
	run.activar_rafaga()
	run.hud._actualizar_poderes()
	await capturar("rafaga", Vector2i(1920, 1080))
	run.queue_free()
	await get_tree().process_frame
	print("REVISIÓN JUGABILIDAD: %d fallas" % fallas)
	get_tree().quit(1 if fallas else 0)

func capturar(nombre: String, tam: Vector2i) -> void:
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/activa_%s_%dx%d.png" % [nombre, tam.x, tam.y])

func comprobar(ok: bool, texto: String) -> void:
	if not ok:
		fallas += 1
	print(("OK " if ok else "FALLA ") + texto)
