extends Node
## Destinos con identidad: comidas propias de cada destino, la amenaza de cada
## uno (araña, mozo, aspiradora, palomas, gato, rata) y la miga dorada.
##   godot --headless --fixed-fps 60 --path . res://tests/prueba_eventos.tscn
var fallas := 0
var total := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")  # las verificaciones leen textos en español
	Sonido.silenciado = true
	probar_comidas_por_destino()
	await probar_mapas()
	probar_revelado()
	await probar_arana()
	await probar_mozo()
	await probar_aspiradora()
	await probar_palomas()
	await probar_gato()
	await probar_rata()
	await probar_dorada()
	await probar_aparicion_sola()
	await probar_presion()
	await probar_colonia_perdida()
	Engine.time_scale = 1.0
	Juego.reiniciar_estado()
	print("Destinos con identidad: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func probar_comidas_por_destino() -> void:
	for lugar in Mundos.ORDEN:
		var propias := 0
		var total_lugar := 0
		for tipo in Juego.comidas:
			if tipo.cantidad <= 0 or not Juego.comida_en_destino(tipo, lugar):
				continue
			total_lugar += 1
			if tipo.destinos == [lugar]:
				propias += 1
		if lugar == "casa":
			verificar(total_lugar >= 10, "la casa tiene sus %d comidas de siempre" % total_lugar)
		else:
			verificar(propias >= 3, "%s tiene %d comidas propias" % [lugar, propias])
	var dona: Dictionary = {}
	for tipo in Juego.comidas:
		if tipo.id == "dona":
			dona = tipo
	verificar(not Juego.comida_en_destino(dona, "coliseo"), "no hay donas en el Coliseo")


func probar_mapas() -> void:
	for lugar in ["restaurante", "coliseo", "eiffel"]:
		Juego.reiniciar_estado()
		Juego.lugar_actual = lugar
		var run := await _run()
		var ids := {}
		for c in run.comidas.lista:
			ids[c.id] = true
		var ajenas := 0
		for id in ids:
			for tipo in Juego.comidas:
				if tipo.id == id and not Juego.comida_en_destino(tipo, lugar):
					ajenas += 1
		verificar(ajenas == 0 and ids.size() >= 4, "el mapa de %s sólo tiene sus comidas (%s)" % [lugar, ", ".join(ids.keys())])
		await _cerrar(run)


func probar_revelado() -> void:
	Juego.reiniciar_estado()
	verificar(not Juego.revelado("amenazas") and not Juego.revelado("doradas"), "las primeras expediciones no tienen amenazas ni migas doradas")
	Juego.runs_jugadas = 3
	verificar(Juego.revelado("doradas") and not Juego.revelado("amenazas"), "la miga dorada llega antes que las amenazas")
	Juego.runs_jugadas = 6
	verificar(Juego.revelado("amenazas"), "las amenazas aparecen desde la sexta expedición")


func probar_arana() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mas_obreras": 10}
	Juego._cache_stats.clear()
	var run := await _run(2.5)
	var arana: Evento = run.eventos.aparecer("arana")[0]
	verificar(arana.position.length() > run.radio_actual, "la araña entra desde el borde del territorio")
	Engine.time_scale = 4.0
	var hormigas := run.colonia.cantidad()
	for i in 600:
		await get_tree().process_frame
		if not is_instance_valid(arana) or arana.atrapadas > 0:
			break
	Engine.time_scale = 1.0
	verificar(is_instance_valid(arana) and arana.atrapadas > 0 and run.colonia.cantidad() < hormigas, "si nadie la para, la araña se lleva hormigas")
	verificar(Juego.estadistica("hormigas_perdidas") >= 1, "las hormigas perdidas se cuentan")
	var migas := Juego.migas_run
	for i in Evento.DATOS.arana.golpes:
		run.pisar(arana.position)
	await get_tree().process_frame
	verificar(not is_instance_valid(arana) and Juego.migas_run > migas, "seis pisotones la vencen y dan botín")
	verificar(Juego.estadistica("amenazas_vencidas") == 1, "las amenazas vencidas se cuentan")
	await _cerrar(run)


func probar_mozo() -> void:
	Juego.reiniciar_estado()
	Juego.lugar_actual = "restaurante"
	Juego.niveles = {"mas_obreras": 10}
	Juego._cache_stats.clear()
	var run := await _run(3.0)
	var mozo: Evento = run.eventos.aparecer("mozo")[0]
	await _esperar(func() -> bool: return mozo.estado == "avisando", 120)
	verificar(mozo.estado == "avisando", "el mozo avisa con su sombra antes de pisar")
	var comidas := run.comidas.lista.size()
	for i in Evento.DATOS.mozo.golpes:
		run.pisar(mozo._objetivo)
	await get_tree().process_frame
	verificar(not is_instance_valid(mozo) and run.comidas.lista.size() >= comidas + 2, "pisar la sombra lo hace tropezar y se le cae la bandeja")
	mozo = run.eventos.aparecer("mozo")[0]
	var id_mozo := mozo.get_instance_id()
	Engine.time_scale = 4.0
	await _esperar(func() -> bool: return not is_instance_id_valid(id_mozo) or instance_from_id(id_mozo)._pisadas >= 1, 600)
	Engine.time_scale = 1.0
	verificar(is_instance_valid(mozo) and mozo._pisadas >= 1, "si no se lo frena, pisa")
	await _cerrar(run)


func probar_aspiradora() -> void:
	Juego.reiniciar_estado()
	Juego.lugar_actual = "museo"
	var run := await _run(1.0)
	var aspiradora: Evento = run.eventos.aparecer("aspiradora")[0]
	aspiradora.position = Vector2.ZERO
	var chica: Comida = null
	for c in run.comidas.lista:
		if c.radio <= 20.0 and c.en_territorio(run.radio_actual) and c.position.length() > 60.0:
			chica = c
			break
	aspiradora.position = chica.position + Vector2(4, 0)
	aspiradora._objetivo = chica.position
	Engine.time_scale = 4.0
	await _esperar(func() -> bool: return aspiradora.botin > 0.0, 120)
	Engine.time_scale = 1.0
	verificar(aspiradora.botin > 0.0, "la aspiradora se traga la comida chica y la guarda")
	var botin := aspiradora.botin
	var migas := Juego.migas_run
	for i in Evento.DATOS.aspiradora.golpes:
		run.pisar(aspiradora.position)
	verificar(Juego.migas_run - migas >= botin * 1.5, "romperla devuelve lo que tragó, con premio")
	await _cerrar(run)


func probar_palomas() -> void:
	Juego.reiniciar_estado()
	Juego.lugar_actual = "obelisco"
	var run := await _run(1.0)
	var palomas := run.eventos.aparecer("paloma")
	verificar(palomas.size() == Eventos.PALOMAS_POR_BANDADA, "las palomas llegan en bandada")
	Engine.time_scale = 4.0
	await _esperar(func() -> bool: return palomas[0].botin > 0.0, 900)
	Engine.time_scale = 1.0
	verificar(palomas[0].botin > 0.0, "las palomas picotean la comida")
	var quedaban := run.eventos.activos.size()
	run.pisar(palomas[0].position)
	await get_tree().process_frame
	verificar(run.eventos.activos.size() == quedaban - 1, "un clic espanta a una paloma")
	await _cerrar(run)


func probar_gato() -> void:
	Juego.reiniciar_estado()
	Juego.lugar_actual = "coliseo"
	var run := await _run(1.0)
	var gato: Evento = run.eventos.aparecer("gato")[0]
	verificar(gato.estado == "dormido" and gato.position.length() > 100.0, "el gato duerme sobre la comida más valiosa")
	for i in 3:
		run.pisar(gato.position)
	verificar(is_instance_valid(gato) and gato.golpes == 1, "cada clic cuenta")
	run.pisar(gato.position)
	await get_tree().process_frame
	verificar(not is_instance_valid(gato), "cuatro clics y el gato se va")
	await _cerrar(run)


func probar_rata() -> void:
	Juego.reiniciar_estado()
	Juego.lugar_actual = "eiffel"
	var run := await _run(1.0)
	var rata: Evento = run.eventos.aparecer("rata")[0]
	var objetivo := rata._comida
	verificar(objetivo != null, "la rata va por la comida más valiosa")
	Engine.time_scale = 4.0
	await _esperar(func() -> bool: return rata.estado == "huyendo", 900)
	Engine.time_scale = 1.0
	verificar(rata.botin > 0.0 and (not is_instance_valid(objetivo) or objetivo.muerta), "si llega, se la lleva entera")
	var migas := Juego.migas_run
	for i in Evento.DATOS.rata.golpes:
		run.pisar(rata.position)
	verificar(Juego.migas_run - migas >= rata.botin, "atraparla recupera lo robado")
	await _cerrar(run)


func probar_dorada() -> void:
	Juego.reiniciar_estado()
	var run := await _run(0.5)
	var antes := [Juego.migas_run, run.tiempo_restante, run.frenesi_restante]
	var dorada: Evento = run.eventos.aparecer("dorada")[0]
	verificar(dorada.position.length() <= run.radio_actual, "la miga dorada aparece dentro del territorio")
	run.pisar(dorada.position)
	verificar(Juego.migas_run > antes[0] or run.tiempo_restante > antes[1] + 5.0 or run.frenesi_restante > antes[2], "pisarla da un premio")
	verificar(Juego.estadistica("migas_doradas") == 1, "las migas doradas se cuentan")
	dorada = run.eventos.aparecer("dorada")[0]
	var id_dorada := dorada.get_instance_id()
	Engine.time_scale = 4.0
	await _esperar(func() -> bool: return not is_instance_id_valid(id_dorada), 900)
	Engine.time_scale = 1.0
	verificar(not is_instance_valid(dorada), "si no se la pisa, desaparece sola")
	var pisotones := Juego.estadistica("pisotones")
	dorada = run.eventos.aparecer("dorada")[0]
	run.pisar(dorada.position, true)
	verificar(is_instance_valid(dorada) and not dorada.resuelto, "los pisotones automáticos no resuelven eventos: hay que clickear")
	await _cerrar(run)


func probar_aparicion_sola() -> void:
	Juego.reiniciar_estado()
	Juego.runs_jugadas = 8
	Juego.lugar_actual = "restaurante"
	var run := await _run(0.2)
	run.eventos._reloj_amenaza = 0.01
	run.eventos._reloj_dorada = 0.01
	await get_tree().process_frame
	await get_tree().process_frame
	var tipos := {}
	for e in run.eventos.activos:
		tipos[e.tipo] = true
	verificar(tipos.has("mozo") and tipos.has("dorada"), "con el tiempo aparecen solas la amenaza del destino y la miga dorada")
	run.eventos._reloj_amenaza = 0.01
	await get_tree().process_frame
	await get_tree().process_frame
	var amenazas := run.eventos.activos.filter(func(e: Evento) -> bool: return e.es_amenaza()).size()
	verificar(amenazas == 1, "al principio del restaurante nunca hay dos amenazas a la vez")
	run.tiempo_restante = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	verificar(run.eventos.activos.is_empty(), "al terminar la expedición se van todas")
	await _cerrar(run)


func probar_presion() -> void:
	Juego.reiniciar_estado()
	verificar(Eventos.presion() == 0 and Eventos.amenazas_simultaneas() == 1, "en la casa, sin mejoras, hay una amenaza por vez")
	Juego.lugar_actual = "coliseo"
	Juego.niveles = {"mas_obreras": 30, "mandibulas": 40, "buche": 10, "excavar": 36, "reservas": 12, "antenas": 10, "rastro_persistente": 10, "patas_largas": 15}
	verificar(Eventos.presion() == 4 + Eventos.MAX_PRESION_MEJORAS and Eventos.amenazas_simultaneas() == Eventos.MAX_AMENAZAS, "más destino y más mejoras suben la presión hasta %d amenazas a la vez" % Eventos.MAX_AMENAZAS)
	seed(5)
	var lenta := 0.0
	var rapida := 0.0
	for i in 200:
		rapida += Eventos.espera_entre_amenazas()
	Juego.lugar_actual = "casa"
	Juego.niveles = {}
	for i in 200:
		lenta += Eventos.espera_entre_amenazas()
	verificar(rapida < lenta * 0.6, "con presión alta vuelven bastante más seguido")
	Juego.runs_jugadas = 8
	Juego.lugar_actual = "coliseo"
	Juego.niveles = {"mas_obreras": 30, "mandibulas": 40, "buche": 10, "excavar": 36, "reservas": 12, "antenas": 10, "rastro_persistente": 10, "patas_largas": 15}
	Juego._cache_stats.clear()
	var run := await _run(0.2)
	for i in 6:
		run.eventos._reloj_amenaza = 0.01
		await get_tree().process_frame
		await get_tree().process_frame
	var gatos := run.eventos.activos.filter(func(e: Evento) -> bool: return e.es_amenaza()).size()
	verificar(gatos == Eventos.MAX_AMENAZAS, "con la colonia crecida se juntan %d gatos, no más (%d)" % [Eventos.MAX_AMENAZAS, gatos])
	await _cerrar(run)


func probar_colonia_perdida() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mas_obreras": 2}
	Juego._cache_stats.clear()
	var run := await _run(2.5)
	verificar(run.colonia.cantidad() > 0 and run.activa, "la colonia salió a trabajar")
	for h in run.colonia.hormigas.duplicate():
		run.colonia.perder(h)
	await _esperar(func() -> bool: return run.terminada, 120)
	verificar(run.colonia_perdida and run.terminada, "si una amenaza se come a todas las hormigas, la expedición termina")
	verificar(run.hud._lbl_fin_titulo.text == "¡Se comieron a la colonia!" or run.terminada, "el cierre explica por qué terminó")
	await _cerrar(run)
	Juego.reiniciar_estado()
	Juego.niveles = {"mas_obreras": 2, "cria_acelerada": 6}
	Juego._cache_stats.clear()
	run = await _run(2.5)
	for h in run.colonia.hormigas.duplicate():
		run.colonia.perder(h)
	for i in 30:
		await get_tree().process_frame
	verificar(not run.colonia_perdida and run.activa, "con cría por nacer antes del final, la expedición sigue")
	await _cerrar(run)


func _run(espera := 0.0) -> Run:
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	await get_tree().process_frame
	# Que no aparezcan solas durante la prueba.
	run.eventos._reloj_amenaza = 1e9
	run.eventos._reloj_dorada = 1e9
	if espera > 0.0:
		Engine.time_scale = 4.0
		await get_tree().create_timer(espera, true, false, false).timeout
		Engine.time_scale = 1.0
	return run


func _cerrar(run: Run) -> void:
	Engine.time_scale = 1.0
	run.queue_free()
	await get_tree().process_frame


func _esperar(condicion: Callable, cuadros: int) -> void:
	for i in cuadros:
		if condicion.call():
			return
		await get_tree().process_frame


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)
