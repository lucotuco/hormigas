extends Node
## Hormiguero de mejoras en Full HD con eventos reales de mouse: pasar el
## mouse abre la ficha, un clic mejora, arrastrar y la rueda mueven la vista.
## También verifica el plano: una cámara por mejora y casta, túneles que salen
## de requisitos reales y cámaras que no se pisan.
var total := 0
var fallas := 0
var tienda: Control


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Juego.reiniciar_estado()
	for id in Juego.REVELABLES:
		Juego.descubiertos[id] = true
	probar_plano()
	tienda = preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	await cuadros(3)
	verificar(ProjectSettings.get_setting("display/window/size/viewport_width") == 1920 and ProjectSettings.get_setting("display/window/size/viewport_height") == 1080, "la base del juego es 1920 × 1080")
	verificar(not tienda._ficha_mejoras.visible and tienda._mapa_hormiguero.size.x > tienda.size.x * .94, "al entrar el hormiguero ocupa toda la pantalla, sin ficha abierta")
	var arbol: ArbolHormiguero = tienda._corte_tierra
	verificar(arbol.get_global_rect().encloses(Rect2(tienda.posicion_camara("legado") - Vector2.ONE, Vector2.ONE * 2)), "el encuadre inicial muestra a la reina")
	for dimensiones in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		get_window().size = dimensiones
		await cuadros(2)
		for id in ["castas", "viajes", "legado"]:
			var boton: Button = tienda._pestanas[id]
			verificar(tienda._mapa_hormiguero.get_global_rect().encloses(boton.get_global_rect()), "el nombre de la sección está dentro del hormiguero: %s %s en %s" % [id, boton.get_global_rect(), tienda._mapa_hormiguero.get_global_rect()])
			await clic_en(boton.get_global_rect().get_center())
			verificar(tienda._seccion == id, "clic real abre " + id)
			verificar(tienda._mapa_hormiguero.is_visible_in_tree(), "el hormiguero sigue visible detrás de " + id)
			verificar(tienda._cuerpo_mejoras.visible == false and tienda._panel_castas.visible == (id == "castas") and tienda._panel_viajes.visible == (id == "viajes") and tienda._panel_legado.visible == (id == "legado"), "sólo se abre el contenido de " + id)
			await clic_en(tienda._boton_volver.get_global_rect().get_center())
			verificar(tienda._seccion == "hogar" and tienda._cuerpo_mejoras.visible, "volver deja el hormiguero listo")
		await clic_en(tienda.posicion_camara("legado"))
		verificar(tienda._seccion == "legado", "un clic en la cámara de la reina abre la jalea real")
		tienda._cambiar_pestana("hogar")
	get_window().size = Vector2i(1920, 1080)
	await cuadros(2)
	await probar_ficha_y_compra()
	await probar_vista()
	await probar_animacion()
	tienda.queue_free()
	await cuadros(1)
	print("Hormiguero Full HD: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func probar_plano() -> void:
	var faltan: Array[String] = []
	for m in Juego.mejoras:
		if not PlanoHormiguero.CAMARAS.has(m.id):
			faltan.append(m.id)
	for c in Juego.castas:
		if c.comprable and not PlanoHormiguero.CAMARAS.has(c.id):
			faltan.append(c.id)
	verificar(faltan.is_empty(), "cada mejora y casta tiene su cámara en el plano (faltan %s)" % ", ".join(faltan))
	var sobran: Array[String] = []
	for id in PlanoHormiguero.CAMARAS:
		if not id in PlanoHormiguero.SECCIONES and not Juego.mejoras_por_id.has(id) and not Juego.castas_por_id.has(id):
			sobran.append(id)
	verificar(sobran.is_empty(), "el plano no tiene cámaras sin mejora (sobran %s)" % ", ".join(sobran))
	var inventados: Array[String] = []
	for tunel in PlanoHormiguero.TUNELES:
		var hasta: String = tunel[1]
		if hasta in PlanoHormiguero.SECCIONES or tunel[0] in ["boca", "legado"]:
			continue
		var requisitos: Array = Juego.mejoras_por_id[hasta].requisitos if Juego.mejoras_por_id.has(hasta) else Juego.castas_por_id[hasta].requisitos
		var real := false
		for r in requisitos:
			real = real or r.id == tunel[0]
		if not real:
			inventados.append("%s→%s" % [tunel[0], hasta])
	verificar(inventados.is_empty(), "cada túnel sale de un requisito real de la cámara a la que llega (%s)" % ", ".join(inventados))
	for raiz in PlanoHormiguero.RAICES:
		var requisitos: Array = Juego.mejoras_por_id[raiz].requisitos if Juego.mejoras_por_id.has(raiz) else Juego.castas_por_id[raiz].requisitos
		verificar(requisitos.is_empty(), "%s sale de la cámara de la reina y no pide nada antes" % raiz)
	var pisadas: Array[String] = []
	var ids := PlanoHormiguero.CAMARAS.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if PlanoHormiguero.rect(ids[i]).grow(4).intersects(PlanoHormiguero.rect(ids[j]).grow(4)):
				pisadas.append("%s/%s" % [ids[i], ids[j]])
	verificar(pisadas.is_empty(), "ninguna cámara se pisa con otra (%s)" % ", ".join(pisadas))


func probar_ficha_y_compra() -> void:
	Juego.migas = 1000
	Juego.cantidad_compra = 1
	tienda._refrescar()
	await mover_a(tienda.posicion_camara("mas_obreras"))
	verificar(tienda._ficha_mejoras.visible and tienda._ficha_id == "mas_obreras" and tienda._lbl_sala.text == "Más obreras", "pasar el mouse abre la ficha de la cámara")
	verificar(tienda._area_nido.get_global_rect().encloses(tienda._ficha_mejoras.get_global_rect()), "la ficha entra en el área del hormiguero")
	var camara: Rect2 = tienda._corte_tierra.rect_en_pantalla("mas_obreras")
	camara.position += tienda._corte_tierra.global_position
	verificar(not tienda._ficha_mejoras.get_global_rect().intersects(camara), "la ficha no tapa la cámara que describe")
	verificar(Juego.nivel_de("mas_obreras") == 0 and Juego.migas == 1000, "mirar no compra")
	var lleno: float = tienda._estados.mas_obreras.lleno
	await clic_en(tienda.posicion_camara("mas_obreras"))
	verificar(Juego.nivel_de("mas_obreras") == 1 and Juego.migas < 1000, "un clic mejora la cámara")
	verificar(tienda._estados.mas_obreras.lleno > lleno and tienda._ficha_id == "mas_obreras" and "Comprado ×1" in tienda._lbl_estado.text and "→" in tienda._lbl_estado.text, "la cámara se llena y la ficha muestra la compra y su cambio")
	var cavado_antes: float = tienda._corte_tierra.cavado[_tunel("mas_obreras", "cria_acelerada")]
	await clic_en(tienda.posicion_camara("mas_obreras"))
	verificar(tienda._corte_tierra.cavado[_tunel("mas_obreras", "cria_acelerada")] > cavado_antes, "el túnel hacia la cámara siguiente se va cavando")
	var saldo := Juego.migas
	tienda._corte_tierra.enfocar("mordida_madera", false)
	await cuadros(1)
	await mover_a(tienda.posicion_camara("mordida_madera"))
	await clic_en(tienda.posicion_camara("mordida_madera"))
	verificar(Juego.nivel_de("mordida_madera") == 0 and Juego.migas == saldo, "una cámara cerrada no se compra")
	verificar("Requiere" in tienda._lbl_cambio.text, "la ficha de una cámara cerrada dice qué le falta")
	await mover_a(tienda._corte_tierra.get_global_rect().position + Vector2(6, 400))
	verificar(not tienda._ficha_mejoras.visible, "al salir de las cámaras la ficha se cierra")
	Juego.reclutadas = {}
	tienda._corte_tierra.enfocar("veloz", false)
	await cuadros(1)
	await clic_en(tienda.posicion_camara("veloz"))
	verificar(Juego.cantidad_casta("veloz") == 1, "un clic en una casta la recluta")
	await clic_en(tienda.posicion_camara("veloz"), MOUSE_BUTTON_RIGHT)
	verificar(tienda._seccion == "castas" and tienda._panel_castas.seleccion == "veloz", "clic derecho en una casta abre su ficha completa")
	tienda._cambiar_pestana("hogar")


func probar_vista() -> void:
	var arbol: ArbolHormiguero = tienda._corte_tierra
	var nivel := Juego.nivel_de("mas_obreras")
	var desde: Vector2 = tienda.posicion_camara("mas_obreras")
	var antes := arbol.mundo.position
	await arrastrar(desde, desde + Vector2(-140, -90))
	verificar(arbol.mundo.position != antes and Juego.nivel_de("mas_obreras") == nivel, "arrastrar mueve el hormiguero sin comprar")
	var zoom := arbol.zoom
	await rueda(arbol.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN)
	verificar(arbol.zoom < zoom, "la rueda aleja la vista")
	for i in 30:
		await rueda(arbol.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN)
	verificar(is_equal_approx(arbol.zoom, arbol.zoom_minimo()) and arbol.get_global_rect().grow(2).encloses(Rect2(arbol.get_global_transform() * arbol.mundo.position, PlanoHormiguero.TAMANO * arbol.zoom)), "alejando del todo entra el hormiguero entero")
	tienda._seleccionar_mejora("antenas")
	await cuadros(30)
	var centro := arbol.get_global_rect().get_center()
	verificar(arbol.get_global_rect().grow(-40).has_point(tienda.posicion_camara("antenas")) and absf(tienda.posicion_camara("antenas").y - centro.y) < 30 and tienda._ficha_id == "antenas" and arbol.zoom >= 0.85, "ver mejora acerca la cámara a la vista y deja la ficha abierta")
	tienda._seleccionar_mejora("corazon")
	await cuadros(30)
	verificar(arbol.get_global_rect().has_point(tienda.posicion_camara("corazon")) and tienda._ficha_mejoras.visible, "una cámara del borde queda a la vista aunque no pueda centrarse")


func probar_animacion() -> void:
	var animacion: ArbolHormiguero.TransitoNido = tienda._animacion_hormiguero
	verificar(animacion.rutas.size() == PlanoHormiguero.TUNELES.size() and animacion.get_child_count() == 0, "las hormigas comparten los túneles en una sola capa, sin nodos por hormiga")
	verificar(not animacion.indices_rutas.is_empty() and animacion.indices_rutas.size() < PlanoHormiguero.TUNELES.size(), "sólo caminan por los túneles ya cavados")
	verificar(not tienda._corte_tierra.is_processing(), "el hormiguero no tiene proceso por cuadro")
	var ruta: Curve2D = animacion.rutas[0]
	verificar(animacion.posicion(ruta, 0, 0).distance_to(animacion.posicion(ruta, 0, 1)) > 15, "las siluetas avanzan por sus recorridos")
	animacion.set_process(false)
	animacion.acumulado = 0
	var antes: int = animacion.actualizaciones
	for i in 60:
		animacion._process(1.0 / 60)
	verificar(animacion.actualizaciones - antes in [29, 30], "la animación limita sus redibujos a 30 Hz")
	tienda._mapa_hormiguero.hide()
	var reloj: float = animacion.reloj
	animacion._process(1.0)
	verificar(animacion.reloj == reloj, "no se anima un hormiguero oculto")
	tienda._mapa_hormiguero.show()
	tienda._cambiar_pestana("viajes")
	tienda._refrescar()
	await cuadros(1)
	verificar(animacion.rutas[0] == ruta, "cambiar de sección no reconstruye las rutas")


func _tunel(desde: String, hasta: String) -> int:
	for i in PlanoHormiguero.TUNELES.size():
		if PlanoHormiguero.TUNELES[i][0] == desde and PlanoHormiguero.TUNELES[i][1] == hasta:
			return i
	return -1


func cuadros(cantidad: int) -> void:
	for i in cantidad:
		await get_tree().process_frame


func _pantalla(punto_global: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * punto_global


func mover_a(punto_global: Vector2) -> void:
	var punto := _pantalla(punto_global)
	var movimiento := InputEventMouseMotion.new()
	movimiento.position = punto
	movimiento.global_position = punto
	Input.parse_input_event(movimiento)
	await cuadros(2)


func clic_en(punto_global: Vector2, boton := MOUSE_BUTTON_LEFT) -> void:
	await mover_a(punto_global)
	var punto := _pantalla(punto_global)
	for presionado in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.position = punto
		evento.global_position = punto
		evento.button_index = boton
		evento.pressed = presionado
		Input.parse_input_event(evento)
		await cuadros(1)


func arrastrar(desde: Vector2, hasta: Vector2) -> void:
	await mover_a(desde)
	var evento := InputEventMouseButton.new()
	evento.position = _pantalla(desde)
	evento.global_position = evento.position
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = true
	Input.parse_input_event(evento)
	await cuadros(1)
	for i in range(1, 7):
		var p := _pantalla(desde.lerp(hasta, i / 6.0))
		var movimiento := InputEventMouseMotion.new()
		movimiento.position = p
		movimiento.global_position = p
		movimiento.relative = _pantalla(desde.lerp(hasta, i / 6.0)) - _pantalla(desde.lerp(hasta, (i - 1) / 6.0))
		movimiento.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(movimiento)
		await cuadros(1)
	var suelta := InputEventMouseButton.new()
	suelta.position = _pantalla(hasta)
	suelta.global_position = suelta.position
	suelta.button_index = MOUSE_BUTTON_LEFT
	suelta.pressed = false
	Input.parse_input_event(suelta)
	await cuadros(1)


func rueda(punto_global: Vector2, boton: MouseButton) -> void:
	var evento := InputEventMouseButton.new()
	evento.position = _pantalla(punto_global)
	evento.global_position = evento.position
	evento.button_index = boton
	evento.pressed = true
	Input.parse_input_event(evento)
	await cuadros(1)


func verificar(valor: bool, mensaje: String) -> void:
	total += 1
	if not valor:
		fallas += 1
	print(("OK: " if valor else "FALLA: ") + mensaje)
