extends Node
## La capacidad reúne porciones contiguas, no retiene una portadora cuando
## perdió el frente. El fixture visual aísla muestras; el de cartón usa
## material/contacto reales y regresa por la cola normal de navegación.
class FuenteMuestra extends Comida:
	var muestra := Rect2(40, 50, 12, 9)
	var origen_muestra := Vector2.ZERO
	var intentos := 0
	func preparar_material() -> bool:
		return true
	func punto_contacto(desde: Vector2) -> Vector2:
		return desde + Vector2.RIGHT
	func morder_local(dano: float, _pos: Vector2, _lado_max := 6.0) -> float:
		if dano <= 0 or muerta:
			return 0.0
		intentos += 1
		vida -= 1.0
		return 0.75
	func region_bocado() -> Rect2:
		return muestra
	func tamano_bocado() -> Vector2:
		return Vector2(4, 3)
	func origen_bocado() -> Vector2:
		return origen_muestra

var total := 0
var fallas := 0


func _init() -> void:
	Juego.guardado_habilitado = false


func _ready() -> void:
	var huellas := huellas_guardados()
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	seed(1194)
	await probar_muestras_y_capacidad()
	await probar_entrega_al_perder_frente()
	verificar(huellas_guardados() == huellas, "la prueba conserva la partida y los ajustes del jugador")
	Juego.reiniciar_estado()
	print("Ciclo de consumo: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func crear_run() -> Run:
	Juego.reiniciar_estado()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true # Fixture geométrico, no perfil de preparación.
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.colonia._activa = false
	run.radio_actual = 12000.0
	return run


func probar_muestras_y_capacidad() -> void:
	var run := crear_run()
	var fuente := FuenteMuestra.new()
	var datos: Dictionary = Juego.comidas[0].duplicate()
	datos.vida = 100.0
	datos.recompensa = 75.0
	fuente.configurar(datos, 1194)
	run.comidas.add_child(fuente)
	fuente.position = Vector2(-400, -300)
	var h := run.colonia._nacer("obrera", fuente.position + Vector2(-10, 0))
	h._capacidad = 12
	h._porciones_ciclo = 1
	h.comida = fuente
	h.estado = Hormiga.Estado.MORDIENDO
	var hijos := h.get_child_count()
	var muestras: Array[Rect2] = []
	var origenes: Array[Vector2] = []
	for i in 4:
		fuente.muestra = Rect2(40 + i * 16, 50, 12, 9)
		fuente.origen_muestra = fuente.position + Vector2(i, -2)
		muestras.append(fuente.muestra)
		origenes.append(fuente.origen_muestra)
		h._reloj_vida = i * 0.5
		h._reloj_mordida = 0.0
		h._morder(0.01)
	verificar(fuente.intentos == 4 and h.bocados == 4 and h.carga == 3.0
		and h.estado == Hormiga.Estado.MORDIENDO and h._capacidad == 12,
		"cuatro porciones contiguas siguen aprovechando el buche de doce, sin limitarlo a tres muestras")
	verificar(h._retazos == [muestras[1], muestras[2], muestras[3]]
		and h._origenes_retazos == [origenes[1], origenes[2], origenes[3]],
		"el cuarto bocado conserva sus coordenadas nuevas entre las tres últimas muestras")
	verificar(h._retazos.size() == 3 and h._angulos_retazos.size() == 3
		and h._tamanos_retazos.size() == 3 and h._origenes_retazos.size() == 3
		and h._tiempos_retazos.size() == 3 and h.get_child_count() == hijos,
		"actualizar una muestra reutiliza los cinco arreglos acotados y no agrega sprites")
	h._detalle_bocado = true
	verificar(h._levantando_retazos and h._tiempos_retazos.back() == h._reloj_vida
		and h._posicion_retazo(2).is_equal_approx(h.to_local(origenes[3])),
		"la última porción comienza su levantado en el origen exacto, también después del tercer bocado")
	var tamanos_reales := true
	h.scale = Vector2(1.4, 0.8)
	for i in h._retazos.size():
		var tamano_mundo: Vector2 = h._escala_retazo(h._retazos[i], i) * h._retazos[i].size * h.global_scale.abs()
		tamanos_reales = tamanos_reales and tamano_mundo.is_equal_approx(Vector2(4, 3))
	verificar(tamanos_reales and h._carga_origen[0] == 3.0 and Juego.migas_run == 0.0,
		"renovar las muestras no agranda el material ni pierde su valor u origen económico")
	for i in 8:
		fuente.muestra.position.x += 16
		h._reloj_vida += 0.5
		h._reloj_mordida = 0.0
		h._morder(0.01)
	verificar(h.bocados == 12 and h.carga == 9.0 and h._carga_origen[0] == 9.0
		and h.estado == Hormiga.Estado.VOLVIENDO and h._retazos.size() == 3,
		"completar doce porciones reales inicia un solo regreso con toda la carga, no sólo las muestras dibujadas")
	run.queue_free()
	await get_tree().process_frame


func probar_entrega_al_perder_frente() -> void:
	var run := crear_run()
	var pieza := run.objetivo_practica
	pieza.preparar_material()
	var puesto := pieza.punto_mordida(Vector2.ZERO, run.radio_actual)
	verificar(puesto != Vector2.INF and pieza.alcanza_contacto(puesto)
		and run.cocina.libre(puesto, Cocina.MARGEN),
		"el fixture empieza sobre un frente físico accesible del cartón real")
	if puesto == Vector2.INF:
		run.queue_free()
		await get_tree().process_frame
		return
	var h := run.colonia._nacer("obrera", puesto)
	h.comida = pieza
	h.estado = Hormiga.Estado.MORDIENDO
	h._capacidad = 1000
	h._porciones_ciclo = 1
	h._dano = pieza.vida_max
	h._velocidad = 1500.0 # Transporte de fixture; no cambia los CSV.
	h._reloj_mordida = 0.0
	h._morder(0.01)
	var carga_real := h.carga
	var bocados_reales := h.bocados
	verificar(carga_real > 0.0 and bocados_reales == 1 and h.estado == Hormiga.Estado.MORDIENDO,
		"un primer bocado real no llena artificialmente un buche amplio")
	# Cortes controlados avanzan sólo por frontera exterior. Simulan que otras
	# obreras retiraron el frente, sin teletransportar esta portadora ni inventar
	# crédito o carga para ella. Su pérdida de contacto debe ser geométrica.
	var cortes := 0
	for paso in 64:
		var contacto := pieza.punto_contacto(puesto)
		if contacto == Vector2.INF or puesto.distance_squared_to(contacto) > pow(Cocina.MARGEN + 5, 2):
			break
		var exterior := contacto + (puesto - contacto).normalized() * 0.5
		if pieza.morder_local(pieza.vida_max, exterior, Juego.stat("tamano_bocado")) > 0.0:
			cortes += 1
	pieza._process(0.2)
	run.cocina.procesar_cambios()
	verificar(cortes > 0 and not pieza.muerta and not pieza.alcanza_contacto(puesto)
		and h.position == puesto and h.carga == carga_real and Juego.migas_run == 0.0,
		"retirar material real aleja el contacto sin mover, cobrar ni llenar la carga de la portadora")
	run.feromonas.mantener_en(pieza.position)
	h._reloj_mordida = 0.0
	h._morder(0.01)
	verificar(h.estado == Hormiga.Estado.VOLVIENDO and h.comida == null
		and h._recuerdo == pieza and not h._reubicando_frente
		and h.carga == carga_real and h.bocados == bocados_reales and h.position == puesto,
		"perder el contacto inicia el regreso con la porción real, sin buscar otra orilla para llenar el buche")
	# Recuperar también una misión de reubicación que ya existía: no conservar
	# aquella excepción de _pensar que retenía portadoras cargadas en YENDO.
	h.comida = pieza
	h.estado = Hormiga.Estado.YENDO_A_COMIDA
	h._reubicando_frente = true
	h._pensar()
	verificar(h.estado == Hormiga.Estado.VOLVIENDO and h.comida == null
		and not h._reubicando_frente and h.carga == carga_real,
		"una reubicación cargada anterior también vuelve, aunque el llamado siga mantenido")
	var saldo := Juego.migas_run
	var segura := true
	for cuadro in 180:
		run._reloj += 1.0 / 60.0
		h._process(1.0 / 60.0)
		run.cocina.procesar_cambios()
		segura = segura and run.cocina.libre(h.position, Cocina.MARGEN - 0.1)
		if h.carga == 0.0:
			break
		await get_tree().process_frame
	verificar(h.carga == 0.0 and h._tiempo_descarga > 0.0
		and h.position.length() <= Hormiguero.RADIO_ENTRADA and segura
		and is_equal_approx(Juego.migas_run - saldo, carga_real),
		"la entrega parcial llega físicamente al nido y acredita exactamente su carga una sola vez")
	h.detener()
	var vacia := run.colonia._nacer("obrera", puesto)
	vacia.comida = pieza
	vacia.estado = Hormiga.Estado.MORDIENDO
	vacia._reloj_mordida = 0.0
	vacia._morder(0.01)
	verificar(vacia.carga == 0.0 and vacia.estado in [Hormiga.Estado.YENDO_A_COMIDA, Hormiga.Estado.EXPLORANDO],
		"perder el frente sin carga sigue buscando trabajo, sin iniciar un regreso vacío")
	run.feromonas.soltar()
	run.queue_free()
	await get_tree().process_frame


func huellas_guardados() -> Dictionary:
	var huellas := {}
	for ruta: String in [Juego.RUTA_PARTIDA, Ajustes.RUTA]:
		huellas[ruta] = FileAccess.get_sha256(ruta) if FileAccess.file_exists(ruta) else "ausente"
	return huellas


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)
