extends Node
## QA de siguiente paso, compra visible y cierre; usa sólo una partida temporal.
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
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if not Graficos.listo:
		await Graficos.preparado
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	Juego.reiniciar_estado()
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	for tam in [Vector2i(1920, 1080), Vector2i(1000, 620)]:
		get_window().size = tam
		await captura("lectura_inicio_%d" % tam.x)
		var area := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		verificar(area.encloses(tienda._lbl_paso.get_global_rect()) and area.encloses(tienda._boton_paso.get_global_rect()), "el paso y su acción quedan dentro de pantalla a %d" % tam.x)
	Juego.niveles = {"mandibulas": 4, "mordida_rapida": 1, "mas_obreras": 4}
	Juego.migas = Juego.costo("mordida_madera")
	Juego._cache_stats.clear()
	tienda._refrescar()
	tienda._seleccionar_mejora("mordida_madera")
	tienda._comprar("mordida_madera")
	await captura("lectura_compra_madera")
	verificar(tienda._ficha_mejoras.get_global_rect().encloses(tienda._lbl_estado.get_global_rect()), "el antes y después cabe dentro de la ficha de compra")
	Juego.niveles.mordida_resistente = 1
	Juego.niveles.mordida_muros = 1
	Juego.coronas_cobradas = {"casa": true}
	Juego.lugares_completados = {"casa": true}
	Juego.coronas = 1
	Juego._cache_stats.clear()
	tienda._cerrar_ficha()
	await captura("lectura_fundacion_lista")
	verificar(tienda._siguiente_paso.get("accion", "") == "legado" and tienda._boton_paso.visible, "la primera fundación se ofrece sin ejecutarla")
	tienda.queue_free()
	await get_tree().process_frame
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.produccion_run = 91
	run.cargas_pendientes = 300
	run.tenia_record = true
	run.mejora_produccion = 25
	run.limpieza_lograda = true
	run.limpieza_registrada = true
	run.nuevo_record_limpieza = true
	run.tiempo_limpieza = 18.25
	run.tiempo_jugado = 18.5
	run.tiempo_retirada = 2.5
	Juego.migas_run = 1911
	Juego.migas = 1911
	Juego.migas_colonia = 100000
	for tam in [Vector2i(1920, 1080), Vector2i(1000, 620)]:
		get_window().size = tam
		run.hud._actualizar_meta()
		run.hud.mostrar_fin()
		for i in 4:
			await get_tree().process_frame
		run.hud._panel_fin.modulate.a = 1
		run.hud._panel_fin.scale = Vector2.ONE
		await captura("lectura_fin_%d" % tam.x)
		var area := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		verificar(area.encloses(run.hud._panel_fin.get_global_rect()), "el cierre y sus acciones caben a %d" % tam.x)
		verificar(run.hud._panel_fin.get_global_rect().encloses(run.hud._boton_tienda.get_global_rect()), "el botón de continuar no depende del scroll a %d" % tam.x)
	run.queue_free()
	await get_tree().process_frame
	await probar_preparaciones()
	Juego.reiniciar_estado()
	print("Revisión lectura: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)

func probar_preparaciones() -> void:
	for tam in [Vector2i(1920, 1080), Vector2i(1000, 620)]:
		get_window().size = tam
		for id in ["madera", "cuadrilla"]:
			Juego.reiniciar_estado()
			Juego.coronas = 1
			Juego.coronas_cobradas = {"casa": true}
			Juego.lugares_completados = {"casa": true}
			Juego.migas_colonia = pow(4, 4) * Juego.DIVISOR_JALEA_MIGAS
			var ventana := VentanaFundar.new()
			add_child(ventana)
			await get_tree().process_frame
			ventana.elegir_preparacion(id)
			for i in 4:
				await get_tree().process_frame
			ventana._scroll.ensure_control_visible(ventana._preparacion)
			await captura("lectura_preparacion_%s_%d" % [id, tam.x])
			var area := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
			verificar(area.encloses(ventana._panel.get_global_rect()) and area.encloses(ventana._boton_fundar.get_global_rect()), "%s: ventana y confirmación dentro de pantalla a %d" % [id, tam.x])
			verificar(ventana._scroll.get_global_rect().encloses(ventana._preparacion.get_global_rect()) and ventana._scroll.get_global_rect().encloses(ventana._lbl_inicio.get_global_rect()), "%s: selector y arranque previsto se ven juntos a %d" % [id, tam.x])
			var previa := Juego.vista_previa_fundar(ventana.elegido, ventana.compras_preparacion())
			verificar(Juego.jalea_por_fundar() == 7 and previa.plan_valido and not ventana._boton_fundar.disabled, "%s: el plan es alcanzable con siete de jalea a %d" % [id, tam.x])
			await clic(ventana._boton_fundar)
			verificar(Juego.fundaciones == 1 and Juego.jalea == previa.jalea and Juego.stat("materiales") == previa.stats.materiales and Juego.stat("hormigas_iniciales") == previa.stats.hormigas_iniciales, "%s: confirmar con clic respeta el arranque y el saldo mostrados a %d" % [id, tam.x])

func clic(boton: Button) -> void:
	var punto := boton.get_global_rect().get_center()
	var movimiento := InputEventMouseMotion.new()
	movimiento.position = punto
	movimiento.global_position = punto
	get_viewport().push_input(movimiento, true)
	await get_tree().process_frame
	for presionado in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.position = punto
		evento.global_position = punto
		evento.pressed = presionado
		get_viewport().push_input(evento, true)
		await get_tree().process_frame
	await get_tree().process_frame

func captura(nombre: String) -> void:
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var idioma := "_en" if TranslationServer.get_locale().begins_with("en") else ""
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + idioma + ".png")
