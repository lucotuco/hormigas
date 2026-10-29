extends Node
## La preparación es una compra confirmada, no un regalo ni una simulación
## que altere la partida. Se preservan los contratos del prestigio existente.
var total := 0
var fallas := 0
const CUADRILLA: Array[String] = ["herencia_madera", "obreras_reales", "jalea_dano"]

func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK " if ok else "FALLA ") + detalle)

func preparar() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mandibulas": 10, "mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego.reclutadas = {"carpintera": 8, "cargadora": 4}
	Juego.migas = 3000
	Juego.migas_colonia = 240.1e6
	Juego.completar_destino()
	Juego._cache_stats.clear()

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	probar_contrato()
	probar_planes()
	probar_rechazo_atomico()
	probar_herencias_no_retroactivas()
	await probar_ventana()
	Juego.reiniciar_estado()
	print("Preparación del rebirth: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)

func probar_contrato() -> void:
	Juego.reiniciar_estado()
	var paso := Juego.proxima_meta()
	verificar(paso.tipo == "nivel" and paso.accion == "mejora" and paso.id == "mandibulas", "la primera meta identifica la compra concreta, sin ejecutar nada")
	Juego.niveles = {"mandibulas": 4}
	Juego.iniciar_run()
	Juego.migas = 300
	Juego.sumar_migas_run(350)
	verificar(Juego.proxima_meta().actual == 650, "la meta cuenta las migas pendientes durante la expedición")
	Juego.terminar_run()
	verificar(Juego.proxima_meta().actual == 650 and Juego.migas_run == 350, "el resultado no cuenta otra vez migas ya cobradas ni borra su resumen")
	preparar()
	paso = Juego.proxima_meta()
	verificar(paso.tipo == "fundacion" and paso.accion == "legado" and Juego.destino_desbloqueado("restaurante"), "tras la casa se propone fundar pero viajar sigue disponible")
	var antes := Juego.datos_partida().duplicate(true)
	Juego.proxima_meta()
	verificar(Juego.datos_partida() == antes, "consultar el siguiente paso no funda, compra ni guarda progreso")

func probar_planes() -> void:
	for decreto in ["numerosa", "guerrera", "recolectora", "exploradora", "invalido"]:
		for valores in [[], ["herencia_madera"], CUADRILLA]:
			var compras: Array[String] = []
			compras.assign(valores)
			preparar()
			Juego.stat("dano")
			var antes := Juego.datos_partida().duplicate(true)
			var cache := Juego._cache_stats.duplicate(true)
			var previa := Juego.vista_previa_fundar(decreto, compras)
			verificar(previa.plan_valido and Juego.datos_partida() == antes and Juego._cache_stats == cache, "%s/%d compras: la cotización es pura y completa" % [decreto, compras.size()])
			var ganada := Juego.jalea_por_fundar()
			verificar(Juego.fundar_colonia(decreto, compras), "%s/%d compras: se confirma la preparación" % [decreto, compras.size()])
			var coincide: bool = previa.jalea == Juego.jalea and previa.castas == Juego.reclutadas and is_equal_approx(previa.migas, Juego.migas)
			for nombre in previa.stats:
				coincide = coincide and is_equal_approx(previa.stats[nombre], Juego.stat(nombre))
			verificar(coincide and Juego.legado == ganada and Juego.jalea + previa.costo_jalea == ganada, "%s/%d compras: arranque exacto, jalea descontada y bonus pasivo intacto" % [decreto, compras.size()])
			var datos: Dictionary = JSON.parse_string(JSON.stringify(Juego.datos_partida()))
			Juego.reiniciar_estado()
			Juego.restaurar_partida(datos)
			verificar(previa.jalea == Juego.jalea and int(previa.stats.materiales) == int(Juego.stat("materiales")), "%s/%d compras: la preparación sobrevive a guardar y cargar" % [decreto, compras.size()])
	preparar()
	var precio := Juego.cotizar_preparacion_fundar(CUADRILLA)
	verificar(precio.costo == 6 and precio.saldo == 4 and precio.compras.size() == 3, "la cuadrilla cobra exactamente las tres mejoras existentes, sin regalar ninguna")

func probar_rechazo_atomico() -> void:
	for valores in [["desconocida"], ["herencia_madera", "herencia_madera"], ["herencia_muros"], ["corona_doble"]]:
		var compras: Array[String] = []
		compras.assign(valores)
		preparar()
		var antes := Juego.datos_partida().duplicate(true)
		var previa := Juego.vista_previa_fundar("numerosa", compras)
		verificar(not previa.plan_valido and not Juego.fundar_colonia("numerosa", compras) and Juego.datos_partida() == antes, "plan inválido %s se rechaza entero sin perder la colonia" % str(compras))
	preparar()
	Juego.migas_colonia = 0
	verificar(not Juego.fundar_colonia("numerosa", CUADRILLA) and Juego.fundaciones == 0 and Juego.nivel_jalea("herencia_madera") == 0, "sin saldo suficiente no se hace una compra parcial ni se funda")
	var excesivo: Array[String] = []
	excesivo.resize(13)
	excesivo.fill("obreras_reales")
	verificar(not Juego.cotizar_preparacion_fundar(excesivo).valido, "el trabajo de cotización de una preparación tiene un límite fijo")

func probar_herencias_no_retroactivas() -> void:
	preparar()
	var compras: Array[String] = ["herencia_madera", "despensa"]
	var previa := Juego.vista_previa_fundar("numerosa", compras)
	Juego.fundar_colonia("numerosa", compras)
	verificar(previa.migas == 0 and Juego.migas == 0 and Juego.nivel_jalea("despensa") == 1, "comprar reservas en este reinicio no conserva retroactivamente las migas anteriores")
	preparar()
	compras = ["obreras_reales", "obreras_reales", "linaje"]
	previa = Juego.vista_previa_fundar("numerosa", compras)
	Juego.fundar_colonia("numerosa", compras)
	verificar(previa.castas.is_empty() and Juego.reclutadas.is_empty() and Juego.nivel_jalea("linaje") == 1, "un linaje recién comprado tampoco conserva retroactivamente las castas")

func probar_ventana() -> void:
	preparar()
	var ventana := VentanaFundar.new()
	add_child(ventana)
	await get_tree().process_frame
	verificar(ventana.preparacion == "guardar" and ventana.compras_preparacion().is_empty(), "la confirmación empieza sin compras automáticas")
	var antes := Juego.datos_partida().duplicate(true)
	ventana.elegir_preparacion("cuadrilla")
	verificar(Juego.datos_partida() == antes and not ventana._boton_fundar.disabled and "Costo total: 6" in ventana._lbl_preparacion.text, "elegir cuadrilla muestra el costo completo sin comprar")
	ventana.fundar()
	verificar(Juego.fundaciones == 1 and Juego.jalea == 4 and Juego.stat("materiales") == 1 and Juego.stat("hormigas_iniciales") > 8, "el botón confirma una colonia que ya puede comer muebles y su cuadrilla")
	await get_tree().process_frame
	ventana = VentanaFundar.new()
	add_child(ventana)
	await get_tree().process_frame
	ventana.elegir_preparacion("cuadrilla")
	verificar(ventana.compras_preparacion().is_empty() and "No se cobra nada" in ventana._lbl_preparacion.text, "una preparación ya aprendida no vuelve a cobrar sus mejoras")
	ventana.queue_free()
	await get_tree().process_frame
