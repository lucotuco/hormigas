extends Node
## Captura la ficha real del hormiguero; no agrega un panel de demostración.
## Los fondos de la tienda se preparan como fixture, nunca se guardan.
var tienda: Control
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma(OS.get_environment("IDIOMA") if OS.get_environment("IDIOMA") != "" else "es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Juego.reiniciar_estado()
	Juego.migas = 10000
	Juego.runs_jugadas = 4
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	if not Graficos.listo and DisplayServer.get_name() != "headless":
		await Graficos.preparado
	get_window().size = Vector2i(1920, 1080)
	tienda = preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	await cuadros(4)
	var orden := 0
	for id in ["mas_obreras", "rastro_persistente", "buche", "cargadora", "carpintera", "mordida_madera", "entradas"]:
		tienda._seleccionar_mejora(id)
		# Vista quieta y ficha conservada: no esperar un tween de cámara.
		tienda._corte_tierra.encuadrar(PlanoHormiguero.rect(id).grow(270), false, 1.0)
		tienda._mostrar_ficha(id)
		await cuadros(4)
		await captura("compras_%02d_%s" % [orden, id])
		orden += 1
	tienda._mostrar_ficha("mas_obreras")
	tienda._corte_tierra.encuadrar(PlanoHormiguero.rect("mas_obreras").grow(270), false, 1.0)
	tienda._comprar("mas_obreras")
	await cuadros(4)
	await captura("compras_07_comprada")
	get_window().size = Vector2i(1280, 720)
	tienda._mostrar_ficha("carpintera")
	tienda._corte_tierra.encuadrar(PlanoHormiguero.rect("carpintera").grow(270), false, 1.0)
	await cuadros(4)
	await captura("compras_08_1280")
	tienda.queue_free()
	await cuadros(1)
	print("Revisión compras claras: %d fallas." % fallas)
	get_tree().quit(1 if fallas else 0)


func captura(nombre: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var ruta := "res://.godot/qa/%s.png" % nombre
	var error := get_viewport().get_texture().get_image().save_png(ruta)
	if error != OK:
		fallas += 1
	print(("OK " if error == OK else "FALLA ") + ruta)


func cuadros(cantidad: int) -> void:
	for i in cantidad:
		await get_tree().process_frame
