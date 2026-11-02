extends Node
## El silbato corta extracción; entradas manuales y Ráfaga no crean recursos.
const RUN := preload("res://mundo/run.tscn")
var total := 0
var fallas := 0

class CocinaControlada extends Cocina:
	func _ready() -> void:
		pass
	func libre(pos: Vector2, margen := 0.0, _volando := false) -> bool:
		return pos.is_finite() and pos.x < 500 and margen == EntradasHormiguero.MARGEN_ACCESO


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	await probar_corte()
	await probar_rafaga()
	await probar_entradas_manuales()
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
