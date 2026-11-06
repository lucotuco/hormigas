extends Node
## Impacto central, regreso al HUD, coalescido y cierre del lienzo real.
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	var partida := huella(Juego.RUTA_PARTIDA)
	var ajustes := huella(Ajustes.RUTA)
	var temblor := Ajustes.temblor
	Ajustes.temblor = 1.0
	probar_etapas()
	probar_lienzo()
	await probar_integracion()
	Ajustes.temblor = temblor
	verificar(huella(Juego.RUTA_PARTIDA) == partida and huella(Ajustes.RUTA) == ajustes,
		"las pruebas no escriben partida ni configuración personal")
	print("Combo visual: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func probar_etapas() -> void:
	for caso in [[-10, 0], [0, 0], [2, 0], [3, 1], [9, 1], [10, 2], [24, 2], [25, 3], [49, 3], [50, 4], [99, 4], [100, 5], [249, 5], [250, 6], [1000000, 6]]:
		verificar(ComboVisual.etapa_de(caso[0]) == caso[1], "combo %d: escalón %d" % [caso[0], caso[1]])


func probar_lienzo() -> void:
	var visual := ComboVisual.new()
	visual.position = Vector2(16, 126)
	add_child(visual)
	var nodos := visual.get_child_count()
	var tweens := get_tree().get_processed_tweens().size()
	var saldo := Juego.migas_run
	var impactos: Array[float] = []
	visual.impacto.connect(func(intensidad: float) -> void: impactos.append(intensidad))
	seed(7194)
	var azar := randf()
	seed(7194)
	verificar(not visual.visible and not visual.is_processing() and nodos == 1
		and visual._chispas.size() == ComboVisual.MAX_CHISPAS,
		"en reposo: un lienzo, una etiqueta y treinta y dos partículas preasignadas")
	var anterior := 0
	var altura_anterior := 0.0
	var paletas: Dictionary = {}
	for umbral: int in ComboVisual.UMBRALES:
		visual.actualizar(umbral)
		verificar(visual.visible and visual.etiqueta.visible and visual._etapa > anterior
			and visual.fase_cinematica() == "impacto" and visual.etiqueta.text == tr("COMBO x%d") % umbral,
			"cada umbral dispara el impacto central con el número real: %d" % umbral)
		visual.avanzar(0.15)
		var limites := visual.limites_etiqueta()
		var pantalla := get_viewport().get_visible_rect()
		verificar(limites.size.x >= pantalla.size.x * 0.3
			and limites.get_center().distance_to(pantalla.get_center()) < 45.0
			and pantalla.grow(2).encloses(limites) and not visual.clip_contents,
			"el combo %d aparece enorme, centrado y sin el recorte de la banda pequeña" % umbral)
		visual.avanzar(ComboVisual.DURACION_IMPACTO - 0.15 + 0.1)
		verificar(visual.fase_cinematica() == "regreso" and visual.progreso_cinematica() > 0.0,
			"el combo %d inicia el vuelo de regreso al HUD" % umbral)
		visual.avanzar(ComboVisual.DURACION_CINEMATICA - ComboVisual.DURACION_IMPACTO - 0.1 + 0.01)
		limites = visual.limites_etiqueta()
		verificar(visual.fase_cinematica() == "inactiva"
			and visual.get_global_rect().grow(3).encloses(limites)
			and limites.size.y >= altura_anterior,
			"el combo %d vuelve al HUD con tamaño progresivo y sin quedar en el centro" % umbral)
		altura_anterior = limites.size.y
		paletas[visual.etiqueta.label_settings.font_color] = true
		anterior = visual._etapa
	verificar(paletas.size() == 6 and impactos.size() == 6 and impactos[5] >= impactos[0],
		"seis escalones: seis colores y seis impulsos de pantalla, de intensidad creciente")
	verificar(visual.etiqueta.label_settings.font_size == ComboVisual.TAMANO_FUENTE
		and visual.etiqueta.label_settings.outline_size > 0
		and visual.etiqueta.label_settings.shadow_size > 0
		and visual.etiqueta.label_settings.shadow_color.a > 0.0,
		"sin placa, el contraste sigue en la fuente nítida, el contorno y el brillo de la letra")
	var celebraciones := visual.celebraciones
	visual.actualizar(250)
	verificar(visual.celebraciones == celebraciones, "reaplicar el mismo valor no repite un hito")
	var fuente := visual.etiqueta.label_settings.font_size
	for combo in range(251, 1251):
		visual.actualizar(combo)
		visual.avanzar(0.001)
	verificar(visual.get_child_count() == nodos and visual._chispas.size() == ComboVisual.MAX_CHISPAS
		and get_tree().get_processed_tweens().size() == tweens and visual.celebraciones == celebraciones
		and visual.etiqueta.label_settings.font_size == fuente,
		"mil entregas no crean nodos, tweens, partículas, fuentes ni celebraciones repetidas")
	verificar(randf() == azar and Juego.migas_run == saldo, "los destellos no cobran migas ni consumen azar de la IA")
	visual.actualizar(2)
	verificar(not visual.visible and not visual.etiqueta.visible and visual._etapa == 0,
		"una nueva racha de una o dos entregas limpia la etapa alta anterior")
	visual.actualizar(3)
	var antes_salto := visual.celebraciones
	visual.avanzar(0.1)
	var progreso_antes := visual.progreso_cinematica()
	visual.actualizar(250)
	verificar(visual._etapa == 6 and visual.celebraciones == antes_salto
		and visual.progreso_cinematica() >= progreso_antes,
		"saltar de tres a doscientos cincuenta actualiza la misma animación sin pila ni reinicio")
	var inicio_tanda := visual.progreso_cinematica()
	for combo in range(251, 1251):
		visual.actualizar(combo)
		visual.avanzar(0.0005)
	verificar(visual.progreso_cinematica() > inicio_tanda and visual.celebraciones == antes_salto
		and visual.fase_cinematica() == "regreso",
		"mil depósitos durante el impacto no reinician ni traban el regreso")
	visual.avanzar(ComboVisual.DURACION_CINEMATICA)
	visual.actualizar(1000000)
	visual.avanzar(0.075)
	verificar(visual.fase_cinematica() == "inactiva"
		and visual.get_global_rect().grow(3).encloses(visual.limites_etiqueta()),
		"el número extremo se ajusta al espacio reservado sin tapar otros paneles")
	Ajustes.temblor = 0.0
	visual.actualizar(3)
	visual.avanzar(0.05)
	var quietas := true
	for chispa: ComboVisual.Chispa in visual._chispas:
		quietas = quietas and chispa.vida == 0.0
	var centro_hud := visual.get_global_transform() * ComboVisual.CENTRO
	verificar(quietas and visual.limites_etiqueta().get_center().distance_to(centro_hud) < 0.01
		and visual.etiqueta.rotation == 0 and visual.etiqueta.scale == Vector2.ONE * visual._escala_hud
		and visual.visible and visual.fase_cinematica() == "inactiva",
		"temblor cero omite centro, regreso, sacudida y partículas, pero conserva el color en el HUD")
	Ajustes.temblor = 1.0
	visual.avanzar(2.0)
	verificar(not visual.visible and not visual.etiqueta.visible and visual._etapa == 0,
		"la racha desaparece al vencer su ventana, sin sostenerla con una animación")
	visual.actualizar(250)
	verificar(visual.visible and visual.celebraciones > celebraciones, "una nueva racha puede celebrar otra vez")
	visual.avanzar(ComboVisual.DURACION_IMPACTO + 0.1)
	verificar(visual.fase_cinematica() == "regreso", "el cierre se prueba durante el vuelo de regreso")
	visual.limpiar()
	visual.actualizar(1000000)
	visual.avanzar(0.1)
	verificar(not visual.visible and not visual.etiqueta.visible and visual._etapa == 0
		and visual._cerrado and visual.fase_cinematica() == "inactiva",
		"limpiar cancela el regreso y es terminal aunque llegue un callback tardío")
	visual.queue_free()


func probar_integracion() -> void:
	Juego.reiniciar_estado()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	var visual := run.hud._combo_visual
	var presentaciones := visual.presentaciones
	var saldo := Juego.migas_run
	for i in 1000:
		run.depositar(0.125)
	verificar(run.combo == 1000 and is_equal_approx(Juego.migas_run - saldo, 125.0)
		and visual.presentaciones == presentaciones and run.hud._combo_sucio,
		"mil descargas reales conservan el ingreso y sólo ensucian una presentación")
	run.hud._process(0.0)
	verificar(visual.presentaciones == presentaciones + 1 and visual.celebraciones == 1
		and visual._etapa == 6 and run.hud._lbl_combo == visual.etiqueta
		and visual.etiqueta.text == tr("COMBO x%d") % 1000 and visual.fase_cinematica() == "impacto",
		"el cuadro presenta sólo el último número y un impacto central, con Label compatible")
	probar_camara(run)
	run.hud._combo_visual.avanzar(0.05)
	# Dejar avanzar sólo el HUD real: si toda la run siguiera deshabilitada,
	# la comprobación de pausa pasaría incluso con un reloj mal configurado.
	run.hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	var progreso_sin_pausa := visual.progreso_cinematica()
	for i in 3:
		await get_tree().process_frame
	verificar(visual.progreso_cinematica() > progreso_sin_pausa,
		"el reloj del HUD real avanza antes de probar la pausa")
	var edad := visual._edad
	var pose := visual.etiqueta.position
	var progreso := visual.progreso_cinematica()
	get_tree().paused = true
	for i in 3:
		await get_tree().process_frame
	verificar(visual._edad == edad and visual.etiqueta.position == pose and visual.progreso_cinematica() == progreso,
		"la pausa congela texto, posición y progreso del impacto central")
	get_tree().paused = false
	run.hud.process_mode = Node.PROCESS_MODE_INHERIT
	run.camara.sacudir(18.0)
	run.camara.avanzar_sacudida(1.0 / 60.0)
	run.hud.limpiar_recompensas()
	run.terminada = true
	run.hud.mostrar_combo(250)
	run.hud._process(0.0)
	verificar(not visual.visible and not run.hud._combo_sucio and visual._cerrado
		and run.camara._sacudida == 0.0 and run.camara.offset == Vector2.ZERO,
		"finalizar descarta callbacks y no revive el combo detrás del resultado")
	run.queue_free()
	await get_tree().process_frame


func probar_camara(run: Run) -> void:
	var camara := run.camara
	var posicion := camara.position
	var acercamiento := camara.zoom
	var objetivo := camara._zoom_objetivo
	var manual := camara._manual
	var limites := camara._limites_visuales
	camara._manual = true
	camara.zoom = Vector2.ONE * Camara.ZOOM_MAXIMO
	camara._zoom_objetivo = Camara.ZOOM_MAXIMO
	seed(18234)
	var esperado := randf()
	seed(18234)
	var limitado := true
	var acotado := true
	var recibio_impulso := false
	for esquina: Vector2 in [limites.position, limites.end, Vector2(limites.position.x, limites.end.y), Vector2(limites.end.x, limites.position.y)]:
		camara.position = esquina
		camara._limitar_posicion()
		camara._sacudida = 0.0
		run.hud._impacto_combo(10000.0)
		recibio_impulso = recibio_impulso or camara._sacudida > 0.0
		acotado = acotado and camara._sacudida <= 24.0
		for i in 12:
			camara._process(1.0 / 60.0)
			var mitad := camara._pantalla / (2.0 * camara.zoom.x)
			var visible := Rect2(camara.position + camara.offset - mitad, mitad * 2.0)
			limitado = limitado and limites.grow(0.1).encloses(visible)
			acotado = acotado and maxf(absf(camara.offset.x), absf(camara.offset.y)) * camara.zoom.x <= 24.1
	verificar(recibio_impulso and acotado, "el hito central sacude la cámara con un techo de veinticuatro píxeles")
	verificar(limitado, "sacudir en las cuatro esquinas no muestra fuera del escenario")
	verificar(randf() == esperado, "el temblor de cámara no consume el azar de hormigas ni amenazas")
	camara._sacudida = 0.0
	run.hud._impacto_combo(18.0)
	run.feromonas.activa = true
	camara.avanzar_sacudida(1.0 / 60.0)
	verificar(camara._sacudida <= 3.0 and maxf(absf(camara.offset.x), absf(camara.offset.y)) * camara.zoom.x <= 3.01,
		"mantener feromonas después del golpe también limita la perturbación de la orden")
	run.feromonas.activa = false
	camara._sacudida = 0.0
	run.hud._impacto_combo(18.0)
	camara.arrastrando = true
	camara.avanzar_sacudida(1.0 / 60.0)
	verificar(camara._sacudida <= 3.0, "arrastrar durante el golpe reduce el temblor ya iniciado")
	camara.arrastrando = false
	camara._sacudida = 0.0
	camara.offset = Vector2.ZERO
	run.activa = false
	run.retirando = true
	run.hud._impacto_combo(18.0)
	verificar(camara._sacudida == 0.0, "una última entrega durante la retirada no inicia un nuevo impulso")
	run.retirando = false
	run.terminada = true
	run.hud._impacto_combo(18.0)
	verificar(camara._sacudida == 0.0, "el callback de impacto posterior al cierre tampoco sacude")
	run.terminada = false
	run.activa = true
	Ajustes.temblor = 0.0
	run.hud._impacto_combo(18.0)
	camara._process(1.0 / 60.0)
	verificar(camara._sacudida == 0.0 and camara.offset == Vector2.ZERO,
		"temblor cero también desactiva por completo la sacudida del mundo")
	Ajustes.temblor = 1.0
	camara.position = posicion
	camara.zoom = acercamiento
	camara._zoom_objetivo = objetivo
	camara._manual = manual
	camara._fase_sacudida = 0.0
	camara.offset = Vector2.ZERO
	camara.force_update_scroll()


func huella(ruta: String) -> String:
	return FileAccess.get_sha256(ruta) if FileAccess.file_exists(ruta) else "ausente"


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)
