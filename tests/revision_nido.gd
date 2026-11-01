extends Node
## Capturas del hormiguero de mejoras con el renderer real, sin tocar el guardado:
## colonia nueva, colonia avanzada, ficha al pasar el mouse, todo el plano,
## una sección abierta y 1280 × 720. Guarda en .godot/qa/nido_*.png.
##   godot --path . res://tests/revision_nido.tscn
var fallas := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma(OS.get_environment("IDIOMA") if OS.get_environment("IDIOMA") != "" else "es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	if not Graficos.listo and DisplayServer.get_name() != "headless":
		await Graficos.preparado
	get_window().size = Vector2i(1920, 1080)
	var inicial := preload("res://ui/tienda.tscn").instantiate()
	add_child(inicial)
	await esperar(3)
	await captura("nido_inicial")
	Juego.iniciar_run()
	Juego.sumar_migas_run(2.5)
	Juego.terminar_run()
	inicial._corte_tierra.encuadrar(Rect2(550, 980, 520, 270), false, 1.6)
	await esperar(2)
	comprobar(inicial._corte_tierra.huellas.descubrimientos == ["provisiones"], "El primer retorno deja provisiones sin exigir una mejora ni una casta")
	await captura("nido_primeras_provisiones")
	inicial.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	# Una colonia a mitad de camino: casa conquistada, restaurante abierto.
	Juego.migas = 3.1e8
	Juego.runs_jugadas = 40
	for id in Juego.REVELABLES:
		Juego.descubiertos[id] = true
	Juego.niveles = {"mas_obreras": 18, "patas_largas": 9, "cria_acelerada": 5, "mandibulas": 16, "pisada": 9, "pisada_auto": 3,
		"mordida_rapida": 6, "mandibulas_acero": 3, "mordida_madera": 1, "mordida_resistente": 1, "filo_aserrado": 2,
		"buche": 7, "recoleccion_eficiente": 9, "huevos_dorados": 2, "banquete": 3, "larvas_glotonas": 2,
		"rastro_persistente": 6, "antenas": 6, "pisoton": 7, "senales_casta": 2, "alarma": 2, "olfato_explorador": 3,
		"reservas": 8, "vuelta_a_casa": 3, "segundo_aire": 2, "relevos": 2, "frenesi_prolongado": 1,
		"excavar": 14, "entradas": 3, "saqueo": 1, "galerias": 1, "nodrizas": 2, "patas_de_seda": 3, "pisada_equipo": 1}
	Juego.reclutadas = {"veloz": 6, "roja": 4, "cargadora": 5, "voladora": 2, "reina": 1, "carpintera": 3}
	Juego.lugares_completados = {"casa": true}
	Juego.coronas_cobradas = {"casa": true}
	Juego.coronas = 2
	Juego.legado = 3
	Juego._cache_stats.clear()
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	await esperar(3)
	await captura("nido_desarrollado")
	var arbol: ArbolHormiguero = tienda._corte_tierra
	# Ficha de una cámara al pasar el mouse por encima.
	await mover_a(tienda.posicion_camara("antenas"))
	comprobar(tienda._ficha_mejoras.visible and tienda._ficha_id == "antenas", "Pasar el mouse abre la ficha de Antenas sensibles")
	await captura("nido_ficha")
	await mover_a(tienda.posicion_camara("roja"))
	comprobar(tienda._ficha_id == "roja", "Las castas también tienen ficha")
	await captura("nido_ficha_casta")
	await mover_a(tienda.posicion_camara("pisada"))
	await captura("nido_ficha_compartida")
	# Todo el plano.
	arbol.encuadrar(Rect2(Vector2.ZERO, PlanoHormiguero.TAMANO), false, 1.0)
	await esperar(2)
	await captura("nido_completo")
	# Cerca, para ver lo que guarda cada cámara.
	arbol.encuadrar(Rect2(420, 560, 900, 700), false, 1.6)
	await esperar(2)
	await captura("nido_cerca")
	tienda._cambiar_pestana("legado")
	await esperar(2)
	await captura("nido_seccion_legado")
	tienda._cambiar_pestana("hogar")
	get_window().size = Vector2i(1280, 720)
	await esperar(3)
	await captura("nido_1280")
	# Historia visible con niveles actuales, y luego los mismos recuerdos con
	# las cámaras reiniciadas. No se conceden premios desde el dibujo.
	get_window().size = Vector2i(1920, 1080)
	tienda._cerrar_ficha()
	await mover_a(tienda.global_position + Vector2(5, 5))
	for hito in ["primera_silla", "primer_tesoro", "primer_derrumbe"]:
		Juego.obtener_hito(hito)
	Juego.sumar_estadistica("migas_totales", 38)
	tienda._refrescar_historia()
	for proyecto in ProyectosCampana.todos():
		for objetivo in proyecto.objetivos:
			Juego.registrar_objetivo_proyecto(objetivo.id)
	arbol.encuadrar(Rect2(410, 0, 890, 650), false, 1.5)
	await esperar(3)
	comprobar(arbol.huellas.conjuntos.size() == 5 and arbol.huellas.descubrimientos.size() == 5, "Los recuerdos reflejan veinte proyectos, los cuatro descubrimientos y las primeras provisiones de Casa")
	await captura("nido_recuerdos")
	arbol.encuadrar(Rect2(550, 990, 620, 230), false, 1.6)
	await esperar(2)
	await captura("nido_descubrimientos_casa")
	comprobar(Juego.fundar_colonia(), "Fundación real para comprobar los recuerdos permanentes")
	arbol.encuadrar(Rect2(Vector2.ZERO, PlanoHormiguero.TAMANO), false, 1.0)
	await esperar(3)
	comprobar(tienda._estados.mas_obreras.lleno == 0 and arbol.huellas.conjuntos.size() == 5, "Las cámaras se reinician, pero los recuerdos permanecen")
	await captura("nido_recuerdos_tras_fundar")
	comprobar(ProjectSettings.get_setting("display/window/size/viewport_width") == 1920, "Resolución base Full HD")
	print("REVISIÓN NIDO: %d fallas" % fallas)
	get_tree().quit(1 if fallas else 0)


func mover_a(punto_global: Vector2) -> void:
	var punto := get_viewport().get_final_transform() * punto_global
	var movimiento := InputEventMouseMotion.new()
	movimiento.position = punto
	movimiento.global_position = punto
	Input.parse_input_event(movimiento)
	await esperar(2)


func esperar(cuadros: int) -> void:
	for i in cuadros:
		await get_tree().process_frame


func comprobar(valor: bool, descripcion: String) -> void:
	if not valor:
		fallas += 1
	print(("OK: " if valor else "FALLA: ") + descripcion)


func captura(nombre: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + ".png")
