extends Node
## Revisión visual de la progresión larga: pestaña Jalea real, confirmación
## de fundar, mejoras de destino y topes que suben. Guarda en .godot/qa/.
##   godot --path . res://tests/revision_jalea.tscn
func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma(OS.get_environment("IDIOMA") if OS.has_environment("IDIOMA") else "es")  # IDIOMA=en para revisar en inglés
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	if not Graficos.listo and DisplayServer.get_name() != "headless":
		await Graficos.preparado
	# Una partida a mitad de camino: casa y restaurante conquistados, una fundación.
	Juego.runs_jugadas = 40
	Juego.lugares_completados = {"casa": true, "restaurante": true}
	Juego.coronas_cobradas = {"casa": true, "restaurante": true}
	Juego.lugar_actual = "museo"
	Juego.coronas = 3
	Juego.fundaciones = 1
	Juego.legado = 28
	Juego.jalea = 14
	Juego.migas_colonia = 4.2e9
	Juego.migas = 3.1e8
	Juego.niveles_jalea = {"obreras_reales": 3, "jalea_dano": 2, "jalea_migas": 1, "herencia_madera": 1, "reloj_real": 1}
	Juego.niveles = {"mas_obreras": 30, "mandibulas": 49, "pisada": 24, "titanio": 2, "bandeja": 3,
		"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1, "buche": 10, "recoleccion_eficiente": 20}
	Juego.hitos = {"primera_silla": true, "primer_derrumbe": true}
	for id in Juego.REVELABLES:
		Juego.descubiertos[id] = true
	Juego._cache_stats.clear()
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	tienda._seleccionar("Mandíbulas")
	await captura("jalea_mejoras_destino")
	tienda._cambiar_pestana("legado")
	await captura("jalea_panel")
	tienda._panel_legado._pedir_fundacion()
	await captura("jalea_confirmar")
	tienda._panel_legado._confirmar.hide()
	get_window().size = Vector2i(1000, 620)
	await captura("jalea_panel_1000")
	get_window().size = Vector2i(1280, 720)
	tienda.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + ".png")
	print(nombre)
