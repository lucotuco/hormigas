extends Node
## Progresión larga: jalea real y árbol de la reina, topes que suben con los
## destinos, mejoras de destino, hitos de nivel y partidas viejas.
##   godot --headless --fixed-fps 60 --path . res://tests/prueba_jalea.tscn
var fallas := 0
var total := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")  # las verificaciones leen textos en español
	Sonido.silenciado = true
	probar_datos()
	probar_formula()
	probar_fundar()
	probar_arbol()
	probar_topes_y_destinos()
	probar_hitos_de_nivel()
	probar_partida_vieja()
	await probar_guardia()
	await probar_panel()
	Juego.reiniciar_estado()
	print("Jalea real y progresión larga: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func probar_datos() -> void:
	verificar(Juego.nodos_jalea.size() >= 10, "se leyó el árbol de la reina (%d nodos)" % Juego.nodos_jalea.size())
	var con_destino := 0
	for m in Juego.mejoras:
		if m.destino != "":
			con_destino += 1
	verificar(con_destino >= 10, "cada destino trae mejoras propias (%d)" % con_destino)
	# Aislar el lector del precio de titanio, que cambia al calibrar el balance.
	verificar(is_equal_approx(Juego._num("2e7"), 20000000.0), "el lector acepta costos en notación científica (2e7)")
	var destinos_con_mejoras := {}
	for m in Juego.mejoras:
		if m.destino != "":
			destinos_con_mejoras[m.destino] = true
	verificar(destinos_con_mejoras.size() == Mundos.ORDEN.size() - 1, "todos los destinos después de la casa traen mejoras")
	var multiplicadoras_elevables := 0
	for m in Juego.mejoras:
		if m.tipo == "multiplica" and (m.elevable or m.tope_por_destino > 1):
			multiplicadoras_elevables += 1
	verificar(multiplicadoras_elevables == 0, "las mejoras que multiplican tienen topes fijos (si no, el prestigio se desboca)")


func probar_formula() -> void:
	Juego.reiniciar_estado()
	verificar(Juego.jalea_por_fundar() == 0 and not Juego.puede_fundar(), "una colonia nueva no tiene nada para fundar")
	Juego.migas_colonia = 100000.0
	verificar(Juego.detalle_fundar().migas == 1, "100.000 migas en la colonia valen 1 de jalea")
	Juego.migas_colonia = 1.6e6
	verificar(Juego.detalle_fundar().migas == 2, "la jalea por migas crece con la raíz cuarta (1,6 M → 2)")
	Juego.migas_colonia = 1e13
	verificar(Juego.detalle_fundar().migas == 100, "y se frena con números grandes (10 billones → 100)")
	Juego.migas_colonia = 1.6e6
	Juego.coronas = 2
	verificar(Juego.jalea_por_fundar() == 2 * Juego.JALEA_POR_CORONA + 2, "cada corona vale %d de jalea" % Juego.JALEA_POR_CORONA)
	Juego.migas_colonia = 0.0
	Juego.migas = 0.0
	Juego.migas_run = 5e5
	Juego.terminar_run()
	verificar(Juego.migas_colonia == 5e5, "las migas de cada run suman a la colonia")


func probar_fundar() -> void:
	Juego.reiniciar_estado()
	Juego.coronas = 3
	Juego.migas = 1e6
	Juego.migas_colonia = 1e6
	Juego.niveles = {"mandibulas": 10, "mordida_madera": 1}
	Juego.reclutadas = {"reina": 2}
	Juego.lugares_completados["casa"] = true
	Juego.hitos["primera_silla"] = true
	Juego._cache_stats.clear()
	var esperada := Juego.jalea_por_fundar()
	verificar(Juego.fundar_colonia(), "se puede fundar con coronas")
	verificar(Juego.jalea == esperada and Juego.legado == esperada and Juego.fundaciones == 1, "fundar da la jalea prometida")
	verificar(Juego.migas == 0 and Juego.niveles.is_empty() and Juego.reclutadas.is_empty() and Juego.migas_colonia == 0, "fundar reinicia migas, mejoras y castas")
	verificar(Juego.lugares_completados.has("casa") and Juego.hitos.has("primera_silla"), "fundar conserva destinos e hitos")
	verificar(is_equal_approx(Juego.stat("multiplicador_migas"), 1.0 + Juego.legado * Juego.BONUS_LEGADO), "la jalea ganada da bonus pasivo de migas")
	Juego.jalea = 0
	Juego._cache_stats.clear()
	verificar(is_equal_approx(Juego.stat("dano"), 1.0 + Juego.legado * Juego.BONUS_LEGADO), "gastar la jalea no saca el bonus pasivo")


func probar_arbol() -> void:
	Juego.reiniciar_estado()
	Juego.jalea = 1000
	verificar(not Juego.comprar_jalea("despensa"), "un nodo con requisito no se compra antes de tiempo")
	var antes := Juego.stat("hormigas_iniciales")
	verificar(Juego.comprar_jalea("obreras_reales") and Juego.stat("hormigas_iniciales") == antes + 4, "Obreras reales suma 4 obreras")
	var dano := Juego.stat("dano")
	Juego.comprar_jalea("jalea_dano")
	verificar(is_equal_approx(Juego.stat("dano"), dano * 1.25), "Mandíbulas de jalea multiplica el daño")
	var costo := Juego.costo_jalea("jalea_dano")
	verificar(costo > Juego.jalea_por_id.jalea_dano.costo_base, "los nodos se encarecen con cada nivel")
	Juego.comprar_jalea("herencia_madera")
	verificar(Juego.nivel_de("mordida_madera") == 1, "Memoria de la madera da la dieta también en la colonia actual")
	Juego.comprar_jalea("despensa")
	Juego.comprar_jalea("linaje") # requiere Obreras reales 2: todavía no
	verificar(Juego.nivel_jalea("linaje") == 0, "Linaje pide Obreras reales nivel 2")
	Juego.comprar_jalea("obreras_reales")
	verificar(Juego.comprar_jalea("linaje"), "con Obreras reales 2 se habilita Linaje")
	Juego.coronas = 1
	Juego.migas = 1e6
	Juego.reclutadas = {"reina": 3, "roja": 8}
	Juego.fundar_colonia()
	verificar(Juego.nivel_de("mordida_madera") == 1, "la colonia nueva nace sabiendo devorar madera")
	verificar(is_equal_approx(Juego.migas, 1e5), "Reservas de la reina conserva el 10% de las migas")
	verificar(Juego.cantidad_casta("roja") == 2 and Juego.cantidad_casta("reina") == 0, "Linaje conserva el 25% de cada casta")
	verificar(Juego.nivel_jalea("obreras_reales") == 2 and Juego.stat("hormigas_iniciales") == Juego.stats_base.hormigas_iniciales + 8, "el árbol de la reina es permanente")
	Juego.reiniciar_estado()
	Juego.jalea = 1000
	Juego.niveles_jalea = {"jalea_migas": 2}
	Juego.comprar_jalea("corona_doble")
	Juego.lugar_actual = "casa"
	verificar(Juego.completar_destino() == int(Mundos.INFO.casa.coronas) + 1, "Corona doble suma una corona por gran objetivo")
	var guardado: Dictionary = JSON.parse_string(JSON.stringify(Juego.datos_partida()))
	Juego.reiniciar_estado()
	Juego.restaurar_partida(guardado)
	verificar(Juego.nivel_jalea("corona_doble") == 1 and Juego.jalea > 0 and Juego.nivel_jalea("jalea_migas") == 2, "jalea y árbol sobreviven al guardado")


func probar_topes_y_destinos() -> void:
	Juego.reiniciar_estado()
	var base := int(Juego.mejoras_por_id.mandibulas.nivel_max)
	verificar(Juego.nivel_maximo("mandibulas") == base, "en la casa el tope es el del CSV")
	Juego.lugares_completados["casa"] = true
	Juego.lugares_completados["restaurante"] = true
	verificar(Juego.nivel_maximo("mandibulas") == base + 2 * int(Juego.mejoras_por_id.mandibulas.tope_por_destino), "cada destino conquistado sube el tope")
	Juego.niveles_jalea["techo"] = 2
	verificar(Juego.nivel_maximo("mandibulas") == base + 2 * int(Juego.mejoras_por_id.mandibulas.tope_por_destino) + 2 * Juego.NIVELES_POR_TECHO, "Cámaras más hondas suma niveles a las elevables")
	verificar(Juego.nivel_maximo("mas_obreras") == int(Juego.mejoras_por_id.mas_obreras.nivel_max) + 2 * int(Juego.mejoras_por_id.mas_obreras.tope_por_destino), "Más obreras no es elevable (cuida el rendimiento)")
	Juego.reiniciar_estado()
	Juego.migas = 1e15
	verificar(not Juego.esta_desbloqueada("titanio") and not Juego.comprar("titanio"), "una mejora de destino no se compra antes de llegar")
	Juego.completar_destino() # Conquista actual, no sólo historial de otra colonia.
	verificar(not Juego.esta_desbloqueada("titanio"), "el restaurante abre el titanio, pero en el hormiguero sigue pidiendo su cámara anterior")
	Juego.niveles["filo_aserrado"] = 1
	verificar(Juego.esta_desbloqueada("titanio") and Juego.comprar("titanio"), "al abrir el restaurante se puede comprar Mandíbulas de titanio")
	verificar(not Juego.esta_desbloqueada("curadora"), "las del museo siguen esperando")


func probar_hitos_de_nivel() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mandibulas": 24}
	Juego._cache_stats.clear()
	var antes := Juego.stat("dano")
	verificar(is_equal_approx(antes, 25.0), "sin hito, 24 niveles de Mandíbulas dan 25 de daño")
	verificar(Juego.proximo_hito_nivel("mandibulas") == 25, "el próximo hito de Mandíbulas es el nivel 25")
	verificar(is_equal_approx(Juego.stat_tras_comprar("mandibulas"), 26.0 * 2.0), "la vista previa muestra el salto del hito")
	Juego.niveles.mandibulas = 25
	Juego._cache_stats.clear()
	verificar(is_equal_approx(Juego.stat("dano"), 52.0) and Juego.proximo_hito_nivel("mandibulas") == 50, "en el nivel 25 el daño se duplica")


func probar_partida_vieja() -> void:
	Juego.reiniciar_estado()
	Juego.restaurar_partida({"version": 3, "legado": 4, "migas": 5000, "niveles": {"mandibulas": 40}})
	verificar(Juego.legado == 12 and Juego.jalea == 12, "el legado viejo se convierte 1 a 3 en jalea para gastar")
	verificar(Juego.migas_colonia == 5000, "las migas viejas cuentan como migas de la colonia")
	verificar(Juego.nivel_de("mandibulas") == Juego.nivel_maximo("mandibulas"), "los niveles se recortan al tope actual")


func probar_guardia() -> void:
	Juego.reiniciar_estado()
	Juego.niveles_jalea = {"guardia": 2}
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.colonia.set_process(false)
	await get_tree().process_frame
	verificar(is_equal_approx(Juego.stat("pisotones_auto"), 2.0), "Guardia nivel 2 da 2 pisotones automáticos por segundo")
	var antes := Juego.migas_run
	var pisotones := Juego.estadistica("pisotones")
	for i in 30:
		run._pisotones_automaticos(0.1)
	verificar(Juego.migas_run > antes, "la guardia pisa comida sola y da migas")
	verificar(Juego.estadistica("pisotones") - pisotones == 6, "a 2 por segundo, en 3 segundos pisa 6 veces (%d)" % (Juego.estadistica("pisotones") - pisotones))
	for i in Colonia.MAX_HORMIGAS + 50:
		run.colonia._nacer()
	verificar(run.colonia.cantidad() == Colonia.MAX_HORMIGAS and run.colonia.colonia_llena(), "la colonia no pasa de %d hormigas (rendimiento)" % Colonia.MAX_HORMIGAS)
	verificar(run.colonia.desplegar_minis(Vector2.ZERO, 2) == 0, "con la colonia llena tampoco nacen miniobreras")
	run.queue_free()
	await get_tree().process_frame


func probar_panel() -> void:
	Juego.reiniciar_estado()
	Juego.coronas = 1
	Juego.jalea = 5
	Juego.migas_colonia = 2e6
	var tienda: Control = preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	await get_tree().process_frame
	verificar(tienda._pestanas.legado.visible and tienda._pestanas.legado.text.begins_with("Jalea real"), "la pestaña se llama Jalea real")
	tienda._cambiar_pestana("legado")
	await get_tree().process_frame
	var textos := _textos(tienda._panel_legado)
	verificar("+%d jalea" % Juego.jalea_por_fundar() in textos, "el panel muestra cuánta jalea daría fundar")
	verificar(Juego.jalea_por_id.obreras_reales.nombre in textos and "Cuesta" in textos, "el panel muestra el árbol de la reina con precios")
	var antes := Juego.nivel_jalea("obreras_reales")
	tienda._panel_legado._comprar_jalea("obreras_reales")
	verificar(Juego.nivel_jalea("obreras_reales") == antes + 1, "se puede comprar un nodo desde el panel")
	Juego.lugares_completados["casa"] = true
	tienda._cambiar_pestana("hogar")
	tienda._refrescar()
	tienda._seleccionar_mejora("titanio")
	verificar(not tienda._estados.titanio.misterio and "Mandíbulas de titanio" in tienda._lbl_sala.text, "con viajes revelados se ven las mejoras de destino en su rama")
	tienda.queue_free()
	await get_tree().process_frame


func _textos(nodo: Node) -> String:
	var salida := ""
	if nodo is Label:
		salida += nodo.text + "\n"
	elif nodo is Button:
		salida += nodo.text + "\n"
	for hijo in nodo.get_children():
		salida += _textos(hijo)
	return salida


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)
