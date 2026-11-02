extends Node
## Capturas de la cámara de la reina en cada etapa (0, 1, 3, 5 y 6 fundaciones)
## con distintos decretos y destinos conquistados. Guarda en .godot/qa/reina_*.png.
##   godot --path . res://tests/revision_reina.tscn
var fallas := 0
const ETAPAS := [[0, "", []], [1, "numerosa", ["casa"]], [3, "guerrera", ["casa", "restaurante", "museo"]],
	[5, "recolectora", ["casa", "restaurante", "museo", "obelisco", "coliseo"]], [6, "exploradora", ["casa", "restaurante", "museo", "obelisco", "coliseo", "eiffel"]]]


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	if not Graficos.listo and DisplayServer.get_name() != "headless":
		await Graficos.preparado
	get_window().size = Vector2i(1920, 1080)
	for etapa in ETAPAS:
		Juego.reiniciar_estado()
		Juego.fundaciones = etapa[0]
		Juego.decreto = etapa[1]
		Juego.legado = 10 * etapa[0]
		Juego.runs_jugadas = 40
		for id in etapa[2]:
			Juego.lugares_completados[id] = true
		Juego._cache_stats.clear()
		var tienda := preload("res://ui/tienda.tscn").instantiate()
		add_child(tienda)
		await esperar(20)
		var arbol: ArbolHormiguero = tienda._corte_tierra
		arbol.encuadrar(PlanoHormiguero.rect("legado").grow(40), false, ArbolHormiguero.ZOOM_MAXIMO)
		await esperar(10)
		comprobar(not tienda.descripcion_reina().is_empty(), "La reina de %d fundaciones tiene descripción" % etapa[0])
		await captura("reina_%d" % etapa[0])
		tienda.queue_free()
		await get_tree().process_frame
	# Volver al hormiguero con una colonia nueva enfoca y celebra a la reina.
	Juego.reiniciar_estado()
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	await esperar(3)
	Juego.fundaciones = 1
	tienda._refrescar()
	await esperar(30)
	comprobar(tienda._aviso_compra.id == "legado", "Fundar enfoca la cámara de la reina y explica qué cambió")
	await captura("reina_al_fundar")
	print("REVISIÓN REINA: %d fallas" % fallas)
	get_tree().quit(1 if fallas else 0)


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
