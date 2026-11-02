extends Node
## Un premio físico adicional al cap pagado, sin nuevas rutas ni recursos.
## La geometría controlada aísla límites/caché; después se prueban los cinco
## planos reales con los objetivos terminados mediante la API administrativa.
const RUN := preload("res://mundo/run.tscn")
const CANDIDATAS := [Vector2(500, 500), Vector2(1100, 800), Vector2(1800, 900),
	Vector2(2600, 1200), Vector2(3400, 1800), Vector2(4700, 2800)]

class CocinaControlada extends Cocina:
	var bloqueada := Rect2()
	var consultas_libre := 0
	func _ready() -> void:
		pass
	func libre(pos: Vector2, margen := 0.0, _volando := false) -> bool:
		consultas_libre += 1
		return PlanoCasa.limites().grow(-50 - margen).has_point(pos) and (not bloqueada.has_area() or not bloqueada.grow(margen).has_point(pos))

var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	await probar_cap_y_retorno()
	for destino in ["restaurante", "museo", "obelisco", "coliseo", "eiffel"]:
		await probar_plano_real(destino)
	await probar_persistencia()
	Juego.reiniciar_estado()
	print("Acceso propio de proyecto: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func logistico(destino: String) -> Dictionary:
	for proyecto in ProyectosCampana.del_destino(destino):
		if int(proyecto.entrada) == 1:
			return proyecto
	return {}


func ancla_del_plano(destino: String, proyecto: Dictionary) -> Vector2:
	var ultimo: Dictionary = proyecto.objetivos.back()
	for mueble: Dictionary in Mundos.plano(destino).muebles:
		if mueble.tipo == ultimo.tipo and mueble.rect.position.distance_squared_to(ultimo.pos) < 0.01:
			var r: Rect2 = mueble.rect
			return r.get_center()
	return Vector2.INF


func preparar(destino: String, completo := false) -> void:
	Juego.reiniciar_estado()
	for anterior in Mundos.ORDEN:
		if anterior == destino:
			break
		Juego.coronas_cobradas[anterior] = true
		Juego.lugares_completados[anterior] = true
		Juego.coronas += int(Mundos.INFO[anterior].coronas)
	Juego.lugar_actual = destino
	# Cinco niveles nativos + la adaptación histórica de Casa = seis normales.
	Juego.niveles.entradas = 5
	Juego._cache_stats.clear()
	if completo:
		for objetivo in logistico(destino).objetivos:
			Juego.registrar_objetivo_proyecto(objetivo.id)


func crear_run() -> Run:
	var run: Run = RUN.instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.radio_actual = 12000
	run.cocina.limite_rutas_por_cuadro = 0
	return run


func entradas_controladas(run: Run, candidatas: Array) -> EntradasHormiguero:
	# Instancia nueva sin consumidores previos: seis alternativas explícitas
	# para aislar el cap de cuántos ambientes tenga cada plano particular.
	var entradas := EntradasHormiguero.new()
	run.add_child(entradas)
	entradas.run = run
	entradas._preparar_proyecto()
	# Cambio pedido: estas posiciones explícitas representan clics del jugador,
	# ya no una lista que se autocoloca al ampliar el territorio.
	for pos: Vector2 in candidatas:
		entradas.colocar(pos)
	return entradas


func probar_cap_y_retorno() -> void:
	preparar("restaurante")
	var run := crear_run()
	var real := run.cocina
	var cocina := CocinaControlada.new()
	run.add_child(cocina)
	run.cocina = cocina
	var entradas := entradas_controladas(run, CANDIDATAS)
	run.entradas = entradas
	entradas.actualizar()
	verificar(Juego.stat("entradas") == 6 and entradas._normales == 6 and entradas.puntos.size() == 7 and entradas.punto_proyecto == Vector2.INF, "seis accesos normales y el nido no consumen ni inventan el premio de proyecto")
	var viejos := entradas.puntos.duplicate()
	var proyecto := logistico("restaurante")
	var ancla := ancla_del_plano("restaurante", proyecto)
	verificar(entradas._ancla_proyecto == ancla and ancla != Vector2.INF, "el ancla usa el centro del último objeto del catálogo, no su esquina ni un ambiente genérico")
	for objetivo in proyecto.objetivos:
		Juego.registrar_objetivo_proyecto(objetivo.id)
	run.radio_actual = ancla.length() - 1
	entradas.actualizar()
	verificar(entradas.puntos == viejos and entradas.punto_proyecto == Vector2.INF, "terminar un proyecto fuera del territorio no revela una entrada remota")
	run.radio_actual = 12000
	cocina.bloqueada = Rect2(ancla - Vector2.ONE * 20, Vector2.ONE * 40)
	var h := Hormiga.new()
	run.colonia.add_child(h)
	h.iniciar(run)
	h.position = ancla + Vector2(15, 0)
	h.carga = 1
	h._volver()
	var regreso_anterior := h.objetivo
	var saldo := Juego.migas_run
	var alimentos := run.comidas.lista.size()
	var restos := run.comidas.fragmentos.size()
	var hormigas := run.colonia.get_child_count()
	var consultas_astar := cocina.busquedas_astar
	entradas.actualizar()
	verificar(entradas.puntos.size() == 8 and entradas._normales == 6 and entradas.punto_proyecto != Vector2.INF, "el proyecto aporta un séptimo acceso secundario incluso con los seis normales completos")
	verificar(entradas.punto_proyecto == ancla + Vector2(96, 0) and cocina.libre(entradas.punto_proyecto, 40), "si el centro está bloqueado usa el primer desvío determinista local que queda libre")
	var intactos := entradas.puntos[0] == Vector2.ZERO
	for i in viejos.size():
		intactos = intactos and entradas.puntos[i] == viejos[i]
	verificar(intactos and h.objetivo == regreso_anterior, "agregar el acceso no mueve el nido, las entradas previas ni el destino de una hormiga que ya vuelve")
	h._volver()
	verificar(h.objetivo == entradas.punto_proyecto and entradas.elegir(ancla) == entradas.punto_proyecto, "un regreso nuevo sí puede elegir el acceso adelantado más cercano")
	verificar(Juego.migas_run == saldo and run.comidas.lista.size() == alimentos and run.comidas.fragmentos.size() == restos and run.colonia.get_child_count() == hormigas, "el acceso no paga dinero ni crea comida, fragmentos o hormigas adicionales")
	var consultas := cocina.consultas_libre
	for i in 100:
		entradas.actualizar()
	verificar(cocina.consultas_libre == consultas and cocina.busquedas_astar == consultas_astar and entradas.puntos.size() == 8, "el punto válido queda cacheado sin consultas geométricas ni A* repetidos ni duplicados")
	# El proyecto aparece primero y no consume los cupos manuales restantes.
	Juego.niveles.entradas = 0
	Juego._cache_stats.clear()
	cocina.bloqueada = Rect2()
	cocina.version += 1
	var futuras := CANDIDATAS.duplicate()
	futuras[1] = ancla
	var temprana := entradas_controladas(run, futuras)
	temprana.actualizar()
	verificar(temprana._normales == 1 and temprana.puntos.size() == 3 and temprana.punto_proyecto == ancla, "el proyecto conserva su ancla automática sin consumir un cupo manual")
	var punto_temprano := temprana.punto_proyecto
	Juego.niveles.entradas = 5
	Juego._cache_stats.clear()
	for pos: Vector2 in CANDIDATAS:
		temprana.colocar(pos)
	temprana.actualizar()
	verificar(temprana._normales == 6 and temprana.puntos.size() == 8 and temprana.puntos.has(ancla) and temprana.punto_proyecto == punto_temprano, "colocar después los seis accesos conserva el premio y todos los espacios normales")
	# Si no existe lugar, no repetir las veintiuna pruebas en cada actualización.
	cocina.bloqueada = Rect2(ancla - Vector2.ONE * 500, Vector2.ONE * 1000)
	cocina.version += 1
	var pendiente := entradas_controladas(run, CANDIDATAS)
	pendiente.actualizar()
	consultas = cocina.consultas_libre
	for i in 100:
		pendiente.actualizar()
	verificar(pendiente.punto_proyecto == Vector2.INF and cocina.consultas_libre == consultas, "un sector bloqueado conserva pendiente el premio sin repetir búsquedas mientras nada cambie")
	cocina.bloqueada = Rect2()
	cocina.version += 1
	pendiente.actualizar()
	verificar(pendiente.punto_proyecto == ancla and pendiente.puntos.size() == 8, "liberar la geometría activa el premio pendiente sin perder ninguno de los seis accesos normales")
	run.cocina = real
	run.queue_free()
	await get_tree().process_frame


func probar_plano_real(destino: String) -> void:
	preparar(destino, true)
	var proyecto := logistico(destino)
	var ancla := ancla_del_plano(destino, proyecto)
	var run := crear_run()
	var antes := run.entradas.puntos.duplicate()
	var saldo := Juego.migas_run
	var alimentos := run.comidas.lista.size()
	var hormigas := run.colonia.get_child_count()
	var astar := run.cocina.busquedas_astar
	run.entradas.actualizar()
	var punto := run.entradas.punto_proyecto
	verificar(punto != Vector2.INF and punto.distance_to(ancla) <= 288.01 and run.cocina.libre(punto, 40), destino + ": el acceso propio queda cerca del último objeto y fuera de obstáculos reales")
	verificar(run.entradas._normales <= 6 and run.entradas.puntos.size() == run.entradas._normales + 2 and run.entradas.puntos.size() <= 8 and run.entradas.puntos[0] == Vector2.ZERO, destino + ": conserva el nido, el cap normal y un único punto adicional")
	var estables := true
	for i in antes.size():
		estables = estables and run.entradas.puntos[i] == antes[i]
	verificar(estables and run.cocina.busquedas_astar == astar, destino + ": revelar el premio sólo agrega puntos, sin mover viejos ni consultar A*")
	verificar(Juego.proyecto_completo(proyecto.id) and Juego.entradas_proyectos(destino) == 1 and Juego.migas_run == saldo and run.comidas.lista.size() == alimentos and run.colonia.get_child_count() == hormigas, destino + ": el premio conserva sus flags sin ingresos, comida ni población extra")
	run.queue_free()
	await get_tree().process_frame


func probar_persistencia() -> void:
	preparar("restaurante", true)
	var proyecto := logistico("restaurante")
	var run := crear_run()
	run.entradas.actualizar()
	var punto := run.entradas.punto_proyecto
	var guardado: Dictionary = JSON.parse_string(JSON.stringify(Juego.datos_partida()))
	run.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	Juego.restaurar_partida(guardado)
	var regreso := crear_run()
	regreso.entradas.actualizar()
	verificar(Juego.proyecto_completo(proyecto.id) and regreso.entradas.punto_proyecto == punto and regreso.entradas.puntos[0] == Vector2.ZERO, "cargar reconstruye el acceso desde el catálogo y sus flags sin guardar otra posición")
	verificar(Juego.migas_run == 0 and not Juego.lugares_completados.has("restaurante"), "recuperar el acceso no vuelve a pagar el proyecto ni conquista el destino")
	regreso.queue_free()
	await get_tree().process_frame
	verificar(Juego.fundar_colonia() and Juego.lugar_actual == "casa" and Juego.proyecto_completo(proyecto.id), "fundar vuelve al nido y conserva el proyecto que ganó el acceso")


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)
