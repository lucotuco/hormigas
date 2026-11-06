extends Node
## Integración física y persistencia. No simula duración ni ingresos humanos.
const RUN := preload("res://mundo/run.tscn")
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	var habia_partida := FileAccess.file_exists(Juego.RUTA_PARTIDA)
	var huella := hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) if habia_partida else 0
	await probar_generacion()
	await probar_aperturas()
	await probar_retiro_entero()
	probar_estado()
	var intacta := habia_partida == FileAccess.file_exists(Juego.RUTA_PARTIDA)
	if habia_partida:
		intacta = intacta and huella == hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA))
	verificar(intacta and not Juego.guardado_habilitado, "los encuentros de prueba no escriben la partida personal")
	print("Hallazgos de la casa: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func verificar(condicion: bool, mensaje: String) -> void:
	total += 1
	if not condicion:
		fallas += 1
	print("OK " if condicion else "FALLA ", mensaje)


func crear() -> Run:
	var run: Run = RUN.instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	return run


func resumen(run: Run) -> Dictionary:
	var masa := 0.0
	var valor := 0.0
	var posiciones := {}
	var migas := {}
	for comida in run.comidas.lista:
		masa += comida.vida_max
		valor += comida.recompensa
		var encuentro := CatalogoHallazgos.por_envoltorio(comida.id)
		posiciones[comida.semilla_dibujo] = {"id": comida.id if encuentro.is_empty() else encuentro.comida, "pos": comida.position}
		if comida.id == "miga":
			migas[comida.semilla_dibujo] = comida.position
	for hallazgo: Dictionary in run.comidas._hallazgos.values():
		masa += float(hallazgo.contenido.vida)
		valor += float(hallazgo.contenido.recompensa)
	return {"masa": masa, "valor": valor, "posiciones": posiciones, "migas": migas, "contexto": run.recorrido.contexto_inicial}


func probar_generacion() -> void:
	Juego.reiniciar_estado()
	var cerrada := crear()
	var antes := resumen(cerrada)
	var ids: Array[String] = []
	var ubicadas := cerrada.comidas._hallazgos.size() == 3
	for comida in cerrada.comidas.lista:
		var datos := CatalogoHallazgos.por_envoltorio(comida.id)
		if not datos.is_empty():
			ids.append(datos.id)
			ubicadas = ubicadas and comida.position.length() >= 250 and comida.position.length() <= 900 and not Graficos.formas_alimento(comida.id).is_empty()
	verificar(ubicadas, "los tres hallazgos tienen cuerpo real, fuera del primer anillo y antes de materiales nuevos")
	verificar(cerrada.comidas.lista.size() == antes.posiciones.size() and cerrada.comidas.resistencia_reservada() > 0, "el contenido reservado no es otro objetivo ni se cuenta dos veces")
	cerrada.queue_free()
	await get_tree().process_frame
	for id in ids:
		Juego.registrar_hallazgo_casa(id)
	var abierta := crear()
	var despues := resumen(abierta)
	verificar(is_equal_approx(antes.masa, despues.masa) and is_equal_approx(antes.valor, despues.valor), "envoltorios más contenidos conservan toda la masa y el valor nativos, sin bonus extra")
	verificar(antes.posiciones == despues.posiciones and antes.migas == despues.migas and antes.migas.size() == 138, "no cambian posiciones, semilla ni ninguna de las 138 migas")
	verificar(abierta.comidas._hallazgos.is_empty() and is_equal_approx(abierta.comidas.resistencia_reservada(), float(abierta.comidas._comida_atajo.tipo.vida)), "los paquetes abiertos no reservan comida; sólo queda la galletita del atajo todavía cerrado")
	verificar(antes.contexto != despues.contexto, "los récords distinguen una casa con paquetes de otra donde ya se abrieron")
	abierta.queue_free()
	await get_tree().process_frame


func probar_aperturas() -> void:
	Juego.reiniciar_estado()
	var run := crear()
	var envoltorios: Array[Comida] = []
	for comida in run.comidas.lista:
		if not CatalogoHallazgos.por_envoltorio(comida.id).is_empty():
			envoltorios.append(comida)
	for envoltorio in envoltorios:
		var id: String = run.comidas._hallazgos[envoltorio.get_instance_id()].id
		var reservado: Dictionary = run.comidas._hallazgos[envoltorio.get_instance_id()].duplicate(true)
		var pos := envoltorio.position
		var vida := envoltorio.vida
		var origen := pos + Vector2.from_angle(envoltorio.rotation) * (envoltorio.radio + 2)
		verificar(envoltorio.morder_local(100, origen) == 0 and envoltorio.vida == vida and envoltorio.mordiscos == null and envoltorio.material_preparandose(), id + ": pedir la máscara no extrae ni publica material incompleto")
		for i in 2000:
			if envoltorio.preparar_material():
				break
			run.preparador_mordiscos.procesar(1000, 128)
		verificar(envoltorio.mordiscos != null and not envoltorio.material_preparandose(), id + ": termina mediante la cola normal, sin fallback síncrono")
		var extraido := 0.0
		var pasos := 0
		while not envoltorio.muerta and pasos < 1000:
			extraido += envoltorio.morder_local(100, origen)
			pasos += 1
		var contenido: Comida
		for comida in run.comidas.lista:
			if comida.position == pos and comida.id == reservado.contenido.id:
				contenido = comida
		verificar(pasos > 1 and envoltorio.muerta and is_instance_valid(contenido) and Juego.hallazgo_casa_abierto(id), id + ": varios retazos abren una sola comida en el mismo lugar")
		if is_instance_valid(contenido):
			verificar(is_equal_approx(contenido.vida_max, reservado.contenido.vida) and is_equal_approx(contenido.recompensa, reservado.contenido.recompensa) and contenido.semilla_dibujo == reservado.semilla, id + ": el contenido conserva su porción exacta y semilla de dibujo")
		verificar(is_equal_approx(extraido, envoltorio.recompensa * Juego.stat("multiplicador_migas")), id + ": el papel transportado coincide con la recompensa realmente extraída")
	verificar(not Juego.hitos.has("primer_tesoro") and Juego.stat("olfato") == Juego.stats_base.olfato, "abrir papel no regala el hito ni el olfato de los muebles")
	verificar(run.comidas._hallazgos.is_empty(), "los tres contenidos reservados se consumen una sola vez al abrir")
	run.queue_free()
	await get_tree().process_frame


func probar_retiro_entero() -> void:
	# La aspiradora recoge un objeto completo: no debe esperar una máscara
	# y perderlo al salir de su radio. No es un atajo para las hormigas.
	var run := crear()
	var alimento: Comida = run.comidas.lista[0]
	var vida := alimento.vida
	var valor := alimento.recompensa * Juego.stat("multiplicador_migas")
	alimento.preparar_material()
	var saldo := Juego.migas_run
	var extraida := run.resistencia_extraida
	var retiros := {"cantidad": 0}
	alimento.destruida.connect(func(_c): retiros.cantidad += 1)
	var botin := alimento.retirar_por_amenaza()
	verificar(is_equal_approx(botin, valor) and alimento.muerta and alimento.vida == 0 and alimento.mordiscos == null and retiros.cantidad == 1, "recoger el alimento completo conserva botín sin preparar una máscara inútil")
	verificar(alimento.retirar_por_amenaza() == 0 and retiros.cantidad == 1 and Juego.migas_run == saldo and is_equal_approx(run.resistencia_extraida - extraida, vida), "el retiro completo conserva señal y masa sin acreditar bonus ni botín antes de vencer al enemigo")
	run.preparador_mordiscos.procesar()
	verificar(not run.preparador_mordiscos.pendiente(alimento), "el recurso retirado no deja una preparación huérfana")
	var parcial := run.comidas._crear(Juego.comidas[0], Vector2(-180, 80), 17)
	parcial.preparar_material()
	for i in 1000:
		if parcial.preparar_material():
			break
		run.preparador_mordiscos.procesar(1000, 128)
	var mordida := parcial.morder_local(0.5, parcial.position + Vector2.from_angle(parcial.rotation) * (parcial.radio + 2))
	var pendiente := parcial.recompensa * parcial.vida / parcial.vida_max * Juego.stat("multiplicador_migas")
	var todo := parcial.recompensa * Juego.stat("multiplicador_migas")
	verificar(is_equal_approx(parcial.retirar_por_amenaza(), pendiente) and is_equal_approx(mordida + pendiente, todo), "recoger comida ya mordida no vuelve a robar el retazo que se llevó la hormiga")
	verificar(run.objetivo_practica.retirar_por_amenaza() == 0 and not run.objetivo_practica.muerta, "las amenazas no usan el retiro de comida para borrar muebles")
	run.queue_free()
	await get_tree().process_frame


func probar_estado() -> void:
	var saldo := Juego.migas
	var guardada := Juego.datos_partida()
	verificar(guardada.version == 10 and guardada.hallazgos_casa_abiertos.size() == 3 and not Juego.registrar_hallazgo_casa("sobre_azucar") and Juego.migas == saldo, "el recuerdo es idempotente y no vuelve a pagar")
	Juego.reiniciar_estado()
	Juego.restaurar_partida(guardada)
	verificar(Juego.hallazgos_casa_abiertos.size() == 3, "el guardado restaura sólo los encuentros completos")
	Juego.coronas = 1
	Juego.fundar_colonia()
	verificar(Juego.hallazgos_casa_abiertos.size() == 3 and Juego.lugar_actual == "casa", "fundar conserva los recuerdos y vuelve a la casa")
	Juego.restaurar_partida({"version": 9, "migas": 93.0, "niveles": {"mandibulas": 2}})
	verificar(Juego.hallazgos_casa_abiertos.is_empty() and Juego.migas == 93 and Juego.nivel_de("mandibulas") == 2, "las partidas anteriores no pierden compras ni reciben aperturas o premios ficticios")
	Juego.restaurar_partida({"version": 10, "hallazgos_casa_abiertos": {"sobre_azucar": true, "bolsa_cereal": 1, "papel_galletita": false, "inexistente": true}})
	verificar(Juego.hallazgos_casa_abiertos == {"sobre_azucar": true} and not Juego.registrar_hallazgo_casa("inexistente"), "la carga rechaza IDs inexistentes y estados que no son booleanos")
	Juego.reiniciar_estado()
	verificar(Juego.hallazgos_casa_abiertos.is_empty(), "empezar una partida nueva limpia los recuerdos")
