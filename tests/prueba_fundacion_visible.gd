extends Node
## La fundación real vuelve al lienzo y hace visible la evolución de la reina.
## No toca la partida ni simula el éxito cambiando sólo el contador.
const TIENDA := preload("res://ui/tienda.tscn")
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	var existia := FileAccess.file_exists(Juego.RUTA_PARTIDA)
	var huella := hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) if existia else 0
	await probar_fundacion(0, "numerosa")
	await probar_fundacion(6, "guerrera")
	Juego.reiniciar_estado()
	var intacta := FileAccess.file_exists(Juego.RUTA_PARTIDA) == existia
	if existia:
		intacta = intacta and hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) == huella
	verificar(intacta and not Juego.guardado_habilitado, "la regresión de fundación no altera el guardado personal")
	print("Fundación visible: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func probar_fundacion(fundaciones_previas: int, decreto_nuevo: String) -> void:
	Juego.reiniciar_estado()
	Juego.fundaciones = fundaciones_previas
	Juego.legado = fundaciones_previas
	Juego.decreto = "numerosa" if fundaciones_previas > 0 else ""
	Juego.migas = 300
	Juego.migas_colonia = 100000
	Juego.completar_destino() # Estado de campaña controlado: habilita la fundación.
	Juego._cache_stats.clear()
	var tienda := TIENDA.instantiate()
	add_child(tienda)
	await cuadros(3)
	tienda._on_camara_pulsada("legado")
	verificar(tienda._seccion == "legado" and tienda._panel_seccion.visible and tienda._panel_legado.is_visible_in_tree(),
		"%d→%d: el flujo empieza con Jalea real tapando el centro" % [fundaciones_previas, fundaciones_previas + 1])
	var estado_anterior: Dictionary = tienda._estados.legado.duplicate(true)
	tienda._panel_legado._pedir_fundacion()
	var confirmar: VentanaFundar = tienda._panel_legado._confirmar
	verificar(is_instance_valid(confirmar) and confirmar.is_inside_tree(), "la confirmación se abre desde PanelCampana real")
	if not is_instance_valid(confirmar):
		tienda.queue_free()
		await cuadros(1)
		return
	await cuadros(1)
	confirmar.elegir(decreto_nuevo)
	var ganada := Juego.jalea_por_fundar()
	var jalea_previa := Juego.jalea
	confirmar.fundar()
	await cuadros(1)
	verificar(Juego.fundaciones == fundaciones_previas + 1 and Juego.decreto == decreto_nuevo and Juego.jalea == jalea_previa + ganada,
		"confirmar ejecuta una sola fundación, conserva el decreto y acredita exactamente su jalea")
	verificar(not is_instance_valid(confirmar), "la confirmación se cierra después de fundar")
	verificar(tienda._seccion == "hogar" and not tienda._panel_seccion.visible and not tienda._panel_legado.is_visible_in_tree() and tienda._cuerpo_mejoras.is_visible_in_tree(),
		"la nueva colonia muestra el hormiguero, sin el panel de legado ocultando la reina")
	verificar(tienda._ficha_mejoras.visible and tienda._ficha_id == "legado" and tienda._lbl_estado.text == tienda.descripcion_reina(),
		"queda abierta la ficha de la reina con una explicación útil de su nueva etapa")
	verificar(tienda._corte_tierra.seleccion == "legado" and tienda._mejora_seleccionada == "legado" and tienda._aviso_compra.id == "legado",
		"la selección conserva la explicación al sacar el mouse de la cámara")
	# Los Button emiten mouse_entered también cuando la animación pasa bajo
	# un puntero quieto: no es un pedido del jugador de cambiar la ficha.
	tienda._corte_tierra._sobrevolar("viajes")
	tienda._on_camara_sobrevolada("")
	verificar(tienda._ficha_mejoras.visible and tienda._ficha_id == "legado" and tienda._mejora_seleccionada == "legado" and tienda._aviso_compra.id == "legado",
		"el hover generado por el encuadre no borra la ficha ni la explicación de la reina")
	var celebrando := false
	for estallido: Dictionary in tienda._corte_tierra.resalte._estallidos:
		celebrando = celebrando or estallido.id == "legado"
	verificar(celebrando, "la reina inicia su celebración en el lienzo visible")
	var estado_nuevo: Dictionary = tienda._estados.legado
	verificar(estado_nuevo.decreto == decreto_nuevo and estado_anterior.decreto != estado_nuevo.decreto,
		"el estado retenido incluye el decreto con el que se dibuja la reina")
	if fundaciones_previas >= 6:
		verificar(estado_anterior.extra == estado_nuevo.extra and tienda._corte_tierra._sin_comprables({"legado": estado_anterior}) != tienda._corte_tierra._sin_comprables({"legado": estado_nuevo}),
			"después de la sexta fundación, cambiar decreto sigue invalidando el color aunque la etapa esté al máximo")
	await get_tree().create_timer(0.4).timeout
	var centro: Vector2 = tienda._corte_tierra.rect_en_pantalla("legado").get_center()
	verificar(centro.distance_to(tienda._corte_tierra.size * 0.5) < 1.0,
		"la animación termina con la reina centrada en la vista")
	tienda._on_camara_sobrevolada("castas")
	var inmovil := InputEventMouseMotion.new()
	tienda._input(inmovil)
	verificar(tienda._foco_programatico and tienda._ficha_id == "legado" and tienda._aviso_compra.id == "legado",
		"el último acomodo del lienzo y un movimiento nulo no cancelan el foco")
	var movimiento := InputEventMouseMotion.new()
	movimiento.relative = Vector2.ONE
	tienda._input(movimiento)
	await cuadros(1)
	tienda._on_camara_sobrevolada("viajes")
	verificar(not tienda._foco_programatico and tienda._ficha_id == "viajes" and tienda._mejora_seleccionada == "" and tienda._aviso_compra.id == "",
		"mover el mouse de verdad devuelve el hover normal y permite elegir otra cámara")
	tienda._mostrar_reina_nueva()
	tienda._on_camara_pulsada("")
	await get_tree().create_timer(0.5).timeout
	verificar(not tienda._foco_programatico and not tienda._ficha_mejoras.visible and tienda._mejora_seleccionada == "",
		"un clic real que cierra la ficha no es deshecho por el final de la celebración")
	tienda._on_camara_sobrevolada("legado")
	verificar(tienda._ficha_mejoras.visible and tienda._ficha_id == "legado",
		"el hover sigue funcionando después de cancelar la presentación")
	tienda.queue_free()
	await cuadros(1)


func cuadros(cantidad: int) -> void:
	for cuadro in cantidad:
		await get_tree().process_frame


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)
