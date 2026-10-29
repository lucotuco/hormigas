extends Node
## Primeros minutos: mecánicas que aparecen de a una, la próxima meta siempre
## visible, extracción sólo por hormigas y unidades legibles en pantalla.
##   godot --headless --fixed-fps 60 --path . res://tests/prueba_progresion.tscn
var fallas := 0
var total := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")  # las verificaciones leen textos en español
	Sonido.silenciado = true
	probar_revelado()
	probar_partida_vieja()
	probar_proxima_meta()
	await probar_hud()
	await probar_tienda()
	await probar_llamado_sin_dano()
	await probar_escala()
	Juego.reiniciar_estado()
	print("Progresión de los primeros minutos: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func probar_revelado() -> void:
	Juego.reiniciar_estado()
	var ocultas := true
	for id in Juego.REVELABLES:
		ocultas = ocultas and not Juego.revelado(id)
	verificar(ocultas, "en la primera run no aparece ninguna mecánica extra")
	Juego.runs_jugadas = 2
	verificar(Juego.revelado("frenesi") and Juego.revelado("compra_lote") and not Juego.revelado("castas"), "frenesí y compra por lote aparecen en la segunda run")
	verificar(Juego.es_nuevo("frenesi"), "una mecánica recién revelada se marca como nueva")
	Juego.marcar_visto("frenesi")
	verificar(not Juego.es_nuevo("frenesi") and Juego.revelado("frenesi"), "marcarla como vista no la oculta")
	Juego.runs_jugadas = 4
	verificar(Juego.revelado("castas") and Juego.revelado("gran_objetivo"), "castas y gran objetivo aparecen después")
	verificar(not Juego.revelado("prioridades"), "las prioridades esperan a que se pueda comer algo más que comida")
	Juego.niveles = {"mordida_madera": 1}
	Juego._cache_stats.clear()
	verificar(Juego.revelado("prioridades"), "las prioridades aparecen con la dieta de madera")
	var guardado: Dictionary = JSON.parse_string(JSON.stringify(Juego.datos_partida()))
	Juego.reiniciar_estado()
	Juego.restaurar_partida(guardado)
	verificar(Juego.revelado("prioridades") and not Juego.es_nuevo("frenesi") and Juego.es_nuevo("castas"), "lo revelado y lo visto sobreviven al guardado")
	Juego.niveles.clear()
	Juego._cache_stats.clear()
	verificar(Juego.revelado("prioridades"), "lo revelado no se vuelve a ocultar (por ejemplo, al fundar una colonia)")


func probar_partida_vieja() -> void:
	Juego.reiniciar_estado()
	Juego.restaurar_partida({"runs_jugadas": 10, "niveles": {"mandibulas": 4}})
	verificar(Juego.revelado("castas") and not Juego.es_nuevo("castas") and not Juego.revelado("viajes"), "una partida anterior muestra lo que le corresponde, sin marcarlo como nuevo")


func probar_proxima_meta() -> void:
	Juego.reiniciar_estado()
	var meta := Juego.proxima_meta()
	verificar(meta.tipo == "nivel" and meta.objetivo == 4.0 and meta.actual == 0.0, "la primera meta es subir Mandíbulas fuertes a nivel 4")
	Juego.niveles = {"mandibulas": 4}
	Juego._cache_stats.clear()
	meta = Juego.proxima_meta()
	verificar(meta.tipo == "nivel" and meta.id == "mordida_rapida" and Juego.esta_desbloqueada("mordida_rapida"), "en el hormiguero la madera está pasando la Mordida rápida, que ya se puede comprar")
	Juego.niveles = {"mandibulas": 4, "mordida_rapida": 1}
	Juego.migas = 300
	Juego._cache_stats.clear()
	meta = Juego.proxima_meta()
	verificar(meta.tipo == "migas" and meta.objetivo == Juego.costo("mordida_madera") and meta.actual == 300.0, "después pide las migas para la dieta de madera")
	Juego.migas_run = 50
	verificar(Juego.proxima_meta().actual == 350.0, "las migas de la run en curso cuentan para la meta")
	Juego.migas_run = 0
	Juego.niveles = {"mandibulas": 10, "mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	verificar(Juego.proxima_meta().tipo == "objetivo", "con todas las dietas, la meta es el gran objetivo")
	Juego.lugares_completados["casa"] = true
	Juego.coronas_cobradas["casa"] = true
	meta = Juego.proxima_meta()
	verificar(meta.tipo == "viaje" and "restaurante" in meta.nombre.to_lower(), "con la casa conquistada, la meta es viajar")


func probar_hud() -> void:
	Juego.reiniciar_estado()
	var run := crear_run()
	await get_tree().process_frame
	var hud := run.hud
	verificar(hud._panel_meta.visible and "banquito" in hud._lbl_meta_nombre.text, "el HUD invita a desarmar el banquito desde la primera run")
	verificar(not hud._panel_inferior.visible, "la primera run no muestra prioridades, frenesí ni gran objetivo")
	run.queue_free()
	await get_tree().process_frame
	Juego.runs_jugadas = 4
	Juego.niveles = {"mandibulas": 4, "mordida_rapida": 1}
	Juego.hitos.primer_derrumbe = true
	Juego.migas = Juego.costo("mordida_madera") + 100
	Juego._cache_stats.clear()
	run = crear_run()
	await get_tree().process_frame
	hud = run.hud
	hud._actualizar_meta()
	verificar(hud._panel_inferior.visible and hud._boton_objetivo.visible and hud._columna_frenesi.visible and not hud._nodos_prioridad[0].visible, "a partir de la cuarta run aparecen frenesí y gran objetivo, sin prioridades")
	verificar(hud._meta_lista and "alcanza" in hud._lbl_meta_progreso.text, "avisa cuando ya alcanzan las migas para la meta")
	run.queue_free()
	await get_tree().process_frame


func probar_tienda() -> void:
	Juego.reiniciar_estado()
	var tienda: Control = preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	await get_tree().process_frame
	verificar(not tienda._pestanas.castas.visible and not tienda._pestanas.viajes.visible and not tienda._cantidades[10].visible, "la tienda inicial sólo muestra mejoras de a una")
	tienda.queue_free()
	await get_tree().process_frame
	Juego.runs_jugadas = 4
	tienda = preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	await get_tree().process_frame
	verificar(tienda._pestanas.castas.visible and "Nuevo" in tienda._pestanas.castas.text and tienda._cantidades[10].visible, "las castas aparecen marcadas como nuevas")
	tienda._cambiar_pestana("castas")
	tienda._refrescar()
	verificar(not "Nuevo" in tienda._pestanas.castas.text, "abrir la pestaña quita la marca de nuevo")
	verificar(tienda._estados.has("pisada"), "el hormiguero conserva la mejora migrada Mandíbulas cooperativas")
	tienda.queue_free()
	await get_tree().process_frame


func probar_llamado_sin_dano() -> void:
	Juego.reiniciar_estado()
	var run := crear_run()
	await get_tree().process_frame
	var miga: Comida = null
	for c in run.comidas.lista:
		if c.id == "miga" and c.position.length() < 400:
			miga = c
			break
	verificar(miga != null, "hay migas cerca del hormiguero para dar la orden")
	var vida := miga.vida
	run.feromonas.mantener_en(miga.position)
	verificar(miga.vida == vida and Juego.migas_run == 0, "llamar sin hormigas no extrae alimento ni da migas")
	run.pisar(miga.position)
	verificar(miga.vida == vida, "el clic manual no extrae alimento")
	Juego.migas = 1000
	Juego.niveles = {"mandibulas": 1, "buche": 1}
	Juego._cache_stats.clear()
	var antes := Juego.stat("dano")
	Juego.comprar("pisada")
	verificar(Juego.stat("dano") == antes + 0.5, "Mandíbulas cooperativas suma daño a las hormigas")
	run.queue_free()
	await get_tree().process_frame


func probar_escala() -> void:
	Juego.reiniciar_estado()
	var run := crear_run()
	run.process_mode = Node.PROCESS_MODE_INHERIT
	await get_tree().create_timer(1.0).timeout
	var zoom := run.camara.zoom.x
	var escala := run.colonia.hormigas[0].scale.x / run.colonia.hormigas[0].escala_casta
	verificar(run.colonia.cantidad() >= 8, "la colonia arranca con al menos 8 obreras")
	verificar(is_equal_approx(escala, clampf(Colonia.ESCALA_EN_PANTALLA / zoom, 1.0, 5.0)) and escala * zoom >= 1.4, "con la cámara alejada las hormigas se ven más grandes")
	run.queue_free()
	await get_tree().process_frame


func crear_run() -> Run:
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	return run


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)
