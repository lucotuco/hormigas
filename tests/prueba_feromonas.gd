extends Node
## Regresiones del llamado con el presupuesto REAL de rutas, no sólo modo síncrono.
var total := 0
var fallas := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	Engine.max_fps = 0
	seed(749)
	var run := crear_run()
	var f := run.feromonas
	var referencia: Array[Hormiga] = []
	for i in 500:
		var h := run.colonia._nacer()
		h.position = Vector2(-200 + i * 0.73, 50 + (i % 17) * 3)
		if i % 9 == 0:
			h.carga = 1
			h.estado = Hormiga.Estado.VOLVIENDO
		else:
			referencia.append(h)
	var punto := Vector2(-100, 140)
	referencia.sort_custom(func(a: Hormiga, b: Hormiga) -> bool: return a.position.distance_squared_to(punto) < b.position.distance_squared_to(punto))
	f.mantener_en(punto)
	var exactas := f.seleccionadas.size() == 24
	for i in 24:
		exactas = exactas and f.llama_a(referencia[i])
	verificar(exactas, "el heap devuelve exactamente las 24 disponibles más cercanas entre 500")
	# El objetivo compartido puede desaparecer entre dos muestreos de 0.2 s.
	var temporal := Comida.new()
	run.add_child(temporal)
	f.objetivo_comida = temporal
	temporal.free()
	referencia[0]._pensar()
	verificar(referencia[0].estado == Hormiga.Estado.SIGUIENDO, "un objetivo liberado entre muestreos no rompe el llamado")
	Juego.niveles = {"pisoton": 25, "rastro_persistente": 10}
	Juego._cache_stats.clear()
	f._actualizar_cercanas()
	verificar(f.seleccionadas.size() == 64 and f.cantidad_atraidas() == 64, "las mejoras conservadas respetan el máximo de 64 llamadas")
	var guardado := Juego.datos_partida()
	Juego.reiniciar_estado()
	Juego.restaurar_partida(guardado)
	verificar(Juego.nivel_de("pisoton") == 25 and Juego.mejoras_por_id.pisoton.stat == "feromona_cantidad", "el antiguo Pisotón conserva sus compras como Coordinación")
	verificar(Juego.mejoras_por_id.pisada.stat == "dano" and not run.has_method("pisar"), "el viejo pisotón mejora mordidas: el cursor no hace daño")
	f._notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	verificar(not f.activa and f.seleccionadas.is_empty(), "perder foco cancela el llamado sin dejar hormigas seleccionadas")
	run.queue_free()
	await get_tree().process_frame
	await probar_clic_real()
	await probar_inaccesible()
	await probar_presupuesto()
	print("Feromonas bajo carga: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)

func crear_run() -> Run:
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	return run

func probar_clic_real() -> void:
	Juego.reiniciar_estado()
	Juego.niveles.mordida_madera = 1
	Juego._cache_stats.clear()
	var run := crear_run()
	run.process_mode = Node.PROCESS_MODE_INHERIT
	run.set_process(false)
	run.colonia.set_process(false) # Sin hormigas: sólo debe actuar el input real.
	await get_tree().process_frame
	var silla := run.comidas.partes[6]
	var alimentos: Array[Comida] = []
	for c in run.comidas.lista:
		if c.position.length() < 500:
			alimentos.append(c)
			break
	alimentos.append(silla)
	var pisa_comida := false
	var paga_comida := false
	var mueble_intacto := true
	var llama := true
	for c in alimentos:
		var vida := c.vida
		var migas := Juego.migas_run
		var boton := InputEventMouseButton.new()
		boton.button_index = MOUSE_BUTTON_LEFT
		boton.pressed = true
		boton.position = get_viewport().get_final_transform() * (get_viewport().get_canvas_transform() * c.position)
		Input.parse_input_event(boton)
		await get_tree().process_frame
		llama = llama and run.feromonas.activa
		if c is PiezaCasa:
			mueble_intacto = mueble_intacto and c.vida == vida and Juego.migas_run == migas
		else:
			pisa_comida = c.vida == vida and not c.muerta
			paga_comida = Juego.migas_run == migas
		boton = boton.duplicate()
		boton.pressed = false
		Input.parse_input_event(boton)
		await get_tree().process_frame
	verificar(llama, "el clic real activa el llamado de hormigas")
	verificar(pisa_comida and paga_comida, "el clic real no hace daño ni entrega migas")
	verificar(mueble_intacto, "el pisotón no rompe muebles: eso es trabajo de las hormigas")
	run.queue_free()
	await get_tree().process_frame

func probar_inaccesible() -> void:
	Juego.reiniciar_estado()
	var run := crear_run()
	run.comidas._indice.clear()
	run.cocina.limite_rutas_por_cuadro = 0 # Aislar reintentos de la cuota por cuadro.
	var centro := Vector2(-100, 400)
	var paredes := [Rect2(-476, 124, 352, 32), Rect2(-476, 444, 352, 32), Rect2(-476, 124, 32, 352), Rect2(-156, 124, 32, 352)]
	for i in paredes.size():
		var rect: Rect2 = paredes[i]
		rect.position += Vector2(200, 100) # Evitar el nuevo banquito de práctica.
		var clave := "prueba:%d" % i
		run.cocina._obstaculos[clave] = {"rect": rect, "pared": true}
		for x in range(floori(rect.position.x / Cocina.SECTOR), floori(rect.end.x / Cocina.SECTOR) + 1):
			for y in range(floori(rect.position.y / Cocina.SECTOR), floori(rect.end.y / Cocina.SECTOR) + 1):
				var celda := Vector2i(x, y)
				if not run.cocina._sectores.has(celda):
					run.cocina._sectores[celda] = []
				run.cocina._sectores[celda].append(clave)
	var h := run.colonia._nacer()
	h.position = Vector2.ZERO
	run.feromonas.mantener_en(centro)
	h._pensar()
	for i in 360:
		h._process(1.0 / 60)
	verificar(h.position.length() < 1 and run.cocina.consultas_ruta < 20, "un destino encerrado no se reintenta cada cuadro ni atraviesa paredes (%d consultas)" % run.cocina.consultas_ruta)
	verificar(run.cocina.busquedas_astar <= 2 and run.cocina.aciertos_cache > 0, "los caminos imposibles también comparten caché")
	run.cocina.quitar_pieza("prueba:3")
	for i in 400:
		run.cocina.procesar_cambios()
		h._process(1.0 / 60)
	verificar(h.position.distance_to(centro) < 2, "abrir un paso invalida el fallo anterior y permite llegar sin soltar el llamado")
	run.queue_free()
	await get_tree().process_frame

func probar_presupuesto() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"pisoton": 25, "rastro_persistente": 10}
	Juego._cache_stats.clear()
	var run := crear_run()
	run.comidas._indice.clear()
	var admitidos := 0
	for i in 20:
		if run.cocina.admitir_ruta():
			admitidos += 1
	verificar(admitidos == run.cocina.limite_rutas_por_cuadro, "se admiten como máximo seis cálculos de ruta por cuadro")
	await get_tree().process_frame
	verificar(run.cocina.admitir_ruta(), "el presupuesto vuelve a estar disponible en el cuadro siguiente")
	for i in 500:
		var h := run.colonia._nacer()
		h.position = Vector2(-90 + (i % 15) * 3, 40 + (i % 11) * 2)
	var respeta_cuota := true
	for cuadro in 240:
		var punto := Vector2(-100 + sin(cuadro * 0.08) * 70, -150) if cuadro < 60 else Vector2(-100, -150)
		run.feromonas.mantener_en(punto)
		run.feromonas._process(1.0 / 60)
		var antes := run.cocina.consultas_ruta
		for h in run.colonia.hormigas:
			h._process(1.0 / 60)
		respeta_cuota = respeta_cuota and run.cocina.consultas_ruta - antes <= run.cocina.limite_rutas_por_cuadro
		await get_tree().process_frame
	verificar(respeta_cuota, "500 hormigas y un cursor móvil respetan el presupuesto sin congelar un cuadro")
	var atendidas := 0
	for h in run.colonia.hormigas:
		if h._version_ruta >= 0:
			atendidas += 1
	verificar(atendidas == 500, "la cola es justa: todas las hormigas reciben turno (%d/500)" % atendidas)
	var llegaron := 0
	for h in run.feromonas.seleccionadas.values():
		if h.position.distance_to(run.feromonas.posicion) < 16:
			llegaron += 1
	verificar(llegaron == 64, "las 64 llamadas llegan aun con la cuota activada (%d/64)" % llegaron)
	if DisplayServer.get_name() != "headless":
		run.hud._process(1.0 / 60)
		run.feromonas.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://.godot/qa")
		get_viewport().get_texture().get_image().save_png("res://.godot/qa/feromonas_500.png")
	run.feromonas.soltar()
	var libres := true
	for h in run.colonia.hormigas:
		h._pensar()
		libres = libres and h.estado != Hormiga.Estado.SIGUIENDO
	verificar(libres, "soltar el botón libera a toda la colonia también bajo carga")
	run.queue_free()
	await get_tree().process_frame

func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", detalle)
