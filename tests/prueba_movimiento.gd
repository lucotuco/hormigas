extends Node
## Regresiones deterministas de llegada, llamado y muebles.
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")  # las verificaciones leen textos en español
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	seed(731)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.cocina.limite_rutas_por_cuadro = 0
	# La línea recta atraviesa la primera pata de silla.
	var inicio := Vector2(460, 0)
	var puntos := run.cocina.ruta(inicio, Vector2.ZERO, run.radio_actual)
	verificar(puntos.size() > 1, "la ruta rodea la pata de silla")
	var anterior := inicio
	var segura := true
	for p in puntos:
		segura = segura and run.cocina.segmento_libre(anterior, p) and p.length() < run.radio_actual
		anterior = p
	verificar(segura, "todos los segmentos son transitables y quedan dentro del territorio")
	var comida_libre := true
	for c in run.comidas.lista:
		comida_libre = comida_libre and run.cocina.libre(c.position, c.radio + 8)
	verificar(comida_libre, "la comida no aparece dentro de muebles")
	# Llegada exacta, incluso cuando un paso supera el radio del hormiguero.
	run.colonia._nacer()
	var h: Hormiga = run.colonia.hormigas.back()
	h.global_position = Vector2(20, 0)
	h.carga = 1
	h._velocidad = 1600
	h._volver()
	h._process(1.0 / 30.0)
	verificar(h.carga == 0 and Juego.migas_run == 1, "una hormiga rápida descarga sin orbitar el hormiguero")
	run.feromonas.mantener_en(Vector2(40, 0))
	h._pensar()
	verificar(h.estado == Hormiga.Estado.SIGUIENDO, "el llamado atrae a la hormiga cercana")
	run.feromonas.soltar()
	h._pensar()
	verificar(h.estado != Hormiga.Estado.SIGUIENDO, "soltar el llamado deja de atraer")
	# La comida puede asomar del límite: se llega a su borde sin salir del mapa.
	var borde: Comida = preload("res://mundo/comida.tscn").instantiate()
	run.add_child(borde)
	borde.position = Vector2(0, -run.radio_actual - 5)
	borde.configurar(Juego.comidas[0], 1)
	borde.radio = 20
	h.global_position = Vector2(0, -run.radio_actual + 20)
	h.comida = borde
	h.estado = Hormiga.Estado.YENDO_A_COMIDA
	h.objetivo = borde.position
	h._meta_ruta = Vector2.INF
	h._caminar(1.0 / 30.0)
	verificar(h.estado == Hormiga.Estado.MORDIENDO and h.global_position.length() < run.radio_actual, "alcanza comida del borde sin quedar empujando el límite")
	h.detener()
	h.comida = null
	borde.queue_free()
	# 500 regresos en paralelo, a distintas velocidades, detrás del mueble.
	var inicio_test := Time.get_ticks_msec()
	for i in 500:
		run.colonia._nacer()
		h = run.colonia.hormigas.back()
		h.global_position = inicio + Vector2(0, (i % 7) - 3)
		h._velocidad = 60 + i * 0.7
		h.carga = 1
		h._volver()
	var atravesaron := false
	for cuadro in 360:
		for ant in run.colonia.hormigas:
			if ant.carga > 0:
				ant._process(1.0 / 30.0)
				if not run.cocina.libre(ant.global_position, 7.5):
					atravesaron = true
	var pendientes := 0
	for ant in run.colonia.hormigas:
		if ant.carga > 0:
			pendientes += 1
	verificar(pendientes == 0, "500 hormigas vuelven y descargan sin quedar atrapadas (%d pendientes)" % pendientes)
	verificar(not atravesaron, "ninguna hormiga atraviesa los muebles")
	print("Simulación de 500 regresos: %d ms (prueba lógica, no benchmark gráfico)." % (Time.get_ticks_msec() - inicio_test))
	# La vista previa no altera la economía.
	var antes := Juego.stat("hormigas_iniciales")
	verificar(Juego.stat_tras_comprar("mas_obreras") == antes + 2 and Juego.stat("hormigas_iniciales") == antes, "la vista previa muestra el valor futuro sin comprar")
	print("Pruebas de movimiento: %d fallas." % fallas)
	run.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if fallas == 0 else 1)


func verificar(condicion: bool, texto: String) -> void:
	print("  OK   " if condicion else "  FALLA ", texto)
	if not condicion:
		fallas += 1
