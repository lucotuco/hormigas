extends Node
## Atracción por cercanía mientras se mantiene el clic, más zoom y paneo reales.
var fallas := 0
var total := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	seed(45)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.cocina.limite_rutas_por_cuadro = 0
	for c in run.comidas.lista:
		c.queue_free()
	run.comidas.lista.clear()
	var f := run.feromonas
	var h := run.colonia._nacer()
	h.position = Vector2(-130, 90)
	h._velocidad = 100
	var lejos := run.colonia._nacer()
	lejos.position = Vector2(500, -350)
	var cargada := run.colonia._nacer()
	cargada.position = Vector2(-100, 120)
	cargada.carga = 1
	cargada._volver()
	for i in 30:
		var cercana := run.colonia._nacer()
		cercana.position = Vector2(-100 - i * 2, 120)
	f.mantener_en(Vector2(-100, 120))
	verificar(f.llama_a(h) and not f.llama_a(lejos), "el llamado selecciona las más cercanas y deja las otras sin ordenar")
	verificar(not f.llama_a(cargada) and cargada.carga == 1, "las que transportan comida terminan su regreso")
	h._pensar()
	verificar(h.estado == Hormiga.Estado.SIGUIENDO and h.objetivo == f.posicion, "la hormiga camina hacia el punto mantenido")
	for i in 60:
		h._process(1.0 / 60)
	verificar(h.position.distance_to(f.posicion) < 2, "la hormiga llega al punto de atracción")
	var pos := h.position
	for i in 30:
		h._process(1.0 / 60)
	verificar(h.position.distance_to(pos) < 2, "permanece cerca mientras se mantiene el llamado")
	f.mantener_en(Vector2(-50, 250))
	f._actualizar_cercanas()
	h._pensar()
	verificar(f.llama_a(h) and h.objetivo == Vector2(-50, 250), "mover el llamado cambia el destino sin seguir un camino anterior")
	f.soltar()
	h._pensar()
	verificar(not f.activa and f.seleccionadas.is_empty() and h.estado != Hormiga.Estado.SIGUIENDO, "al soltar cesa la atracción inmediatamente")
	verificar(not f.has_method("agregar_punto"), "no queda el sistema de rastros dirigidos")
	for i in 35:
		var ant := run.colonia._nacer()
		ant.position = Vector2(-100 - i * 3, 120)
	f.mantener_en(Vector2(-100, 120))
	f._actualizar_cercanas()
	verificar(f.seleccionadas.size() == Feromonas.MAX_ATRAIDAS, "se eligen las 24 más cercanas sin ordenar a toda la colonia")
	f.mantener_en(Vector2(0, -550))
	f._actualizar_cercanas()
	verificar(f.llama_a(lejos) and not f.seleccionadas.is_empty(), "un punto alejado igual atrae a las más cercanas sin exigir que ya estén al lado")
	Juego.niveles.rastro_persistente = 2
	Juego._cache_stats.clear()
	f._actualizar_cercanas()
	verificar(f.seleccionadas.size() == 30, "Llamado potente aumenta en tres por nivel las hormigas que responden")
	Juego.niveles.rastro_persistente = 0
	Juego._cache_stats.clear()
	var tipo: Dictionary = Juego.comidas[2].duplicate()
	tipo.vida = 100
	run.comidas._crear(tipo, Vector2(-100, 300), 5)
	var comida: Comida = run.comidas.lista.back()
	h.position = Vector2(-100, 270)
	h.estado = Hormiga.Estado.EXPLORANDO
	h.comida = null
	h.carga = 0
	f.mantener_en(comida.position)
	f._actualizar_cercanas()
	for i in 120:
		h._process(1.0 / 60)
		if comida.vida < 100:
			break
	verificar(comida.vida < 100 and h.carga > 0, "si el punto está sobre comida las cercanas llegan y recolectan")
	f.mantener_en(Vector2(8000, 0))
	f._actualizar_cercanas()
	verificar(f.seleccionadas.is_empty(), "el llamado no controla zonas todavía fuera del territorio")
	f.soltar()
	var cam := run.camara
	cam.centrar()
	var cursor := Vector2(850, 260)
	var antes := cam.get_canvas_transform().affine_inverse() * cursor
	cam.zoom_hacia(1.8, cursor)
	var despues := cam.get_canvas_transform().affine_inverse() * cursor
	verificar(antes.distance_to(despues) < 0.1, "el zoom conserva el punto bajo el cursor")
	var z := cam.zoom.x
	cam.ajustar_a_radio(900)
	cam._process(1.0 / 60)
	verificar(is_equal_approx(z, cam.zoom.x), "el encuadre automático no deshace el zoom manual")
	pos = cam.position
	cam.desplazar(Vector2(50, -25))
	verificar(cam.position.distance_to(pos - Vector2(50, -25) / z) < 0.1, "el desplazamiento respeta el zoom")
	cam.ver_casa()
	verificar(cam.position == PlanoCasa.LIMITES.get_center(), "se puede encuadrar la casa completa")
	cam.centrar()
	run.process_mode = Node.PROCESS_MODE_INHERIT
	run.set_process(false)
	run.colonia.set_process(false)
	for ant in run.colonia.hormigas:
		ant.set_process(false)
	await get_tree().process_frame
	cam.ajustar_a_radio(run.radio_actual)
	cam.centrar()
	await get_tree().process_frame
	var t := get_viewport().get_canvas_transform()
	# parse_input_event recibe coordenadas de ventana, antes del estirado.
	var ventana := get_viewport().get_final_transform()
	var inicio := ventana * (t * Vector2(-100, 100))
	var fin := ventana * (t * Vector2(-100, 200))
	var boton := InputEventMouseButton.new()
	boton.button_index = MOUSE_BUTTON_LEFT
	boton.pressed = true
	boton.position = inicio
	Input.parse_input_event(boton)
	await get_tree().process_frame
	verificar(f.activa, "presionar el clic real activa el llamado")
	var mover := InputEventMouseMotion.new()
	mover.position = fin
	mover.relative = fin - inicio
	mover.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(mover)
	await get_tree().process_frame
	verificar(f.posicion.distance_to(Vector2(-100, 200)) < 2, "el llamado sigue la posición real del cursor")
	boton = boton.duplicate()
	boton.pressed = false
	boton.position = fin
	Input.parse_input_event(boton)
	await get_tree().process_frame
	verificar(not f.activa and f.seleccionadas.is_empty(), "soltar el clic real apaga el llamado")
	var rueda := InputEventMouseButton.new()
	rueda.button_index = MOUSE_BUTTON_WHEEL_UP
	rueda.pressed = true
	rueda.position = fin
	z = cam.zoom.x
	Input.parse_input_event(rueda)
	await get_tree().process_frame
	verificar(cam.zoom.x > z, "la rueda real cambia el zoom")
	boton = InputEventMouseButton.new()
	boton.button_index = MOUSE_BUTTON_RIGHT
	boton.pressed = true
	boton.position = fin
	Input.parse_input_event(boton)
	await get_tree().process_frame
	pos = cam.position
	mover.position = fin + Vector2(60, 0)
	mover.relative = Vector2(60, 0)
	mover.button_mask = MOUSE_BUTTON_MASK_RIGHT
	Input.parse_input_event(mover)
	await get_tree().process_frame
	boton = boton.duplicate()
	boton.pressed = false
	Input.parse_input_event(boton)
	await get_tree().process_frame
	verificar(cam.position != pos and not cam.arrastrando and not f.activa, "mover el mapa no activa feromonas")
	print("Controles y atracción: %d verificaciones; %d fallas." % [total, fallas])
	run.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if fallas == 0 else 1)

func verificar(ok: bool, texto: String) -> void:
	total += 1
	print("  OK   " if ok else "  FALLA ", texto)
	if not ok:
		fallas += 1
