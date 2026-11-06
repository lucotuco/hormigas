extends Node
## Impacto central → regreso → HUD real, en cada escalón y tamaño de ventana.
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	Ajustes.temblor = 1.0
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	if not Graficos.listo:
		await Graficos.preparado
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.colonia._process(0.5) # La obrera inicial real, sin agrandar ni duplicar la colonia.
	run.hud._process(0.0)
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	for umbral: int in ComboVisual.UMBRALES:
		run.hud.mostrar_combo(umbral)
		run.hud._process(0.15)
		await captura("combo_%03d_impacto" % umbral)
		verificar_impacto(run.hud, "combo %d" % umbral)
		run.hud._process(ComboVisual.DURACION_IMPACTO - 0.15 + 0.2)
		await captura("combo_%03d_regreso" % umbral)
		verificar(run.hud._combo_visual.fase_cinematica() == "regreso",
			"el combo %d vuela del centro hacia el HUD" % umbral)
		run.hud._process(ComboVisual.DURACION_CINEMATICA - ComboVisual.DURACION_IMPACTO - 0.2 + 0.01)
		await captura("combo_%03d" % umbral)
		verificar(run.hud._combo_visual._etapa == ComboVisual.etapa_de(umbral)
			and run.hud._combo_visual.fase_cinematica() == "inactiva", "escalón devuelto al HUD: %d" % umbral)
		verificar_limites(run.hud, "combo %d al regresar" % umbral)
	run.hud.mostrar_combo(1)
	run.hud._process(0.0) # Nueva racha: el batch siguiente debe generar un solo impacto.
	var presentaciones := run.hud._combo_visual.presentaciones
	for i in 1000:
		run.depositar(0.125)
	run.hud._process(0.15)
	await captura("combo_mil_entregas")
	verificar(run.combo == 1000 and is_equal_approx(Juego.migas_run, 125.0)
		and run.hud._combo_visual.presentaciones == presentaciones + 1,
		"mil descargas: un número visual y el ingreso exacto")
	verificar_impacto(run.hud, "mil descargas")
	run.hud._process(ComboVisual.DURACION_CINEMATICA - 0.15 + 0.01)
	await captura("combo_mil_hud")
	verificar_limites(run.hud, "mil descargas al regresar")
	get_window().size = Vector2i(1000, 620)
	for i in 5:
		await get_tree().process_frame
	run.hud.mostrar_combo(1)
	run.hud._process(0.0)
	run.hud.mostrar_combo(250)
	run.hud._process(0.15)
	await captura("combo_centro_1000")
	verificar_impacto(run.hud, "ventana 1000")
	run.hud._process(ComboVisual.DURACION_IMPACTO - 0.15 + 0.2)
	await captura("combo_regreso_1000")
	run.hud._process(ComboVisual.DURACION_CINEMATICA - ComboVisual.DURACION_IMPACTO - 0.2 + 0.01)
	await captura("combo_mil_1000")
	verificar_limites(run.hud, "ventana 1000 al regresar")
	Ajustes.temblor = 0.0
	run.hud.mostrar_combo(3)
	run.hud._process(0.05)
	await captura("combo_sin_movimiento")
	var centro_hud := run.hud._combo_visual.get_global_transform() * ComboVisual.CENTRO
	verificar(run.hud._combo_visual.limites_etiqueta().get_center().distance_to(centro_hud) < 0.01
		and run.hud._combo_visual.etiqueta.rotation == 0.0
		and run.hud._combo_visual.etiqueta.scale == Vector2.ONE * run.hud._combo_visual._escala_hud,
		"temblor cero conserva la lectura sin desplazamiento")
	verificar(run.hud._combo_visual.fase_cinematica() == "inactiva",
		"temblor cero omite la animación central")
	verificar_limites(run.hud, "sin movimiento")
	run.hud.limpiar_recompensas()
	await captura("combo_cierre")
	verificar(not run.hud._combo_visual.visible and not run.hud._lbl_combo.visible,
		"el cierre no deja el combo central encima del resultado")
	run.queue_free()
	await get_tree().process_frame
	await probar_sin_fondos()
	await capturar_camaras()
	print("Revisión combo visual: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func probar_sin_fondos() -> void:
	# Aislar el mismo lienzo en un viewport con alpha real. Ocultar sólo la
	# letra permite comprobar los píxeles debajo, sin confundir contorno negro
	# legítimo con una placa negra o el viejo oscurecimiento de pantalla.
	var visor := SubViewport.new()
	visor.size = Vector2i(640, 360)
	visor.disable_3d = true
	visor.transparent_bg = true
	visor.world_2d = World2D.new()
	visor.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(visor)
	var visual := ComboVisual.new()
	visual.position = Vector2(16, 16)
	visor.add_child(visual)
	var temblor := Ajustes.temblor
	Ajustes.temblor = 0.0
	visual.actualizar(250)
	visual.etiqueta.hide()
	var imagen := await imagen_lienzo(visor)
	var centro_hud := Vector2i(visual.position + ComboVisual.CENTRO)
	verificar(imagen.get_pixelv(centro_hud).a < 0.001,
		"HUD sin letra: el centro de la antigua placa es totalmente transparente")
	verificar(esquinas_transparentes(imagen), "el combo normal tampoco pinta un fondo de pantalla")
	Ajustes.temblor = 1.0
	visual.actualizar(1)
	visual.actualizar(250)
	visual.avanzar(0.15)
	visual.etiqueta.hide()
	imagen = await imagen_lienzo(visor)
	verificar(visual.fase_cinematica() == "impacto" and esquinas_transparentes(imagen),
		"el impacto central conserva las esquinas transparentes: no oscurece el juego")
	verificar(imagen.get_pixel(320, 180).a < 0.001,
		"debajo de la letra central no hay rectángulo ni relleno negro")
	visual.avanzar(ComboVisual.DURACION_IMPACTO - 0.15 + 0.2)
	imagen = await imagen_lienzo(visor)
	verificar(visual.fase_cinematica() == "regreso" and esquinas_transparentes(imagen),
		"el regreso tampoco deja una cortina oscura detrás del texto")
	visual.avanzar(ComboVisual.DURACION_CINEMATICA - ComboVisual.DURACION_IMPACTO - 0.2 + 0.01)
	imagen = await imagen_lienzo(visor)
	verificar(imagen.get_pixelv(centro_hud).a < 0.001,
		"al aterrizar el combo sigue sin placa rectangular")
	Ajustes.temblor = temblor
	visor.queue_free()
	await get_tree().process_frame


func imagen_lienzo(visor: SubViewport) -> Image:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return visor.get_texture().get_image()


func esquinas_transparentes(imagen: Image) -> bool:
	for punto: Vector2i in [Vector2i(4, 4), Vector2i(635, 4), Vector2i(4, 355), Vector2i(635, 355)]:
		if imagen.get_pixelv(punto).a >= 0.001:
			return false
	return true


func capturar_camaras() -> void:
	# Fixture visual explícita de las tres cámaras compradas, no un piloto.
	get_window().size = Vector2i(1920, 1080)
	Juego.niveles = {"migas_brillantes": 1, "mandibulas_destello": 1, "pulso_colonia": 1}
	Juego._cache_stats.clear()
	var tienda: Control = preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	tienda._corte_tierra.encuadrar(Rect2(460, 720, 1080, 650), false, 1.0)
	await captura("combo_camaras_compradas")
	for id: String in ["migas_brillantes", "mandibulas_destello", "pulso_colonia"]:
		verificar(tienda._mapa_hormiguero.get_global_rect().has_point(tienda.posicion_camara(id)),
			"la cámara comprada queda visible dentro del hormiguero: " + id)
	tienda.queue_free()
	await get_tree().process_frame
	Juego.reiniciar_estado()


func verificar_limites(hud: HUD, contexto: String) -> void:
	var combo := hud._combo_visual.get_global_rect()
	var libre := not combo.intersects(hud._caja_migas.get_global_rect())
	for nodo: Control in [hud._lbl_tiempo, hud._barra_tiempo, hud._panel_meta, hud._panel_progresion]:
		libre = libre and not combo.intersects(nodo.get_global_rect())
	verificar(get_viewport().get_visible_rect().encloses(combo) and libre
		and combo.grow(3).encloses(hud._combo_visual.limites_etiqueta()),
		contexto + ": la banda del combo no tapa migas, tiempo ni objetivos")


func verificar_impacto(hud: HUD, contexto: String) -> void:
	var visual := hud._combo_visual
	var limites := visual.limites_etiqueta()
	var pantalla := get_viewport().get_visible_rect()
	verificar(visual.fase_cinematica() == "impacto" and limites.size.x >= pantalla.size.x * 0.3
		and limites.get_center().distance_to(pantalla.get_center()) < 45.0
		and pantalla.grow(2).encloses(limites) and not visual.clip_contents,
		contexto + ": impacto enorme, centrado, legible y sin recorte")


func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/%s.png" % nombre)


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)
