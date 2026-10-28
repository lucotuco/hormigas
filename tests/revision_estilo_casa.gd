extends Node
## Encuadres reales para revisar paleta, apoyo y lectura del atlas de la casa.
var fallas := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	get_window().size = Vector2i(1920, 1080)
	if not Graficos.listo:
		await Graficos.preparado
	Juego.reiniciar_estado()
	Juego.lugar_actual = "casa"
	Juego.runs_jugadas = 15
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	seed(617)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.hud.hide()
	run.eventos.hide()
	run.niebla.hide()
	# Único readback para QA: comprobar el arte horneado, nunca durante el juego.
	var atlas := Graficos.textura.get_image()
	var piezas_revisadas := 0
	for parte in run.comidas.partes:
		if parte.pieza.tipo not in ["silla", "planta", "inodoro"] or parte.pieza.get("practica", false):
			continue
		var coincide := true
		for i in 16:
			var desde := parte.position + Vector2.from_angle(TAU * i / 16) * parte.rect_mundo.size.length()
			var contacto := parte.punto_mordida(desde, 12000)
			coincide = coincide and contacto != Vector2.INF and opaco_cerca(parte, parte.material_cercano(contacto), atlas)
		piezas_revisadas += 1
		if not coincide:
			fallas += 1
		print("OK " if coincide else "FALLA ", "contactos sobre arte opaco: ", parte.pieza.clave)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	run.camara.ver_casa()
	await captura("estilo_casa_general")
	for zona in [{"id": "cocina", "centro": Vector2(400, 180), "zoom": 0.62}, {"id": "comedor", "centro": Vector2(2960, 300), "zoom": 0.78}, {"id": "living", "centro": Vector2(5510, 590), "zoom": 0.60}, {"id": "dormitorio", "centro": Vector2(350, 3230), "zoom": 0.60}, {"id": "bano", "centro": Vector2(5600, 3540), "zoom": 0.64}]:
		run.camara.position = zona.centro
		run.camara.zoom = Vector2.ONE * float(zona.zoom)
		run.camara.force_update_scroll()
		await captura("estilo_casa_" + String(zona.id))
	print("ATLAS ", Graficos.textura.get_width(), "x", Graficos.textura.get_height(), " regiones=", Graficos.regiones.size())
	var bytes := 0
	for nombre in Sonido.SONIDOS:
		var stream := AudioSuave.crear(nombre)
		bytes += stream.data.size()
	print("AUDIO sintetizado bytes=", bytes, " pool=", Sonido.TAMANO_POOL)
	run.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	print("Estilo cenital: %d verificaciones; %d fallas." % [piezas_revisadas, fallas])
	get_tree().quit(0 if fallas == 0 else 1)

func opaco_cerca(parte: PiezaCasa, punto: Vector2, atlas: Image) -> bool:
	var id := Graficos.clave_mueble(parte.pieza.dibujo)
	var clave: String = Graficos._mueble_claves[id]
	var region: Rect2 = Graficos.regiones[clave]
	var original: Rect2 = Graficos.tamanos[clave]
	var escala: Vector2 = parte.rect_mundo.size / Graficos._mueble_medidas[id]
	var local := (punto - parte.rect_mundo.position) / escala
	var pixel := Vector2i(region.position + (local - original.position) / original.size * region.size)
	var tolerancia := Vector2i((Vector2.ONE * 12 / escala / original.size * region.size).ceil())
	for y in range(pixel.y - tolerancia.y, pixel.y + tolerancia.y + 1):
		for x in range(pixel.x - tolerancia.x, pixel.x + tolerancia.x + 1):
			if Rect2i(region).has_point(Vector2i(x, y)) and atlas.get_pixel(x, y).a > 0.65:
				return true
	return false

func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + ".png")
	print("CAPTURA ", nombre)
