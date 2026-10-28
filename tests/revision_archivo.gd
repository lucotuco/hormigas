extends Node
## Revisión con renderer de archivo, paginado y resultado de limpieza.
var fallas := 0
var total := 0

func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("OK " if ok else "FALLA ", detalle)

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma(OS.get_environment("IDIOMA") if OS.has_environment("IDIOMA") else "es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if not Graficos.listo:
		await Graficos.preparado
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	Juego.reiniciar_estado()
	for i in 15:
		Juego.runs_jugadas += 1
		Juego.registrar_limpieza({"destino": Mundos.ORDEN[i % 6], "dieta": i % 4,
			"territorio": 620 + i * 240.0, "version_mapa": Mundos.VERSION_CONTENIDO,
			"completa": i % 4 == 3, "tiempo_limpieza": 18.25 + i * 1.2,
			"tiempo_total": 20.75 + i * 1.2, "migas": 1234.0 * (i + 1), "produccion": 90.0, "pendiente": 0.0})
	var archivo := PanelArchivo.new()
	add_child(archivo)
	for tam in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1000, 620)]:
		get_window().size = tam
		await captura("archivo_%d" % tam.x)
		var area := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		verificar(area.encloses(archivo._panel.get_global_rect()), "archivo y cierre dentro de pantalla a %d" % tam.x)
		verificar(archivo._lista.get_child_count() <= PanelArchivo.POR_PAGINA and not archivo._exportar.disabled, "página acotada y exportación disponible a %d" % tam.x)
	archivo.queue_free()
	await get_tree().process_frame
	Juego.lugar_actual = "casa"
	Juego.niveles = {"mandibulas": 4, "mordida_madera": 1}
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.limpieza_lograda = true
	run.limpieza_registrada = true
	run.nuevo_record_limpieza = true
	run.tiempo_limpieza = 18.25
	run.tiempo_jugado = 18.5
	run.tiempo_retirada = 2.5
	run.produccion_run = 91
	run.cargas_pendientes = 14
	Juego.migas_run = 1911
	Juego.migas = 11923
	Juego.migas_colonia = 100000
	for tam in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1000, 620)]:
		get_window().size = tam
		run.hud.mostrar_fin()
		for i in 4:
			await get_tree().process_frame
		run.hud._panel_fin.modulate.a = 1
		run.hud._panel_fin.scale = Vector2.ONE
		await captura("limpieza_resultado_%d" % tam.x)
		var area := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		verificar(area.encloses(run.hud._panel_fin.get_global_rect()), "el resultado completo y sus botones caben a %d" % tam.x)
	run.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	print("Revisión archivo: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)

func captura(nombre: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var idioma := "_en" if TranslationServer.get_locale().begins_with("en") else ""
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + idioma + ".png")
