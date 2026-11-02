extends Node
## La orden sostenida trabaja el círculo completo, no estaciona obreras en
## su centro. Usa reservas reales y preparación asíncrona, sin tocar partidas.
class FuenteTrabajo extends Comida:
	var danos: Array[float] = []
	var venenos: Array[float] = []
	func preparar_material() -> bool:
		return true
	func punto_contacto(desde: Vector2) -> Vector2:
		return desde
	func morder_local(dano: float, _pos: Vector2, _lado_max := 6.0) -> float:
		danos.append(dano)
		return 0.0
	func aplicar_veneno(dano_por_segundo: float, _duracion: float, _run: Run, _origen := Vector2.INF) -> void:
		venenos.append(dano_por_segundo)

var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	seed(911)
	await probar_area_y_agotamiento()
	await probar_prioridad_manual()
	await probar_cupos_y_elegibilidad()
	await probar_reserva_y_retorno()
	await probar_escala_y_visibilidad()
	await probar_trabajo_rafaga()
	Juego.reiniciar_estado()
	print("Área de feromonas y escala estable: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func verificar(condicion: bool, mensaje: String) -> void:
	total += 1
	if not condicion:
		fallas += 1
	print("OK " if condicion else "FALLA ", mensaje)


func crear_run() -> Run:
	Juego.reiniciar_estado()
	var r: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	r.radio_actual = 620.0
	r.camara.zoom = Vector2.ONE
	r.camara.force_update_scroll()
	# Los recursos nativos siguen en sus nodos, pero esta consulta aislada sólo
	# ve los declarados abajo. No se altera la navegación ni su presupuesto.
	r.comidas._indice.clear()
	return r


func crear_comida(r: Run, pos: Vector2) -> Comida:
	var tipo: Dictionary = r.comidas._tipo_comida("miga").duplicate(true)
	tipo.vida = 100.0
	tipo.recompensa = 20.0
	r.comidas._crear(tipo, pos, 911)
	return r.comidas.lista.back()


func preparar(r: Run, c: Comida) -> void:
	c.preparar_material()
	for paso in 10000:
		if not c.material_preparandose():
			break
		r.preparador_mordiscos.procesar(1000000, 128)
	verificar(c.mordiscos != null and not r.preparacion_sincrona, "el fixture prepara con la cola real sin activar un fallback síncrono")


func probar_area_y_agotamiento() -> void:
	var r := crear_run()
	var centro := Vector2(-220, -140)
	var primera := crear_comida(r, centro + Vector2(72, 0))
	var segunda := crear_comida(r, centro + Vector2(0, -66))
	var h := r.colonia._nacer()
	h.position = centro
	h._olfato = 15.0
	r.feromonas.mantener_en(centro)
	verificar(primera.distancia_a(centro) > h._olfato and segunda.distancia_a(centro) > h._olfato,
		"ambas comidas quedan fuera del olfato puntual que antes dejaba la hormiga inmóvil")
	h._pensar()
	var elegida := h.comida
	var restante := segunda if elegida == primera else primera
	verificar(is_instance_valid(elegida) and elegida in [primera, segunda] and h.estado == Hormiga.Estado.YENDO_A_COMIDA,
		"mantener el cursor sobre suelo asigna trabajo dentro del círculo sin exigir comida bajo su centro")
	if not is_instance_valid(elegida):
		r.queue_free()
		await get_tree().process_frame
		return
	preparar(r, elegida)
	elegida.morder(elegida.vida_max * 2.0)
	# Sin soltar ni refrescar selección: el cache incluye la vecina viva y la
	# reserva agotada no puede obligar a esperar hasta el próximo tick de cursor.
	h._pensar()
	verificar(r.feromonas.activa and h.comida == restante and h.estado == Hormiga.Estado.YENDO_A_COMIDA,
		"agotar un recurso durante el clic sostenido toma otra comida del área inmediatamente")
	verificar(elegida.trabajadoras == 0 and restante.trabajadoras == 1,
		"cambiar de objetivo libera la reserva vieja y conserva una sola nueva")
	h._comidas_sin_ruta[restante.get_instance_id()] = h._reloj_vida + 5.0
	h._pensar()
	verificar(h.comida == null and h.estado == Hormiga.Estado.SIGUIENDO,
		"un recurso excluido por navegación no se reasigna en un bucle bajo el llamado")
	r.queue_free()
	await get_tree().process_frame


func probar_prioridad_manual() -> void:
	var r := crear_run()
	var centro := Vector2(-220, -140)
	var vieja := crear_comida(r, centro + Vector2(50, 0))
	var nueva := crear_comida(r, centro)
	var h := r.colonia._nacer("obrera", centro + Vector2(-25, 0))
	h.comida = vieja
	h.estado = Hormiga.Estado.YENDO_A_COMIDA
	h._proxima_busqueda_llamado = h._reloj_vida + 100.0
	r.feromonas.mantener_en(nueva.position)
	h._pensar()
	verificar(r.feromonas.objetivo_comida == nueva and h.comida == nueva and vieja.trabajadoras == 0 and nueva.trabajadoras == 1,
		"apuntar expresamente a otra comida reemplaza el trabajo automático retenido y libera su reserva, aun durante el enfriamiento")
	r.feromonas.mantener_en(centro + Vector2(0, 25))
	r.feromonas._actualizar_cercanas()
	h._pensar()
	verificar(r.feromonas.objetivo_comida == null and h.comida == nueva and nueva.trabajadoras == 1,
		"volver a señalar suelo conserva el trabajo útil del área, sin alternar objetivos ni duplicar puestos")
	var otra := r.colonia._nacer("obrera", vieja.position)
	otra.comida = vieja
	otra.estado = Hormiga.Estado.MORDIENDO
	r.feromonas.mantener_en(vieja.position)
	r.feromonas._actualizar_cercanas()
	h._pensar()
	verificar(r.feromonas.objetivo_comida == vieja and h.comida == nueva and vieja.trabajadoras == 1 and nueva.trabajadoras == 1,
		"señalar un recurso lleno no roba su puesto ni cancela el trabajo alternativo reservado")
	r.queue_free()
	await get_tree().process_frame


func probar_cupos_y_elegibilidad() -> void:
	var r := crear_run()
	var centro := Vector2(-220, -140)
	var primera := crear_comida(r, centro)
	var segunda := crear_comida(r, centro + Vector2(45, 0))
	var grupo: Array[Hormiga] = []
	for i in 8:
		var h := r.colonia._nacer()
		h.position = centro + Vector2(-i, 0)
		grupo.append(h)
	r.feromonas.mantener_en(centro)
	for h in grupo:
		h._pensar()
	verificar(primera.trabajadoras == 1 and segunda.trabajadoras == 1,
		"apuntar a una miga reparte el exceso hacia sus vecinas sin superar cupos")
	var trabajadoras := primera.trabajadoras + segunda.trabajadoras
	r.feromonas._actualizar_cercanas()
	for h in grupo:
		h._pensar()
	verificar(primera.trabajadoras + segunda.trabajadoras == trabajadoras,
		"un nuevo muestreo no expulsa una reserva válida ni duplica trabajadoras")
	for h in grupo:
		h.comida = null
		h.detener()
	var voladora := r.colonia._nacer("voladora", centro)
	primera.muerta = true
	segunda.muerta = true
	var pesado := FragmentoCasa.new()
	r.comidas.add_child(pesado)
	pesado.iniciar(centro, 50.0, 3)
	r.comidas._indexar(pesado)
	r.feromonas._actualizar_cercanas()
	voladora._pensar()
	verificar(voladora.comida == null and pesado.trabajadoras == 0,
		"la orden manual tampoco autoriza a una voladora a transportar fragmentos de muro")
	r.feromonas.mantener_en(Vector2(r.radio_actual + 100.0, 0))
	r.feromonas._actualizar_cercanas()
	verificar(r.feromonas.seleccionadas.is_empty() and not r.feromonas.llama_a(voladora),
		"mantener el cursor fuera del territorio no reserva trabajo ni llama hormigas")
	r.queue_free()
	await get_tree().process_frame


func probar_reserva_y_retorno() -> void:
	var r := crear_run()
	var centro := Vector2(-220, -140)
	var c := crear_comida(r, centro)
	var h := r.colonia._nacer("obrera", centro + Vector2(-5, 0))
	h.comida = c
	h.estado = Hormiga.Estado.MORDIENDO
	h._reloj_mordida = 0.73
	r.feromonas.mantener_en(centro)
	c.preparar_material()
	for i in 4:
		r.feromonas._actualizar_cercanas()
		h._pensar()
	verificar(h.comida == c and h.estado == Hormiga.Estado.MORDIENDO and c.trabajadoras == 1,
		"el llamado conserva una reserva mientras se prepara su máscara, sin reubicarla ni duplicarla")
	verificar(is_equal_approx(h._reloj_mordida, 0.73),
		"actualizar el área no reinicia el reloj del mordisco ya empezado")
	h.carga = 2.0
	h._volver()
	var entrada := h.objetivo
	r.feromonas._actualizar_cercanas()
	h._pensar()
	verificar(h.estado == Hormiga.Estado.VOLVIENDO and h.objetivo == entrada and h.carga == 2.0 and not r.feromonas.llama_a(h),
		"el llamado no secuestra un retorno con carga ni cambia su entrada de descarga")
	r.feromonas.soltar()
	verificar(r.feromonas._comidas_area.is_empty() and r.feromonas._ids_area.is_empty(),
		"soltar libera también el cache de recursos del área")
	r.queue_free()
	await get_tree().process_frame


func probar_escala_y_visibilidad() -> void:
	var r := crear_run()
	var obrera := r.colonia._nacer("obrera", Vector2.ZERO)
	var reina := r.colonia._nacer("reina", Vector2.ZERO)
	var mini := r.colonia._nacer("mini", Vector2.ZERO)
	var estable := true
	var visible := true
	for zoom: float in [0.08, 0.25, 0.5, 1.0, 4.0]:
		r.camara.zoom = Vector2.ONE * zoom
		r.camara.force_update_scroll()
		r.colonia._actualizar_visibilidad()
		for h in [obrera, reina, mini]:
			estable = estable and h.scale == Vector2.ONE * h.escala_casta
			visible = visible and h.en_pantalla and h.visible
	verificar(estable, "obrera, reina y mini conservan exactamente la escala de su casta en todo el zoom")
	verificar(visible, "cambiar zoom conserva el culling de las hormigas dentro de cámara")
	var nueva := r.colonia._nacer("roja", Vector2.ZERO)
	verificar(nueva.scale == Vector2.ONE * nueva.escala_casta,
		"nacer con zoom distinto tampoco aplica una escala compensatoria")
	nueva.position = Vector2(1000000, 1000000)
	r.colonia._actualizar_visibilidad()
	verificar(not nueva.en_pantalla and not nueva.visible and nueva.scale == Vector2.ONE * nueva.escala_casta,
		"una hormiga fuera de cámara se oculta sin cambiar tamaño ni perder su estado")
	r.queue_free()
	await get_tree().process_frame


func probar_trabajo_rafaga() -> void:
	var r := crear_run()
	var fuente := FuenteTrabajo.new()
	var datos: Dictionary = r.comidas._tipo_comida("miga").duplicate(true)
	datos.vida = 1000.0
	r.comidas.add_child(fuente)
	fuente.configurar(datos, 911)
	fuente.position = Vector2(-220, -140)
	var h := r.colonia._nacer("roja", fuente.position + Vector2(-5, 0))
	h.comida = fuente
	h.estado = Hormiga.Estado.MORDIENDO
	h._dano = 8.0
	var intervalo := h._intervalo_mordida
	h._reloj_mordida = 0.0
	h._morder(0.01)
	verificar(fuente.danos.size() == 1 and is_equal_approx(fuente.danos[0], 8.0),
		"fuera de Ráfaga la hormiga emite exactamente su daño base")
	h._reloj_mordida = 0.5
	h._morder(0.1)
	verificar(is_equal_approx(h._reloj_mordida, 0.4) and fuente.danos.size() == 1,
		"el reloj normal de trabajo avanza sin adelantar otra mordida")
	r.poderes.carga_entregas = r.poderes.entregas_necesarias()
	verificar(r.activar_rafaga(), "el poder real se activa con las entregas necesarias del CSV")
	var multiplicador := Juego.stat("rafaga_multiplicador_dano")
	h._reloj_mordida = 0.5
	h._morder(0.1)
	verificar(is_equal_approx(h._reloj_mordida, 0.5 - 0.1 * Juego.stat("rafaga_multiplicador_ritmo")) and fuente.danos.size() == 1,
		"Ráfaga acelera sólo el reloj de mordida con el ritmo declarado en CSV")
	h._reloj_mordida = 0.0
	h._morder(0.01)
	verificar(fuente.danos.size() == 2 and multiplicador > 1.0 and is_equal_approx(fuente.danos[1], 8.0 * multiplicador),
		"Ráfaga multiplica el trabajo emitido por Hormiga, no solamente el texto del poder")
	verificar(fuente.venenos.size() == 2 and is_equal_approx(fuente.venenos[1], 8.0 * 0.8 * multiplicador),
		"el veneno emitido captura el mismo multiplicador una sola vez")
	verificar(h._dano == 8.0 and h._intervalo_mordida == intervalo,
		"el poder no altera la copia de daño base ni el intervalo de mordida")
	r.poderes.cerrar()
	h._reloj_mordida = 0.0
	h._morder(0.01)
	verificar(fuente.danos.size() == 3 and is_equal_approx(fuente.danos[2], 8.0),
		"al terminar Ráfaga las siguientes mordidas recuperan exactamente su daño normal")
	r.retirando = true
	h._reloj_mordida = 0.0
	h._morder(0.01)
	verificar(fuente.danos.size() == 3 and fuente.venenos.size() == 3,
		"la retirada no emite otra mordida ni veneno aunque el reloj esté listo")
	r.queue_free()
	await get_tree().process_frame
