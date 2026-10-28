extends Node
## Comprueba el árbol dibujado, sus pestañas y dos tamaños sin tocar el guardado.
var fallas := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	if not Graficos.listo and DisplayServer.get_name() != "headless":
		await Graficos.preparado
	get_window().size = Vector2i(1920, 1080)
	var inicial := preload("res://ui/tienda.tscn").instantiate()
	add_child(inicial)
	await get_tree().process_frame
	await get_tree().process_frame
	await captura("nido_inicial")
	inicial.queue_free()
	await get_tree().process_frame
	Juego.migas = 3.1e8
	Juego.runs_jugadas = 40
	for id in Juego.REVELABLES:
		Juego.descubiertos[id] = true
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	for dimensiones in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		get_window().size = dimensiones
		await get_tree().process_frame
		await get_tree().process_frame
		for rama in tienda.SALAS:
			tienda._salas[rama].boton.pressed.emit()
			comprobar(tienda._rama == rama, "Selecciona " + rama)
			var boton: Button = tienda._salas[rama].boton
			comprobar(boton.get_parent().get_global_rect().encloses(boton.get_global_rect()), "Cámara dentro del corte: " + rama)
		tienda._cambiar_pestana("hogar")
		await captura("nido_%d" % dimensiones.x)
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame
	await get_tree().process_frame
	for id in tienda.NOMBRES_PESTANAS:
		tienda._pestanas[id].pressed.emit()
		comprobar(tienda._cuerpo_mejoras.visible == (id == "hogar"), "Pestaña " + id)
		comprobar(tienda._mapa_hormiguero.is_visible_in_tree(), "Hormiguero persistente en " + id)
		await captura("nido_seccion_" + id)
	comprobar(tienda._animacion_hormiguero.rutas.size() == Juego.mejoras.size() + 10, "Cada mejora tiene un recorrido compartido por un máximo de 22 hormigas")
	tienda._cambiar_pestana("hogar")
	tienda._seleccionar_mejora("mordida_madera")
	await captura("nido_ficha")
	tienda._cambiar_pestana("hogar")
	Juego.niveles = {"mas_obreras": 10, "mandibulas": 12, "pisada": 8, "buche": 4, "patas_largas": 5, "rastro_persistente": 5, "antenas": 4, "reservas": 5, "excavar": 8, "cria_acelerada": 3, "recoleccion_eficiente": 5, "mordida_madera": 1, "mordida_resistente": 1}
	Juego.lugares_completados = {"casa": true, "restaurante": true}
	Juego.coronas_cobradas = {"casa": true, "restaurante": true}
	Juego.coronas = 3
	Juego._cache_stats.clear()
	tienda._refrescar()
	await captura("nido_desarrollado")
	var animacion = tienda._animacion_hormiguero
	var ruta: Curve2D = animacion.rutas[0]
	comprobar(animacion.posicion(ruta, 0, 0).distance_to(animacion.posicion(ruta, 0, 1)) > 15, "Las hormigas avanzan por los túneles")
	comprobar(ProjectSettings.get_setting("display/window/size/viewport_width") == 1920, "Resolución base Full HD")
	print("REVISIÓN NIDO: %d fallas" % fallas)
	get_tree().quit(1 if fallas else 0)

func comprobar(valor: bool, descripcion: String) -> void:
	if not valor:
		fallas += 1
	print(("OK: " if valor else "FALLA: ") + descripcion)

func captura(nombre: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + ".png")
