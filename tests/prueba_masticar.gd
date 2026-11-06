extends Node
## Presentación del trabajo: el doble confirma contacto/preparación y declara
## sus porciones. La geometría real se cubre en geometria_material y materiales.
## Los sprites sin textura permiten verificar el contrato también en headless,
## sin inventar un atlas global ni medir rendimiento del renderer vacío.
class FuenteTrabajo extends Comida:
	var lista := true
	var produce := false
	var contacto := Vector2.RIGHT
	var preparaciones := 0
	var contactos := 0
	var intentos := 0
	var trabajo := 0.0
	var muestra := Rect2(111, 222, 12, 9)
	var tamano_real := Vector2(4, 3)
	func preparar_material() -> bool:
		preparaciones += 1
		return lista
	func material_preparandose() -> bool:
		return not lista
	func punto_contacto(desde: Vector2) -> Vector2:
		contactos += 1
		return desde + contacto if contacto.is_finite() else Vector2.INF
	func punto_trabajo(desde: Vector2, _territorio: float, _volando: bool, _puesto: int) -> Vector2:
		return desde + Vector2(40, 0)
	func morder_local(dano: float, _pos: Vector2, _lado_max := 6.0) -> float:
		intentos += 1
		trabajo += dano
		if not produce or dano <= 0 or muerta:
			return 0.0
		vida -= minf(dano, vida)
		return 1.25
	func region_bocado() -> Rect2:
		return muestra
	func tamano_bocado() -> Vector2:
		return tamano_real
	func origen_bocado() -> Vector2:
		return global_position + Vector2(-radio, 0)

var total := 0
var fallas := 0


func _init() -> void:
	Juego.guardado_habilitado = false


func _ready() -> void:
	var huellas := huellas_guardados()
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	# En la revisión opcional con ventana, esperar antes de inyectar regiones
	# evita que una señal tardía reemplace los sprites de este fixture lógico.
	if DisplayServer.get_name() != "headless" and not Graficos.listo:
		await Graficos.preparado
	probar_curva()
	await probar_trabajo()
	verificar(huellas_guardados() == huellas, "masticar no toca la partida ni los ajustes guardados")
	Juego.reiniciar_estado()
	print("Masticar: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func probar_curva() -> void:
	verificar(Graficos.CUADROS_MASTICAR == 4 and AspectoHormiga.CICLOS_MASTICAR == 2.0,
		"el gesto usa cuatro cuadros y dos ciclos visuales por segundo")
	var acotada := true
	var periodica := true
	for i in range(-64, 65):
		var fase := i * TAU / 32.0
		var cierre := AspectoHormiga.cierre_masticar(fase)
		acotada = acotada and cierre >= 0.0 and cierre <= 1.0
		periodica = periodica and is_equal_approx(cierre, AspectoHormiga.cierre_masticar(fase + TAU))
	verificar(acotada and periodica, "la mandíbula abre y cierra de forma periódica y acotada")
	verificar(is_zero_approx(AspectoHormiga.cierre_masticar(0))
		and is_equal_approx(AspectoHormiga.cierre_masticar(PI), 1.0)
		and AspectoHormiga.cierre_masticar(PI * 0.5) > 0.4
		and AspectoHormiga.cierre_masticar(PI * 0.5) < 0.6,
		"apertura, media apertura y cierre son poses distintas, no un pulso imperceptible")


func crear_run() -> Run:
	Juego.reiniciar_estado()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true # Fixture de presentación, no perfil de preparación.
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.colonia._activa = false
	run.camara.zoom = Vector2.ONE
	return run


func preparar_sprites(h: Hormiga) -> void:
	if not is_instance_valid(h._cuerpo):
		h._cuerpo = Sprite2D.new()
		h.add_child(h._cuerpo)
	if not is_instance_valid(h._carga_sprite):
		h._carga_sprite = Sprite2D.new()
		h.add_child(h._carga_sprite)
	h._tipo_animacion = h.casta
	h._evolucion_animacion = h._evolucion
	# Desvincular las cachés, no vaciarlas: con renderer real pueden ser los
	# mismos arreglos compartidos que usa el resto de la colonia.
	h._animacion = []
	h._animacion_masticar = []
	for i in Graficos.CUADROS:
		h._animacion.append(Rect2(100 + i * 72, 100, 72, 72))
	for i in Graficos.CUADROS_MASTICAR:
		h._animacion_masticar.append(Rect2(100 + i * 54, 300, 54, 54))
	h._fase = 0.0
	h._desfase_masticar = 0.0
	h._reloj_vida = 0.0
	h.en_pantalla = true
	h.rotation = 0.0
	h._angulo_mordida = 0.0


func probar_trabajo() -> void:
	var run := crear_run()
	var fuente := FuenteTrabajo.new()
	var datos: Dictionary = Juego.comidas[0].duplicate()
	datos.vida = 100.0
	datos.recompensa = 125.0
	fuente._usar_cache = false
	fuente.configurar(datos, 7501)
	run.comidas.add_child(fuente)
	fuente.position = Vector2(-400, -300)
	fuente.rotation = 0.0
	var h := run.colonia._nacer("obrera", fuente.position + Vector2(-10, 0))
	preparar_sprites(h)
	h._capacidad = 20
	h._porciones_ciclo = 1
	h.comida = fuente
	h.estado = Hormiga.Estado.MORDIENDO
	var hijos := h.get_child_count()
	var cuerpo_id := h._cuerpo.get_instance_id()
	var carga_id := h._carga_sprite.get_instance_id()
	fuente.lista = false
	h._reloj_mordida = 0.23
	for i in 5:
		h._morder(0.1)
		h._actualizar_sprite()
	verificar(not h._masticando_visual and not h._esta_masticando() and not h._masticando_animacion
		and fuente.intentos == 0 and fuente.contactos == 0 and h.carga == 0.0
		and h._reloj_mordida == 0.23 and h.estado == Hormiga.Estado.MORDIENDO,
		"esperar la preparación conserva el trabajo pero no finge estar masticando")
	fuente.lista = true
	h._reloj_mordida = 0.0
	h._morder(0.01)
	h._actualizar_sprite()
	verificar(h._masticando_visual and h._esta_masticando() and h._masticando_animacion
		and h._contacto_visual == h.global_position + Vector2.RIGHT
		and fuente.intentos == 1 and fuente.trabajo > 0.0
		and h.carga == 0.0 and h.bocados == 0 and h._retazos.is_empty() and Juego.migas_run == 0.0,
		"el contacto confirmado anima el esfuerzo contra material duro, sin inventar una extracción")
	var caminando := h._animacion.duplicate()
	var masticando := h._animacion_masticar.duplicate()
	for intervalo: float in [0.6, 0.05]:
		h._intervalo_mordida = intervalo
		var vistos := {}
		for cuadro in 12:
			h._reloj_vida = cuadro / 12.0
			h._actualizar_sprite()
			vistos[h._cuerpo.region_rect] = true
		var cuadros_correctos := vistos.size() == Graficos.CUADROS_MASTICAR
		for region: Rect2 in vistos:
			cuadros_correctos = cuadros_correctos and region in masticando and not region in caminando
		verificar(cuadros_correctos and h._animacion == caminando and h._animacion_masticar == masticando,
			"a 12 Hz se leen las cuatro poses de trabajo con intervalo real %.2f, sin reemplazar la caché de caminar" % intervalo)
	# La animación de trabajo no presupone que ya existe una muestra: primero
	# el esfuerzo sin carga; recién esta llamada real declara una porción.
	fuente.produce = true
	h._intervalo_mordida = 0.6
	h._reloj_mordida = 0.0
	h._morder(0.01)
	h._actualizar_sprite()
	verificar(h.carga == 1.25 and h.bocados == 1 and h._retazos == [fuente.muestra]
		and h._carga_origen == [1.25, 0.0, 0.0] and h._masticando_animacion,
		"una porción real mantiene región, tamaño y valor mientras continúa masticando")
	var antes := estado_real(h, fuente, run)
	var tweens := get_tree().get_processed_tweens().size()
	seed(7501)
	var azar_esperado := randf()
	seed(7501)
	for cuadro in 500:
		h._reloj_vida += 1.0 / 12.0
		h._actualizar_sprite()
	var azar_despues := randf()
	verificar(estado_real(h, fuente, run) == antes,
		"quinientos ticks visuales no mueven la hormiga ni cambian rutas, daño, reloj, contacto, carga o economía")
	verificar(azar_despues == azar_esperado and h.get_child_count() == hijos
		and h._cuerpo.get_instance_id() == cuerpo_id and h._carga_sprite.get_instance_id() == carga_id
		and get_tree().get_processed_tweens().size() == tweens,
		"masticar reutiliza los mismos sprites y no consume azar ni crea nodos o tweens por cuadro")
	verificar(h._carga_sprite.region_rect == fuente.muestra
		and (h._carga_sprite.scale * h._carga_sprite.region_rect.size * h.global_scale.abs()).is_equal_approx(fuente.tamano_real)
		and h._posicion_retazo(0).is_equal_approx(Vector2(5.8, 0)),
		"el gesto no agranda el retazo ni cambia el material que queda agarrado en la boca")
	probar_condiciones(h, fuente, run, caminando)
	# Perder el frente con carga debe volver; no seguir masticando el aire ni
	# abandonar el valor transportado para completar otra orilla.
	fuente.contacto = Vector2.INF
	h._reloj_mordida = 0.0
	var intentos := fuente.intentos
	var cargada := h.carga
	h._morder(0.01)
	h._actualizar_sprite()
	verificar(h.estado == Hormiga.Estado.VOLVIENDO and h.comida == null
		and not h._masticando_visual and not h._masticando_animacion
		and h._contacto_visual == Vector2.INF and h.carga == cargada and fuente.intentos == intentos,
		"perder el contacto devuelve la portadora sin otra mordida ni animación contra una superficie inexistente")
	# Restaurar trabajo válido y probar detener desde la pose activa, no desde
	# el retorno que ya había limpiado las banderas visuales.
	fuente.contacto = Vector2.RIGHT
	h.comida = fuente
	h.estado = Hormiga.Estado.MORDIENDO
	h._reloj_mordida = 0.0
	fuente.produce = false
	h._morder(0.01)
	h._actualizar_sprite()
	verificar(h._masticando_animacion, "el fixture vuelve a una pose de trabajo antes de detenerlo")
	var fisica := h.transform
	var reloj_vida := h._reloj_vida
	var reloj_mordida := h._reloj_mordida
	h.detener()
	verificar(h.estado == Hormiga.Estado.QUIETA and not h._masticando_visual and not h._masticando_animacion
		and h.comida == null and h._cuerpo.position.is_zero_approx() and is_zero_approx(h._cuerpo.rotation)
		and h._cuerpo.scale.is_equal_approx(Vector2.ONE / 3.0) and h.transform == fisica and h.carga == cargada,
		"detener limpia la pose inmediatamente sin mover la hormiga física ni borrar su carga")
	intentos = fuente.intentos
	h._process(0.5)
	verificar(h._reloj_vida == reloj_vida and h._reloj_mordida == reloj_mordida
		and fuente.intentos == intentos and h.carga == cargada and not h._masticando_animacion,
		"QUIETA no avanza el gesto ni vuelve a trabajar después del final")
	probar_primera_mordida(run)
	run.queue_free()
	await get_tree().process_frame


func probar_primera_mordida(run: Run) -> void:
	var fuente := FuenteTrabajo.new()
	var datos: Dictionary = Juego.comidas[0].duplicate()
	datos.vida = 100.0
	datos.recompensa = 125.0
	fuente._usar_cache = false
	fuente.configurar(datos, 7502)
	run.comidas.add_child(fuente)
	fuente.position = Vector2(-350, -300)
	fuente.rotation = 0.0
	fuente.produce = true
	var h := run.colonia._nacer("obrera", fuente.position + Vector2(-10, 0))
	preparar_sprites(h)
	h._capacidad = 1
	h._porciones_ciclo = 1
	h.comida = fuente
	h.estado = Hormiga.Estado.MORDIENDO
	h._reloj_mordida = 0.4
	var saldo := Juego.migas_run
	h._morder(0.01)
	h._actualizar_sprite()
	verificar(h._masticando_animacion and h._masticando_visual and fuente.contactos == 1
		and fuente.intentos == 0 and fuente.trabajo == 0.0 and h.carga == 0.0 and h.bocados == 0
		and is_equal_approx(h._reloj_mordida, 0.39) and Juego.migas_run == saldo,
		"capacidad uno confirma el primer contacto y mastica antes de extraer, sin adelantar el reloj de trabajo")
	for cuadro in 10:
		h._reloj_vida += 1.0 / 12.0
		h._morder(0.01)
		h._actualizar_sprite()
	verificar(h._masticando_animacion and fuente.contactos == 1 and fuente.intentos == 0
		and h.carga == 0.0 and is_equal_approx(h._reloj_mordida, 0.29),
		"el contacto inicial del alimento se cachea entre ticks sin consultas geométricas nuevas ni mordidas anticipadas")
	h._reloj_mordida = 0.0
	h._morder(0.01)
	h._actualizar_sprite()
	verificar(h.estado == Hormiga.Estado.VOLVIENDO and h.comida == null and h._recuerdo == fuente
		and fuente.contactos == 2 and fuente.intentos == 1 and h.bocados == 1 and h.carga == 1.25
		and not h._masticando_visual and not h._masticando_animacion and Juego.migas_run == saldo,
		"la primera mordida real renueva el contacto, llena el buche y corta el gesto al volver sin cobrar antes de entregar")


func probar_condiciones(h: Hormiga, fuente: FuenteTrabajo, run: Run, caminando: Array) -> void:
	var intentos := fuente.intentos
	var carga := h.carga
	var estados := true
	for estado: Hormiga.Estado in [Hormiga.Estado.EXPLORANDO, Hormiga.Estado.SIGUIENDO,
			Hormiga.Estado.YENDO_A_COMIDA, Hormiga.Estado.VOLVIENDO, Hormiga.Estado.QUIETA]:
		h.estado = estado
		h._actualizar_sprite()
		estados = estados and not h._masticando_animacion and h._cuerpo.region_rect in caminando
	verificar(estados, "explorar, seguir feromonas, viajar, volver y quedar quieta no reutilizan la pose de comer")
	h.estado = Hormiga.Estado.MORDIENDO
	h.rotation = PI
	h._actualizar_sprite()
	verificar(not h._masticando_animacion and is_equal_approx(h.rotation, PI),
		"mirar en dirección opuesta no muestra mandíbulas contra el mueble ni gira la física desde el renderer")
	h.rotation = 0.0
	h.en_pantalla = false
	h._actualizar_sprite()
	var sin_detalle := not h._detalle_bocado and not h._masticando_animacion
	h.en_pantalla = true
	run.camara.zoom = Vector2.ONE * 0.1
	h._actualizar_sprite()
	sin_detalle = sin_detalle and not h._detalle_bocado and not h._masticando_animacion
	verificar(sin_detalle, "fuera de pantalla o lejos de cámara se omite el detalle de masticar")
	run.camara.zoom = Vector2.ONE
	run.retirando = true
	h._actualizar_sprite()
	var fin_corta := not h._masticando_animacion
	run.retirando = false
	run.activa = false
	h._actualizar_sprite()
	fin_corta = fin_corta and not h._masticando_animacion
	run.activa = true
	verificar(fin_corta, "retirada y expedición inactiva cortan el gesto aunque el último contacto siga cacheado")
	fuente.muerta = true
	h._actualizar_sprite()
	var invalido := not h._masticando_animacion
	fuente.muerta = false
	var contacto := h._contacto_visual
	h._contacto_visual = Vector2.INF
	h._actualizar_sprite()
	invalido = invalido and not h._masticando_animacion
	h._contacto_visual = contacto
	h._actualizar_sprite()
	verificar(invalido and h._masticando_animacion and h.carga == carga and fuente.intentos == intentos,
		"comida agotada o contacto no finito no mastican; restaurar condiciones sólo recupera la pose, no el daño")


func estado_real(h: Hormiga, fuente: FuenteTrabajo, run: Run) -> Dictionary:
	# _reloj_vida es el reloj visual que conduce explícitamente el fixture.
	# La pose y _levantando_retazos pueden cambiar; todos estos datos no.
	return {
		"estado": h.estado, "fisica": h.transform, "objetivo": h.objetivo,
		"comida": h.comida.get_instance_id(), "ruta": h._ruta.duplicate(), "indice": h._indice_ruta,
		"meta": h._meta_ruta, "pedido": h._pedido_ruta, "reloj": h._reloj_mordida,
		"dano": h._dano, "intervalo": h._intervalo_mordida, "capacidad": h._capacidad,
		"carga": h.carga, "bocados": h.bocados, "origen": h._carga_origen.duplicate(),
		"muestras": h._retazos.duplicate(), "angulos": h._angulos_retazos.duplicate(),
		"tamanos": h._tamanos_retazos.duplicate(), "origenes": h._origenes_retazos.duplicate(),
		"tiempos": h._tiempos_retazos.duplicate(), "bocado": h._tiempo_bocado,
		"contacto": h._contacto_visual, "mirada": h._angulo_mordida,
		"vida": fuente.vida, "trabajo": fuente.trabajo, "intentos": fuente.intentos,
		"preparaciones": fuente.preparaciones, "contactos": fuente.contactos,
		"migas": Juego.migas_run, "ingresos": run.ingresos.duplicate(),
		"rutas": run.cocina.consultas_ruta, "combo": run.combo,
	}


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
