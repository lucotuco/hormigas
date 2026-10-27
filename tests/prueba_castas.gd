extends Node
## Economía, compatibilidad de guardado y habilidades reales sin tocar el save.
var fallas := 0
var total := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	seed(91)
	var comprables := 0
	for c in Juego.castas:
		if c.comprable:
			comprables += 1
	verificar(comprables == 5, "hay cinco castas reclutables y dos castas de apoyo")
	verificar(not Juego.comprar_casta("reina") and Juego.total_especialistas() == 0, "no se compra sin migas")
	verificar(not Juego.comprar_casta("mini") and not Juego.comprar_casta("inexistente"), "no se compran miniobreras ni IDs inválidos")
	Juego.migas = 10000
	for c in Juego.castas:
		if not c.comprable:
			continue
		var saldo := Juego.migas
		var costo := Juego.costo_casta(c.id)
		verificar(Juego.comprar_casta(c.id) and Juego.cantidad_casta(c.id) == 1 and Juego.migas == saldo - costo, "reclutar %s descuenta el precio exacto" % c.nombre)
		verificar(Juego.costo_casta(c.id) > costo, "el precio de %s crece por unidad" % c.nombre)
	var guardado: Dictionary = JSON.parse_string(JSON.stringify(Juego.datos_partida()))
	Juego.reclutadas.reina = 3
	var saldo := Juego.migas
	verificar(not Juego.comprar_casta("reina") and Juego.migas == saldo, "el límite de reinas no consume migas")
	Juego.reiniciar_estado()
	Juego.restaurar_partida(guardado)
	verificar(Juego.total_especialistas() == 5 and Juego.cantidad_casta("reina") == 1, "las unidades sobreviven al roundtrip del guardado JSON")
	Juego.restaurar_partida({"version": 1, "migas": 123, "niveles": {"mas_obreras": 2}})
	verificar(Juego.migas == 123 and Juego.nivel_de("mas_obreras") == 2 and Juego.total_especialistas() == 0, "una partida antigua conserva progreso y no inventa castas")
	Juego.restaurar_partida({"reclutadas": {"reina": 99, "roja": -2, "mini": 80, "inexistente": 5}})
	verificar(Juego.cantidad_casta("reina") == 3 and Juego.total_especialistas() == 3, "se validan límites y castas permitidas al cargar")
	Juego.restaurar_partida(guardado)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.colonia._process(3.0)
	var conteo := run.colonia.conteo_castas()
	verificar(run.colonia.cantidad() == 10 and conteo.get("reina", 0) == 1 and conteo.get("voladora", 0) == 1, "la expedición despliega obreras y todas las unidades compradas")
	var reina: Hormiga
	var roja: Hormiga
	var voladora: Hormiga
	var cargadora: Hormiga
	var veloz: Hormiga
	for h in run.colonia.hormigas:
		match h.casta:
			"reina": reina = h
			"roja": roja = h
			"voladora": voladora = h
			"cargadora": cargadora = h
			"veloz": veloz = h
	verificar(veloz._velocidad > Juego.stat("velocidad") * 1.9, "la exploradora es realmente más rápida")
	verificar(cargadora._capacidad == int(Juego.stat("capacidad")) * 4, "la cargadora transporta cuatro veces más bocados")
	# El vuelo atraviesa la proyección de un mueble; el regreso termina en depósito.
	voladora.global_position = Vector2(460, 0)
	voladora.carga = 1
	voladora._volver()
	var sobrevolo := false
	for i in 180:
		if voladora.carga <= 0:
			break
		voladora._caminar(1.0 / 30)
		if not run.cocina.libre(voladora.global_position):
			sobrevolo = true
	verificar(sobrevolo and voladora.carga == 0, "la voladora sobrevuela la pata y deposita su carga")
	# Congelamos el desplazamiento de la reina para medir sus tandas.
	reina._velocidad = 0
	reina._process(5.9)
	verificar(run.colonia.minis_nacidas == 0, "la reina espera el intervalo de despliegue")
	reina._process(0.11)
	verificar(run.colonia.minis_nacidas == 2 and Juego.cantidad_casta("mini") == 0, "la reina crea dos minis temporales")
	reina._process(120)
	verificar(run.colonia.minis_nacidas == 24, "se respeta el límite de minis por reina")
	# La roja envenena la comida al morder, además de llevar su bocado.
	var tipo: Dictionary = Juego.comidas[2].duplicate()
	tipo.vida = 100
	tipo.recompensa = 100
	run.comidas._crear(tipo, Vector2(-60, 0), 17)
	var comida: Comida = run.comidas.lista.back()
	roja.comida = comida
	roja.estado = Hormiga.Estado.MORDIENDO
	roja._reloj_mordida = 0
	roja._morder(0.1)
	verificar(comida.veneno_restante == 3 and roja.carga > 0, "la mordida roja aplica veneno y conserva la carga normal")
	var dps := roja._dano * 0.8
	comida.aplicar_veneno(dps * 0.5, 3, run)
	var vida := comida.vida
	var migas := Juego.migas_run
	for i in 6:
		comida._process(0.5)
	verificar(is_equal_approx(vida - comida.vida, dps * 3), "el veneno hace el daño esperado sin acumularse")
	verificar(is_equal_approx(Juego.migas_run - migas, dps * 3), "las migas corroídas se acreditan una sola vez")
	comida.aplicar_veneno(dps, 3, run)
	vida = comida.vida
	run.activa = false
	run.colonia.detener()
	comida._process(1)
	reina._process(60)
	verificar(comida.vida == vida and run.colonia.minis_nacidas == 24, "veneno y refuerzos se detienen al finalizar la expedición")
	run.queue_free()
	await get_tree().process_frame
	# Otra expedición recupera las compradas y no las minis de la anterior.
	run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.colonia._process(3)
	verificar(run.colonia.cantidad() == 10 and run.colonia.minis_nacidas == 0, "las especialistas vuelven en otra expedición y las minis no se guardan")
	run.queue_free()
	await get_tree().process_frame
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	tienda._cambiar_pestana("castas")
	await get_tree().process_frame
	var panel: PanelCastas = tienda._panel_castas
	verificar(panel.visible and panel._filas.size() == 5, "la tienda permite abrir el catálogo de las cinco castas")
	for id in panel._filas:
		panel._seleccionar(id)
		verificar(panel._nombre.text == Juego.castas_por_id[id].nombre and not panel._habilidad.text.is_empty(), "la ficha de %s tiene información real" % id)
	panel._seleccionar("veloz")
	var antes := Juego.cantidad_casta("veloz")
	panel._boton.pressed.emit()
	verificar(Juego.cantidad_casta("veloz") == antes + 1, "el botón de la ficha recluta una unidad")
	tienda.queue_free()
	await get_tree().process_frame
	print("Castas: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func verificar(condicion: bool, texto: String) -> void:
	total += 1
	print("  OK   " if condicion else "  FALLA ", texto)
	if not condicion:
		fallas += 1
