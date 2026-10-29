extends Node
var fallas := 0
var total := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")  # las verificaciones leen textos en español
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	Juego.migas = 100000
	var oferta := Juego.cotizar_mejora("mas_obreras", 10)
	var suma := 0.0
	var obreras: Dictionary = Juego.mejoras_por_id.mas_obreras
	for i in 10:
		suma += floorf(obreras.costo_base * pow(obreras.crecimiento, i))
	verificar(oferta.cantidad == 10 and oferta.costo == suma, "el lote ×10 suma los precios de sus diez niveles")
	var antes := Juego.migas
	verificar(Juego.comprar_lote("mas_obreras", 10) == 10 and Juego.migas == antes - suma and Juego.nivel_de("mas_obreras") == 10, "×10 compra exactamente diez niveles con su costo real")
	Juego.niveles.mas_obreras = 28
	Juego._cache_stats.clear()
	verificar(Juego.cotizar_mejora("mas_obreras", 10).cantidad == 2, "un lote nunca supera el nivel máximo")
	Juego.reiniciar_estado()
	# Alcanzan exactamente dos niveles y sobra una miga. No fijar el precio
	# histórico: este contrato debe seguir valiendo al calibrar la economía.
	Juego.migas = floorf(obreras.costo_base) + floorf(obreras.costo_base * obreras.crecimiento) + 1
	verificar(Juego.comprar_lote("mas_obreras", 0) == 2 and Juego.migas == 1, "Máx compra todo lo que alcanza y conserva el cambio")
	antes = Juego.migas
	verificar(Juego.comprar_lote("mandibulas", 10) == 0 and Juego.migas == antes, "un lote que no alcanza no consume migas ni compra parcialmente")
	Juego.migas = 1e9
	verificar(Juego.comprar_lote("mandibulas_acero", 0) == 0, "Máx respeta los requisitos de las mejoras")
	Juego.reclutadas = {"voladora": 1}
	verificar(Juego.comprar_castas_lote("reina", 10) == 3 and Juego.cantidad_casta("reina") == 3, "los lotes de castas respetan su límite")
	verificar(Juego.comprar_castas_lote("reina", 0) == 0, "una casta completa no se vuelve a cobrar")
	Juego.reiniciar_estado()
	Juego.migas = 25000
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	Juego.cambiar_cantidad_compra(10)
	verificar(tienda.disponibles_por_rama().Colonia > 0 and tienda._leyenda.Colonia.text.ends_with(str(tienda.disponibles_por_rama().Colonia)), "la rama avisa cuántas mejoras se pueden comprar")
	antes = Juego.stat("hormigas_iniciales")
	tienda._comprar("mas_obreras")
	verificar(Juego.stat("hormigas_iniciales") == antes + 20, "el selector ×10 de la tienda ejecuta la compra por lotes")
	Juego.migas = 0
	Juego.migas_cambiaron.emit(0)
	verificar(tienda.disponibles_por_rama().Colonia == 0 and tienda._leyenda.Colonia.text.ends_with("Colonia"), "el aviso se apaga cuando ya no alcanza el saldo")
	tienda.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	Juego.cambiar_cantidad_compra(1)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.cocina.limite_rutas_por_cuadro = 0
	var casa := run.cocina
	verificar(PlanoCasa.AMBIENTES.size() == 7 and PlanoCasa.LIMITES.size.x >= 7500, "la casa tiene siete ambientes y un plano mayor")
	var destinos := {"cocina": Vector2(-200, 500), "comedor": Vector2(2100, 1000), "living": Vector2(4600, 600), "pasillo": Vector2(500, 1800), "dormitorio": Vector2(1300, 3300), "estudio": Vector2(2600, 3600), "bano": Vector2(5800, 4200)}
	var inicio_test := Time.get_ticks_msec()
	for zona in destinos:
		var destino: Vector2 = destinos[zona]
		var ruta := casa.ruta(Vector2.ZERO, destino, 9500)
		var segura := not ruta.is_empty()
		var pos := Vector2.ZERO
		for p in ruta:
			segura = segura and casa.segmento_libre(pos, p)
			pos = p
		verificar(segura and pos.distance_to(destino) < 1, "se llega a %s por puertas sin atravesar paredes o muebles" % zona)
	print("Navegación por siete ambientes y construcción compartida: %d ms." % (Time.get_ticks_msec() - inicio_test))
	verificar(not casa.segmento_libre(Vector2.ZERO, Vector2(460, 0)) and casa.segmento_libre(Vector2.ZERO, Vector2(460, 0), true), "las voladoras pasan sobre sillas que bloquean a las obreras")
	var a := Vector2(1600, -300)
	var b := Vector2(1850, -300)
	verificar(not casa.segmento_libre(a, b, true) and casa.ruta(a, b, 9500, true).size() > 1, "las voladoras también usan puertas para cruzar paredes")
	var comidas_validas := true
	var zonas_con_comida := {}
	for c in run.comidas.lista:
		comidas_validas = comidas_validas and casa.libre(c.position, c.radio + 8)
		zonas_con_comida[PlanoCasa.ambiente_en(c.position)] = true
	verificar(comidas_validas and zonas_con_comida.size() >= 5, "la comida está repartida por ambientes y fuera de muebles y paredes")
	run.radio_actual = 9500
	for zona in destinos:
		var regreso_seguro := true
		for casta in ["obrera", "veloz", "voladora"]:
			var h := run.colonia._nacer(casta, destinos[zona])
			h.carga = 1
			h._volver()
			for paso in 2000:
				if h.carga == 0:
					break
				h._process(0.1)
				regreso_seguro = regreso_seguro and casa.libre(h.position, 7.5, casta == "voladora")
			regreso_seguro = regreso_seguro and h.carga == 0
			h.detener()
		verificar(regreso_seguro, "obreras, veloces y voladoras regresan desde %s sin quedar atrapadas ni cruzar obstáculos" % zona)
	run.camara.ver_casa()
	verificar(run.camara.position == PlanoCasa.limites().get_center(), "H permite encuadrar toda la casa")
	run.queue_free()
	await get_tree().process_frame
	print("Casa y lotes: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)

func verificar(ok: bool, texto: String) -> void:
	total += 1
	print("  OK   " if ok else "  FALLA ", texto)
	if not ok:
		fallas += 1
