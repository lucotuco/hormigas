extends Node
## Revisión visual del menú, la configuración, las estadísticas y la pausa.
## Guarda en .godot/qa/. Con IDIOMA=en, en inglés.
##   godot --path . res://tests/revision_menu.tscn
func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma(OS.get_environment("IDIOMA") if OS.has_environment("IDIOMA") else "es")  # IDIOMA=en para revisar en inglés
	Sonido.silenciado = true
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	if not Graficos.listo and DisplayServer.get_name() != "headless":
		await Graficos.preparado
	Juego.reiniciar_estado()
	Juego.runs_jugadas = 37
	Juego.fundaciones = 2
	Juego.jalea = 31
	Juego.legado = 60
	Juego.lugares_completados = {"casa": true, "restaurante": true}
	Juego.lugar_actual = "museo"
	Juego.estadisticas = {"migas_totales": 4.6e9, "migas_gastadas": 4.1e9, "tiempo_total": 9815.0, "tiempo_en_runs": 7420.0,
		"comidas_devoradas": 18234, "partes_devoradas": 912, "pisotones": 23011, "derrumbes": 57, "hormigas_nacidas": 41250,
		"mayor_colonia": 500, "mejor_combo": 214, "objetivos_conquistados": 4, "coronas_ganadas": 9, "niveles_comprados": 1460,
		"castas_reclutadas": 160, "jalea_gastada": 29}
	Juego.mejor_run = 3.2e8
	var menu: Control = preload("res://ui/menu.tscn").instantiate()
	add_child(menu)
	await captura("menu")
	menu.abrir_configuracion()
	await captura("menu_configuracion")
	menu.abrir_estadisticas()
	await captura("menu_estadisticas")
	menu.queue_free()
	Juego.lugar_actual = "casa"
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	for i in 30:
		await get_tree().process_frame
	run.hud.pausar()
	await captura("pausa")
	run.hud.reanudar()
	run.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + ".png")
	print(nombre)
