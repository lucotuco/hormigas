extends Node
## Regresión: colonia grande sin llamado y objetivos que desaparecen al llegar.
var fallas := 0
var total := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Sonido.silenciado = true
	await probar_cambio_de_objetivo()
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	seed(519)
	Engine.max_fps = 0
	var r: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(r)
	r.set_process(false)
	r.set_process_unhandled_input(false)
	r.feromonas.set_process_unhandled_input(false)
	r.colonia.set_process(false)
	r.hud.set_process(false)
	r.hud.hide()
	r.radio_actual = 3500
	r.niebla.radio = 3500
	r.camara.zoom_hacia(0.24 / r.camara.zoom.x, get_viewport().get_visible_rect().size * 0.5)
	r.camara.position = Vector2(900, 500)
	r.camara.set_process(false)
	r.camara.set_process_input(false)
	r.camara.set_process_unhandled_input(false)
	r.camara.force_update_scroll()
	for i in 500:
		var h := r.colonia._nacer()
		h._velocidad = 240
		h._dano = 200
		h._capacidad = 6
		h._olfato = 100
	var llegaron_lejos: Dictionary = {}
	var visitas_10 := 0
	var quietas_sin_trabajo := 0
	var posiciones: Dictionary = {}
	var seguidas_quietas: Dictionary = {}
	for paso in 2400:
		await get_tree().process_frame
		for h in r.colonia.hormigas:
			if h.position.length_squared() > 1000 * 1000:
				llegaron_lejos[h.get_instance_id()] = true
		if (paso + 1) % 600 == 0:
			if paso == 599:
				visitas_10 = llegaron_lejos.size()
			var estados := [0, 0, 0, 0, 0, 0]
			var centro := 0
			var borde := 0.0
			for h in r.colonia.hormigas:
				estados[h.estado] += 1
				centro += int(h.position.length_squared() < 500 * 500)
				borde = maxf(borde, h.position.length())
			print("DISPERSIÓN %d s: estados %s | centro %d | radio %.0f | visitaron >1000: %d | rutas %d" % [(paso + 1) / 60, estados, centro, borde, llegaron_lejos.size(), r.cocina.consultas_ruta])
			if DisplayServer.get_name() != "headless" and paso in [599, 2399]:
				r.colonia._actualizar_escala()
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute("res://.godot/qa")
				get_viewport().get_texture().get_image().save_png("res://.godot/qa/dispersion_%d.png" % [(paso + 1) / 60])
		if (paso + 1) % 60 == 0:
			quietas_sin_trabajo = 0
			for h in r.colonia.hormigas:
				var id := h.get_instance_id()
				var quieta: bool = posiciones.has(id) and h.position.distance_squared_to(posiciones[id]) < 9 and h.estado in [Hormiga.Estado.EXPLORANDO, Hormiga.Estado.YENDO_A_COMIDA] and not h._esperando_ruta
				seguidas_quietas[id] = int(seguidas_quietas.get(id, 0)) + 1 if quieta else 0
				quietas_sin_trabajo += int(seguidas_quietas[id] >= 4)
				posiciones[id] = h.position
	verificar(visitas_10 >= 100, "la colonia empieza a explorar afuera del núcleo desde los primeros diez segundos")
	verificar(llegaron_lejos.size() >= 250, "la mayoría de la colonia sale de la zona inicial sin llamado")
	verificar(quietas_sin_trabajo <= 10, "no quedan grupos de exploradoras detenidas durante cuatro segundos sin trabajo")
	verificar(r.colonia.exploracion._reservas.size() <= r.colonia.cantidad(), "el reparto por sectores nunca reserva más destinos que hormigas")
	verificar(Juego.migas_run > 0 and not r.feromonas.activa, "la dispersión mantiene la recolección y los regresos al nido sin feromonas")
	r.colonia.detener()
	verificar(r.colonia.exploracion._reservas.is_empty() and r.colonia.exploracion._ocupacion.is_empty(), "al detener la colonia se liberan todas las reservas de exploración")
	r.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	print("Dispersión: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)

func probar_cambio_de_objetivo() -> void:
	Juego.reiniciar_estado()
	var r: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	var h := r.colonia._nacer()
	var agotada: Comida = r.comidas.lista[0]
	h.comida = agotada
	h.estado = Hormiga.Estado.YENDO_A_COMIDA
	h.objetivo = agotada.position
	var anterior := h.objetivo
	agotada.muerta = true
	# Aislamos el cambio de tarea del hallazgo de otros alimentos.
	for c in r.comidas.lista:
		h._comidas_sin_ruta[c.get_instance_id()] = 100
	for p in r.comidas.partes:
		h._comidas_sin_ruta[p.get_instance_id()] = 100
	h._pensar()
	verificar(h.comida == null and agotada.trabajadoras == 0 and h.estado == Hormiga.Estado.EXPLORANDO and h.objetivo != anterior, "si otra hormiga termina el alimento, abandona su objetivo y libera el puesto")
	var destino := h.objetivo
	for i in 6:
		h._pensar()
	verificar(h.objetivo == destino and destino != Vector2.INF, "buscar alimento no reinicia continuamente el destino de exploración")
	# Sin lugar libre no debe lanzar 24 búsquedas cada cuadro.
	var bloqueada := r.cocina.piezas[0].duplicate()
	bloqueada.rect = Rect2(-100, -100, 200, 200)
	r.cocina._obstaculos[bloqueada.clave] = bloqueada
	r.cocina._sectores.clear()
	for x in range(-1, 1):
		for y in range(-1, 1):
			r.cocina._sectores[Vector2i(x, y)] = [bloqueada.clave]
	h.position = Vector2.ZERO
	r.radio_actual = 15
	h._elegir_destino_al_azar()
	verificar(h.objetivo == Vector2.INF, "si no hay destino válido no conserva una meta vieja")
	var reloj := h._reloj_vagar
	h._caminar(1.0 / 60)
	verificar(h.objetivo == Vector2.INF and h._reloj_vagar < reloj, "un intento fallido espera su plazo en vez de recalcular cada cuadro")
	r.queue_free()
	await get_tree().process_frame

func verificar(ok: bool, texto: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", texto)
