extends Node
## Recorrido gráfico de la nueva progresión, sin tocar el guardado.
func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma(OS.get_environment("IDIOMA") if OS.has_environment("IDIOMA") else "es")  # IDIOMA=en para revisar en inglés
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	seed(445)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	var silla: PiezaCasa
	var muro: PiezaCasa
	for parte in run.comidas.partes:
		if parte.pieza.clave == "mueble:6":
			silla = parte
		if parte.pieza.pared and parte.rect_mundo.has_point(Vector2(1700, -300)):
			muro = parte
	run.hud._process(0)
	run.hud.mostrar_inspeccion(silla)
	await captura("material_bloqueado")
	Juego.niveles = {"mandibulas": 4, "mordida_madera": 1}
	Juego._cache_stats.clear()
	for i in 16:
		var h := run.colonia._nacer("obrera", Vector2(25, -120 + i * 16))
		h._capacidad = 50
	run.feromonas.mantener_en(silla.position)
	for paso in 45:
		run.feromonas._process(0.1)
		for h in run.colonia.hormigas:
			h._process(0.1)
		for parte in run.comidas.partes.duplicate():
			parte._process(0.1)
		run.cocina.procesar_cambios()
	run.colonia._actualizar_escala()
	run.hud._process(0.5)
	run.hud.mostrar_inspeccion(silla)
	await captura("silla_devorandose")
	for paso in 180:
		run.feromonas._process(0.1)
		for h in run.colonia.hormigas:
			h._process(0.1)
		for parte in run.comidas.partes.duplicate():
			parte._process(0.1)
		run.cocina.procesar_cambios()
		if silla.muerta:
			break
	run.hud._process(0.5)
	run.hud.mostrar_inspeccion(null)
	await captura("silla_devorada")
	run.feromonas.limpiar()
	Juego.niveles.mordida_resistente = 1
	Juego.niveles.mordida_muros = 1
	Juego._cache_stats.clear()
	run.radio_actual = 9500
	run.niebla.radio = 9500
	run.camara.zoom_hacia(0.7 / run.camara.zoom.x, get_viewport().get_visible_rect().size * 0.5)
	run.camara.position = Vector2(1700, -260)
	run.camara.force_update_scroll()
	run.hud._process(0.5)
	run.hud.mostrar_inspeccion(muro)
	await captura("muro_antes")
	muro.morder(muro.vida + 1)
	run.hud.mostrar_inspeccion(null)
	await captura("muro_abierto")
	run.queue_free()
	await get_tree().process_frame
	Juego.migas = 500000
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	tienda._seleccionar_mejora("mordida_resistente")
	await get_tree().process_frame
	await get_tree().process_frame
	await captura("tienda_materiales")
	get_window().size = Vector2i(1000, 620)
	await captura("tienda_materiales_1000")
	tienda.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + ".png")
	print(nombre)
