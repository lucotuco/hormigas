extends Node
## Historia visual sin progreso paralelo: sólo objetos/proyectos terminados,
## hitos y premios existentes. No altera la economía ni agrega actores.
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Juego.reiniciar_estado()
	probar_catalogo()
	await probar_historia_y_camaras()
	Juego.reiniciar_estado()
	print("Huellas del hormiguero: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func probar_catalogo() -> void:
	var vacio := HuellasNido.capturar()
	verificar(vacio.descubrimientos.is_empty() and vacio.conjuntos.is_empty() and HuellasNido.regiones(vacio).is_empty(), "una colonia nueva no muestra recuerdos inventados ni veinte casilleros por completar")
	verificar(HuellasNido.CONJUNTOS.size() == 5 and ProyectosCampana.del_destino("casa").is_empty(), "los recuerdos amplían los cinco destinos sin convertir Casa en un checklist")
	var todos: Array[String] = []
	var ids := HuellasNido.CONJUNTOS.keys()
	for destino: String in ids:
		var proyectos := ProyectosCampana.del_destino(destino)
		verificar(proyectos.size() == 4, "se conserva el recuerdo de los cuatro proyectos sin miniaturas decorativas en " + destino)
		var individuales := true
		for i in proyectos.size():
			var uno: Array[String] = [str(proyectos[i].id)]
			var estado := HuellasNido.desde_progreso({}, {}, uno)
			individuales = individuales and estado.conjuntos.size() == 1 and estado.conjuntos[destino] == [i]
			todos.append(proyectos[i].id)
		verificar(individuales, "cualquier proyecto puede dejar su recuerdo sin exigir los anteriores en " + destino)
		var r: Rect2 = HuellasNido.CONJUNTOS[destino].rect
		var libre := Rect2(Vector2.ZERO, PlanoHormiguero.TAMANO).encloses(r)
		for camara in PlanoHormiguero.CAMARAS:
			libre = libre and not r.intersects(PlanoHormiguero.rect(camara).grow(4))
		for otro: String in ids:
			if otro != destino:
				libre = libre and not r.intersects(HuellasNido.CONJUNTOS[otro].rect)
		verificar(libre, "el conjunto no tapa cámaras comprables ni otro recuerdo en " + destino)
	var completo := HuellasNido.desde_progreso({"primera_silla": true, "primer_tesoro": true, "primer_derrumbe": true}, {"casa": true}, todos)
	verificar(completo.conjuntos.size() == 5 and completo.descubrimientos.size() == 4 and todos.size() == 20, "veinte proyectos y cuatro descubrimientos producen sólo cinco conjuntos y cuatro cambios del nido")
	var falsos := HuellasNido.desde_progreso({"primera_silla": false, "inventado": true}, {"casa": false}, ["inventado"])
	verificar(falsos.descubrimientos.is_empty() and falsos.conjuntos.is_empty(), "IDs ajenos y flags falsos nunca inventan recuerdos")
	verificar(HuellasNido.desde_progreso({}, {}, [], 0.0).descubrimientos.is_empty() and HuellasNido.desde_progreso({}, {}, [], 0.1).descubrimientos == ["provisiones"], "cero ingresos no crea provisiones y la primera fracción real sí deja una huella temprana")
	var antes: Dictionary = Juego.datos_partida().duplicate(true)
	HuellasNido.capturar()
	verificar(Juego.datos_partida() == antes, "consultar las huellas no compra, paga, guarda ni agrega progreso")


func probar_historia_y_camaras() -> void:
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	await get_tree().process_frame
	await get_tree().process_frame
	var arbol: ArbolHormiguero = tienda._corte_tierra
	var rutas := arbol.transito.rutas.duplicate()
	var nodos := arbol.mundo.get_child_count()
	Juego.migas = 90
	tienda._on_migas_cambiaron(Juego.migas)
	verificar(arbol.huellas.descubrimientos.is_empty(), "tener saldo sin ingresos históricos no inventa unas primeras provisiones")
	Juego.iniciar_run()
	Juego.sumar_migas_run(2.5)
	Juego.terminar_run()
	verificar(Juego.estadistica("migas_totales") == 2.5 and arbol.huellas.descubrimientos == ["provisiones"], "el primer retorno con ingresos reales reviste la despensa usando sólo la estadística existente")
	var primero: Dictionary = ProyectosCampana.del_destino("restaurante")[0]
	Juego.registrar_objetivo_proyecto(primero.objetivos[0].id)
	verificar(tienda._huellas.conjuntos.is_empty(), "terminar un objeto de un proyecto pendiente no construye su recuerdo completo")
	for objetivo in primero.objetivos:
		Juego.registrar_objetivo_proyecto(objetivo.id)
	verificar(tienda._huellas.conjuntos.get("restaurante", []) == [0] and arbol.huellas == tienda._huellas, "el proyecto terminado actualiza su sala por señal, sin esperar otro cuadro ni escanear el mapa")
	for hito in ["primera_silla", "primer_tesoro", "primer_derrumbe"]:
		Juego.obtener_hito(hito)
	Juego.runs_jugadas = 4 # Las castas ya se revelaron por la condición normal.
	Juego.completar_destino() # Casa: el acceso real ya está ganado.
	verificar(arbol.huellas.descubrimientos == ["provisiones", "madera", "despensa", "soportes", "salida"], "los cuatro premios reales se suman a las primeras provisiones sin inventar otro premio")
	var huellas: Dictionary = tienda._huellas
	tienda._on_migas_cambiaron(Juego.migas)
	verificar(is_same(huellas, tienda._huellas), "cambiar las migas no vuelve a calcular el historial del hormiguero")
	tienda._mostrar_ficha("carpintera")
	verificar("Se conserva al fundar" in tienda._lbl_estado.text and tr(Juego.HITOS.primera_silla.premio) in tienda._lbl_estado.text, "la ficha existente distingue el premio permanente del precio y nivel de esta colonia")
	tienda._mostrar_ficha("entradas")
	verificar("acceso secundario" in tienda._lbl_estado.text, "el segundo acceso visible conserva la descripción real de la adaptación de Casa")
	tienda._mostrar_ficha("viajes")
	verificar(tienda._lbl_estado.text == tr("Los recuerdos del recorrido se conservan al fundar."), "Viajes explica los recuerdos sin abrir otra pantalla ni imponer tareas")
	tienda._cerrar_ficha()
	Juego.niveles.mas_obreras = 3
	Juego.reclutadas.carpintera = 1
	tienda._refrescar()
	var llenado: float = tienda._estados.mas_obreras.lleno
	var historia_antes: Dictionary = arbol.huellas.duplicate(true)
	verificar(Juego.fundar_colonia(), "el cierre usa la fundación real con las coronas de Casa")
	verificar(arbol.huellas == historia_antes and Juego.lugar_actual == "casa", "fundar conserva exactamente los recuerdos y vuelve a Casa")
	verificar(Juego.estadistica("migas_totales") == 2.5 and "provisiones" in arbol.huellas.descubrimientos, "fundar conserva la estadística fuente de las primeras provisiones, sin flag nuevo ni recompensa repetida")
	verificar(llenado > 0 and tienda._estados.mas_obreras.lleno == 0 and tienda._estados.carpintera.nivel == 0, "los recuerdos no conservan por error el llenado ni las reclutas reiniciadas")
	var encuadre: Rect2 = tienda.zona_explorada()
	var visibles := true
	for r in HuellasNido.regiones(arbol.huellas):
		visibles = visibles and encuadre.encloses(r)
	verificar(visibles, "el encuadre de la nueva colonia incluye sus recuerdos históricos")
	verificar(arbol.mundo.get_child_count() == nodos and arbol.capa_huellas.get_child_count() == 0 and not arbol.capa_huellas.is_processing(), "todas las huellas comparten una capa retenida, sin nodos por objeto ni proceso por cuadro")
	verificar(arbol.transito.rutas == rutas, "los descubrimientos no agregan hormigas ni reconstruyen rutas de tránsito")
	Juego.borrar_partida() # Guardado deshabilitado: sólo estado/señales, sin borrar el archivo real.
	verificar(arbol.huellas.descubrimientos.is_empty() and arbol.huellas.conjuntos.is_empty(), "borrar la partida también retira todas las huellas sin dejar caché vieja")
	tienda.queue_free()
	await get_tree().process_frame


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)
