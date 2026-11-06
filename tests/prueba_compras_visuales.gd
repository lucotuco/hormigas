extends Node
## Contrato de las compras visuales: catálogo, economía, tienda y persistencia.
## El saldo y los requisitos se preparan explícitamente para aislar la compra;
## esta fixture no mide duración ni pretende simular ingresos de una partida.
const CASOS := [
	{"id": "migas_brillantes", "rama": "Recolección", "requisito": "buche", "nivel": 1,
		"costo": 120.0, "stat": "multiplicador_migas", "tipo": "multiplica", "valor": 1.08},
	{"id": "mandibulas_destello", "rama": "Mandíbulas", "requisito": "mandibulas", "nivel": 2,
		"costo": 180.0, "stat": "dano", "tipo": "multiplica", "valor": 1.08},
	{"id": "pulso_colonia", "rama": "Feromonas", "requisito": "alarma", "nivel": 1,
		"costo": 1200.0, "stat": "frenesi_duracion", "tipo": "suma", "valor": 1.0},
]
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	var existia := FileAccess.file_exists(Juego.RUTA_PARTIDA)
	var huella := FileAccess.get_sha256(Juego.RUTA_PARTIDA) if existia else ""
	probar_catalogo()
	probar_compras()
	probar_guardado_y_fundacion()
	await probar_tienda()
	Juego.reiniciar_estado()
	verificar(FileAccess.file_exists(Juego.RUTA_PARTIDA) == existia
		and (not existia or FileAccess.get_sha256(Juego.RUTA_PARTIDA) == huella),
		"las compras, la carga y la fundación de QA no modifican la partida del jugador")
	print("Compras visuales: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func probar_catalogo() -> void:
	Juego.reiniciar_estado()
	for caso: Dictionary in CASOS:
		var id: String = caso.id
		verificar(Juego.mejoras_por_id.has(id), id + ": existe en el catálogo real")
		if not Juego.mejoras_por_id.has(id):
			continue
		var m: Dictionary = Juego.mejoras_por_id[id]
		verificar(m.rama == caso.rama and m.stat == caso.stat and m.tipo == caso.tipo
			and is_equal_approx(m.valor, caso.valor) and is_equal_approx(m.costo_base, caso.costo),
			id + ": el CSV define su rama, precio y efecto real")
		verificar(m.requisitos.size() == 1 and m.requisitos[0].id == caso.requisito
			and m.requisitos[0].nivel == caso.nivel and m.destino == "",
			id + ": sólo pide el requisito acordado, sin destino oculto")
		verificar(m.nivel_max == 1 and m.tope_por_destino == 0 and not m.elevable
			and m.bonus_cada == 0 and Juego.nivel_maximo(id) == 1,
			id + ": es una compra única sin hitos ni extensiones de tope")
		var dependencias: Array[String] = []
		for otra: Dictionary in Juego.mejoras:
			for requisito: Dictionary in otra.requisitos:
				if requisito.id == id:
					dependencias.append(otra.id)
		for casta: Dictionary in Juego.castas:
			for requisito: Dictionary in casta.requisitos:
				if requisito.id == id:
					dependencias.append(casta.id)
		verificar(dependencias.is_empty(),
			id + ": es una hoja opcional, no bloquea mejoras ni castas existentes")
		Juego.lugares_completados = {"casa": true, "restaurante": true, "museo": true,
			"obelisco": true, "coliseo": true, "eiffel": true}
		Juego.niveles_jalea = {"techo": int(Juego.jalea_por_id.techo.nivel_max)}
		verificar(Juego.nivel_maximo(id) == 1,
			id + ": los destinos y las cámaras hondas no permiten volver a comprarla")
		Juego.reiniciar_estado()


func _preparar_compra(caso: Dictionary) -> void:
	Juego.reiniciar_estado()
	Juego.niveles[caso.requisito] = caso.nivel
	Juego.migas = float(caso.costo) * 20.0
	Juego._cache_stats.clear()


func _esperado(caso: Dictionary, antes: float) -> float:
	return antes * float(caso.valor) if caso.tipo == "multiplica" else antes + float(caso.valor)


func probar_compras() -> void:
	for caso: Dictionary in CASOS:
		var id: String = caso.id
		if not Juego.mejoras_por_id.has(id):
			continue
		_preparar_compra(caso)
		Juego.niveles[caso.requisito] = int(caso.nivel) - 1
		Juego._cache_stats.clear()
		var bloqueada := Juego.datos_partida().duplicate(true)
		verificar(not Juego.esta_desbloqueada(id) and Juego.comprar_lote(id, 10) == 0
			and Juego.datos_partida() == bloqueada,
			id + ": comprar sin su requisito no gasta migas ni activa su efecto")
		for cantidad in [1, 10, 0]:
			_preparar_compra(caso)
			Juego.cantidad_compra = cantidad
			var saldo := Juego.migas
			var antes := Juego.stat(caso.stat)
			var esperado := _esperado(caso, antes)
			var partida_antes := Juego.datos_partida().duplicate(true)
			var oferta := Juego.cotizar_mejora(id, cantidad)
			verificar(oferta.puede and oferta.cantidad == 1 and is_equal_approx(oferta.costo, caso.costo),
				"%s: ×%d cotiza exactamente un nivel y su precio" % [id, cantidad])
			verificar(is_equal_approx(Juego.stat_tras_comprar(id, 10), esperado),
				id + ": la vista previa respeta el tope de un nivel")
			VistaCompra.comparar(id)
			verificar(Juego.datos_partida() == partida_antes and Juego.nivel_de(id) == 0
				and is_equal_approx(Juego.stat(caso.stat), antes),
				id + ": cotizar y mirar no compran ni activan efectos")
			verificar(Juego.comprar_lote(id, cantidad) == 1 and Juego.nivel_de(id) == 1
				and is_equal_approx(Juego.migas, saldo - float(caso.costo)),
				"%s: ×%d compra y cobra una sola vez" % [id, cantidad])
			verificar(is_equal_approx(Juego.stat(caso.stat), esperado),
				id + ": la compra aplica el cambio prometido a la estadística real")
			var comprada := Juego.datos_partida().duplicate(true)
			verificar(Juego.esta_al_maximo(id) and Juego.cotizar_mejora(id, 0).cantidad == 0
				and Juego.comprar_lote(id, 10) == 0 and Juego.comprar_lote(id, 0) == 0
				and Juego.datos_partida() == comprada,
				id + ": insistir con ×10 o Máx no vuelve a cobrar ni apila el efecto")


func probar_guardado_y_fundacion() -> void:
	Juego.reiniciar_estado()
	# Preparación administrativa para guardar tres compras, no una ruta de progreso.
	Juego.niveles = {"buche": 1, "mandibulas": 2, "alarma": 1}
	Juego.migas = 10000
	for caso: Dictionary in CASOS:
		verificar(Juego.comprar(caso.id), caso.id + ": se compra antes de guardar")
	# Un registro sintético válido sólo verifica preservación del archivo.
	Juego.runs_jugadas = 2
	Juego.registrar_limpieza({"destino": "casa", "dieta": 1, "territorio": 620.0,
		"version_mapa": Mundos.VERSION_CONTENIDO, "completa": false,
		"tiempo_limpieza": 12.0, "tiempo_total": 14.0,
		"migas": 100.0, "produccion": 100.0 / 14.0, "pendiente": 0.0})
	Juego.hitos = {"primer_tesoro": true}
	Juego.lugares_completados = {"casa": true}
	var guardado: Dictionary = JSON.parse_string(JSON.stringify(Juego.datos_partida()))
	Juego.reiniciar_estado()
	Juego.restaurar_partida(guardado)
	for caso: Dictionary in CASOS:
		# El hito y la adaptación pueden alterar stats: la referencia proviene del
		# mismo guardado, con sólo esta mejora desactivada, no de una base inventada.
		verificar(Juego.nivel_de(caso.id) == 1 and Juego.esta_al_maximo(caso.id),
			caso.id + ": guardar y cargar JSON conserva la compra única")
		var actual := Juego.stat(caso.stat)
		Juego.niveles.erase(caso.id)
		Juego._cache_stats.clear()
		var sin_mejora := Juego.stat(caso.stat)
		Juego.niveles[caso.id] = 1
		Juego._cache_stats.clear()
		verificar(is_equal_approx(actual, _esperado(caso, sin_mejora)),
			caso.id + ": cargar conserva el efecto real, no sólo el nombre de la compra")
	var anterior := guardado.duplicate(true)
	for caso: Dictionary in CASOS:
		anterior.niveles.erase(caso.id)
	Juego.restaurar_partida(anterior)
	for caso: Dictionary in CASOS:
		verificar(Juego.nivel_de(caso.id) == 0 and not Juego.esta_al_maximo(caso.id),
			caso.id + ": una partida anterior sin el ID no inventa la compra")
	Juego.restaurar_partida(guardado)
	var archivo := Juego.archivo_expediciones.duplicate(true)
	var marcas := Juego.records_limpieza.duplicate(true)
	var hitos := Juego.hitos.duplicate(true)
	var destinos := Juego.lugares_completados.duplicate(true)
	# Una corona de QA habilita la API normal de fundación sin tocar archivos.
	Juego.coronas = 1
	verificar(Juego.fundar_colonia() and Juego.fundaciones == 1 and Juego.lugar_actual == "casa",
		"fundar por la API normal reinicia la colonia en la casa")
	for caso: Dictionary in CASOS:
		verificar(Juego.nivel_de(caso.id) == 0,
			caso.id + ": la nueva colonia no hereda efectos visuales sin recomprarlos")
	verificar(Juego.archivo_expediciones == archivo and Juego.records_limpieza == marcas
		and Juego.hitos == hitos and Juego.lugares_completados == destinos,
		"fundar quita las tres compras pero conserva archivo, récords, hitos e historia")


func probar_tienda() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"buche": 1, "mandibulas": 2, "alarma": 1}
	Juego.migas = 10000
	Juego.cantidad_compra = 10
	Juego.runs_jugadas = 4
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	await cuadros(3)
	for caso: Dictionary in CASOS:
		var antes := Juego.datos_partida().duplicate(true)
		var stat_antes := Juego.stat(caso.stat)
		tienda._mostrar_ficha(caso.id)
		verificar(Juego.datos_partida() == antes and Juego.nivel_de(caso.id) == 0,
			caso.id + ": mostrar su ficha en la tienda no realiza la compra")
		var saldo := Juego.migas
		tienda._comprar(caso.id)
		await cuadros(1)
		verificar(Juego.nivel_de(caso.id) == 1 and tienda._estados[caso.id].nivel == 1
			and tienda._corte_tierra.estados[caso.id].nivel == 1
			and is_equal_approx(Juego.migas, saldo - float(caso.costo))
			and is_equal_approx(Juego.stat(caso.stat), _esperado(caso, stat_antes)),
			caso.id + ": comprar desde la tienda cobra y actualiza estadística y cámara reales")
		tienda._comprar(caso.id)
		verificar(Juego.nivel_de(caso.id) == 1 and is_equal_approx(Juego.migas, saldo - float(caso.costo)),
			caso.id + ": la tienda no duplica el efecto ni el cobro al insistir")
	tienda.queue_free()
	await cuadros(1)


func cuadros(cantidad: int) -> void:
	for i in cantidad:
		await get_tree().process_frame


func verificar(condicion: bool, texto: String) -> void:
	total += 1
	if not condicion:
		fallas += 1
	print(("OK " if condicion else "FALLA ") + texto)
