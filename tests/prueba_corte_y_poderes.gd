extends Node
## El silbato corta extracción; entradas manuales y Ráfaga no crean recursos.
const RUN := preload("res://mundo/run.tscn")
const HISTORICAS: Array[Vector2] = [Vector2(250, 25), Vector2(400, -50),
	Vector2(-250, 25), Vector2(-400, -50), Vector2(250, 300), Vector2(-250, 300)]
var total := 0
var fallas := 0

class CocinaControlada extends Cocina:
	var limite_x := 500.0
	var bloqueadas: Array[Rect2] = []
	var consultas_libre := 0
	func _ready() -> void:
		pass
	func libre(pos: Vector2, margen := 0.0, _volando := false) -> bool:
		consultas_libre += 1
		if not pos.is_finite() or pos.x >= limite_x or margen != EntradasHormiguero.MARGEN_ACCESO:
			return false
		for rect in bloqueadas:
			if rect.grow(margen).has_point(pos):
				return false
		return true


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	await probar_corte()
	await probar_rafaga()
	await probar_entradas_manuales()
	await probar_layout_tras_fundar()
	await probar_guardadas_pendientes()
	await probar_slots_reservados()
	await probar_orden_acceso_proyecto()
	Juego.reiniciar_estado()
	print("Corte y poderes de colonia: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func crear() -> Run:
	Juego.reiniciar_estado()
	Juego.niveles = {"entradas": 2, "mordida_madera": 1}
	Juego._cache_stats.clear()
	var r: Run = RUN.instantiate()
	add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	return r


func probar_corte() -> void:
	var r := crear()
	var alimento := Comida.new()
	alimento._usar_cache = false
	r.comidas.add_child(alimento)
	alimento.configurar({"id": "corte_fixture", "nombre": "Comida de prueba", "forma": "miga", "color": Color.BROWN,
		"vida": 10000.0, "recompensa": 1000.0, "radio": 32.0}, 123)
	alimento.position = Vector2(70, 0)
	alimento.preparar_material()
	alimento.aplicar_veneno(10000, 10, r, Vector2(110, 0))
	alimento._procesar_veneno(0.2)
	r.cola_erosion.encolar(alimento, 5000, Vector2(110, 0))
	r.reglas._pendientes.append({"parte": null})
	var llevando := r.colonia._nacer("obrera", Vector2(30, 0))
	llevando.carga = 7
	var sin_carga := r.colonia._nacer("obrera", Vector2(40, 0))
	sin_carga.estado = Hormiga.Estado.MORDIENDO
	sin_carga.comida = alimento
	r.tiempo_restante = 0.01
	var jugado := r.tiempo_jugado
	r._process(0.1)
	verificar(not r.activa and r.retirando and not r.cerrando_erosion and r.tiempo_restante == 0,
		"el reloj vencido pasa directo a retirada, sin liquidación de daño")
	verificar(is_equal_approx(r.tiempo_jugado - jugado, 0.01) and r.tiempo_espera_erosion == 0,
		"sólo cuenta el último tiempo real disponible, no el exceso de cuadro")
	verificar(not r.preparador_mordiscos.tiene_pendientes() and not alimento.material_preparandose() and alimento.mordiscos == null,
		"el silbato cancela preparación incompleta y limpia su estado de espera")
	verificar(not r.cola_erosion.tiene_pendientes() and alimento.veneno_restante == 0 and alimento._veneno_acumulado == 0 and r.reglas._pendientes.is_empty(),
		"se descartan corrosión, fracción de veneno y dominó todavía no extraídos")
	r.cola_erosion.procesar(1000000, 100)
	r.preparador_mordiscos.procesar(1000000, 100)
	alimento._procesar_veneno(100)
	r.reglas._process(100)
	sin_carga._morder(100)
	verificar(alimento.vida == alimento.vida_max and Juego.migas_run == 0,
		"ninguna fuente vuelve a quitar HP ni a pagar después del silbato")
	verificar(llevando.carga == 7 and llevando.estado == Hormiga.Estado.VOLVIENDO and sin_carga.estado == Hormiga.Estado.QUIETA,
		"sólo las hormigas que ya tenían carga vuelven para entregarla")
	verificar(not r.cola_erosion.encolar(alimento, 1000, Vector2(110, 0)), "la cola cerrada rechaza trabajo nuevo")
	llevando._descargar()
	verificar(Juego.migas_run == 7 and llevando.carga == 0 and r.poderes.carga_entregas == 0,
		"la última entrega acredita exactamente la carga previa sin cargar otro poder")
	r._cerrar()
	var runs := Juego.runs_jugadas
	r._cerrar()
	verificar(r.terminada and Juego.runs_jugadas == runs and Juego.migas_run == 7, "repetir el cierre no reabre daño ni duplica pagos")
	r.queue_free()
	await get_tree().process_frame


func probar_rafaga() -> void:
	var r := crear()
	verificar(not r.activar_rafaga() and r.multiplicador_dano_activo() == 1, "Ráfaga arranca vacía y no altera daño base")
	r.registrar_ingreso(100000)
	r.depositar(0)
	verificar(r.poderes.carga_entregas == 0, "premios y depósitos vacíos no cargan el poder")
	var saldo := Juego.migas_run
	for i in int(Juego.stat("rafaga_entregas")) - 1:
		r.depositar(1)
	verificar(not r.activar_rafaga(), "una entrega menos que el requisito no alcanza")
	r.depositar(1)
	verificar(r.poderes.lista() and r.activar_rafaga(), "las entregas reales completan y activan Ráfaga")
	verificar(Juego.migas_run == saldo + Juego.stat("rafaga_entregas") and r.poderes.carga_entregas == 0,
		"activar no compra monedas ni paga un premio: sólo consume la carga de entregas")
	verificar(is_equal_approx(r.multiplicador_dano_activo(), Juego.stat("rafaga_multiplicador_dano")),
		"el multiplicador activo sale del CSV y no cambia las estadísticas permanentes")
	verificar(is_equal_approx(r.multiplicador_ritmo_activo(), Juego.stat("rafaga_multiplicador_ritmo")),
		"el ritmo de mordida temporal también respeta el CSV sin agrandar cada retazo")
	r.poderes.procesar(Juego.stat("rafaga_duracion"))
	verificar(r.multiplicador_dano_activo() == 1 and r.multiplicador_ritmo_activo() == 1 and r.poderes.descanso_restante > 0,
		"la fuerza temporal termina exactamente al agotar su duración")
	for i in int(Juego.stat("rafaga_entregas")):
		r.depositar(1)
	verificar(not r.activar_rafaga(), "recargar entregas no permite saltarse el descanso")
	r.poderes.procesar(Juego.stat("rafaga_descanso"))
	verificar(r.activar_rafaga(), "terminar el descanso permite usar la carga reunida")
	r._iniciar_retirada()
	verificar(r.multiplicador_dano_activo() == 1 and not r.activar_rafaga(), "retirarse cancela el poder e impide reactivarlo")
	r.queue_free()
	await get_tree().process_frame


func probar_entradas_manuales() -> void:
	var r := crear()
	var original := r.cocina
	var cocina := CocinaControlada.new()
	r.add_child(cocina)
	r.cocina = cocina
	r.radio_actual = 620
	verificar(r.entradas.puntos == [Vector2.ZERO] and r.entradas_disponibles() == 2,
		"comprar entradas otorga cupos sin autocolocar accesos")
	var saldo := Juego.migas_run
	verificar(r.iniciar_colocacion_entrada() and r.poderes.colocando_entrada, "N habilita un modo de colocación con cupos comprados")
	verificar(not r.colocar_entrada(Vector2(600, 0)) and not r.colocar_entrada(Vector2.INF) and not r.colocar_entrada(Vector2(610, 0)),
		"piso bloqueado, coordenadas inválidas y margen fuera de territorio no se aceptan")
	verificar(r.entradas_disponibles() == 2 and r.poderes.colocando_entrada, "un clic inválido no gasta cupo ni cierra el modo")
	var elegida := Vector2(250, 25)
	verificar(r.colocar_entrada(elegida) and r.entradas.puntos.has(elegida) and r.entradas_disponibles() == 1,
		"el acceso queda en la posición exacta elegida y usa un solo cupo")
	verificar(not r.poderes.colocando_entrada and r.entradas.elegir(elegida) == elegida,
		"confirmar sale del modo y habilita el punto como entrega más cercana")
	verificar(r.iniciar_colocacion_entrada() and r.colocar_entrada(elegida) and not r.entradas.puntos.has(elegida) and r.entradas_disponibles() == 2 and r.poderes.colocando_entrada,
		"clic sobre una entrada puesta la levanta para moverla y devuelve su cupo")
	verificar(r.colocar_entrada(elegida) and r.entradas.puntos.has(elegida) and r.entradas_disponibles() == 1, "la entrada levantada se vuelve a colocar")
	r.iniciar_colocacion_entrada()
	r.cancelar_colocacion_entrada()
	verificar(not r.poderes.colocando_entrada and r.entradas_disponibles() == 1, "cancelar no consume el cupo disponible")
	r.iniciar_colocacion_entrada()
	verificar(r.colocar_entrada(Vector2(400, -50)) and r.entradas_disponibles() == 0, "el último cupo se coloca")
	verificar(r.iniciar_colocacion_entrada() and not r.colocar_entrada(Vector2(-300, 120)), "sin cupos se puede abrir el modo para mover, pero no agregar otra")
	r.cancelar_colocacion_entrada()
	verificar(Juego.migas_run == saldo and r.entradas.puntos.size() == 3, "colocar accesos no crea recursos ni mueve el nido")
	verificar(Juego.entradas_de(Juego.lugar_actual) == [elegida, Vector2(400, -50)], "las entradas colocadas quedan guardadas para el destino")
	r.cocina = original
	r.queue_free()
	await get_tree().process_frame
	# La expedición siguiente las repone sola, en el mismo lugar.
	var guardado := Juego.datos_partida()
	var otra := crear()
	Juego.restaurar_partida(guardado)
	Juego.niveles = {"entradas": 2, "mordida_madera": 1}
	Juego._cache_stats.clear()
	var cocina_otra := CocinaControlada.new()
	otra.add_child(cocina_otra)
	otra.cocina = cocina_otra
	otra.radio_actual = 620
	otra.entradas._repuestas = false # El fixture cargó el layout después de crear la run.
	otra.entradas._reponer_guardadas()
	verificar(otra.entradas.puntos == [Vector2.ZERO, elegida, Vector2(400, -50)] and otra.entradas_disponibles() == 0, "la expedición siguiente repone las entradas guardadas sin pedir N")
	verificar(Juego.entradas_de("casa").size() == 2, "las posiciones sobreviven a guardar y cargar la partida")
	otra.queue_free()
	await get_tree().process_frame


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)


func instalar_cocina(r: Run) -> CocinaControlada:
	var cocina := CocinaControlada.new()
	r.add_child(cocina)
	r.cocina = cocina
	r.entradas._repuestas = false # La geometría controlada reemplaza la cocina nativa del fixture.
	return cocina


func renovar_entradas(r: Run) -> void:
	# En estos casos se reemplazó la cocina DESPUÉS del inicio real. Usar un
	# nodo nuevo aísla el layout de cualquier selección hecha con el plano nativo.
	r.entradas.queue_free()
	r.entradas = EntradasHormiguero.new()
	r.add_child(r.entradas)
	r.entradas.iniciar(r)


func probar_layout_tras_fundar() -> void:
	var r := crear()
	instalar_cocina(r)
	Juego.lugares_completados["casa"] = true
	Juego.niveles.entradas = 5
	Juego.coronas = 1
	Juego._cache_stats.clear()
	Juego.guardar_entradas("casa", HISTORICAS)
	r.entradas.actualizar()
	verificar(r.entradas._normales == 6 and Juego.entradas_de("casa") == HISTORICAS,
		"el layout de seis posiciones se activa con cinco niveles y la adaptación real de Casa")
	verificar(Juego.fundar_colonia() and Juego.stat("entradas") == 1 and Juego.entradas_de("casa") == HISTORICAS,
		"fundar reduce seis cupos a uno sin borrar las seis posiciones históricas")
	r.queue_free()
	await get_tree().process_frame
	var nueva: Run = RUN.instantiate()
	add_child(nueva)
	nueva.process_mode = Node.PROCESS_MODE_DISABLED
	instalar_cocina(nueva)
	renovar_entradas(nueva)
	verificar(nueva.entradas._manuales == [HISTORICAS[0]] and nueva.entradas._normales == 1 and Juego.entradas_de("casa") == HISTORICAS,
		"la nueva colonia repone sólo el primer cupo y conserva las otras cinco posiciones no activas")
	var reemplazo := Vector2(0, 300)
	verificar(nueva.iniciar_colocacion_entrada() and nueva.colocar_entrada(HISTORICAS[0]),
		"una entrada activa se puede levantar aunque ya use el único cupo de la colonia")
	nueva.entradas.actualizar()
	verificar(nueva.entradas._normales == 0 and nueva.entradas.puntos == [Vector2.ZERO],
		"el cupo levantado se reserva para el movimiento, sin activar otra histórica entre clics")
	verificar(nueva.colocar_entrada(reemplazo) and nueva.entradas._manuales == [reemplazo],
		"la entrada levantada se coloca en su destino nuevo sin gastar otro cupo")
	var esperado := HISTORICAS.duplicate()
	esperado[0] = reemplazo
	verificar(Juego.entradas_de("casa") == esperado,
		"mover la primera modifica sólo esa posición y conserva su prioridad delante de las otras cinco")
	var guardado: Dictionary = JSON.parse_string(JSON.stringify(Juego.datos_partida()))
	nueva.queue_free()
	await get_tree().process_frame
	Juego.restaurar_partida(guardado)
	var siguiente: Run = RUN.instantiate()
	add_child(siguiente)
	siguiente.process_mode = Node.PROCESS_MODE_DISABLED
	instalar_cocina(siguiente)
	renovar_entradas(siguiente)
	verificar(siguiente.entradas._manuales == [reemplazo] and Juego.entradas_de("casa") == esperado,
		"guardar/cargar y otra expedición de un cupo recuperan la primera movida sin perder las cinco reservadas")
	siguiente.queue_free()
	await get_tree().process_frame


func probar_guardadas_pendientes() -> void:
	var r := crear()
	var cocina := instalar_cocina(r)
	var a := Vector2(250, 25)
	var b := Vector2(400, -50)
	var c := Vector2(-800, 0)
	var historicas: Array[Vector2] = [a, b, c]
	cocina.bloqueadas.append(Rect2(b - Vector2.ONE * 20, Vector2.ONE * 40))
	Juego.guardar_entradas("casa", historicas)
	r.entradas.actualizar()
	verificar(r.entradas._manuales == [a] and Juego.entradas_de("casa") == historicas,
		"territorio y obstáculos impiden activar dos posiciones sin borrarlas del layout")
	var consultas := cocina.consultas_libre
	for i in 100:
		r.entradas.actualizar()
	verificar(cocina.consultas_libre == consultas,
		"las históricas pendientes no repiten consultas de piso mientras no cambien geometría, radio o cupos")
	var extra := Vector2(0, 300)
	verificar(r.entradas.colocar(extra) and Juego.entradas_de("casa") == [a, b, c, extra],
		"agregar con un slot libre conserva también las históricas bloqueadas y remotas")
	verificar(r.entradas.quitar(extra) and Juego.entradas_de("casa") == historicas,
		"quitar esa entrada borra sólo su propia posición, no el subconjunto que faltaba restaurar")
	r.entradas.cancelar_reubicacion()
	r.radio_actual = 1000
	r.entradas.actualizar()
	verificar(r.entradas._manuales == [a, c] and Juego.entradas_de("casa") == historicas,
		"ampliar territorio repone la histórica ahora accesible sin pedir otro clic ni cambiar el layout")
	cocina.bloqueadas.clear()
	cocina.version += 1
	Juego.niveles.entradas = 3
	Juego._cache_stats.clear()
	r.entradas.actualizar()
	verificar(r.entradas._normales == 3 and r.entradas.puntos.has(b) and Juego.entradas_de("casa") == historicas,
		"recuperar cupos y liberar geometría repone también la posición antes bloqueada")
	consultas = cocina.consultas_libre
	for i in 100:
		r.entradas.actualizar()
	verificar(cocina.consultas_libre == consultas and r.entradas.puntos.size() == 4,
		"las restauraciones completas quedan cacheadas, sin duplicados ni búsquedas repetidas")
	r.queue_free()
	await get_tree().process_frame


func probar_slots_reservados() -> void:
	for cantidad in range(7):
		var r := crear()
		var cocina := instalar_cocina(r)
		Juego.lugares_completados["casa"] = true
		Juego.niveles.entradas = 5
		Juego._cache_stats.clear()
		var historicas := HISTORICAS.slice(0, cantidad)
		for punto in historicas:
			cocina.bloqueadas.append(Rect2(punto - Vector2.ONE * 20, Vector2.ONE * 40))
		Juego.guardar_entradas("casa", historicas)
		r.entradas.actualizar()
		verificar(r.entradas._normales == 0 and r.entradas.puntos == [Vector2.ZERO],
			"%d slots guardados pueden quedar inactivos sin convertirse en cupos usados" % cantidad)
		var extra := Vector2(0, 300)
		var colocada := r.entradas.colocar(extra)
		var esperado := historicas.duplicate()
		if cantidad < EntradasHormiguero.MAX_NORMALES:
			esperado.append(extra)
		verificar(colocada == (cantidad < EntradasHormiguero.MAX_NORMALES) and Juego.entradas_de("casa") == esperado,
			"%d slots reservados: agregar respeta el máximo de seis sin sobrescribir ninguna histórica" % cantidad)
		if cantidad == EntradasHormiguero.MAX_NORMALES:
			var saldo := Juego.migas_run
			verificar(r.iniciar_colocacion_entrada() and r.entradas._mostrar_guardadas and r.entradas.puede_levantar(historicas[0]),
				"con seis reservadas y cero activas, N muestra y permite levantar la histórica elegida")
			verificar(r.colocar_entrada(historicas[0]) and r.entradas._normales == 0 and r.entradas.puntos == [Vector2.ZERO],
				"levantar una inactiva libera su slot guardado, no resta un cupo activo inexistente")
			esperado = historicas.duplicate()
			esperado[0] = extra
			verificar(r.colocar_entrada(extra) and Juego.entradas_de("casa") == esperado and r.entradas._normales == 1 and not r.entradas._mostrar_guardadas,
				"mover esa histórica reutiliza exactamente su slot e índice y cierra la edición tenue")
			Juego.niveles.entradas = 1
			Juego.lugares_completados.clear()
			Juego._cache_stats.clear()
			verificar(not r.entradas.puede_levantar(historicas[1]) and not r.entradas.quitar(historicas[1]) and Juego.entradas_de("casa") == esperado,
				"con el único cupo ocupado, una histórica inactiva no se ofrece para un movimiento imposible")
			verificar(r.entradas.puede_levantar(extra) and Juego.migas_run == saldo,
				"la activa sí puede levantarse porque devuelve su cupo real, sin crear ingresos")
			r.entradas.quitar(extra)
			r.cancelar_colocacion_entrada()
			var restantes := historicas.slice(1)
			verificar(r.entradas._indice_reubicacion == -1 and Juego.entradas_de("casa") == restantes,
				"cancelar limpia el índice del movimiento y conserva todas las demás posiciones guardadas")
			Juego.niveles.entradas = 0
			Juego._cache_stats.clear()
			r.hud._actualizar_poderes()
			verificar(not r.iniciar_colocacion_entrada() and r.hud._boton_entrada.disabled and not r.entradas.puede_levantar(historicas[1]),
				"sin cupos reales ni entradas activas, N y la vista previa no ofrecen mover una histórica gratis")
		r.queue_free()
		await get_tree().process_frame


func probar_orden_acceso_proyecto() -> void:
	var r := crear()
	var cocina := instalar_cocina(r)
	cocina.limite_x = 100000
	Juego.lugar_actual = "restaurante"
	Juego.niveles.entradas = 1
	Juego._cache_stats.clear()
	var proyecto: Dictionary
	for candidato in ProyectosCampana.del_destino("restaurante"):
		if int(candidato.entrada) == 1:
			proyecto = candidato
			break
	for objetivo in proyecto.objetivos:
		Juego.registrar_objetivo_proyecto(objetivo.id)
	var ultimo: Dictionary = proyecto.objetivos.back()
	var ancla := Vector2.INF
	for mueble: Dictionary in Mundos.plano("restaurante").muebles:
		if mueble.tipo == ultimo.tipo and mueble.rect.position.distance_squared_to(ultimo.pos) < 0.01:
			ancla = mueble.rect.get_center()
			break
	Juego.guardar_entradas("restaurante", [ancla])
	r.entradas.queue_free()
	r.entradas = EntradasHormiguero.new()
	r.add_child(r.entradas)
	r.radio_actual = 12000
	r.activa = false
	r.entradas.iniciar(r)
	verificar(r.entradas.puntos == [Vector2.ZERO] and r.entradas.punto_proyecto == Vector2.INF,
		"antes de activar la run, el premio de proyecto no ocupa una posición manual todavía sin restaurar")
	r.activa = true
	r.entradas.actualizar()
	verificar(r.entradas._manuales == [ancla] and r.entradas.punto_proyecto == ancla + Vector2(96, 0) and r.entradas.puntos.size() == 3,
		"al activar se restaura primero la manual exacta y el proyecto elige su desvío independiente")
	verificar(Juego.entradas_de("restaurante") == [ancla] and r.entradas._normales == 1,
		"el premio de proyecto no reescribe el layout ni consume otro cupo manual")
	r.queue_free()
	await get_tree().process_frame
