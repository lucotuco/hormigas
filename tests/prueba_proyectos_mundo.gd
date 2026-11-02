extends Node
## Contratos físicos y de ciclo de vida, con daño bulk explícito. No mide
## ritmo humano ni usa esa extracción administrativa como prueba de IA.
const RUN := preload("res://mundo/run.tscn")
const MUEBLES := {"restaurante": 57, "museo": 37, "obelisco": 41, "coliseo": 47, "eiffel": 45}
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	verificar(ProyectosCampana.todos().size() == 20 and ProyectosCampana.objetivos_destino("casa").is_empty(), "veinte proyectos amplían cinco destinos sin alterar el arranque de la casa")
	var objetivos := 0
	for destino in MUEBLES:
		objetivos += ProyectosCampana.objetivos_destino(destino).size()
	verificar(objetivos == 42, "el catálogo corresponde a cuarenta y dos muebles concretos existentes")
	for destino in MUEBLES:
		var antes := total
		await probar_destino(destino)
		await probar_contextos_historicos(destino)
		await probar_checkpoint_conquista(destino)
		verificar(total - antes >= 50, destino + ": más de cincuenta contratos físicos y de progreso")
	Juego.reiniciar_estado()
	print("Proyectos en el mundo: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func preparar(destino: String) -> void:
	Juego.reiniciar_estado()
	# Sólo habilita el contexto del destino bajo prueba. No concede sus
	# proyectos, su victoria ni ingresos; evita que restaurar vuelva a casa.
	for anterior in Mundos.ORDEN:
		if anterior == destino:
			break
		Juego.coronas_cobradas[anterior] = true
		Juego.lugares_completados[anterior] = true
		Juego.coronas += int(Mundos.INFO[anterior].coronas)
	Juego.lugar_actual = destino
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()


func crear_run() -> Run:
	var run: Run = RUN.instantiate()
	run.preparacion_sincrona = true # La persistencia se prueba con extracción directa.
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.radio_actual = 12000
	run.cocina.limite_rutas_por_cuadro = 0
	return run


func buscar(run: Run, id: String) -> PiezaCasa:
	for parte in run.comidas.partes:
		if parte.pieza.get("objetivo_proyecto", "") == id:
			return parte
	return null


func contar_comida(run: Run, id: String) -> int:
	var cantidad := 0
	for comida in run.comidas.lista:
		if is_instance_valid(comida) and not comida.muerta and comida.id == id:
			cantidad += 1
	return cantidad


func devorar(parte: PiezaCasa) -> void:
	# Daño administrativo deliberado para comprobar callbacks/persistencia;
	# los bocados locales y la carga real tienen sus suites independientes.
	for paso in 32:
		if not is_instance_valid(parte) or parte.muerta:
			return
		if parte.derrumbando:
			parte._process(0.36)
		else:
			parte.morder(parte.vida_max * 2)
	verificar(is_instance_valid(parte) and parte.muerta, "el ciclo administrativo termina sin soportes imposibles")


func firma_plano(plano: Dictionary) -> String:
	var firma := ""
	for mueble: Dictionary in plano.muebles:
		firma += "%s:%s:%s:%s:%s|" % [mueble.tipo, mueble.rect, Graficos.clave_mueble(mueble), mueble.get("objetivo_proyecto", ""), mueble.get("proyecto_vida", 0.0)]
	return firma.sha256_text()


func probar_destino(destino: String) -> void:
	preparar(destino)
	var plano := Mundos.plano(destino)
	var firma := firma_plano(plano)
	var proyectos := ProyectosCampana.del_destino(destino)
	var objetivos := ProyectosCampana.objetivos_destino(destino)
	var metadatos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://datos/siluetas_muebles.json"))
	verificar(proyectos.size() == 4 and plano.muebles.size() == int(MUEBLES[destino]), destino + ": cuatro proyectos sin agregar muebles")
	verificar(plano.limites == PlanoCasa.LIMITES_JUGABLES and plano.limites_visuales == PlanoCasa.LIMITES_VISUALES, destino + ": no agranda área navegable ni fondo")
	var run := crear_run()
	var canonica := run.objetivo_mapa
	var vida_canonica := canonica.vida_max
	var coronas_antes := Juego.coronas
	var entradas_antes := int(Juego.stat("entradas"))
	verificar(is_instance_valid(run.objetivo_actual()) and run.objetivo_actual().pieza.has("objetivo_proyecto"), destino + ": el objetivo sugerido es un proyecto físico")
	verificar(not Juego.proyectos_completos(destino) and Juego.entradas_proyectos(destino) == 0, destino + ": no hay progreso ni accesos regalados")
	var suma_vida := 0.0
	var suma_ratios := 0.0
	var vistos: Dictionary = {}
	verificar(int(proyectos[0].entrada) == 1 and float(proyectos[0].vida_relativa) <= 0.35, destino + ": la logística aparece primero y no exige más de un tercio de la meta")
	if destino in ["obelisco", "eiffel"]:
		verificar(proyectos.back().objetivos.size() == 1 and float(proyectos.back().vida_relativa) <= 0.5, destino + ": la fuente lateral no equivale a otro monumento completo sin checkpoint")
	for indice in proyectos.size():
		var proyecto: Dictionary = proyectos[indice]
		suma_ratios += float(proyecto.vida_relativa)
		verificar(float(proyecto.vida_relativa) > 0 and int(proyecto.entrada) == int(indice == 0), proyecto.id + ": presupuesto positivo del CSV y un solo proyecto logístico")
		var vida_proyecto := 0.0
		for objetivo: Dictionary in proyecto.objetivos:
			verificar(not vistos.has(objetivo.id) and objetivo.id.begins_with(proyecto.id + "/") and ProyectosCampana.objetivo(objetivo.id) == objetivo, objetivo.id + ": alias global único y resoluble")
			vistos[objetivo.id] = true
			var parte := buscar(run, objetivo.id)
			verificar(is_instance_valid(parte) and parte.pieza.proyecto_id == proyecto.id and not parte.pieza.meta, objetivo.id + ": corresponde a una pieza real no canónica")
			if not is_instance_valid(parte):
				continue
			var original: Dictionary = plano.muebles[parte.pieza.mueble]
			verificar(parte.pieza.tipo == objetivo.tipo and parte.rect_mundo == original.rect and original.rect.position.distance_squared_to(objetivo.pos) < 0.01, objetivo.id + ": conserva tipo y geometría existente")
			var nativa := MaterialesCasa.definir(original.tipo, original.rect, original.color)
			var valor_nativo := float(nativa.recompensa) * float(Mundos.INFO[destino].factor)
			verificar(is_equal_approx(parte.recompensa, valor_nativo), objetivo.id + ": recompensa nativa sin multiplicarla por la nueva vida")
			verificar(is_equal_approx(parte.vida_max, vida_canonica * float(proyecto.vida_relativa) / proyecto.objetivos.size()), objetivo.id + ": fracción individual de la resistencia canónica")
			verificar(parte.nivel_requerido == MaterialesCasa.nivel_tipo(objetivo.tipo) and parte.nivel_requerido == int(nativa.nivel), objetivo.id + ": dieta propia sin convertir madera en pared")
			var clave_atlas := Graficos.clave_mueble(original)
			verificar(metadatos.has(clave_atlas) and Graficos.clave_mueble(parte.pieza.dibujo) == clave_atlas, objetivo.id + ": reutiliza una silueta y clave de atlas existentes")
			var punto := parte.punto_mordida(Vector2.ZERO, run.radio_actual)
			verificar(punto != Vector2.INF and parte.alcanza_desde(punto) and run.cocina.libre(punto, Cocina.MARGEN), objetivo.id + ": tiene borde de trabajo fuera de la colisión")
			verificar(run.cocina._obstaculos.has(parte.pieza.clave) and parte.celdas.size() <= 16, objetivo.id + ": participa de la navegación con hasta dieciséis celdas")
			vida_proyecto += parte.vida_max
		verificar(is_equal_approx(vida_proyecto, vida_canonica * float(proyecto.vida_relativa)), proyecto.id + ": la suma física conserva el presupuesto total del proyecto")
		suma_vida += vida_proyecto
	verificar(vistos.size() == objetivos.size() and is_equal_approx(suma_vida, vida_canonica * suma_ratios), destino + ": los cuatro proyectos conservan la suma de resistencia del CSV sin reemplazar la meta")
	var copia := ProyectosCampana.del_destino(destino)
	copia[0].nombre = "NO CAMBIAR EL CATÁLOGO"
	verificar(ProyectosCampana.del_destino(destino)[0].nombre == proyectos[0].nombre, destino + ": las consultas no mutan el catálogo compartido")
	# Un objeto terminado persiste; el mordido pero no terminado no se cuenta
	# como hecho ni transmite una barra de HP virtual a la expedición nueva.
	var primero: Dictionary = proyectos[0].objetivos[0]
	var segundo: Dictionary = proyectos[0].objetivos[1]
	var primera_parte := buscar(run, primero.id)
	devorar(primera_parte)
	verificar(Juego.objetivo_proyecto_completo(primero.id) and not Juego.proyecto_completo(proyectos[0].id), destino + ": registra el objeto entero sin adelantar su grupo")
	var parcial := buscar(run, segundo.id)
	parcial.morder_en(parcial.vida_max * 0.02, parcial.rect_mundo.position)
	verificar(parcial.vida < parcial.vida_max and not Juego.objetivo_proyecto_completo(segundo.id), destino + ": un recorte parcial no acredita un objetivo entero")
	devorar(canonica)
	verificar(Juego.meta_destino_devorada(destino) and not run.objetivo_completado and Juego.coronas == coronas_antes, destino + ": comer la meta antes de los proyectos no da la corona")
	var siguiente := Mundos.ORDEN.find(destino) + 1
	if siguiente < Mundos.ORDEN.size():
		verificar(not Juego.destino_desbloqueado(Mundos.ORDEN[siguiente]), destino + ": el viaje siguiente sigue bloqueado")
	var guardado: Dictionary = JSON.parse_string(JSON.stringify(Juego.datos_partida()))
	run.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	Juego.restaurar_partida(guardado)
	verificar(Juego.lugar_actual == destino and Juego.objetivo_proyecto_completo(primero.id) and Juego.meta_destino_devorada(destino), destino + ": guardar y cargar conserva objetos y meta devorados")
	verificar(not Juego.objetivo_proyecto_completo(segundo.id) and not Juego.lugares_completados.has(destino), destino + ": cargar no inventa progreso ni una victoria histórica")
	var regreso := crear_run()
	verificar(buscar(regreso, primero.id) == null and regreso.objetivo_mapa == null, destino + ": el objeto completo y la meta pendiente se omiten físicamente")
	var nueva_parcial := buscar(regreso, segundo.id)
	verificar(is_instance_valid(nueva_parcial) and is_equal_approx(nueva_parcial.vida, nueva_parcial.vida_max), destino + ": el objeto parcial vuelve como material real intacto")
	verificar(firma_plano(Mundos.plano(destino)) == firma, destino + ": persistir no altera el plano ni su caché de atlas")
	verificar(is_instance_valid(regreso.objetivo_actual()) and regreso.objetivo_actual().pieza.has("objetivo_proyecto"), destino + ": la sugerencia continúa aunque ya no exista la canónica")
	# Orden inverso deliberado: no hay puertas artificiales entre proyectos.
	for indice in range(proyectos.size() - 1, -1, -1):
		var proyecto: Dictionary = proyectos[indice]
		var alijos_antes := contar_comida(regreso, proyecto.alijo)
		var credito_antes := Juego.migas_run
		var bonus_esperado := 0.0
		var ultima: PiezaCasa
		for objetivo: Dictionary in proyecto.objetivos:
			if Juego.objetivo_proyecto_completo(objetivo.id):
				continue
			ultima = buscar(regreso, objetivo.id)
			verificar(is_instance_valid(ultima), objetivo.id + ": está disponible sin completar proyectos anteriores")
			if is_instance_valid(ultima):
				var recompensa_nativa := ultima.recompensa
				devorar(ultima)
				bonus_esperado += recompensa_nativa * Juego.stat("bonus_destruir") * Juego.stat("multiplicador_migas")
		verificar(Juego.proyecto_completo(proyecto.id), proyecto.id + ": se completa en orden libre con extracción física")
		verificar(contar_comida(regreso, proyecto.alijo) == alijos_antes + 1, proyecto.id + ": crea exactamente un alijo real al terminar el grupo")
		var alijos_completos := contar_comida(regreso, proyecto.alijo)
		var saldo_completo := Juego.migas_run
		var entradas_completas := Juego.entradas_proyectos(destino)
		if is_instance_valid(ultima):
			regreso.recorrido.registrar_destruccion(ultima)
		verificar(contar_comida(regreso, proyecto.alijo) == alijos_completos and Juego.migas_run == saldo_completo and Juego.entradas_proyectos(destino) == entradas_completas, proyecto.id + ": repetir el registro no duplica alijo ni dinero ni acceso")
		verificar(is_equal_approx(Juego.migas_run - credito_antes, bonus_esperado) and int(Juego.stat("entradas")) == entradas_antes, proyecto.id + ": sólo acredita el bonus nativo de destrucción y deja el alijo para transportar")
	verificar(regreso.objetivo_completado and Juego.coronas == coronas_antes + int(Mundos.INFO[destino].coronas), destino + ": el último lateral cierra la meta pendiente y paga las coronas del destino")
	verificar(Juego.proyectos_completos(destino) and Juego.entradas_proyectos(destino) == 1 and Juego.entradas_proyectos("casa") == 0, destino + ": el acceso de logística es local y se entrega una sola vez")
	if siguiente < Mundos.ORDEN.size():
		verificar(Juego.destino_desbloqueado(Mundos.ORDEN[siguiente]), destino + ": los proyectos y la meta abren el viaje siguiente")
	verificar(Juego.completar_destino() == 0 and Juego.coronas == coronas_antes + int(Mundos.INFO[destino].coronas), destino + ": repetir la victoria no vuelve a cobrar coronas")
	regreso.entradas.actualizar()
	verificar(regreso.entradas.puntos.size() <= 8, destino + ": mantiene el nido, seis accesos normales y uno propio del proyecto")
	var plano_hecho := MaterialesCasa.piezas()
	var recuperadas := 0
	for pieza: Dictionary in plano_hecho:
		if pieza.pared:
			continue
		if plano.muebles[pieza.mueble].has("objetivo_proyecto"):
			recuperadas += 1
			verificar(not pieza.has("objetivo_proyecto") and not pieza.has("proyecto_vida"), destino + ": una conquista histórica devuelve recursos normales sin HP de proyecto")
	verificar(recuperadas == objetivos.size() and firma_plano(Mundos.plano(destino)) == firma, destino + ": la victoria histórica no elimina mobiliario del plano compartido")
	regreso.queue_free()
	await get_tree().process_frame
	var repetida := crear_run()
	verificar(is_zero_approx(repetida.recorrido.progreso()), destino + ": una meta histórica repuesta empieza con progreso físico cero")
	var meta_repetida := repetida.objetivo_mapa
	meta_repetida.morder_en(meta_repetida.vida_max * 0.1, meta_repetida.rect_mundo.position)
	var fraccion_fisica := 1.0 - meta_repetida.vida / meta_repetida.vida_max
	verificar(fraccion_fisica > 0 and fraccion_fisica < 1 and is_equal_approx(repetida.recorrido.progreso(), fraccion_fisica), destino + ": el progreso histórico parcial coincide con la fracción realmente devorada")
	var normales := 0
	for parte in repetida.comidas.partes:
		if parte.pieza.pared:
			continue
		var original: Dictionary = plano.muebles[parte.pieza.mueble]
		if not original.has("objetivo_proyecto"):
			continue
		normales += 1
		var nativa := MaterialesCasa.definir(original.tipo, original.rect, original.color)
		var vida_nativa := float(nativa.vida) * float(Mundos.INFO[destino].factor) * Juego.stat("resistencia_muebles")
		verificar(not parte.pieza.has("objetivo_proyecto") and is_equal_approx(parte.vida_max, vida_nativa), destino + ": el recurso histórico reaparece con su resistencia nativa real")
	verificar(normales == objetivos.size() and Juego.entradas_proyectos(destino) == 1, destino + ": repetir el mapa no reclama proyectos ni duplica su acceso")
	repetida.queue_free()
	await get_tree().process_frame


func registrar_todos(destino: String) -> void:
	# Preparación administrativa explícita: esta fixture sólo prueba la
	# recuperación y el contexto, no afirma haber transportado los recursos.
	for objetivo in ProyectosCampana.objetivos_destino(destino):
		Juego.registrar_objetivo_proyecto(objetivo.id)


func contar_muebles_repuestos(run: Run, destino: String) -> int:
	var plano := Mundos.plano(destino)
	var cantidad := 0
	for parte in run.comidas.partes:
		if not parte.pieza.pared and plano.muebles[parte.pieza.mueble].has("objetivo_proyecto"):
			cantidad += 1
	return cantidad


func probar_contextos_historicos(destino: String) -> void:
	preparar(destino)
	registrar_todos(destino)
	verificar(Juego.proyectos_completos(destino) and not Juego.meta_destino_devorada(destino) and not Juego.lugares_completados.has(destino), destino + ": la fixture A termina proyectos explícitos pero no inventa la meta ni historia")
	var adelantada := crear_run()
	var contexto_a := adelantada.recorrido.contexto_inicial
	verificar(contar_muebles_repuestos(adelantada, destino) == 0 and is_instance_valid(adelantada.objetivo_mapa), destino + ": A omite los proyectos hechos y conserva su meta intacta")
	var registro_a := {"destino": destino, "version_mapa": Mundos.VERSION_CONTENIDO,
		"dieta": 3, "territorio": 620.0, "completa": false, "recorrido": contexto_a}
	Juego.completar_destino()
	adelantada.queue_free()
	await get_tree().process_frame
	var historica := crear_run()
	var contexto_b := historica.recorrido.contexto_inicial
	verificar(contar_muebles_repuestos(historica, destino) == ProyectosCampana.objetivos_destino(destino).size() and is_instance_valid(historica.objetivo_mapa), destino + ": B repone muebles nativos y meta en una visita histórica")
	verificar(not contexto_a.is_empty() and not contexto_b.is_empty() and contexto_a != contexto_b, destino + ": el contexto inicial distingue recorrido adelantado y replay histórico")
	var registro_b: Dictionary = registro_a.duplicate()
	registro_b.recorrido = contexto_b
	verificar(Juego.clave_limpieza(registro_a) != Juego.clave_limpieza(registro_b), destino + ": los dos recorridos físicos no compiten por el mismo récord")
	historica.queue_free()
	await get_tree().process_frame


func probar_checkpoint_conquista(destino: String) -> void:
	preparar(destino)
	registrar_todos(destino)
	Juego.registrar_meta_destino()
	Juego.migas = 123.0
	var coronas_antes := Juego.coronas
	var estadistica_antes := float(Juego.estadisticas.get("coronas_ganadas", 0.0))
	var guardado: Dictionary = JSON.parse_string(JSON.stringify(Juego.datos_partida()))
	Juego.reiniciar_estado()
	Juego.restaurar_partida(guardado)
	verificar(Juego.meta_destino_devorada(destino) and Juego.proyectos_completos(destino) and not Juego.coronas_cobradas.has(destino) and not Juego.lugares_completados.has(destino), destino + ": restaura el checkpoint intermedio sin adelantar su corona")
	var recuperada := crear_run()
	verificar(recuperada.objetivo_completado and Juego.coronas_cobradas.has(destino) and Juego.coronas == coronas_antes + int(Mundos.INFO[destino].coronas), destino + ": el arranque recupera exactamente la corona pendiente")
	verificar(recuperada.objetivo_mapa == null and contar_muebles_repuestos(recuperada, destino) == 0, destino + ": resolver el checkpoint no repone piezas ya devoradas")
	verificar(Juego.migas == 123.0 and Juego.migas_run == 0 and recuperada.ingresos == [0.0, 0.0, 0.0], destino + ": la recuperación no paga extracción ni alijos ni bonus de destrucción")
	verificar(float(Juego.estadisticas.get("coronas_ganadas", 0.0)) == estadistica_antes + int(Mundos.INFO[destino].coronas) and not recuperada.recorrido.conquista_pendiente(), destino + ": la estadística y el checkpoint quedan cerrados una sola vez")
	var coronas_recuperadas := Juego.coronas
	var estadistica_recuperada := float(Juego.estadisticas.get("coronas_ganadas", 0.0))
	recuperada.queue_free()
	await get_tree().process_frame
	var posterior := crear_run()
	verificar(Juego.coronas == coronas_recuperadas and float(Juego.estadisticas.get("coronas_ganadas", 0.0)) == estadistica_recuperada and not posterior.recorrido.conquista_pendiente(), destino + ": abrir otra expedición no farmea la corona recuperada")
	verificar(Juego.migas == 123.0 and Juego.migas_run == 0 and posterior.ingresos == [0.0, 0.0, 0.0], destino + ": repetir el arranque tampoco crea ingresos por el checkpoint")
	posterior.queue_free()
	await get_tree().process_frame


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)
