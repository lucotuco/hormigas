extends Node
## Imágenes del MISMO juego: no usa otra textura, escalas físicas de QA ni
## un dibujo alternativo. Sólo congela la simulación para revisar contornos.
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	get_window().size = Vector2i(1920, 1080)
	if not Graficos.listo:
		await Graficos.preparado
	await get_tree().process_frame
	var presupuesto: Dictionary = Graficos.presupuesto_atlas
	var dimensiones := Vector2i(Graficos.textura.get_width(), Graficos.textura.get_height())
	var bytes := dimensiones.x * dimensiones.y * 4
	verificar(dimensiones == presupuesto.actual and bytes == presupuesto.bytes_actual,
		"las medidas del plan compacto coinciden con la textura GPU publicada")
	verificar(presupuesto.regiones_mejoradas == 10
		and bytes <= Graficos.MAX_BYTES_ATLAS,
		"todo el atlas permanece dentro de los 49,5 MiB anteriores, con escalas fijas")
	var atlas_vivos := 0
	for hijo in Graficos.get_children():
		if hijo is SubViewport:
			atlas_vivos += 1
	verificar(atlas_vivos == 1, "queda un solo atlas compartido, no una copia por destino o zoom")
	print("DEFINICION atlas_base=", presupuesto.base, " bytes_base=", presupuesto.bytes_base,
		" atlas_actual=", dimensiones, " bytes_actual=", bytes,
		" incremento_MiB=", (bytes - int(presupuesto.bytes_base)) / 1048576.0,
		" preflight_ms=", int(presupuesto.tiempo_usec) / 1000.0)
	Juego.reiniciar_estado()
	Juego.lugar_actual = "casa"
	Juego.runs_jugadas = 15
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	seed(617)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.hud.hide()
	run.niebla.hide()
	run.eventos.hide()
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	var vistas := {}
	for pieza: PiezaCasa in run.comidas.partes:
		var id := ""
		if pieza.pieza.get("practica", false):
			id = "carton"
		elif pieza.pieza.get("perfil", "") == "silla_inicial":
			id = "silla"
		elif pieza.pieza.tipo == "mesada" and pieza.rect_mundo.position.y < -500:
			id = "mesada"
		elif pieza.pieza.tipo in ["mesa", "planta", "inodoro", "sofa"]:
			id = pieza.pieza.tipo
		if id == "" or vistas.has(id):
			continue
		vistas[id] = true
		run.camara.position = pieza.position
		run.camara.zoom = Vector2.ONE * (1.3 if id in ["mesada", "mesa"] else (0.9 if id == "sofa" else 3.2))
		run.camara.force_update_scroll()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var ruta := "res://.godot/qa/definicion_casa_" + id + ".png"
		verificar(get_viewport().get_texture().get_image().save_png(ruta) == OK,
			"captura de contorno nativo " + id)
		if id == "silla":
			await probar_silla_cercana(run, pieza)
		elif id == "mesa":
			run.camara.position = pieza.rect_mundo.end - Vector2(60, 60)
			run.camara.zoom = Vector2.ONE * Camara.ZOOM_MAXIMO
			run.camara.force_update_scroll()
			await capturar("mesa_borde_zoom_maximo")
	verificar(vistas.size() == 7, "se revisan siete familias de objetos y sus detalles cercanos")
	run.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	print("Definición Casa: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func probar_silla_cercana(run: Run, silla: PiezaCasa) -> void:
	run.camara.zoom = Vector2.ONE * Camara.ZOOM_MAXIMO
	run.camara.force_update_scroll()
	await capturar("silla_zoom_maximo")
	# Mismo cuerpo, máscara, boca y carga que el juego; no pintar un hueco
	# de QA encima ni agrandar la hormiga para disimular el tamaño del bocado.
	silla._preparar_mordiscos()
	var derecha := silla.position + Vector2(silla.rect_mundo.size.x, 0)
	var boca := silla.punto_contacto(derecha) + Vector2(10.5, 0)
	var h := run.colonia._nacer("obrera", boca)
	h._dano = 1.0e6
	h._capacidad = 20
	h._porciones_ciclo = 1
	h.estado = Hormiga.Estado.MORDIENDO
	h.comida = silla
	h.rotation = PI
	h._reloj_mordida = 0
	var area := silla.mordiscos.area_total()
	h._morder(1.0 / 60.0)
	silla._process(0.13)
	h._reloj_vida += 0.3
	h._actualizar_sprite()
	verificar(h.carga > 0 and h._retazos.size() == 1 and h._tamanos_retazos.size() == 1
		and h._tamanos_retazos[0].is_equal_approx(silla.tamano_bocado())
		and area > silla.mordiscos.area_total(),
		"un bocado retira material real y la hormiga lleva exactamente su tamaño")
	await capturar("silla_un_bocado")
	h.hide()
	var mordidas := 0
	for i in 24:
		boca = silla.punto_contacto(derecha) + Vector2(10.5, 0)
		mordidas += int(silla.morder_local(1.0e6, boca, 6.0) > 0)
	silla._process(0.13)
	verificar(mordidas == 24 and not silla.muerta, "24 mordidas pequeñas abren el borde sin borrar el mueble")
	await capturar("silla_24_bocados")


func capturar(nombre: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	verificar(get_viewport().get_texture().get_image().save_png("res://.godot/qa/definicion_casa_" + nombre + ".png") == OK,
		"captura real " + nombre)


func verificar(condicion: bool, mensaje: String) -> void:
	total += 1
	if not condicion:
		fallas += 1
	print("OK " if condicion else "FALLA ", mensaje)
