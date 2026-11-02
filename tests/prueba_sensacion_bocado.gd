extends Node
## Aísla presentación/sonido: el doble entrega porciones declaradas y la
## extracción geométrica real sigue cubierta por porciones_reales/mordiscos.
class FuenteMuestra extends Comida:
	var muestra := Rect2(111, 222, 12, 9)
	var tamano_real := Vector2(4, 3)
	var intentos := 0
	var lista := true
	func preparar_material() -> bool:
		return lista
	func material_preparandose() -> bool:
		return not lista
	func punto_contacto(desde: Vector2) -> Vector2:
		return desde + Vector2(1, 0)
	func morder_local(dano: float, _pos: Vector2, _lado_max := 6.0) -> float:
		intentos += 1
		if dano <= 0 or muerta:
			return 0
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


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Juego.reiniciar_estado()
	probar_curvas()
	probar_audio()
	await probar_ciclo()
	Juego.reiniciar_estado()
	print("Sensación de bocado: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func probar_curvas() -> void:
	verificar(AspectoHormiga.preparar_bocado(-1) == 0 and AspectoHormiga.preparar_bocado(1.5) == 1, "la anticipación queda acotada sin extender ni cambiar el reloj de mordida")
	verificar(AspectoHormiga.preparar_bocado(0.8) > AspectoHormiga.preparar_bocado(0.4), "el cuerpo prepara la mordida hacia el final del intervalo real")
	var origen := Vector2(-6, 2)
	var pinza := Vector2(5.8, 0)
	verificar(AspectoHormiga.levantar_retazo(origen, pinza, 0) == origen and AspectoHormiga.levantar_retazo(origen, pinza, 1) == pinza, "la muestra empieza exactamente en el material retirado y termina en la pinza")
	var medio := AspectoHormiga.levantar_retazo(origen, pinza, AspectoHormiga.DURACION_LEVANTADO * 0.5)
	verificar(medio.x > origen.x and medio.x < pinza.x and medio.y < origen.lerp(pinza, 0.5).y, "levantar describe un arco corto, no un salto instantáneo ni una escala inventada")
	verificar(AspectoHormiga.pulso_bocado(-0.1, 0.2) == 0 and AspectoHormiga.pulso_bocado(0, 0.2) == 1 and AspectoHormiga.pulso_bocado(0.3, 0.2) == 0, "chasquido y entrega son pulsos visuales finitos")


func probar_audio() -> void:
	var familias := ["mordida", "mordida_carton", "mordida_madera", "mordida_piedra", "levantar"]
	var firmas := {}
	for nombre: String in familias:
		var sonido := AudioSuave.crear(nombre)
		var pico := 0
		for i in range(0, sonido.data.size(), 2):
			pico = maxi(pico, absi(sonido.data.decode_s16(i)))
		verificar(sonido.get_length() <= 0.1 and sonido.get_length() > 0.03 and pico > 100 and pico < 32767 and absi(sonido.data.decode_s16(sonido.data.size() - 2)) < 120, nombre + ": timbre breve, sin clipping y con salida suave")
		firmas[hash(sonido.data)] = true
	verificar(firmas.size() == familias.size(), "comida, cartón, madera, piedra y recogida no reutilizan el mismo timbre")
	var anteriores: Dictionary = Sonido._ultimo.duplicate()
	Sonido._ultimo.clear()
	var admitidos := 0
	for i in 1000:
		if Sonido._admitir(familias[i % familias.size()], i / 1000.0):
			admitidos += 1
	verificar(admitidos <= 6 and admitidos >= 5 and Sonido._ultimo.size() == 1, "mil intentos de familias mezcladas comparten como máximo seis inicios de material por segundo")
	verificar(Sonido._admitir("deposito", 1.0) and Sonido._admitir("comprar", 1.0), "el crujido no bloquea la confirmación independiente de entrega o compra")
	Sonido._ultimo = anteriores
	verificar(Sonido.detalle_material(0.1, 1) and not Sonido.detalle_material(0.1, 500) and Sonido.detalle_material(1, 500), "la primera obrera conserva sonido y una colonia lejana silencia el detalle")
	verificar(Sonido._reproductores.size() == Sonido.TAMANO_POOL, "el banco mantiene un pool global fijo, sin voces por hormiga ni por astilla")
	var voz := Sonido._siguiente
	for i in 100:
		Sonido.tocar(familias[i % familias.size()])
	verificar(Sonido.silenciado and Sonido._siguiente == voz and Sonido._ultimo == anteriores, "silenciar descarta las interacciones sin iniciar voces ni consumir el presupuesto de sonido")


func probar_ciclo() -> void:
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true # Fixture de presentación, no medición de preparación.
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	var fuente := FuenteMuestra.new()
	var datos: Dictionary = Juego.comidas[0].duplicate()
	datos.vida = 100
	datos.recompensa = 125
	fuente.configurar(datos, 417)
	run.comidas.add_child(fuente)
	fuente.position = Vector2(-400, -300)
	var h := run.colonia._nacer("obrera", fuente.position + Vector2(-10, 0))
	h._capacidad = 20
	h._fase = 0
	h.comida = fuente
	h.estado = Hormiga.Estado.MORDIENDO
	verificar(h._sonido_bocado(fuente) == "mordida" and is_instance_valid(run.objetivo_practica) and h._sonido_bocado(run.objetivo_practica) == "mordida_carton", "el cartón tutorial tiene timbre propio y la comida conserva su crujido")
	var forma_original := fuente.forma
	var papeles := true
	for forma: String in DibujoHallazgo.FORMAS:
		fuente.forma = forma
		papeles = papeles and h._sonido_bocado(fuente) == "mordida_carton"
	verificar(papeles, "los tres envoltorios nuevos usan papel/cartón sin consultar catálogos por hormiga")
	fuente.forma = forma_original
	var fragmento := FragmentoCasa.new()
	verificar(h._sonido_bocado(fragmento) == "levantar", "recoger un montón usa un gesto sonoro distinto de arrancar material")
	fragmento.free()
	fuente.lista = false
	h._reloj_mordida = 0.23
	var objetivo_previo := h.objetivo
	for i in 5:
		h._morder(0.2)
	verificar(h.estado == Hormiga.Estado.MORDIENDO and h.comida == fuente and h.objetivo == objetivo_previo and h._reloj_mordida == 0.23 and h.carga == 0 and fuente.intentos == 0, "esperar material presupuestado conserva frente, reserva y reloj sin extraer ni reubicar")
	fuente.lista = true
	# Sprites sin textura: permiten probar transforms en headless sin atlas
	# falso, framebuffer, física, tween o nodos adicionales por cada muestra.
	h._cuerpo = Sprite2D.new()
	h.add_child(h._cuerpo)
	h._carga_sprite = Sprite2D.new()
	h.add_child(h._carga_sprite)
	h._tipo_animacion = h.casta
	h._evolucion_animacion = h._evolucion
	h._animacion.assign([Rect2(0, 0, 72, 72)])
	run.camara.zoom = Vector2.ONE
	var hijos := h.get_child_count()
	var posicion := h.position
	var reloj := 0.0
	for i in 5:
		h._reloj_vida = i * 0.5
		fuente.muestra.position.x += 12
		h._reloj_mordida = 0
		h._morder(0.1)
		reloj = h._reloj_mordida
	verificar(fuente.intentos == 5 and h.carga == 6.25 and h.bocados == 5 and Juego.migas_run == 0, "la presentación no retrasa mordidas, inventa entregas ni modifica carga o cantidad de bocados")
	verificar(h._retazos.size() == 3 and h._origenes_retazos.size() == 3 and h._tiempos_retazos.size() == 3 and h.get_child_count() == hijos, "cinco mordidas guardan a lo sumo tres muestras y metadatos, sin nodos por astilla")
	verificar(h._tamanos_retazos == [Vector2(4, 3), Vector2(4, 3), Vector2(4, 3)], "el levantado conserva el tamaño world de los huecos sin agrandar ni miniaturizar retazos")
	h._reloj_vida = h._tiempos_retazos[0]
	h._detalle_bocado = true
	verificar(h._posicion_retazo(0).is_equal_approx(h.to_local(h._origenes_retazos[0])), "el origen visual se copia por valor desde el bocado real")
	h._reloj_vida += 0.5
	verificar(h._posicion_retazo(0).is_equal_approx(Vector2(5.8, 0)), "después de levantar la porción permanece agarrada en la boca")
	var secundarios := true
	for i in [1, 2]:
		h._detalle_bocado = true
		h._reloj_vida = h._tiempos_retazos[i]
		var desde := h._posicion_retazo(i)
		h._reloj_vida += AspectoHormiga.DURACION_LEVANTADO * 0.5
		var medio := h._posicion_retazo(i)
		h._reloj_vida += AspectoHormiga.DURACION_LEVANTADO
		var hasta := h._posicion_retazo(i)
		secundarios = secundarios and desde.is_equal_approx(h.to_local(h._origenes_retazos[i])) and not medio.is_equal_approx(desde) and not medio.is_equal_approx(hasta)
	verificar(secundarios, "el segundo y tercer retazo también atraviesan origen, arco y agarre: no aparecen fijos ni saltan de golpe")
	h._reloj_vida = h._tiempos_retazos.back() + AspectoHormiga.DURACION_LEVANTADO + 0.01
	h._reloj_mordida = h._intervalo_mordida * 0.25
	var reloj_pose := h._reloj_mordida
	var rotacion := h.rotation
	for i in 50:
		h._actualizar_sprite()
	verificar(not h._levantando_retazos, "el último redibujo asienta las muestras al terminar 0,18 s y después apaga su animación")
	verificar(h.position == posicion and h.rotation == rotacion and h._reloj_mordida == reloj_pose and h.carga == 6.25 and fuente.intentos == 5, "actualizar la pose no mueve la hormiga física, no cambia el reloj ni vuelve a extraer")
	verificar(not h._cuerpo.position.is_zero_approx() and not h._cuerpo.scale.is_equal_approx(Vector2.ONE / 3), "sólo el sprite prepara el gesto, con el cuerpo físico intacto")
	verificar(is_equal_approx(h._escala_retazo(h._retazos[0]).x * h._retazos[0].size.x * absf(h.global_scale.x), 4), "la pose del cuerpo no escala el material transportado")
	run.camara.zoom = Vector2.ONE * 0.1
	h._actualizar_sprite()
	verificar(not h._detalle_bocado and h._cuerpo.position.is_zero_approx() and h._cuerpo.rotation == 0 and h.carga == 6.25, "lejos de cámara se omite el gesto detallado sin omitir carga ni trabajo")
	run.camara.zoom = Vector2.ONE
	verificar(reloj > 0 and is_equal_approx(reloj, h._intervalo_mordida - 0.1 * run.factor_ritmo()), "el intervalo de trabajo conserva exactamente su cálculo previo")
	var muestra := h._retazos[0]
	fuente.queue_free()
	await get_tree().process_frame
	h._actualizar_sprite()
	verificar(h._carga_sprite.visible and h._carga_sprite.region_rect == muestra and h.carga == 6.25, "la muestra sigue transportándose aunque se libere el nodo fuente")
	# Un regreso físico corto, no una acreditación desde la animación.
	h.position = Vector2(22, 0)
	h.objetivo = Vector2.ZERO
	h.estado = Hormiga.Estado.VOLVIENDO
	h._meta_ruta = Vector2.ZERO
	h._pedido_ruta = Vector2.ZERO
	h._ruta = PackedVector2Array([Vector2.ZERO])
	h._indice_ruta = 0
	run.retirando = true
	for i in 10:
		if h.carga <= 0:
			break
		h._caminar(0.1)
	verificar(h.carga == 0 and Juego.migas_run == 6.25 and h._retazos.is_empty() and h._origenes_retazos.is_empty() and h._tiempos_retazos.is_empty() and not h._carga_sprite.visible, "el regreso acredita una sola entrega real y limpia de inmediato todas las muestras, sin cargas fantasma")
	var credito := Juego.migas_run
	h._actualizar_sprite()
	verificar(Juego.migas_run == credito and h._tiempo_descarga == h._reloj_vida and h._cuerpo.position.x > 0, "el asentado de entrega es sólo visual y no vuelve a cobrar el material")
	run.queue_free()
	await get_tree().process_frame


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)
