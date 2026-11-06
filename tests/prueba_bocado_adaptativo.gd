extends Node
## El objetivo grande puede aprovechar mandíbulas fuertes sin cambiar la
## resistencia, el valor ni el bocado de los muebles comunes. El fixture físico
## usa el descriptor/material real de las dos mesas de la casa, sin tocar CSV.
const BASE := 6.0
const EPS := 0.001

class MesaConRegion extends PiezaCasa:
	func region_bocado() -> Rect2:
		if DisplayServer.get_name() != "headless":
			return super.region_bocado()
		# Sólo metadatos de presentación para headless, que no hornea atlas.
		# No reemplaza geometría, contacto, extracción, vida, recompensa ni daño.
		return Rect2(Vector2(640, 640) + (_porcion_reciente.position - rect_mundo.position) * 3.0,
			_porcion_reciente.size * 3.0) if _porcion_reciente.has_area() else Rect2()

var total := 0
var fallas := 0


func _init() -> void:
	Juego.guardado_habilitado = false


func _ready() -> void:
	var huellas := huellas_guardados()
	var balance := huellas_balance()
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	if DisplayServer.get_name() != "headless" and not Graficos.listo:
		await Graficos.preparado
	probar_reglas_del_lado()
	await probar_mesa_real(true)
	await probar_mesa_real(false)
	verificar(huellas_guardados() == huellas, "la prueba no modifica la partida ni los ajustes del jugador")
	verificar(huellas_balance() == balance, "la resistencia, los precios y las fuentes de balance quedan intactos")
	Juego.reiniciar_estado()
	print("Bocado adaptativo: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func probar_reglas_del_lado() -> void:
	# Fixture puro: densidad 2 HP/u². No participa en el mapa ni modifica el
	# estado de Juego; permite verificar exactamente sqrt(daño/densidad).
	var pieza := PiezaCasa.new()
	pieza.rect_mundo = Rect2(0, 0, 100, 80)
	pieza.vida_max = 16000.0
	pieza.vida = pieza.vida_max
	pieza.pieza = {}
	verificar(pieza.lado_para_dano(1.0e12, BASE) == BASE,
		"sin metadatos de gran objetivo, incluso un daño enorme conserva el lado de seis")
	pieza.pieza = {"meta": false, "objetivo_proyecto": ""}
	verificar(pieza.lado_para_dano(1.0e12, BASE) == BASE,
		"un mueble común con meta=false y proyecto vacío también conserva seis")
	for datos: Dictionary in [{"meta": true}, {"meta": false, "objetivo_proyecto": "mesa_del_proyecto"}]:
		pieza.pieza = datos
		var firma := [pieza.vida, pieza.vida_max, pieza.rect_mundo, pieza.version_forma, pieza.pieza.duplicate(true)]
		var invalidos := true
		for dano: float in [0.0, 1.0, 72.0, -1.0, -1.0e12, NAN, INF, -INF]:
			invalidos = invalidos and pieza.lado_para_dano(dano, BASE) == BASE
		var nombre := "meta del destino" if datos.get("meta", false) else "objetivo de proyecto"
		verificar(invalidos, nombre + ": daño bajo, negativo o no finito nunca agranda el bocado")
		verificar(is_equal_approx(pieza.lado_para_dano(288.0, BASE), 12.0)
			and is_equal_approx(pieza.lado_para_dano(1152.0, BASE), 24.0)
			and is_equal_approx(pieza.lado_para_dano(1.0e12, BASE), 24.0),
			nombre + ": la fuerza intermedia crece por densidad y la fuerza enorme queda en veinticuatro")
		var monotono := true
		var previo := BASE
		for dano: float in [0.0, 32.0, 72.0, 150.0, 288.0, 500.0, 1152.0, 1.0e12]:
			var lado := pieza.lado_para_dano(dano, BASE)
			monotono = monotono and lado >= previo and lado >= BASE and lado <= BASE * 4.0
			previo = lado
		verificar(monotono and pieza.lado_para_dano(1.0e12, 3.0) == 12.0
			and pieza.lado_para_dano(1.0e12, 10.0) == 40.0,
			nombre + ": la cota siempre es cuatro veces el lado recibido, no un tamaño sin límite")
		verificar(firma == [pieza.vida, pieza.vida_max, pieza.rect_mundo, pieza.version_forma, pieza.pieza],
			nombre + ": calcular el tamaño no modifica resistencia, geometría ni metadatos")
	pieza.pieza = {"meta": true}
	pieza.vida_max = 0.0
	verificar(pieza.lado_para_dano(1.0e12, BASE) == BASE, "una densidad nula conserva el lado base sin división inválida")
	pieza.free()


func crear_run() -> Run:
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true # Una mordida aislada, no perfil de preparación.
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.colonia._activa = false
	run.radio_actual = 12000.0
	return run


func probar_mesa_real(es_meta: bool) -> void:
	var run := crear_run()
	var original: PiezaCasa
	for candidata: PiezaCasa in run.comidas.partes:
		if (es_meta and candidata.pieza.get("meta", false) and candidata.pieza.tipo == "mesa_comedor") \
				or (not es_meta and candidata.pieza.tipo == "mesa" and not candidata.pieza.get("meta", false)):
			original = candidata
			break
	var nombre := "gran mesa familiar" if es_meta else "mesa común de cocina"
	verificar(original != null, nombre + ": existe el descriptor real esperado de la casa")
	if original == null:
		run.queue_free()
		await get_tree().process_frame
		return
	var mesa := MesaConRegion.new()
	run.comidas.add_child(mesa)
	mesa.iniciar(original.pieza.duplicate(true), run.cocina)
	verificar(mesa.pieza == original.pieza and mesa.vida_max == original.vida_max
		and mesa.recompensa == original.recompensa and mesa.grilla == original.grilla
		and mesa.preparar_material(), nombre + ": conserva balance, máscara y preparación reales; sólo adapta la región headless")
	if mesa.mordiscos == null:
		run.queue_free()
		await get_tree().process_frame
		return
	var desde := Vector2(mesa.rect_mundo.position.x - 200.0, mesa.rect_mundo.get_center().y)
	var puesto := mesa.punto_mordida(desde, run.radio_actual)
	var contacto := mesa.punto_contacto(puesto) if puesto.is_finite() else Vector2.INF
	verificar(puesto.is_finite() and contacto.is_finite()
		and absf(puesto.distance_to(contacto) - (Cocina.MARGEN + 1.0)) < EPS
		and run.cocina.libre(puesto, Cocina.MARGEN),
		nombre + ": la obrera usa el puesto nativo a nueve unidades del contacto, sobre piso libre")
	if not puesto.is_finite() or not contacto.is_finite():
		run.queue_free()
		await get_tree().process_frame
		return
	var h := run.colonia._nacer("obrera", puesto)
	h.comida = mesa
	h.estado = Hormiga.Estado.MORDIENDO
	h.rotation = (contacto - puesto).angle()
	h._capacidad = 1000
	h._porciones_ciclo = 1
	h._dano = mesa.vida_max # Fuerza del fixture, no una modificación al balance.
	h._reloj_mordida = 0.0
	var dano_fixture := h._dano
	var lado := mesa.lado_para_dano(h._dano * RolesHormiga.dano(h.casta, mesa.nivel_requerido) * run.reglas.factor_dano(mesa), BASE)
	var area := mesa.mordiscos.area_total()
	var vida := mesa.vida
	var saldo := Juego.migas_run
	var celda := mesa._celda_contacto
	var hp_pixel: float = mesa.mordiscos._hp_pixel[celda]
	var originales := mesa.mordiscos._pixeles.duplicate()
	h._morder(0.0)
	var porcion := mesa._porcion_reciente
	var carga_real := h.carga
	var retirado := vida - mesa.vida
	var tamano := mesa.tamano_bocado()
	var cota := BASE * 4.0 if es_meta else BASE
	verificar(h.bocados == 1 and carga_real > 0.0 and h.estado == Hormiga.Estado.MORDIENDO
		and h._dano == dano_fixture and h._capacidad == 1000 and h._porciones_ciclo == 1,
		nombre + ": una llamada real produce un solo bocado sin forzar regreso, capacidad ni daño extra")
	verificar(porcion.has_area() and porcion.size.x <= cota + EPS and porcion.size.y <= cota + EPS
		and (maxf(porcion.size.x, porcion.size.y) > BASE + EPS if es_meta else lado == BASE)
		and lado == cota, nombre + ": el retazo grande está limitado a 24; el común sigue limitado a 6")
	verificar(is_equal_approx(area - mesa.mordiscos.area_total(), porcion.get_area())
		and is_equal_approx(retirado, porcion.get_area() / mesa.mordiscos._area_pixel * hp_pixel)
		and muestras_retiradas(mesa.mordiscos, porcion, originales),
		nombre + ": área, píxeles ausentes y resistencia descontada describen exactamente el mismo retazo sólido")
	verificar(h._retazos.size() == 1 and h._retazos[0] == mesa.region_bocado()
		and h._tamanos_retazos == [tamano] and tamano == porcion.size
		and h._origenes_retazos == [porcion.get_center()],
		nombre + ": la región, el tamaño y el origen transportados pertenecen a la porción recién retirada")
	var escala_exacta := h._retazos.size() == 1
	if escala_exacta:
		var medido: Vector2 = h._escala_retazo(h._retazos[0]) * h._retazos[0].size * h.global_scale.abs()
		escala_exacta = medido.is_equal_approx(porcion.size)
	verificar(escala_exacta and is_equal_approx(carga_real,
		mesa.recompensa * retirado / mesa.vida_max * Juego.stat("multiplicador_migas"))
		and is_equal_approx(h._carga_origen[0] + h._carga_origen[1] + h._carga_origen[2], carga_real)
		and Juego.migas_run == saldo, nombre + ": el material mantiene escala y valor reales sin pagar antes de entregarlo")
	# El transporte también es físico. Acelerar sólo la velocidad evita que la
	# suite mida minutos de viaje; no acerca el nido ni mueve la hormiga a mano.
	h._velocidad = 1500.0
	h._volver()
	run.retirando = true
	for cuadro in 600:
		if h.carga == 0.0:
			break
		run._reloj += 1.0 / 60.0
		h._caminar(1.0 / 60.0)
		await get_tree().process_frame
	verificar(h.carga == 0.0 and h.position.length() <= Hormiguero.RADIO_ENTRADA
		and is_equal_approx(Juego.migas_run - saldo, carga_real),
		nombre + ": el regreso acredita una sola vez exactamente el valor del material retirado")
	run.queue_free()
	await get_tree().process_frame


func muestras_retiradas(m: MordiscosMaterial, porcion: Rect2, originales: PackedByteArray) -> bool:
	if not porcion.has_area():
		return false
	for y: float in [0.1, 0.5, 0.9]:
		for x: float in [0.1, 0.5, 0.9]:
			var punto := porcion.position + porcion.size * Vector2(x, y)
			var pixel := Vector2i(((punto - m._rect_mundo.position) / m._paso).floor())
			var indice := pixel.y * m._ancho + pixel.x
			if indice < 0 or indice >= originales.size() or originales[indice] == 0 or m.contiene(punto):
				return false
	return true


func huellas_guardados() -> Dictionary:
	var huellas := {}
	for ruta: String in [Juego.RUTA_PARTIDA, Ajustes.RUTA]:
		huellas[ruta] = FileAccess.get_sha256(ruta) if FileAccess.file_exists(ruta) else "ausente"
	return huellas


func huellas_balance() -> Dictionary:
	var huellas := {}
	for nombre: String in DirAccess.get_files_at("res://datos"):
		if nombre.ends_with(".csv"):
			huellas[nombre] = FileAccess.get_sha256("res://datos/" + nombre)
	huellas["mundos.gd"] = FileAccess.get_sha256("res://mundo/mundos.gd")
	return huellas


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)
