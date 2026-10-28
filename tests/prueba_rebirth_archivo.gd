extends Node
## Viajes por colonia, historial permanente y archivo acotado sin tocar partidas.
var total := 0
var fallas := 0

func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("OK " if ok else "FALLA ", detalle)

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	probar_rebirth()
	probar_archivo()
	await probar_panel()
	Juego.reiniciar_estado()
	print("Rebirth y archivo: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)

func registro(tiempo := 12.5) -> Dictionary:
	return {"destino": "casa", "dieta": 1, "territorio": 620.0, "version_mapa": Mundos.VERSION_CONTENIDO,
		"completa": false, "tiempo_limpieza": tiempo, "tiempo_total": tiempo + 2,
		"migas": 100.0, "produccion": 100.0 / (tiempo + 2), "pendiente": 0.0}

func probar_rebirth() -> void:
	Juego.reiniciar_estado()
	for id in Mundos.ORDEN:
		Juego.lugares_completados[id] = true
		Juego.coronas_cobradas[id] = true
	Juego.lugar_actual = "eiffel"
	Juego.coronas = 21
	Juego.runs_jugadas = 30
	Juego.registrar_limpieza(registro())
	Juego.hitos = {"primer_monumento": true}
	var tope := Juego.nivel_maximo("mas_obreras")
	verificar(Juego.fundar_colonia("exploradora") and Juego.lugar_actual == "casa", "rebirth vuelve a la casa aunque se funde desde Eiffel")
	verificar(Juego.destino_desbloqueado("casa") and not Juego.destino_desbloqueado("restaurante") and not Juego.elegir_destino("eiffel"), "sólo la casa queda disponible y no se saltan viajes por API")
	verificar(Juego.lugares_completados.size() == 6 and Juego.hitos.has("primer_monumento") and Juego.nivel_maximo("mas_obreras") == tope, "descubrimientos, premios y topes históricos no se pierden")
	verificar(Juego.archivo_expediciones.size() == 1 and Juego.records_limpieza.size() == 1, "el archivo sobrevive a fundar")
	Juego.completar_destino()
	verificar(Juego.elegir_destino("restaurante") and not Juego.elegir_destino("museo"), "reconquistar casa abre restaurante, no el resto del mundo")
	Juego.completar_destino()
	verificar(Juego.elegir_destino("museo") and not Juego.elegir_destino("obelisco"), "cada destino se vuelve a abrir en orden")
	var guardado := Juego.datos_partida().duplicate(true)
	Juego.reiniciar_estado()
	Juego.restaurar_partida(guardado)
	verificar(Juego.lugar_actual == "museo" and not Juego.destino_desbloqueado("obelisco"), "guardar conserva los viajes de esta colonia, no sólo el historial")
	guardado.lugar = "eiffel"
	guardado.coronas_cobradas = {}
	Juego.restaurar_partida(guardado)
	verificar(Juego.lugar_actual == "casa", "una partida con destino inaccesible vuelve a casa al cargar")
	guardado.erase("coronas_cobradas")
	guardado.erase("archivo_expediciones")
	guardado.erase("records_limpieza")
	guardado.version = 3
	Juego.restaurar_partida(guardado)
	verificar(Juego.destino_desbloqueado("eiffel") and Juego.archivo_expediciones.is_empty(), "partidas antiguas sin progreso por colonia conservan su recorrido y no inventan tiempos")

func probar_archivo() -> void:
	Juego.reiniciar_estado()
	Juego.runs_jugadas = 1
	var r := registro()
	verificar(Juego.registrar_limpieza(r) and Juego.archivo_expediciones.size() == 1, "la primera limpieza crea archivo y marca personal")
	verificar(not Juego.registrar_limpieza(r) and Juego.archivo_expediciones.size() == 1, "cerrar dos veces la misma expedición no duplica el archivo")
	Juego.runs_jugadas += 1
	verificar(Juego.registrar_limpieza(registro(10)), "un tiempo menor reemplaza la marca de su categoría")
	Juego.runs_jugadas += 1
	verificar(not Juego.registrar_limpieza(registro(20)) and Juego.archivo_expediciones.size() == 3, "un tiempo peor entra al archivo sin borrar el récord")
	verificar(Juego.records_limpieza.values()[0].tiempo_limpieza == 10, "la marca conserva el menor tiempo, no el último")
	for campo in ["dieta", "territorio", "version_mapa", "completa"]:
		Juego.runs_jugadas += 1
		var distinto := registro(30)
		distinto[campo] = true if campo == "completa" else distinto[campo] + 1
		verificar(Juego.registrar_limpieza(distinto), "%s crea una categoría distinta de limpieza" % campo)
	var cantidad := Juego.archivo_expediciones.size()
	for invalido in [{}, {"destino": "inventado"}, {"tiempo_limpieza": NAN}, {"tiempo_limpieza": -1}, {"tiempo_total": 1}, {"dieta": 5}, {"territorio": INF}, {"colonia": []}, {"completa": 1}]:
		var datos := r.duplicate(true)
		datos.merge(invalido, true)
		if invalido.is_empty():
			datos.erase("produccion")
		Juego.runs_jugadas += 1
		verificar(not Juego.registrar_limpieza(datos), "registro inválido rechazado: %s" % [invalido.keys()])
	verificar(Juego.archivo_expediciones.size() == cantidad, "datos inválidos no generan registros")
	var exportado := Juego.datos_archivo_expediciones()
	exportado.expediciones[0].migas = -1
	verificar(Juego.archivo_expediciones[0].migas == 100, "exportar entrega una copia sin alterar la partida")
	var guardado: Dictionary = JSON.parse_string(JSON.stringify(Juego.datos_partida()))
	Juego.reiniciar_estado()
	Juego.restaurar_partida(guardado)
	verificar(Juego.archivo_expediciones.size() == cantidad and Juego.records_limpieza.size() == 5, "archivo y marcas sobreviven a JSON y carga")
	Juego.reiniciar_estado()
	for i in Juego.MAX_ARCHIVO_EXPEDICIONES + 5:
		Juego.runs_jugadas += 1
		Juego.registrar_limpieza(registro(200 - i))
	verificar(Juego.archivo_expediciones.size() == Juego.MAX_ARCHIVO_EXPEDICIONES and Juego.records_limpieza.size() == 1, "el historial tiene un límite fijo y el mejor tiempo se conserva")
	guardado = Juego.datos_partida().duplicate(true)
	guardado.archivo_expediciones.append({"destino": "invalido"})
	guardado.records_limpieza["corrupto"] = {"destino": "casa", "colonia": []}
	Juego.restaurar_partida(guardado)
	verificar(Juego.archivo_expediciones.size() <= Juego.MAX_ARCHIVO_EXPEDICIONES and Juego.records_limpieza.size() == 1, "la carga valida y acota los datos corruptos")

func probar_panel() -> void:
	var panel := PanelArchivo.new()
	add_child(panel)
	await get_tree().process_frame
	verificar(panel._lista.get_child_count() <= PanelArchivo.POR_PAGINA, "el archivo sólo construye una página, no toda la historia")
	panel._modo = 1
	panel._refrescar()
	verificar(panel._lista.get_child_count() == PanelArchivo.POR_PAGINA and not panel._siguiente.disabled, "el historial se pagina sin perder entradas")
	panel._pasar(1)
	verificar(panel._pagina == 1 and not panel._anterior.disabled, "se puede recorrer el archivo")
	panel._destino = "eiffel"
	panel._refrescar()
	verificar(panel.registros_visibles().is_empty() and panel._lista.get_child_count() == 1, "un destino sin marcas muestra estado vacío")
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	var ruta := "res://.godot/qa/archivo_limpieza_prueba.json"
	panel._exportar_a(ruta)
	var exportado = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	verificar(exportado is Dictionary and exportado.get("formato") == "hormigas_expediciones" and exportado.expediciones.size() == Juego.archivo_expediciones.size(), "exporta un JSON legible del archivo, sin incluir toda la partida")
	panel.queue_free()
	await get_tree().process_frame
