extends Node
## La ficha compara trabajo real sin simular agentes ni modificar la partida.
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	var existia := FileAccess.file_exists(Juego.RUTA_PARTIDA)
	var huella := hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) if existia else 0
	Juego.reiniciar_estado()
	Juego.migas = 10000
	var previo := Juego.datos_partida().duplicate(true)
	var obreras := VistaCompra.comparar("mas_obreras")
	verificar(obreras.modo == "colonia" and obreras.antes == 1 and obreras.despues == 2,
		"la primera compra compara una obrera con dos, no una colonia inventada")
	Juego.cantidad_compra = 10
	var lote := VistaCompra.comparar("mas_obreras")
	verificar(lote.despues == Juego.stat_tras_comprar("mas_obreras", Juego.cotizar_mejora("mas_obreras", 10).cantidad),
		"la comparación de diez usa la cotización y sus topes reales")
	Juego.cantidad_compra = 0
	var maximo := VistaCompra.comparar("mas_obreras")
	verificar(maximo.despues == Juego.stat_tras_comprar("mas_obreras", Juego.cotizar_mejora("mas_obreras", 0).cantidad),
		"Máx muestra exactamente el lote que alcanza")
	Juego.cantidad_compra = 1
	var carga := VistaCompra.comparar("buche")
	verificar(carga.modo == "carga" and carga.antes == 1 and carga.despues == 2 and "Mismo bocado" in carga.nota,
		"más buche suma bocados sin prometer porciones más grandes")
	var cargadora := VistaCompra.comparar("cargadora")
	verificar(cargadora.antes == Juego.stats_casta("obrera").capacidad and cargadora.despues == Juego.stats_casta("cargadora").capacidad,
		"la cargadora se compara con la obrera usando su capacidad efectiva")
	var carpintera := VistaCompra.comparar("carpintera")
	verificar(is_equal_approx(carpintera.despues, Juego.stats_casta("carpintera").dano * RolesHormiga.dano("carpintera", 1)),
		"la ficha de carpintera muestra daño real sobre madera")
	var dieta := VistaCompra.comparar("mordida_madera")
	verificar(dieta.modo == "madera" and dieta.antes == 0 and dieta.despues == 1,
		"la dieta ilustra acceso a madera, no un agujero gigante")
	verificar(VistaCompra.comparar("mordida_resistente").is_empty(),
		"una dieta distinta no reutiliza una demostración falsa de madera")
	var entrada := VistaCompra.comparar("entradas")
	verificar(entrada.antes == 0 and entrada.despues == 1 and "N:" in entrada.nota and Juego.entradas_colocadas.is_empty(),
		"la entrada explica su colocación manual sin colocar accesos")
	verificar("Colonia inicial: 1" in VistaCompra.aviso_llamado("rastro_persistente"),
		"con una obrera se avisa que más cupo de llamado todavía no suma participación")
	verificar(VistaCompra.aviso_llamado("buche") == "" and VistaCompra.comparar("antenas").is_empty(),
		"no se agregan avisos ni demostraciones ajenas a otra mejora")
	verificar(Juego.datos_partida() == previo,
		"mirar todas las comparaciones conserva economía, niveles, progreso y accesos")
	Juego.reclutadas = {"veloz": 8}
	verificar("9 de 9" in VistaCompra.aviso_llamado("rastro_persistente"),
		"el llamado cuenta especialistas en la población inicial")
	Juego.niveles = {"mas_obreras": 15}
	Juego._cache_stats.clear()
	verificar(VistaCompra.aviso_llamado("rastro_persistente") == "",
		"el aviso desaparece cuando la colonia puede usar todo el cupo")
	Juego.hitos = {"primera_silla": true, "cuatro_sillas": true}
	Juego._cache_stats.clear()
	verificar(is_equal_approx(VistaCompra.comparar("carpintera").despues, Juego.stats_casta("carpintera").dano * RolesHormiga.dano("carpintera", 1))
		and VistaCompra.comparar("cargadora").despues == Juego.stats_casta("cargadora").capacidad,
		"los premios ya obtenidos se incluyen sin duplicar fórmulas de roles")
	Juego.reiniciar_estado()
	Juego.migas = 1000
	Juego.runs_jugadas = 4
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	await cuadros(3)
	tienda._mostrar_ficha("mas_obreras")
	verificar(tienda._vista_compra.visible and tienda._vista_compra.datos.antes == 1 and not tienda._vista_compra.is_processing(),
		"la ficha integra una vista retenida sin proceso por cuadro ni hormigas extra")
	tienda._comprar("mas_obreras")
	verificar(Juego.nivel_de("mas_obreras") == 1 and tienda._vista_compra.datos.antes == 1 and tienda._vista_compra.datos.despues == 2,
		"después de comprar queda visible el cambio logrado, no la próxima compra")
	tienda._mostrar_ficha("buche")
	verificar(tienda._vista_confirmada.is_empty() and tienda._vista_compra.datos.modo == "carga",
		"al cambiar de cámara se limpia la demostración anterior")
	tienda._mostrar_ficha("rastro_persistente")
	verificar(tienda._lbl_utilidad.visible and "Colonia inicial: 2" in tienda._lbl_utilidad.text,
		"la advertencia se presenta en la ficha y se actualiza tras sumar una obrera")
	for tamano in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		get_window().size = tamano
		await cuadros(2)
		for id in ["mas_obreras", "buche", "cargadora", "carpintera", "mordida_madera", "entradas"]:
			tienda._mostrar_ficha(id)
			await cuadros(2)
			verificar(tienda._area_nido.get_global_rect().grow(1).encloses(tienda._ficha_mejoras.get_global_rect()),
				"la ficha comparativa entra en el hormiguero: %s a %s" % [id, tamano])
	tienda.queue_free()
	await cuadros(1)
	verificar(FileAccess.file_exists(Juego.RUTA_PARTIDA) == existia and (not existia or hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) == huella),
		"las pruebas no modifican el guardado del jugador")
	print("Compras claras: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func cuadros(cantidad: int) -> void:
	for i in cantidad:
		await get_tree().process_frame


func verificar(condicion: bool, texto: String) -> void:
	total += 1
	if not condicion:
		fallas += 1
	print(("OK " if condicion else "FALLA ") + texto)
