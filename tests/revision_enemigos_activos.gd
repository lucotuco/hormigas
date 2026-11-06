extends Node
## Capturas del renderer real con los mismos nodos, avisos y robo del juego.
## La carga de muestra representa material previamente extraído; no se cobra.
var total := 0
var fallas := 0
var run: Run


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Juego.reiniciar_estado()
	if DisplayServer.get_name() == "headless":
		verificar(false, "esta revisión necesita renderer real")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	get_window().size = Vector2i(1920, 1080)
	if not Graficos.listo:
		await Graficos.preparado
	run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.radio_actual = 9500
	run.hud.hide()
	run.niebla.hide()
	run.recorrido.hide()
	var centro := run.cocina.ajustar_destino(Vector2(-400, 300), run.radio_actual)
	var h := run.colonia._nacer("cargadora", centro)
	h.carga = 37.5
	h.bocados = 1
	h._material_carga = 1
	h._carga_origen = [0.0, 37.5, 0.0]
	h.estado = Hormiga.Estado.VOLVIENDO
	h._ruta = PackedVector2Array()
	h.queue_redraw()
	run.camara._manual = true
	run.camara.position = centro
	run.camara.zoom = Vector2.ONE * 2.5
	run.camara._zoom_objetivo = 2.5
	run.camara.force_update_scroll()
	run.comidas.soltar_fragmento(centro + Vector2(140, 60), 41, 1)
	var resto: FragmentoCasa = run.comidas.fragmentos.back()
	var avispa := nuevo("avispa")
	var rival := nuevo("rival")
	var arana := nuevo("arana")
	var cucaracha := nuevo("cucaracha")
	if avispa == null or rival == null or arana == null or cucaracha == null:
		get_tree().quit(1)
		return
	avispa.position = centro + Vector2(-120, -50)
	rival.position = resto.position + Vector2(-resto.radio - 2, 0)
	arana.position = centro + Vector2(-180, 120)
	cucaracha.position = centro + Vector2(190, -100)
	for e in run.eventos.activos:
		e.queue_redraw()
	# Las posiciones se fijan sólo para comparar encuadres. Dejar expirar los
	# pulsos de aparición originales antes de emitir los avisos de ataque.
	run.efectos._process(3)
	verificar(run.eventos.amenazas_activas() == 4, "cuatro individuos reales comparten la escena, no iconos de una maqueta")
	await captura("enemigos_00_entrada")
	avispa._aviso_restante = 0
	avispa._avispa(0.01)
	rival._aviso_restante = 0
	rival._comida = resto
	rival._recolector(0.01)
	avispa.queue_redraw()
	rival.queue_redraw()
	run.efectos._process(0.05)
	var ingreso := Juego.migas_run
	var aviso := await captura("enemigos_01_aviso")
	verificar(avispa.estado == "marcando" and rival.estado == "cargando" and h.carga == 37.5
		and not resto.muerta, "el aviso señala ataque y carga sin retirar material por anticipado")
	var marca := avispa._objetivo
	avispa.golpear()
	run.efectos._process(0.035)
	var golpe := await captura("enemigos_02_golpe")
	verificar(diferencias(aviso, golpe) > 30 and avispa._destello > 0
		and avispa._pausa_golpe > 0 and avispa._objetivo == marca,
		"un clic cambia píxeles y pausa la amenaza, sin mover el área anunciada")
	avispa._avispa(float(avispa._datos.aviso) + 0.01)
	avispa._avispa(2.0)
	rival._recolector(float(rival._datos.aviso) + 0.01)
	var robo_resto_real := resto.muerta and not run.comidas.fragmentos.has(resto)
	for e in [avispa, rival]:
		e.queue_redraw()
	run.efectos._process(0.04)
	await captura("enemigos_03_botin")
	verificar(avispa.estado == "huyendo" and avispa.botin == 37.5 and h.carga == 0
		and rival.estado == "huyendo" and rival.botin == 41 and robo_resto_real,
		"el botín dibujado sólo aparece después de retirar la carga y el montón reales")
	for e in [avispa, rival]:
		e._huir(Eventos.parametro("escape_duracion") - 0.2)
	run.efectos._process(3)
	await captura("enemigos_04_escape")
	verificar(Juego.migas_run == ingreso, "avisar, golpear sin vencer y robar no acreditan premios ficticios")
	run._detener_extraccion()
	await captura("enemigos_05_cierre")
	verificar(run.eventos.activos.is_empty() and not run.activa, "el cierre elimina todos los encuentros y su feedback")
	run.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	print("Revisión enemigos activos: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func nuevo(tipo: String) -> Evento:
	var lista := run.eventos.aparecer(tipo)
	verificar(not lista.is_empty(), "aparece " + tipo + " con la fábrica real")
	return lista[0] if not lista.is_empty() else null


func captura(nombre: String) -> Image:
	for i in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var imagen := get_viewport().get_texture().get_image()
	verificar(imagen.save_png("res://.godot/qa/" + nombre + ".png") == OK, "captura " + nombre)
	return imagen


func diferencias(a: Image, b: Image) -> int:
	var cantidad := 0
	for y in range(0, a.get_height(), 3):
		for x in range(0, a.get_width(), 3):
			cantidad += int(a.get_pixel(x, y) != b.get_pixel(x, y))
	return cantidad


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("OK " if ok else "FALLA ", mensaje)
