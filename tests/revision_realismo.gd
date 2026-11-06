extends Node
## QA con render real: textos, señal fuera de cámara y destrucción del nuevo arte.
var fallas := 0
var total := 0

func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("OK " if ok else "FALLA ", detalle)

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	if not Graficos.listo:
		await Graficos.preparado
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	Juego.reiniciar_estado()
	Juego.runs_jugadas = 10
	Juego.niveles = {"excavar": 20, "mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var r: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	r.niebla.hide()
	r.hud._lbl_aviso.text = ""
	var indicador: HUD.IndicadorEventos
	for n in r.hud.get_child(0).get_children():
		if n is HUD.IndicadorEventos:
			indicador = n
	for tipo in ["arana", "dorada", "paloma"]:
		for e in r.eventos.aparecer(tipo):
			e.position = Vector2(3000, 20000)
	r.hud._lbl_aviso.text = ""
	for tam in [Vector2i(1280, 720), Vector2i(1000, 620)]:
		get_window().size = tam
		await get_tree().process_frame
		await get_tree().process_frame
		r.camara.ver_casa()
		r.hud._process(0)
		indicador.queue_redraw()
		r.efectos._textos.clear()
		for i in 40:
			r.efectos.numero(Vector2(1800 + (i % 6) * 500, 1600 + (i / 6) * 100), 10000 + i, Color(1.0, 0.82, 0.3), 2.4)
		r.efectos.queue_redraw()
		await captura("realismo_hud_%d" % tam.x)
		verificar(indicador.etiquetas.size() == 3, "tres tipos de evento, una sola etiqueta por bandada")
		var seguras := true
		for caja in indicador.etiquetas:
			seguras = seguras and caja.position.x >= 0 and caja.end.x <= indicador.size.x and caja.end.y + 12 < r.hud._panel_inferior.position.y
		verificar(seguras, "las etiquetas y flechas no pisan la barra inferior a %d px" % tam.x)
		var rects := r.efectos._rect_textos
		var presupuesto := 8 if r.efectos._zoom() < 0.25 else Efectos.MAX_TEXTOS_VISIBLES
		verificar(not rects.is_empty() and rects.size() <= presupuesto,
			"hay premios visibles dentro del presupuesto de %d textos a zoom%.2f" % [presupuesto, r.efectos._zoom()])
		var separados := true
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				separados = separados and not rects[i].intersects(rects[j])
		verificar(separados, "los premios no se superponen")
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	for direccion in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		for e in r.eventos.activos:
			e.position = Vector2(3000, 1700) + direccion * 20000
		indicador.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var separados := indicador.etiquetas.size() == 3
		for i in indicador.etiquetas.size():
			for j in range(i + 1, indicador.etiquetas.size()):
				separados = separados and not indicador.etiquetas[i].intersects(indicador.etiquetas[j])
		verificar(separados, "las señales no se superponen en el borde %s" % direccion)
	r.hud.hide()
	r.efectos.hide()
	r.eventos.hide()
	r.camara.position = Vector2(3100, 100)
	r.camara.zoom = Vector2.ONE * 0.45
	r.camara.force_update_scroll()
	for p in r.comidas.partes:
		if p.pieza.tipo == "mesa_comedor":
			var vida := p.vida
			await extraer_fragmentos(r, p)
			verificar(p.mordiscos != null and p.vida < vida and p.vivas.size() < p.celdas.size()
				and not p.muerta and not r.cola_erosion.tiene_pendientes(),
				"el mueble ilustrado pierde fragmentos reales preparados, no desaparece entero")
	await captura("realismo_fragmentos")
	r.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()
	print("Realismo render: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func extraer_fragmentos(r: Run, pieza: PiezaCasa) -> void:
	# La Run está detenida para capturar. Servir explícitamente los mismos
	# presupuestos de preparación y erosión; una solicitud aún pendiente no es
	# daño ni autoriza a editar vidas/vivas para que la fotografía parezca rota.
	for i in 512:
		if pieza.preparar_material():
			break
		r.preparador_mordiscos.procesar()
		await get_tree().process_frame
	if pieza.mordiscos == null:
		return
	var desde := pieza.rect_mundo.position - Vector2(8, 8)
	if not r.cola_erosion.encolar(pieza, pieza.vida_max * 0.15, desde):
		return
	for i in 2048:
		if not r.cola_erosion.tiene_pendientes():
			break
		r.preparador_mordiscos.procesar()
		r.cola_erosion.procesar()
		pieza._process(1.0 / 60.0)
		r.cocina.procesar_cambios()
		await get_tree().process_frame
	pieza._process(0.1)


func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + ".png")
