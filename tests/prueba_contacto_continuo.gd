extends Node
## Otra obrera retira el apoyo mientras todavía falta más de un segundo
## para la mordida propia. La boca no puede seguir masticando aire hasta
## vencer ese reloj, ni depender del refresco diferido de la navegación.
const PASO := 1.0 / 60.0
var total := 0
var fallas := 0

class MaterialConLecturas extends MordiscosMaterial:
	var lecturas := 0
	func contiene(pos: Vector2) -> bool:
		lecturas += 1
		return super.contiene(pos)


## Doble explícito del contacto de un alimento cóncavo/mordido: la normal
## local está a90° de su centro. Aísla la orientación, no prueba su silueta,
## la preparación ni el balance; el reloj y el daño de la obrera son normales.
class FuenteContactoLateral extends Comida:
	var contacto_mundo := Vector2.ZERO
	var consultas := 0
	var intentos_mordida := 0
	func preparar_material() -> bool:
		return true
	func punto_contacto(_desde: Vector2) -> Vector2:
		consultas += 1
		return contacto_mundo
	func morder_local(_dano: float, _pos: Vector2, _lado_max := 6.0) -> float:
		intentos_mordida += 1
		return 0.0


func _init() -> void:
	Juego.guardado_habilitado = false


func _ready() -> void:
	var huellas := huellas_guardados()
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	await probar_contacto(false)
	await probar_contacto(true)
	await probar_retroceso_corto_y_reapoyo()
	await probar_llegada_apoyada()
	for id in ["galletita", "torta"]:
		await probar_contacto_alimento(id, false)
		await probar_contacto_alimento(id, true)
	await probar_orientacion_al_contacto_alimento()
	probar_bordes_contacto()
	verificar(huellas == huellas_guardados(), "el ensayo no modifica la partida ni los ajustes personales")
	print("Contacto continuo: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func probar_contacto(con_carga: bool) -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	seed(2817)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.radio_actual = 12000.0
	run.cocina.limite_rutas_por_cuadro = 0
	var nombre := "con carga parcial" if con_carga else "sin carga"
	var mesa: PiezaCasa
	for parte: PiezaCasa in run.comidas.partes:
		if parte.pieza.tipo == "mesa_comedor":
			mesa = parte
			break
	verificar(mesa != null and mesa.preparar_material(), nombre + ": se prepara la mesa real del comedor")
	if mesa == null or mesa.mordiscos == null:
		run.queue_free()
		await get_tree().process_frame
		return
	var desde := Vector2(mesa.rect_mundo.position.x - 160.0, mesa.rect_mundo.get_center().y)
	var puesto := mesa.punto_mordida(desde, run.radio_actual)
	verificar(puesto.is_finite() and mesa.alcanza_contacto(puesto), nombre + ": el puesto inicial alcanza material vivo")
	if not puesto.is_finite():
		run.queue_free()
		await get_tree().process_frame
		return
	var h := run.colonia._nacer("obrera", puesto)
	h.comida = mesa
	h.estado = Hormiga.Estado.MORDIENDO
	h._capacidad = 4
	h._porciones_ciclo = 1
	h._dano = mesa.vida_max
	h._reloj_pensar = 10.0
	if con_carga:
		# La carga nace de una porción física; no se escribe un saldo ficticio.
		h._reloj_mordida = 0.0
		h._morder(PASO)
		verificar(h.carga > 0.0 and h.bocados == 1 and h.estado == Hormiga.Estado.MORDIENDO,
			nombre + ": una porción real deja el buche parcialmente ocupado")
		# Comenzar la espera en un frente nativo todavía alcanzable, sin alterar
		# el retazo ni el valor que acaba de salir de la mesa.
		puesto = mesa.punto_mordida(desde + Vector2(0, 48), run.radio_actual)
		h.position = puesto
	h._intervalo_mordida = 2.5
	h._reloj_mordida = 1.5
	h._version_mirada = -1
	h._posicion_mirada = Vector2.INF
	h._morder(0.0) # Primear el contacto/mirada sin emitir otra mordida.
	verificar(h.estado == Hormiga.Estado.MORDIENDO and mesa.alcanza_contacto(h.position)
		and h._reloj_mordida == 1.5 and h._masticando_visual,
		nombre + ": espera con apoyo confirmado y todavía 1,5 segundos pendientes")
	var version_forma := mesa.version_forma
	var version_material := mesa._version_material
	var area := mesa.mordiscos.area_total()
	var cortes := 0
	# Otra operación real retira el apoyo. La misma boca sólo puede quitar
	# porciones locales mientras están en alcance; no se pintan píxeles vacíos
	# ni se mueve la hormiga para fabricar la pérdida de contacto.
	for intento in 64:
		if not mesa.alcanza_contacto(h.position):
			break
		var valor := mesa.morder_local(mesa.vida_max, h.position, 6.0)
		if valor <= 0.0:
			break
		cortes += 1
	var contacto_nuevo := mesa.punto_contacto(h.position)
	var distancia := h.position.distance_to(contacto_nuevo) if contacto_nuevo.is_finite() else INF
	verificar(cortes > 0 and mesa.mordiscos.area_total() < area and not mesa.muerta
		and contacto_nuevo.is_finite() and distancia > Cocina.MARGEN + 5,
		nombre + ": cortes físicos ajenos alejan el apoyo más de 13 unidades sin terminar la mesa")
	verificar(mesa.version_forma == version_forma and mesa._version_material > version_material
		and mesa._geometria_pendiente and mesa._reloj_geometria > PASO,
		nombre + ": el material cambió antes del refresco diferido de geometría de 0,12 segundos")
	var vida := mesa.vida
	var carga := h.carga
	var bocados := h.bocados
	var saldo := Juego.migas_run
	var posicion := h.position
	var camara := run.camara.transform
	var zoom := run.camara.zoom
	var offset := run.camara.offset
	h._reloj_pensar = 10.0
	h._process(PASO)
	verificar(h.estado != Hormiga.Estado.MORDIENDO and not h._masticando_visual
		and h._reloj_mordida > 1.0,
		nombre + ": abandona la masticación de aire en el cuadro siguiente, sin esperar la mordida")
	if con_carga:
		verificar(h.estado == Hormiga.Estado.VOLVIENDO and h.comida == null,
			nombre + ": vuelve con el retazo real en lugar de perseguir otro borde cargada")
	else:
		verificar(h.estado in [Hormiga.Estado.YENDO_A_COMIDA, Hormiga.Estado.EXPLORANDO],
			nombre + ": busca otro apoyo sin afirmar que todavía está comiendo")
	verificar(mesa.vida == vida and h.carga == carga and h.bocados == bocados and Juego.migas_run == saldo
		and h.position == posicion,
		nombre + ": detectar aire no arranca material, inventa carga, paga ni teletransporta")
	verificar(run.camara.transform == camara and run.camara.zoom == zoom and run.camara.offset == offset,
		nombre + ": el cambio de apoyo no mueve ni sacude la cámara")
	if h.estado == Hormiga.Estado.MORDIENDO:
		print("DIAG CONTACTO ", nombre, " cortes=", cortes, " distancia=", distancia,
			" version_forma=", version_forma, "->", mesa.version_forma,
			" version_material=", version_material, "->", mesa._version_material,
			" mirada=", h._version_mirada, " reloj=", h._reloj_mordida,
			" visual=", h._masticando_visual, " carga=", h.carga)
	run.queue_free()
	await get_tree().process_frame


## El contacto retrocede poco y continúa dentro de la API geométrica de13u.
## No alcanza con invalidar cuando queda lejano: tampoco se puede devolver
## el puesto viejo del caché y entrar en un ciclo de reubicar sin reapoyarse.
func probar_retroceso_corto_y_reapoyo() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	seed(2821)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.radio_actual = 12000.0
	var mesa: PiezaCasa
	for parte: PiezaCasa in run.comidas.partes:
		if parte.pieza.tipo == "mesa_comedor":
			mesa = parte
			break
	if mesa == null or not mesa.preparar_material():
		verificar(false, "retroceso corto: la mesa real prepara el material")
		run.queue_free()
		await get_tree().process_frame
		return
	var desde := Vector2(mesa.rect_mundo.position.x - 160.0, mesa.rect_mundo.get_center().y)
	var puesto := mesa.punto_mordida(desde, run.radio_actual)
	if not puesto.is_finite():
		verificar(false, "retroceso corto: la mesa real ofrece un puesto inicial finito")
		run.queue_free()
		await get_tree().process_frame
		return
	var h := run.colonia._nacer("obrera", puesto)
	h.comida = mesa
	h.estado = Hormiga.Estado.MORDIENDO
	h._puesto = 3 # Puesto central real, sin desplazamiento tangencial.
	h._intervalo_mordida = 2.5
	h._reloj_mordida = 1.5
	h._reloj_pensar = 10.0
	h._morder(0.0)
	var contacto_inicial := h._contacto_visual
	var cache_inicial := mesa.punto_mordida(h.position, run.radio_actual)
	verificar(puesto.is_finite() and h.estado == Hormiga.Estado.MORDIENDO
		and h.position.distance_to(contacto_inicial) <= 9.25 and cache_inicial.distance_to(puesto) <= 0.001
		and is_finite(h._distancia_apoyo),
		"retroceso corto: prima apoyo de9u y también el caché del puesto desde la posición real")
	var cortes := 0
	var distancia := h.position.distance_to(contacto_inicial)
	for intento in 8:
		if distancia > 9.25:
			break
		# Cada corte ajeno sigue siendo una porción física de6u. Se detiene
		# apenas el apoyo crece, antes de superar las13u de la API original.
		if mesa.morder_local(mesa.vida_max, h.position, 6.0) <= 0.0:
			break
		cortes += 1
		distancia = h.position.distance_to(mesa.punto_contacto(h.position))
	verificar(cortes > 0 and distancia > 9.25 and distancia <= Cocina.MARGEN + 5.0
		and not mesa.mordiscos.contacto_vigente(contacto_inicial) and mesa._geometria_pendiente,
		"retroceso corto: los cortes retiran el apoyo antes del refresco, aun con material entre9,25y13u")
	var vida := mesa.vida
	var carga := h.carga
	var saldo := Juego.migas_run
	var posicion := h.position
	h._process(PASO)
	verificar(h.estado == Hormiga.Estado.YENDO_A_COMIDA and not h._masticando_visual
		and h._reloj_mordida > 1.0 and h.position == posicion and h.objetivo.is_finite()
		and mesa.vida == vida and h.carga == carga and Juego.migas_run == saldo,
		"retroceso corto: deja de comer aire y busca apoyo nuevo sin esperar el reloj ni extraer otra porción")
	var cache_nuevo := mesa.punto_mordida(posicion, run.radio_actual)
	var contacto_cache := mesa.punto_contacto(cache_nuevo)
	verificar(cache_nuevo.is_finite() and contacto_cache.is_finite()
		and mesa.mordiscos.contacto_vigente(contacto_cache) and contacto_cache != contacto_inicial,
		"retroceso corto: el caché no conserva el contacto retirado aunque el puesto pueda seguir siendo transitable")
	var llego := false
	var segura := true
	for cuadro in 120:
		if h.estado != Hormiga.Estado.YENDO_A_COMIDA:
			break
		run._reloj += PASO
		h._caminar(PASO)
		segura = segura and run.cocina.libre(h.position, Cocina.MARGEN)
		if h.estado == Hormiga.Estado.MORDIENDO:
			llego = h.position.distance_squared_to(h.objetivo) <= 0.0625
			break
		await get_tree().process_frame
	# No se fuerza la posición, la carga ni el reloj al reapoyarse. Incluso
	# si un contorno obliga a reutilizar el mismo piso, debe aceptar la nueva
	# distancia legítima del puesto y no volver a reubicarse indefinidamente.
	for repeticion in 8:
		h._morder(0.0)
	verificar(llego and segura and h.estado == Hormiga.Estado.MORDIENDO and h._masticando_visual
		and h._contacto_visual.is_finite() and h.position.distance_to(h._contacto_visual) <= h._distancia_apoyo
		and h._distancia_apoyo <= Cocina.MARGEN + 5.0 and h._reloj_mordida > 0.0
		and mesa.vida == vida and h.carga == carga and Juego.migas_run == saldo,
		"retroceso corto: llega físicamente y retoma apoyo estable sin bucle, daño ni pago artificial")
	if not llego or h.estado != Hormiga.Estado.MORDIENDO:
		print("DIAG REAPOYO cortes=", cortes, " distancia=", distancia, " inicial=", puesto,
			" objetivo=", h.objetivo, " pos=", h.position, " estado=", h.estado,
			" apoyo=", h._distancia_apoyo, " contacto=", h._contacto_visual,
			" cache_inicial=", cache_inicial, " cache_nuevo=", cache_nuevo)
	run.queue_free()
	await get_tree().process_frame


func probar_llegada_apoyada() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	seed(2818)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.radio_actual = 12000.0
	var mesa: PiezaCasa
	for parte: PiezaCasa in run.comidas.partes:
		if parte.pieza.tipo == "mesa_comedor":
			mesa = parte
			break
	verificar(mesa != null and mesa.preparar_material(), "llegada: se usa otra mesa real intacta")
	if mesa == null or mesa.mordiscos == null:
		run.queue_free()
		await get_tree().process_frame
		return
	var desde := Vector2(mesa.rect_mundo.position.x - 160.0, mesa.rect_mundo.get_center().y)
	var puesto := mesa.punto_mordida(desde, run.radio_actual)
	var inicio := puesto + Vector2(-50, 0)
	verificar(puesto.is_finite() and run.cocina.libre(inicio, Cocina.MARGEN),
		"llegada: comienza en piso libre, a 50 unidades del puesto de apoyo")
	if not puesto.is_finite():
		run.queue_free()
		await get_tree().process_frame
		return
	var h := run.colonia._nacer("obrera", inicio)
	h.comida = mesa
	h.estado = Hormiga.Estado.YENDO_A_COMIDA
	h.objetivo = puesto
	h._velocidad = 60.0
	h._version_objetivo = mesa.version_forma
	var camara := run.camara.transform
	var zoom := run.camara.zoom
	var offset := run.camara.offset
	var vida := mesa.vida
	var saldo := Juego.migas_run
	var llego := false
	var distancia := INF
	for cuadro in 180:
		run._reloj += PASO
		h._caminar(PASO)
		if h.estado == Hormiga.Estado.MORDIENDO:
			llego = true
			var contacto := mesa.punto_contacto(h.position)
			distancia = h.position.distance_to(contacto) if contacto.is_finite() else INF
			break
		await get_tree().process_frame
	verificar(llego and distancia <= 9.25,
		"llegada: no empieza a masticar a 13 unidades; primero alcanza el apoyo de 9 unidades")
	verificar(mesa.vida == vida and h.carga == 0.0 and Juego.migas_run == saldo,
		"llegada: caminar hasta el apoyo no adelanta mordidas, carga ni pagos")
	verificar(run.camara.transform == camara and run.camara.zoom == zoom and run.camara.offset == offset,
		"llegada: acercarse al material no altera la cámara")
	if not llego or distancia > 9.25:
		print("DIAG LLEGADA estado=", h.estado, " inicio=", inicio, " puesto=", puesto,
			" pos=", h.position, " distancia_contacto=", distancia, " ruta=", h._indice_ruta, "/", h._ruta.size())
	run.queue_free()
	await get_tree().process_frame


func huellas_guardados() -> Dictionary:
	var huellas := {}
	for ruta: String in [Juego.RUTA_PARTIDA, Ajustes.RUTA]:
		huellas[ruta] = FileAccess.get_sha256(ruta) if FileAccess.file_exists(ruta) else "ausente"
	return huellas


func probar_orientacion_al_contacto_alimento() -> void:
	Juego.reiniciar_estado()
	seed(2820)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.radio_actual = 12000.0
	var fuente := FuenteContactoLateral.new()
	var datos: Dictionary = run.comidas._tipo_comida("galletita").duplicate()
	fuente.configurar(datos, 1128)
	run.comidas.add_child(fuente)
	fuente.position = run.cocina.ajustar_destino(Vector2(100, -120), run.radio_actual)
	var puesto := fuente.position + Vector2(20.0, 0.0)
	fuente.contacto_mundo = puesto + Vector2(0.0, -1.5)
	var h := run.colonia._nacer("obrera", puesto)
	h.comida = fuente
	h.estado = Hormiga.Estado.MORDIENDO
	var angulo_centro := (fuente.global_position - h.global_position).angle()
	var angulo_contacto := (fuente.contacto_mundo - h.global_position).angle()
	h.rotation = angulo_centro
	h._reloj_mordida = h._intervalo_mordida * 0.9
	var reloj := h._reloj_mordida
	var intervalo := h._intervalo_mordida
	var dano := h._dano
	var vida := fuente.vida
	var carga := h.carga
	var bocados := h.bocados
	var saldo := Juego.migas_run
	var tiempo_bocado := h._tiempo_bocado
	h._morder(0.0)
	verificar(absf(angle_difference(angulo_contacto, angulo_centro)) > 1.5
		and h._contacto_visual == fuente.contacto_mundo and h._masticando_visual
		and h._posicion_mirada == puesto and h._vida_mirada == vida and fuente.consultas == 1
		and h._reloj_mordida == reloj and h.estado == Hormiga.Estado.MORDIENDO,
		"orientación del alimento: _morder(0) cachea la normal lateral real sin adelantar la espera")
	var ritmo := run.factor_ritmo() * run.multiplicador_ritmo_activo()
	var delta := minf(0.01, reloj / (24.0 * ritmo))
	var sigue_contacto := true
	var error_inicial := absf(angle_difference(h.rotation, angulo_contacto))
	for paso in 12:
		var hacia_contacto := rotate_toward(h.rotation, angulo_contacto, Hormiga.VELOCIDAD_GIRO * delta)
		var hacia_centro := rotate_toward(h.rotation, angulo_centro, Hormiga.VELOCIDAD_GIRO * delta)
		h._morder(delta)
		sigue_contacto = sigue_contacto and absf(angle_difference(h.rotation, hacia_contacto)) < 0.00001
		sigue_contacto = sigue_contacto and absf(angle_difference(h.rotation, hacia_centro)) > 0.00001
	verificar(sigue_contacto and absf(angle_difference(h.rotation, angulo_contacto)) < error_inicial
		and h._angulo_mordida == angulo_contacto and fuente.consultas == 1,
		"orientación del alimento: cada cuadro pendiente gira hacia el contacto cacheado, nunca hacia el centro")
	verificar(h.estado == Hormiga.Estado.MORDIENDO and h._reloj_mordida > 0.0
		and is_equal_approx(h._reloj_mordida, reloj - 12.0 * delta * ritmo)
		and h._intervalo_mordida == intervalo and h._dano == dano
		and fuente.intentos_mordida == 0 and fuente.vida == vida and h.carga == carga
		and h.bocados == bocados and h.position == puesto and Juego.migas_run == saldo
		and h._tiempo_bocado == tiempo_bocado,
		"orientación del alimento: el reloj avanza normalmente sin extraer, cobrar, mover ni inventar un tirón")
	if not sigue_contacto:
		print("DIAG ORIENTACIÓN contacto=", angulo_contacto, " centro=", angulo_centro,
			" rotation=", h.rotation, " cache=", h._angulo_mordida,
			" reloj=", h._reloj_mordida, " consultas=", fuente.consultas)
	run.queue_free()
	await get_tree().process_frame


func probar_contacto_alimento(id: String, con_carga: bool) -> void:
	Juego.reiniciar_estado()
	seed(2819)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.radio_actual = 12000.0
	run.cocina.limite_rutas_por_cuadro = 0
	var nombre := "%s %s" % [id, "con carga parcial" if con_carga else "sin carga"]
	var centro := run.cocina.ajustar_destino(Vector2(100, -120), run.radio_actual)
	var alimento := run.comidas._crear(run.comidas._tipo_comida(id), centro, 1127)
	verificar(alimento.radio >= 15.0 and alimento.preparar_material(),
		nombre + ": alimento real del CSV con silueta y radio originales")
	if alimento.mordiscos == null:
		run.queue_free()
		await get_tree().process_frame
		return
	var puesto := alimento.punto_mordida(centro - Vector2(100, 0), run.radio_actual)
	verificar(puesto.is_finite(), nombre + ": tiene un puesto nativo de contacto")
	if not puesto.is_finite():
		run.queue_free()
		await get_tree().process_frame
		return
	var h := run.colonia._nacer("obrera", puesto)
	h.comida = alimento
	h.estado = Hormiga.Estado.MORDIENDO
	h._capacidad = 4
	h._porciones_ciclo = 1
	h._dano = alimento.vida_max
	h._reloj_pensar = 10.0
	if con_carga:
		h._reloj_mordida = 0.0
		h._morder(PASO)
		verificar(h.carga > 0.0 and h.bocados == 1 and not alimento.muerta,
			nombre + ": transporta una porción físicamente retirada sin terminar el alimento")
		h.position = alimento.punto_mordida(centro + Vector2(100, 0), run.radio_actual)
	h._intervalo_mordida = 2.5
	h._reloj_mordida = 1.5
	h._version_mirada = -1
	h._posicion_mirada = Vector2.INF
	h._morder(0.0)
	verificar(h.estado == Hormiga.Estado.MORDIENDO and h._masticando_visual
		and h._contacto_visual.is_finite() and h.position.distance_squared_to(h._contacto_visual) <= 9.0,
		nombre + ": comienza la espera con un contacto real a no más de 3 unidades")
	var apoyo_anterior := alimento.to_local(h._contacto_visual)
	var cortes := 0
	for intento in 32:
		var contacto := alimento.punto_contacto(h.position)
		if not contacto.is_finite() or h.position.distance_squared_to(contacto) > 9.0:
			break
		if alimento.morder_local(alimento.vida_max, h.position, 6.0) <= 0.0:
			break
		cortes += 1
	var contacto_nuevo := alimento.punto_contacto(h.position)
	var distancia := h.position.distance_to(contacto_nuevo) if contacto_nuevo.is_finite() else INF
	verificar(cortes > 0 and not alimento.muerta and alimento.vida > 0.0
		and contacto_nuevo.is_finite() and distancia > 3.0
		and not alimento.mordiscos.contacto_vigente(apoyo_anterior),
		nombre + ": otras bocas retiran el apoyo y alejan el frente sin agotar el alimento")
	var vida := alimento.vida
	var carga := h.carga
	var bocados := h.bocados
	var saldo := Juego.migas_run
	var posicion := h.position
	var camara := run.camara.transform
	var zoom := run.camara.zoom
	var offset := run.camara.offset
	h._reloj_pensar = 10.0
	h._process(PASO)
	verificar(h.estado != Hormiga.Estado.MORDIENDO and not h._masticando_visual and h._reloj_mordida > 1.0,
		nombre + ": deja de masticar aire en el siguiente cuadro con el reloj todavía pendiente")
	verificar((h.estado == Hormiga.Estado.VOLVIENDO if con_carga else h.estado in [Hormiga.Estado.YENDO_A_COMIDA, Hormiga.Estado.EXPLORANDO])
		and alimento.vida == vida and h.carga == carga and h.bocados == bocados
		and Juego.migas_run == saldo and h.position == posicion,
		nombre + ": conserva el material y el retazo sin cobrar ni arrancar otra porción")
	verificar(run.camara.transform == camara and run.camara.zoom == zoom and run.camara.offset == offset,
		nombre + ": recuperar el apoyo no mueve ni sacude la cámara")
	if h.estado == Hormiga.Estado.MORDIENDO or distancia <= 3.0 or alimento.muerta:
		print("DIAG ALIMENTO ", nombre, " cortes=", cortes, " distancia=", distancia,
			" estado=", h.estado, " reloj=", h._reloj_mordida, " vida=", alimento.vida,
			" apoyo_vigente=", alimento.mordiscos.contacto_vigente(apoyo_anterior))
	run.queue_free()
	await get_tree().process_frame


func probar_bordes_contacto() -> void:
	var rect := Rect2(-40, 25, 100, 80)
	var normales := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	var nombres := ["izquierdo", "derecho", "superior", "inferior"]
	for lado in 4:
		var material := MaterialConLecturas.new()
		material.configurar(rect, Vector2i.ONE, [[rect]], PackedFloat64Array([1000.0]))
		var paso := rect.size / Vector2(material.tamano_mascara())
		# Centrar el otro eje dentro de un píxel evita que el contacto pertenezca
		# también a su vecino: sólo el borde exterior está exactamente incluido.
		var interior := rect.position + (Vector2(material.tamano_mascara() / 2) + Vector2.ONE * 0.5) * paso
		var borde := Vector2(rect.position.x if lado == 0 else rect.end.x, interior.y) if lado < 2 \
			else Vector2(interior.x, rect.position.y if lado == 2 else rect.end.y)
		material.lecturas = 0
		verificar(material.contacto_vigente(borde) and material.lecturas <= 4,
			"contacto %s: incluye el borde exacto con como máximo cuatro lecturas R8" % nombres[lado])
		verificar(material.contacto_vigente(borde + normales[lado] * 0.005)
			and not material.contacto_vigente(borde + normales[lado] * 0.02),
			"contacto %s: el margen local es 0,01, no una búsqueda de material distante" % nombres[lado])
		var retirado := material.recortar_local(0, 1000.0, borde + normales[lado] * 0.5, 6.0)
		material.lecturas = 0
		verificar(retirado > 0.0 and material.vida_celda(0) > 0.0
			and not material.contacto_vigente(borde) and material.lecturas == 4,
			"contacto %s: retirar físicamente ese píxel invalida el apoyo sin recorrer el árbol" % nombres[lado])


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)
