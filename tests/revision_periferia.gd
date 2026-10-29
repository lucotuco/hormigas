extends Node
## QA de la ampliación real: mismos recursos, renderer y cámara del juego.
## No mide FPS. Las capturas y lecturas de píxeles son sólo de esta revisión.
var total := 0
var fallas := 0

func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("OK " if ok else "FALLA ", detalle)

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma(OS.get_environment("IDIOMA") if OS.has_environment("IDIOMA") else "es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	if DisplayServer.get_name() == "headless":
		push_error("La revisión de periferia requiere renderer real")
		get_tree().quit(1)
		return
	get_window().size = Vector2i(1920, 1080)
	if not Graficos.listo:
		await Graficos.preparado
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	verificar(Graficos.textura.get_width() == 2048 and Graficos.textura.get_height() <= 5504, "la ampliación no agranda el atlas de 43 MiB")
	print("ATLAS PERIFERIA %dx%d / %d regiones" % [Graficos.textura.get_width(), Graficos.textura.get_height(), Graficos.regiones.size()])
	for destino in Mundos.ORDEN:
		Juego.reiniciar_estado()
		Juego.lugar_actual = destino
		seed(417)
		var run: Run = preload("res://mundo/run.tscn").instantiate()
		add_child(run)
		run.process_mode = Node.PROCESS_MODE_DISABLED
		run.hud.hide()
		run.niebla.hide()
		run.eventos.hide()
		run.camara.ver_casa()
		await captura("periferia_" + destino)
		var vista := rect_vista(run.camara)
		verificar(vista.grow(2).encloses(PlanoCasa.limites()), destino + ": H encuadra todo el terreno jugable en Full HD")
		verificar(PlanoCasa.limites_visuales().grow(2).encloses(vista), destino + ": H no muestra fondo fuera del paisaje")
		run.camara.zoom_hacia(0.001, get_viewport().get_visible_rect().size * 0.5)
		await captura("periferia_alejada_" + destino)
		verificar(PlanoCasa.limites_visuales().grow(2).encloses(rect_vista(run.camara)), destino + ": la rueda no puede salir del paisaje")
		if destino == "casa":
			await comprobar_ventanas(run)
		get_window().size = Vector2i(1920, 1080)
		run.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Juego.reiniciar_estado()
	print("Revisión gráfica de periferia: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)

func comprobar_ventanas(run: Run) -> void:
	for tamano in [Vector2i(1000, 620), Vector2i(2560, 1080)]:
		get_window().size = tamano
		await get_tree().process_frame
		await get_tree().process_frame
		run.camara._process(0)
		run.camara.zoom_hacia(0.001, get_viewport().get_visible_rect().size * 0.5)
		run.camara.desplazar(Vector2(100000, -100000))
		await captura("periferia_borde_%d" % tamano.x)
		verificar(PlanoCasa.limites_visuales().grow(2).encloses(rect_vista(run.camara)), "zoom y arrastre siguen dentro al redimensionar a %d" % tamano.x)
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame
	await get_tree().process_frame
	run.hud.show()
	run.niebla.show()
	run.camara.ajustar_a_radio(run.radio_actual, true)
	run.camara.centrar()
	await captura("periferia_inicio")
	run.hud.hide()
	run.niebla.hide()

func rect_vista(camara: Camara) -> Rect2:
	var inversa := camara.get_canvas_transform().affine_inverse()
	var pantalla := get_viewport().get_visible_rect().size
	var a := inversa * Vector2.ZERO
	var b := inversa * pantalla
	return Rect2(a.min(b), (b - a).abs())

func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + ".png")
	print("CAPTURA ", nombre)
