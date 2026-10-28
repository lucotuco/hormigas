extends Node
## Hormiguero Full HD: clics reales, cuatro secciones persistentes y animación acotada.
var total := 0
var fallas := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	for id in Juego.REVELABLES:
		Juego.descubiertos[id] = true
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	await get_tree().process_frame
	await get_tree().process_frame
	verificar(ProjectSettings.get_setting("display/window/size/viewport_width") == 1920 and ProjectSettings.get_setting("display/window/size/viewport_height") == 1080, "la base del juego es 1920 × 1080")
	verificar(not tienda._ficha_mejoras.visible and tienda._mapa_hormiguero.size.x > tienda.size.x * .94, "al entrar el árbol ocupa toda la pantalla sin un panel lateral permanente")
	for dimensiones in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		get_window().size = dimensiones
		await get_tree().process_frame
		await get_tree().process_frame
		for id in ["castas", "viajes", "legado", "hogar"]:
			var boton: Button = tienda._pestanas[id]
			verificar(tienda._mapa_hormiguero.get_global_rect().encloses(boton.get_global_rect()), "la sección está dentro del hormiguero: " + id)
			await clic(tienda._boton_volver if id == "hogar" else boton)
			verificar(tienda._seccion == id, "clic de ventana selecciona " + id)
			verificar(tienda._mapa_hormiguero.is_visible_in_tree(), "el hormiguero permanece visible en " + id)
			verificar(tienda._cuerpo_mejoras.visible == (id == "hogar") and tienda._panel_castas.visible == (id == "castas") and tienda._panel_viajes.visible == (id == "viajes") and tienda._panel_legado.visible == (id == "legado"), "sólo se abre el contenido seleccionado")
		await clic(tienda._pestanas.castas)
		await clic(tienda._boton_volver)
		await clic(tienda._salas.Colonia.boton)
		verificar(tienda._seccion == "hogar" and tienda._rama == "Colonia", "una rama vuelve a sus mejoras desde otra sección")
		tienda._cerrar_ficha()
		await clic(tienda._nodos_mejoras.mas_obreras.boton)
		verificar(tienda._ficha_mejoras.visible and tienda._mejora_seleccionada == "mas_obreras", "un clic real en una subcámara abre su ficha de mejora")
		verificar(tienda._ficha_mejoras.size.x < tienda._mapa_hormiguero.size.x * .25 and tienda._mapa_hormiguero.get_global_rect().encloses(tienda._ficha_mejoras.get_global_rect()), "la ficha contextual deja visible la mayor parte del hormiguero (%s dentro de %s)" % [tienda._ficha_mejoras.get_global_rect(), tienda._mapa_hormiguero.get_global_rect()])
		tienda._cerrar_ficha()
	var animacion = tienda._animacion_hormiguero
	verificar(animacion.rutas.size() == Juego.mejoras.size() + 10 and animacion.get_child_count() == 0, "las mejoras comparten recorridos en una sola capa sin nodos por hormiga")
	verificar(tienda._nodos_mejoras.size() == Juego.mejoras.size(), "cada mejora de los CSV tiene una subcámara propia")
	var nombres_dentro := true
	for nodo in tienda._nodos_mejoras.values():
		nombres_dentro = nombres_dentro and tienda._mapa_hormiguero.get_global_rect().encloses(nodo.nombre.get_global_rect()) and nodo.nombre.size.x <= 171
	verificar(nombres_dentro, "los nombres de mejoras respetan el ancho y los bordes del nido")
	var requisitos := true
	for m in Juego.mejoras:
		if m.requiere_id == "":
			continue
		for camino in tienda._corte_tierra.caminos:
			if camino.id == m.id:
				requisitos = requisitos and camino.puntos[0].distance_to(tienda._corte_tierra.posicion_mejora(m.requiere_id) * tienda._corte_tierra.size) < 1
	verificar(requisitos, "cada túnel de mejora parte del requisito real y no de un enlace inventado")
	var recursos := Juego.migas
	Juego.migas = 1000
	tienda._refrescar()
	var niveles: int = tienda._corte_tierra.niveles_totales
	tienda._comprar("mas_obreras")
	verificar(tienda._corte_tierra.niveles_totales > niveles and tienda._nodos_mejoras.mas_obreras.icono.nivel > 0, "comprar cambia la excavación y el contenido visible del hormiguero")
	Juego.migas = recursos
	verificar(not tienda._corte_tierra.is_processing(), "el fondo no tiene proceso por cuadro")
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
	await get_tree().process_frame
	verificar(animacion.rutas[0] == ruta, "cambiar de sección no reconstruye las rutas")
	tienda.queue_free()
	await get_tree().process_frame
	print("Hormiguero Full HD: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)

func clic(boton: Button) -> void:
	var punto := get_viewport().get_final_transform() * boton.get_global_rect().get_center()
	var movimiento := InputEventMouseMotion.new()
	movimiento.position = punto
	movimiento.global_position = punto
	Input.parse_input_event(movimiento)
	await get_tree().process_frame
	for presionado in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.position = punto
		evento.global_position = punto
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = presionado
		Input.parse_input_event(evento)
		await get_tree().process_frame

func verificar(valor: bool, mensaje: String) -> void:
	total += 1
	if not valor:
		fallas += 1
	print(("OK: " if valor else "FALLA: ") + mensaje)
