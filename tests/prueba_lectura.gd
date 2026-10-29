extends Node
## Próximo paso optativo, compras concretas y resumen acotado, sin guardar.
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
	Ajustes.pausar_sin_foco = false
	await probar_tienda()
	await probar_resumen()
	Juego.reiniciar_estado()
	print("Lectura del progreso: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)

func probar_tienda() -> void:
	Juego.reiniciar_estado()
	for id in Juego.REVELABLES:
		Juego.descubiertos[id] = true
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	await get_tree().process_frame
	await get_tree().process_frame
	verificar(not tienda._ficha_mejoras.visible and tienda._seccion == "hogar", "entrar no abre ni compra la recomendación")
	verificar("SIGUIENTE PASO" in tienda._lbl_paso.text, "la tienda muestra una meta concreta además de estadísticas")
	verificar(tienda._boton_paso.visible and tienda._siguiente_paso.get("accion", "") == "mejora", "el requisito real tiene una acción disponible desde el comienzo")
	tienda._siguiente_paso = {"accion": "mejora", "id": "mordida_madera"}
	var antes := Juego.datos_partida().duplicate(true)
	tienda._ver_siguiente_paso()
	verificar(tienda._mejora_seleccionada == "mordida_madera" and tienda._ficha_mejoras.visible, "ver mejora abre la cámara exacta")
	verificar(Juego.datos_partida() == antes, "acercar una cámara no compra ni modifica la partida")
	verificar("otro material" in tienda._lbl_estado.text, "la ficha describe cómo cambia el trabajo de la colonia")
	Juego.migas = 1.0e7
	Juego.cantidad_compra = 1
	tienda._seleccionar_mejora("mas_obreras")
	var obreras := int(Juego.stat("hormigas_iniciales"))
	tienda._comprar("mas_obreras")
	verificar(("%d obreras → %d obreras" % [obreras, int(Juego.stat("hormigas_iniciales"))]) in tienda._lbl_estado.text, "la compra muestra el cambio real antes y después")
	Juego.cantidad_compra = 10
	var nivel := Juego.nivel_de("mas_obreras")
	tienda._comprar("mas_obreras")
	verificar(Juego.nivel_de("mas_obreras") == nivel + 10 and "+10 niveles" in tienda._lbl_estado.text, "el feedback respeta la cantidad realmente comprada")
	for stat in ["hormigas_iniciales", "velocidad", "capacidad", "dano", "materiales", "entradas", "radio_territorio", "olfato", "feromona_cantidad", "duracion_run", "multiplicador_migas", "pisotones_auto"]:
		verificar(not tienda._efecto_practico(stat).is_empty(), "explicación de conducta disponible para " + stat)
	verificar("automáticos/s" in tienda._valor_stat("pisotones_auto", 0.5), "los pisotones por segundo no se presentan como daño por mordida")
	tienda._siguiente_paso = {"accion": "legado", "id": ""}
	tienda._ver_siguiente_paso()
	verificar(tienda._seccion == "legado" and tienda._panel_legado.visible, "ver fundación abre sus opciones sin fundar ni cambiar destino")
	tienda._siguiente_paso = {"accion": "casta", "id": "carpintera"}
	tienda._ver_siguiente_paso()
	verificar(tienda._seccion == "castas" and tienda._panel_castas.visible, "ver una casta abre el panel correspondiente")
	Juego.niveles = {"mandibulas": 4, "mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego.coronas_cobradas = {"casa": true}
	Juego.lugares_completados = {"casa": true}
	Juego.coronas = 1
	Juego._cache_stats.clear()
	tienda._refrescar()
	verificar(tienda._boton_paso.text == "Ver fundación" and tienda._siguiente_paso.get("accion", "") == "legado", "conquistar la casa deja a la vista la primera fundación opcional")
	verificar(Juego.fundaciones == 0 and Juego.lugar_actual == "casa", "mostrar la fundación no la ejecuta ni fuerza un viaje")
	tienda.queue_free()
	await get_tree().process_frame

func probar_resumen() -> void:
	Juego.reiniciar_estado()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.produccion_run = 12.5
	run.mejora_produccion = 25
	run.tenia_record = true
	run.tiempo_jugado = 40
	run.cargas_pendientes = 25
	Juego.migas_run = 75
	Juego.migas = 75
	run.hud.mostrar_fin()
	await get_tree().process_frame
	await get_tree().process_frame
	verificar("migas/s" in run.hud._lbl_fin_resumen.text and "+25%" in run.hud._lbl_fin_resumen.text, "rendimiento y comparación se leen sin desplazar detalles")
	verificar("TRANSPORTE" in run.hud._lbl_fin_siguiente.text and "10%" in run.hud._lbl_fin_consejo.text, "una proporción importante sin entregar propone transporte con evidencia")
	verificar(not run.hud._scroll_fin.is_ancestor_of(run.hud._boton_tienda), "la acción de seguir no queda escondida dentro del scroll")
	verificar(run.hud._scroll_fin.custom_minimum_size.y <= 210 and run.hud._lbl_fin_detalle.get_parent() == run.hud._scroll_fin, "el detalle crece dentro de un área acotada")
	run.cargas_pendientes = 1
	Juego.migas_run = 99
	run.hud._actualizar_consejo_fin()
	verificar(not "TRANSPORTE" in run.hud._lbl_fin_siguiente.text, "una carga residual no se presenta como cuello de botella dominante")
	run.limpieza_lograda = true
	run.limpieza_completa = true
	run.limpieza_registrada = true
	run.nuevo_record_limpieza = true
	run.tiempo_limpieza = 18.25
	run.hud.mostrar_fin()
	await get_tree().process_frame
	verificar(run.hud._lbl_fin_titulo.text == "¡Mapa despejado!" and "Limpieza:" in run.hud._lbl_fin_detalle.text, "el detalle conserva las marcas y el tipo de cierre")
	verificar(run.hud._lbl_fin_record.visible and "LIMPIEZA" in run.hud._lbl_fin_record.text and not run.hud._scroll_fin.is_ancestor_of(run.hud._lbl_fin_record), "la mejor marca de limpieza está a la vista antes del scroll")
	var area := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	verificar(area.encloses(run.hud._panel_fin.get_global_rect()), "el resumen y las acciones caben dentro de la pantalla")
	run.queue_free()
	await get_tree().process_frame
