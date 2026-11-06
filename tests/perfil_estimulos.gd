extends Node
## Perfil con renderer real, no prueba de diversión, audio ni duración de campaña.
## Se reconstruye cada caso: control = feedback natural; completo = amenazas
## reales al tope y demanda cosmética sintética de impactos/ráfagas. Los números,
## vuelos y ganancias sólo vienen del trabajo real de las hormigas. Las amenazas
## sí pueden cambiar trabajo, ingresos y RNG:
## la diferencia NO aísla el costo de dibujar efectos como un A/B causal puro.
## Completo compra las tres mejoras visuales; sus bonus también afectan el
## trabajo. El combo se alimenta sólo con los depósitos reales del escenario.
## Temblor a 1 en memoria: se exige ver el impacto central y su regreso,
## contar chispas vivas y avanzar la sacudida real sin leer teclado/mouse.
## Se mide tiempo transcurrido entre cuadros; CPU aislada no se midió.
## Ejecutar con --fixed-fps 60: así los 640 cuadros siempre contienen el
## mismo tiempo de simulación, aunque la GPU termine cada cuadro más rápido.
const CANTIDAD := 500
const CALENTAMIENTO := 40
const MEDICION := 600
const SEMILLA := 827
const RADIO := 9500.0
const CONFIGURACIONES := [
	{"destino": "casa", "equipo": ["corte", "contagio"]},
	{"destino": "museo", "equipo": ["sondeo", "barrido"]},
	{"destino": "coliseo", "equipo": ["cantera", "contagio"]},
	{"destino": "eiffel", "equipo": ["cantera", "puente"]},
]
const TIPOS := ["obrera", "carpintera", "cargadora", "roja", "voladora", "demoledora"]
const RUTA_RESULTADOS := "res://.godot/qa/perfil_estimulos.json"
const CEROS_VISUALES := ["0", "0.0", "0.00", "0.000", "0,0", "0,00", "0,000", "+0", "+0.0", "+0.00", "+0.000", "+0,0", "+0,00", "+0,000"]
var _fallas := 0
var _resultados: Array[Dictionary] = []


func _init() -> void:
	Juego.guardado_habilitado = false


func _ready() -> void:
	var huellas := _huellas_guardados()
	if DisplayServer.get_name() == "headless":
		_verificar(false, "este perfil exige renderer real; headless no mide FPS")
		get_tree().quit(1)
		return
	Ajustes.pausar_sin_foco = false
	Ajustes.temblor = 1.0 # Fixture visual; no guarda la preferencia personal.
	get_tree().paused = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true # No mide mezcla/reproducción de audio.
	Engine.time_scale = 1.0
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if not Graficos.listo:
		await Graficos.preparado
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not get_viewport().get_visible_rect().size.is_equal_approx(Vector2(1920, 1080)):
		_verificar(false, "ejecutar con --resolution 1920x1080: se exige el lienzo Full HD real")
		get_tree().quit(1)
		return
	_verificar(Graficos.textura != null, "atlas gráfico compartido terminado antes de medir")
	print("ESTÍMULOS CONFIG %s | 1920x1080 | semilla %d | %d hormigas | %d warm + %d muestras por caso | audio silenciado | temblor 1 en memoria; cámara sin teclado/mouse | CPU aislada no medida" % [RenderingServer.get_current_rendering_method(), SEMILLA, CANTIDAD, CALENTAMIENTO, MEDICION])
	for configuracion in CONFIGURACIONES:
		for completo in [false, true]:
			await _medir(configuracion, completo)
	_verificar(_huellas_guardados() == huellas, "partida y ajustes del jugador conservan existencia y SHA-256")
	var informe := {"renderer": RenderingServer.get_current_rendering_method(), "resolucion": "1920x1080", "semilla": SEMILLA, "calentamiento": CALENTAMIENTO, "muestras": MEDICION, "audio": "silenciado; mezcla no medida", "medicion": "tiempo transcurrido entre cuadros; CPU aislada no medida", "numeros": "pagos naturales únicamente; impactos/ráfagas cosméticos sintéticos en completo", "comparacion": "mismo inicio, no A/B causal: amenazas alteran el trabajo real", "guardados_antes": huellas, "guardados_despues": _huellas_guardados(), "casos": _resultados, "fallas": _fallas}
	informe["combo_y_camara"] = "temblor 1 en memoria; impacto/regreso por depósitos naturales; sacudida real a 1/60 sin teclado, zoom ni arrastre"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/qa"))
	var archivo := FileAccess.open(RUTA_RESULTADOS, FileAccess.WRITE)
	if archivo != null:
		archivo.store_string(JSON.stringify(informe, "\t"))
		archivo.close()
	else:
		_verificar(false, "se puede escribir el informe aislado en .godot/qa")
	print("Perfil de estímulos: %d casos / %d fallas. Los milisegundos no garantizan 60 FPS ni legibilidad humana." % [_resultados.size(), _fallas])
	get_tree().quit(0 if _fallas == 0 else 1)


func _medir(configuracion: Dictionary, completo: bool) -> void:
	Juego.reiniciar_estado()
	Juego.runs_jugadas = 10 # Frenesí revelado en ambos casos, como en una colonia real de 500.
	seed(SEMILLA)
	Juego.lugar_actual = configuracion.destino
	# Fixture de estrés, no niveles usados para estimar economía/campaña.
	Juego.niveles = {"entradas": 5, "mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1, "excavar": 30, "rastro_persistente": 10, "pisoton": 10}
	if completo:
		for id: String in ["migas_brillantes", "mandibulas_destello", "pulso_colonia"]:
			Juego.niveles[id] = 1
	for evolucion in configuracion.equipo:
		Juego.evoluciones_desbloqueadas[evolucion] = true
	Juego.evoluciones_equipadas.assign(configuracion.equipo)
	Juego._cache_stats.clear()
	if completo:
		for tipo: String in [Eventos.AMENAZAS[Juego.lugar_actual], Eventos.VARIANTES[Juego.lugar_actual], "avispa", "rival"]:
			_verificar(not Evento.datos_tipo(tipo).is_empty(), "configuración real disponible para " + tipo)
	var nodos_antes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var huerfanos_antes := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.set_process(false) # Sin reloj/fin/pisotón; _reloj se avanza a 1/60 abajo.
	run.set_process_unhandled_input(false)
	run.eventos.set_process(false) # El fixture llena el cupo, no mide cadencia.
	run.feromonas.set_process_unhandled_input(false)
	run.camara.set_process(false)
	run.camara.set_process_input(false)
	run.camara.set_process_unhandled_input(false)
	run.poderes.set_process_unhandled_input(false)
	# Mantener visibilidad y procesamiento normal de colonia, sin nacimientos
	# programados que cambiarían la población del escenario.
	run.colonia._por_salir = 0
	run.colonia._cola_castas.clear()
	run.colonia._intervalo_cria = 0.0
	run.objetivo_completado = true # Evitar cámara lenta de conquista, no sus HP.
	run.radio_actual = RADIO
	run.niebla.radio = RADIO
	_colocar_accesos(run)
	run.camara.zoom = Vector2.ONE * 0.28
	run.camara.position = Vector2(1200, 700)
	run.camara.force_update_scroll()
	var frente := run.objetivo_actual()
	var dano := maxf(20.0, frente.vida_max * 0.005) if is_instance_valid(frente) else 20.0
	_reponer_colonia(run, dano, 0)
	var tiempos: Array[float] = []
	var maximos := {"particulas": 0, "ondas": 0, "textos": 0, "marcas": 0, "textos_dibujados": 0, "nodos_efectos": 0, "amenazas": 0, "eventos": 0, "amenazas_visibles": 0, "fragmentos": 0, "rutas": 0, "erosion": 0, "preparador": 0, "preparaciones_pendientes": 0, "erosiones_pendientes": 0, "portadoras": 0, "hormigas_visibles": 0}
	var seguimiento: Dictionary = {}
	var pagos := {"descargas": {}, "descargas_min_muestreadas": 0, "cuadros_con_fraccion_asignada": 0, "cuadros_con_pago_normal_asignado": 0, "cuadros_hud_ganancia_visible": 0, "cuadros_saldo_fraccional": 0, "texto_cero_erroneo": 0, "textos_deposito_max": 0, "depositos_dibujados_max": 0, "fracciones_dibujadas_max": 0, "normales_dibujados_max": 0, "vuelos_max": 0, "slots_vuelos_max": 0, "nodos_vuelos_max": 0, "nodos_hud_max": 0, "pool_textos_max": 0, "pool_particulas_max": 0, "pool_ondas_max": 0, "pool_marcas_max": 0}
	var nodos_hud_iniciales := run.hud.get_child_count()
	maximos["chispas_combo"] = 0
	maximos["chispas_combo_activas"] = 0
	maximos["halos"] = 0
	maximos["masticando_visibles"] = 0
	maximos["etapa_combo"] = 0
	maximos["cuadros_combo_impacto"] = 0
	maximos["cuadros_combo_regreso"] = 0
	maximos["ancho_combo_impacto_px"] = 0.0
	maximos["offset_camara_px"] = 0.0
	var consultas := 0
	var astar := 0
	var extraido := 0.0
	var ingresos := 0.0
	var dibujos := 0.0
	var reposiciones := 0
	var minimo_hormigas := CANTIDAD
	var minimo_al_iniciar_cuadro := CANTIDAD
	var amenazas_creadas := 0
	var montones_fixture := 0
	var anterior := Time.get_ticks_usec()
	for cuadro in CALENTAMIENTO + MEDICION:
		if cuadro == CALENTAMIENTO:
			consultas = run.cocina.consultas_ruta
			astar = run.cocina.busquedas_astar
			extraido = run.resistencia_extraida
			ingresos = Juego.migas_run
			for h in run.colonia.hormigas:
				pagos.descargas[h.get_instance_id()] = h._tiempo_descarga
			anterior = Time.get_ticks_usec()
		# Sólo las ventanas de combo/entrega avanzan. No se activa el pisotón,
		# el cierre por cronómetro ni se atribuye duración de campaña al fixture.
		run._reloj += 1.0 / 60.0
		# Mismo helper que la cámara normal: mide su dibujo/offset sin leer
		# las teclas físicas de quien esté usando la PC durante el perfil.
		run.camara.avanzar_sacudida(1.0 / 60.0)
		run.camara.force_update_scroll()
		minimo_hormigas = mini(minimo_hormigas, run.colonia.cantidad())
		# Si una amenaza captura una unidad, nace una reemplazante explícita.
		# Se informa ese costo; no se devuelve carga ni se inventa material.
		reposiciones += _reponer_colonia(run, dano, cuadro)
		minimo_al_iniciar_cuadro = mini(minimo_al_iniciar_cuadro, run.colonia.cantidad())
		if cuadro % 30 == 0:
			_orientar(run)
		if completo and cuadro >= CALENTAMIENTO and (cuadro - CALENTAMIENTO) % 30 == 0:
			# Primero dar tiempo al trabajo real. Si no generó restos, una única
			# pila sintética de seis migas permite disputar un objeto, no dinero
			# automático. El informe la separa de la extracción del escenario.
			if cuadro == CALENTAMIENTO:
				montones_fixture = _asegurar_monton_para_rival(run)
			amenazas_creadas += _llenar_amenazas(run)
		if completo:
			_estimular(run, cuadro)
		await get_tree().process_frame
		var ahora := Time.get_ticks_usec()
		if cuadro >= CALENTAMIENTO:
			var ms := (ahora - anterior) / 1000.0
			tiempos.append(ms)
			dibujos += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			_observar(run, maximos, seguimiento, (cuadro - CALENTAMIENTO) % 10 == 0)
			_observar_pagos(run, pagos, (cuadro - CALENTAMIENTO) % 10 == 0)
			if ms > 40.0:
				print("PICO ESTÍMULOS %s %s cuadro%d: %.2f ms entre cuadros | rutas %d | erosión %d | preparación %d" % [configuracion.destino, "completo" if completo else "control", cuadro - CALENTAMIENTO, ms, run.cocina._pedidos_cuadro, run.cola_erosion.operaciones_ultimo_cuadro, run.preparador_mordiscos.unidades_ultimo_cuadro])
		anterior = ahora
	var etiqueta := "%s %s" % [configuracion.destino, "completo" if completo else "control"]
	var resultado := {"destino": configuracion.destino, "fase": "completo" if completo else "control", "equipo": configuracion.equipo, "cuadros_ms": tiempos, "cuadro": _resumir(tiempos), "dibujos_media": dibujos / MEDICION, "maximos": maximos, "hormigas_final": run.colonia.cantidad(), "minimo_antes_de_reponer": minimo_hormigas, "reposiciones": reposiciones, "amenazas_creadas": amenazas_creadas, "amenazas_observadas": seguimiento.values(), "montones_sinteticos": montones_fixture, "valor_montones_sinteticos": montones_fixture * 6.0, "primer_spawn_en_muestra_cero": completo, "consultas_ruta": run.cocina.consultas_ruta - consultas, "astar": run.cocina.busquedas_astar - astar, "resistencia_extraida_real": run.resistencia_extraida - extraido, "ingresos_reales": Juego.migas_run - ingresos, "erosion_emitida": run.cola_erosion.trabajo_emitido, "erosion_admitida": run.cola_erosion.trabajo_admitido, "ingresos_erosion": run.cola_erosion.ingresos_reales, "mascaras_terminadas": run.preparador_mordiscos.terminadas, "preparacion_unidad_max_ms": run.preparador_mordiscos.max_unidad_usec / 1000.0, "preparacion_publicacion_max_ms": run.preparador_mordiscos.max_publicacion_usec / 1000.0, "erosion_operacion_max_ms": run.cola_erosion.max_operacion_usec / 1000.0}
	print("ESTÍMULOS %s: %.2f ms media | %.2f p95 | %.2f p99 | %.2f peor | %d/%d sobre16.67 | dibujos %.0f" % [etiqueta, resultado.cuadro.media, resultado.cuadro.p95, resultado.cuadro.p99, resultado.cuadro.peor, resultado.cuadro.sobre_16_67, MEDICION, resultado.dibujos_media])
	print("  TRABAJO %d rutas / %d A* | %.3f HP físicos | %.3f migas reales | %d reposiciones | amenazas máx %d/%d, visibles %d | pools %d partículas / %d ondas / %d textos / %d marcas" % [resultado.consultas_ruta, resultado.astar, resultado.resistencia_extraida_real, resultado.ingresos_reales, reposiciones, maximos.amenazas, Eventos.MAX_AMENAZAS, maximos.amenazas_visibles, maximos.particulas, maximos.ondas, maximos.textos, maximos.marcas])
	resultado.minimo_al_iniciar_cuadro = minimo_al_iniciar_cuadro
	pagos.erase("descargas") # Sólo se exporta el conteo mínimo, no IDs de nodos.
	resultado.pagos_reales = pagos
	_verificar(not get_tree().paused and run.activa and run.colonia.is_processing() and minimo_al_iniciar_cuadro == CANTIDAD and is_equal_approx(Engine.time_scale, 1.0), etiqueta + ": cada cuadro empieza con 500 IA reales, visibilidad y paso normal")
	_verificar(resultado.consultas_ruta > 0 and resultado.resistencia_extraida_real > 0.0, etiqueta + ": navegación y extracción física reales, no colonia inmóvil")
	_verificar(maximos.masticando_visibles > 0, etiqueta + ": las mandíbulas nuevas se dibujan durante el trabajo real, no sólo están cargadas en el atlas")
	_verificar(maximos.rutas <= run.cocina.limite_rutas_por_cuadro and maximos.erosion <= ColaErosion.PASOS_POR_CUADRO and maximos.preparador <= PreparadorMordiscos.UNIDADES_POR_CUADRO, etiqueta + ": presupuestos de rutas, erosión y preparación respetados")
	_verificar(maximos.particulas <= Efectos.MAX_PARTICULAS and maximos.ondas <= Efectos.MAX_ONDAS and maximos.textos <= Efectos.MAX_TEXTOS and maximos.marcas <= Efectos.MAX_MARCAS and maximos.textos_dibujados <= Efectos.MAX_TEXTOS_VISIBLES and maximos.nodos_efectos == 0, etiqueta + ": pools acotados, sin emisores/nodos por gesto")
	_verificar(maximos.chispas_combo <= ComboVisual.MAX_CHISPAS and maximos.halos <= Efectos.MAX_ENTRADAS_HALO,
		etiqueta + ": combo y frenesí conservan treinta y dos chispas y ocho halos como máximo")
	_verificar(maximos.cuadros_combo_impacto > 0 and maximos.cuadros_combo_regreso > 0 and maximos.ancho_combo_impacto_px > 300.0,
		etiqueta + ": un combo natural se vio grande en el centro y regresó al HUD dentro de la ventana medida")
	_verificar(maximos.chispas_combo_activas > 0 and maximos.chispas_combo_activas <= ComboVisual.MAX_CHISPAS,
		etiqueta + ": hubo chispas de combo vivas, no sólo slots preasignados")
	_verificar(maximos.amenazas <= Eventos.MAX_AMENAZAS and maximos.eventos <= Eventos.MAX_AMENAZAS + 1 and maximos.fragmentos <= Comidas.MAX_FRAGMENTOS, etiqueta + ": amenazas, dorada y material suelto respetan los techos reales")
	_verificar(pagos.descargas_min_muestreadas > 0 and pagos.textos_deposito_max > 0 and pagos.depositos_dibujados_max > 0 and pagos.cuadros_hud_ganancia_visible > 0 and pagos.vuelos_max > 0, etiqueta + ": descargas naturales producen números dibujados, ganancia HUD y vuelos reales")
	_verificar(pagos.texto_cero_erroneo == 0, etiqueta + ": ningún pago/saldo positivo observado se presenta como cero")
	_verificar(pagos.pool_textos_max <= Efectos.MAX_TEXTOS and pagos.pool_particulas_max <= Efectos.MAX_PARTICULAS and pagos.pool_ondas_max <= Efectos.MAX_ONDAS and pagos.pool_marcas_max <= Efectos.MAX_MARCAS and pagos.vuelos_max <= VueloMigas.MAXIMO and pagos.slots_vuelos_max == VueloMigas.MAXIMO and pagos.nodos_vuelos_max == 0 and pagos.nodos_hud_max <= nodos_hud_iniciales, etiqueta + ": activos+libres y HUD/vuelos conservan pools fijos, sin nodos por pago")
	if pagos.cuadros_con_fraccion_asignada > 0:
		_verificar(pagos.fracciones_dibujadas_max > 0, etiqueta + ": los pagos fraccionales naturales observados también se dibujan")
	else:
		print("  COBERTURA %s: sin fracción natural asignada durante esta ventana; no se inyectó un pago para forzarla." % etiqueta)
	if pagos.cuadros_con_pago_normal_asignado > 0:
		_verificar(pagos.normales_dibujados_max > 0, etiqueta + ": los pagos normales naturales observados también se dibujan")
	print("  PAGOS %d descargas mínimas muestreadas | números de depósito %d asignados / %d dibujados máx | fracciones dibujadas %d | HUD visible %d cuadros | vuelos %d/%d | pool textos %d/%d" % [pagos.descargas_min_muestreadas, pagos.textos_deposito_max, pagos.depositos_dibujados_max, pagos.fracciones_dibujadas_max, pagos.cuadros_hud_ganancia_visible, pagos.vuelos_max, VueloMigas.MAXIMO, pagos.pool_textos_max, Efectos.MAX_TEXTOS])
	print("  COMBO NATURAL %d cuadros de impacto / %d de regreso | ancho central máx %.1f px | chispas activas %d/%d slots | offset real cámara máx %.2f px" % [maximos.cuadros_combo_impacto, maximos.cuadros_combo_regreso, maximos.ancho_combo_impacto_px, maximos.chispas_combo_activas, maximos.chispas_combo, maximos.offset_camara_px])
	print("  MASTICAR %d hormigas visibles con cuadros de mandíbula (máximo muestreado)" % maximos.masticando_visibles)
	if completo:
		_verificar(maximos.amenazas == Eventos.MAX_AMENAZAS and maximos.amenazas_visibles > 0 and maximos.particulas > 0 and maximos.ondas > 0, etiqueta + ": hubo amenazas al tope y presentación visible sostenida")
		for datos: Dictionary in seguimiento.values():
			print("  AMENAZA %s: fases %s | botín real máximo %.3f | consultas %d" % [datos.tipo, ",".join(PackedStringArray(datos.estados.keys())), datos.botin_max, datos.consultas])
		print("  CARGAS portadoras máx %d | hormigas visibles máx %d/500 (muestreo cada10 cuadros) | montones sintéticos %d. Un robo/ataque no observado no se considera validado." % [maximos.portadoras, maximos.hormigas_visibles, montones_fixture])
	resultado.cierre = await _comprobar_cierre(run, etiqueta)
	run.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	resultado.nodos_despues_de_liberar = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - nodos_antes
	resultado.huerfanos_despues_de_liberar = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) - huerfanos_antes
	_verificar(resultado.nodos_despues_de_liberar <= 0 and resultado.huerfanos_despues_de_liberar <= 0, etiqueta + ": al liberar la run no quedan nodos/huérfanos nuevos")
	_resultados.append(resultado)


func _colocar_accesos(run: Run) -> void:
	# Mismo criterio determinista de perfil_proyectos: cinco elecciones manuales
	# legales antes de medir. No se agrega automatización al juego.
	var candidatos: Array[Vector2] = []
	for ambiente: Dictionary in Mundos.plano(Juego.lugar_actual).ambientes:
		var rect: Rect2 = ambiente.rect
		for y in range(64, int(rect.size.y), 128):
			for x in range(64, int(rect.size.x), 128):
				var punto := rect.position + Vector2(x, y)
				if run.entradas.puede_colocar(punto):
					candidatos.append(punto)
	while run.entradas_disponibles() > 0:
		var mejor := Vector2.INF
		var distancia := 0.0
		for punto in candidatos:
			var cercana := INF
			for entrada: Vector2 in run.entradas.puntos:
				cercana = minf(cercana, punto.distance_squared_to(entrada))
			if cercana > distancia and run.entradas.puede_colocar(punto):
				mejor = punto
				distancia = cercana
		if mejor == Vector2.INF:
			break
		run.iniciar_colocacion_entrada()
		if not run.colocar_entrada(mejor):
			break
	_verificar(run.entradas._normales == 5, Juego.lugar_actual + ": cinco accesos comprados y ubicados en suelo real")


func _reponer_colonia(run: Run, dano: float, turno: int) -> int:
	var repuestas := 0
	while run.colonia.cantidad() < CANTIDAD:
		var indice := run.colonia.cantidad() + turno
		var origen: Vector2 = run.entradas.puntos[indice % run.entradas.puntos.size()]
		var h := run.colonia._nacer(TIPOS[indice % TIPOS.size()], origen)
		if h == null:
			break
		h._velocidad = 300.0
		h._dano = dano
		h._capacidad = 6.0
		h._olfato = 180.0
		repuestas += 1
	return repuestas


func _orientar(run: Run) -> void:
	var objetivo := run.objetivo_actual()
	if is_instance_valid(objetivo):
		var punto := objetivo.punto_mordida(Vector2.ZERO, RADIO)
		if punto != Vector2.INF:
			run.feromonas.mantener_en(punto)


func _llenar_amenazas(run: Run) -> int:
	var creadas := 0
	var presentes: Dictionary = {}
	for e in run.eventos.activos:
		if is_instance_valid(e) and not e.resuelto:
			presentes[e.tipo] = true
	for tipo: String in [Eventos.AMENAZAS[Juego.lugar_actual], Eventos.VARIANTES[Juego.lugar_actual], "avispa", "rival"]:
		if run.eventos.amenazas_activas() >= Eventos.MAX_AMENAZAS:
			break
		if presentes.has(tipo):
			continue
		creadas += run.eventos.aparecer(tipo).size()
	run.eventos.aparecer("dorada") # Un solo premio simultáneo, sin cobrarlo aquí.
	return creadas


func _asegurar_monton_para_rival(run: Run) -> int:
	if not run.comidas.fragmentos.is_empty():
		return 0
	var centro := run.feromonas.posicion if run.feromonas.activa else run.camara.get_screen_center_position()
	var punto := run.cocina.ajustar_destino(centro + Vector2(70, 40), RADIO)
	if punto == Vector2.INF:
		return 0
	run.comidas.soltar_fragmento(punto, 6.0, 1)
	return 1 if not run.comidas.fragmentos.is_empty() else 0


func _estimular(run: Run, cuadro: int) -> void:
	# Impactos/ráfagas cosméticos sintéticos, dentro de la cámara. No se llaman
	# numero/entrega/deposito ni se acredita un pago para fabricar feedback.
	var centro := run.camara.get_screen_center_position()
	var pos := centro + Vector2(sin(cuadro * 0.13) * 380.0, cos(cuadro * 0.17) * 180.0)
	if cuadro % 30 == 0 and run.frenesi_restante > 0.0:
		run.efectos.actualizar_frenesi(run.frenesi_restante, PackedVector2Array(run.entradas.puntos))
	if cuadro % 3 == 0:
		run.efectos.mordida(pos, Color("ccb98c"), cuadro % 4, Vector2.RIGHT)
	if cuadro % 12 == 0:
		run.efectos.habilidad(pos, pos + Vector2(70, -30), Color("a4c78a"))
	if cuadro % 30 == 0:
		var fase: String = ["aviso", "impacto", "repelido"][(cuadro / 30 as int) % 3]
		run.efectos.amenaza(pos, fase, 36.0, Vector2.LEFT)
	if cuadro % 45 == 0:
		run.efectos.rafaga(centro, 90.0)
		run.efectos.racha(centro + Vector2(0, -70), 4)
		run.efectos.epico(centro, Color("e9ca8a"), 90.0)


func _observar(run: Run, maximos: Dictionary, seguimiento: Dictionary, contar_hormigas: bool) -> void:
	var fx := run.efectos
	var combo := run.hud._combo_visual
	maximos.chispas_combo = maxi(int(maximos.chispas_combo), combo._chispas.size())
	var chispas_vivas := 0
	for chispa: ComboVisual.Chispa in combo._chispas:
		chispas_vivas += int(chispa.vida > 0.0)
	maximos.chispas_combo_activas = maxi(int(maximos.chispas_combo_activas), chispas_vivas)
	maximos.halos = maxi(int(maximos.halos), fx.halos_dibujados)
	maximos.etapa_combo = maxi(int(maximos.etapa_combo), combo._etapa)
	maximos.offset_camara_px = maxf(float(maximos.offset_camara_px), run.camara.offset.length() * run.camara.zoom.x)
	var visibles := 0
	var vista: Rect2 = run.get_viewport_rect()
	var limites_combo := combo.limites_etiqueta()
	if combo.is_visible_in_tree() and combo.etiqueta.is_visible_in_tree() and combo.modulate.a > 0.05 and vista.intersects(limites_combo):
		match combo.fase_cinematica():
			"impacto":
				maximos.cuadros_combo_impacto += 1
				maximos.ancho_combo_impacto_px = maxf(float(maximos.ancho_combo_impacto_px), limites_combo.size.x)
			"regreso":
				maximos.cuadros_combo_regreso += 1
	for e in run.eventos.activos:
		if not is_instance_valid(e) or not e.es_amenaza() or e.resuelto:
			continue
		if vista.has_point(run.a_pantalla(e._centro())):
			visibles += 1
		var id := e.get_instance_id()
		if not seguimiento.has(id):
			seguimiento[id] = {"tipo": e.tipo, "estados": {}, "botin_max": 0.0, "consultas": 0}
		seguimiento[id].estados[e.estado] = true
		seguimiento[id].botin_max = maxf(float(seguimiento[id].botin_max), e.botin)
		seguimiento[id].consultas = maxi(int(seguimiento[id].consultas), e.consultas_objetivos)
	if contar_hormigas:
		var portadoras := 0
		var hormigas_visibles := 0
		var masticando_visibles := 0
		for h in run.colonia.hormigas:
			portadoras += int(h.carga > 0.0)
			hormigas_visibles += int(h.en_pantalla)
			masticando_visibles += int(h.en_pantalla and h.visible and h._masticando_animacion)
		maximos.portadoras = maxi(int(maximos.portadoras), portadoras)
		maximos.hormigas_visibles = maxi(int(maximos.hormigas_visibles), hormigas_visibles)
		maximos.masticando_visibles = maxi(int(maximos.masticando_visibles), masticando_visibles)
	var valores := {"particulas": fx._particulas.size(), "ondas": fx._ondas.size(), "textos": fx._textos.size(), "marcas": fx._marcas.size(), "textos_dibujados": fx._rect_textos.size(), "nodos_efectos": fx.get_child_count(), "amenazas": run.eventos.amenazas_activas(), "eventos": run.eventos.activos.size(), "amenazas_visibles": visibles, "fragmentos": run.comidas.fragmentos.size(), "rutas": run.cocina._pedidos_cuadro, "erosion": run.cola_erosion.operaciones_ultimo_cuadro, "preparador": run.preparador_mordiscos.unidades_ultimo_cuadro, "preparaciones_pendientes": run.preparador_mordiscos.cantidad_pendientes(), "erosiones_pendientes": run.cola_erosion.cantidad_pendientes()}
	for clave in valores:
		maximos[clave] = maxi(int(maximos[clave]), int(valores[clave]))


func _observar_pagos(run: Run, pagos: Dictionary, contar_hormigas: bool) -> void:
	var fx := run.efectos
	var depositos := 0
	var fraccion := false
	var normal := false
	for t in fx._textos:
		if t.clase != "deposito" or t.cantidad <= 0.0:
			continue
		depositos += 1
		fraccion = fraccion or t.cantidad < 1.0
		normal = normal or t.cantidad >= 1.0
		pagos.texto_cero_erroneo += int(t.texto.strip_edges() in CEROS_VISUALES)
	pagos.cuadros_con_fraccion_asignada += int(fraccion)
	pagos.cuadros_con_pago_normal_asignado += int(normal)
	if contar_hormigas:
		for h in run.colonia.hormigas:
			var id := h.get_instance_id()
			var previa := float(pagos.descargas.get(id, -10.0))
			if h._tiempo_descarga >= 0.0 and h._tiempo_descarga > previa:
				pagos.descargas_min_muestreadas += 1
			pagos.descargas[id] = h._tiempo_descarga
	var hud := run.hud
	if hud._ganancia_reciente > 0.0 and hud._ganancia_visible > 0.0 and hud._lbl_ganancia.is_visible_in_tree() and hud._lbl_ganancia.modulate.a > 0.0 and hud._lbl_ganancia.get_global_rect().intersects(run.get_viewport_rect()):
		pagos.cuadros_hud_ganancia_visible += 1
		pagos.texto_cero_erroneo += int(hud._lbl_ganancia.text.strip_edges() in CEROS_VISUALES)
	if hud._migas_mostradas > 0.0 and hud._migas_mostradas < 1.0:
		pagos.cuadros_saldo_fraccional += 1
		pagos.texto_cero_erroneo += int(hud._lbl_migas.text.strip_edges() in CEROS_VISUALES)
	var vuelo := hud._vuelo_migas
	var valores := {"textos_deposito_max": depositos, "depositos_dibujados_max": fx.depositos_dibujados, "fracciones_dibujadas_max": fx.fracciones_dibujadas, "normales_dibujados_max": maxi(0, fx.depositos_dibujados - fx.fracciones_dibujadas), "vuelos_max": vuelo.cantidad, "slots_vuelos_max": vuelo.migas.size(), "nodos_vuelos_max": vuelo.get_child_count(), "nodos_hud_max": hud.get_child_count(), "pool_textos_max": fx._textos.size() + fx._textos_libres.size(), "pool_particulas_max": fx._particulas.size() + fx._libres.size(), "pool_ondas_max": fx._ondas.size() + fx._ondas_libres.size(), "pool_marcas_max": fx._marcas.size() + fx._marcas_libres.size()}
	for clave in valores:
		pagos[clave] = maxi(int(pagos[clave]), int(valores[clave]))


func _comprobar_cierre(run: Run, etiqueta: String) -> Dictionary:
	var importe_ya_acreditado := run.hud._ganancia_reciente
	var inicio := Time.get_ticks_usec()
	run._cerrar() # Ruta real de salida; no espera animación/cámara lenta.
	var costo := (Time.get_ticks_usec() - inicio) / 1000.0
	var saldo := Juego.migas_run
	var extraido := run.resistencia_extraida
	# Llamadas tardías explícitas: no reviven pools ni aparecen nuevos enemigos.
	run.efectos.mordida(Vector2.ZERO, Color.WHITE)
	run.efectos.amenaza(Vector2.ZERO, "impacto")
	run.efectos.epico(Vector2.ZERO, Color.WHITE)
	if importe_ya_acreditado > 0.0:
		# Reproducir un callback de un importe YA cobrado, no otro depósito:
		# estas APIs sólo presentan el pago y deben rechazarlo tras el cierre.
		run.efectos.deposito(Vector2.ZERO, importe_ya_acreditado)
		run.hud.registrar_ganancia(importe_ya_acreditado)
	run.hud.migas_voladoras(run.a_pantalla(Vector2.ZERO), 1)
	var tardios := run.eventos.aparecer(Eventos.VARIANTES[Juego.lugar_actual]).size()
	await get_tree().process_frame
	await get_tree().process_frame
	var limpio := run.eventos.activos.is_empty() and not run.eventos.is_processing() and not run.cola_erosion.tiene_pendientes() and not run.preparador_mordiscos.tiene_pendientes() and run.efectos._particulas.is_empty() and run.efectos._ondas.is_empty() and run.efectos._textos.is_empty() and run.efectos._marcas.is_empty() and not run.efectos.is_processing()
	var vuelo := run.hud._vuelo_migas
	var slots_activos := 0
	for m in vuelo.migas:
		slots_activos += int(m.activa)
	var hud_limpio := vuelo.migas.size() == VueloMigas.MAXIMO and vuelo.cantidad == 0 and slots_activos == 0 and not vuelo.is_processing() and run.hud._ganancia_visible <= 0.0 and not run.hud._lbl_ganancia.visible
	_verificar(limpio and tardios == 0, etiqueta + ": cerrar cancela colas, amenazas y pools; callbacks tardíos no los reactivan")
	_verificar(hud_limpio, etiqueta + ": cerrar deja los 40 slots de vuelo inactivos y ningún callback revive la ganancia HUD")
	_verificar(Juego.migas_run == saldo and run.resistencia_extraida == extraido, etiqueta + ": después del cierre no se extrae ni acredita material nuevo")
	return {"ms": costo, "sin_pendientes": limpio, "hud_limpio": hud_limpio, "slots_vuelo_activos": slots_activos, "callback_importe_ya_acreditado": importe_ya_acreditado, "eventos_tardios": tardios, "migas_despues": Juego.migas_run, "extraccion_despues": run.resistencia_extraida}


func _resumir(valores: Array[float]) -> Dictionary:
	var ordenados: Array[float] = valores.duplicate()
	ordenados.sort()
	var suma := 0.0
	var sobre := 0
	for ms in ordenados:
		suma += ms
		sobre += int(ms > 1000.0 / 60.0)
	return {"media": suma / ordenados.size(), "p95": ordenados[ceili(ordenados.size() * 0.95) - 1], "p99": ordenados[ceili(ordenados.size() * 0.99) - 1], "peor": ordenados.back(), "sobre_16_67": sobre}


func _huellas_guardados() -> Dictionary:
	var huellas: Dictionary = {}
	for ruta: String in [Juego.RUTA_PARTIDA, Ajustes.RUTA]:
		huellas[ruta] = FileAccess.get_sha256(ruta) if FileAccess.file_exists(ruta) else "ausente"
	return huellas


func _verificar(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK " + mensaje)
	else:
		_fallas += 1
		push_error("FALLA " + mensaje)
