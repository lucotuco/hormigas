extends Node
## Secuencia real de un bocado y su regreso. Sólo detiene la simulación entre
## capturas para ver las poses; nunca mueve la hormiga física con la animación.
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	if not Graficos.listo:
		await Graficos.preparado
	for nombre in ["mordida", "mordida_carton", "mordida_madera", "mordida_piedra", "levantar", "deposito"]:
		var audio := AudioSuave.crear(nombre)
		comprobar(audio.save_to_wav("res://.godot/qa/sensacion_" + nombre + ".wav") == OK, "muestra QA de sonido " + nombre)
	Juego.niveles = {"mordida_madera": 1}
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true # Capturas de presentación, no benchmark de preparación.
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.hud.hide()
	run.niebla.hide()
	run.eventos.hide()
	var carton: PiezaCasa
	var madera: PiezaCasa
	for pieza in run.comidas.partes:
		if pieza.pieza.get("practica", false):
			carton = pieza
		elif pieza.pieza.get("perfil", "") == "silla_inicial":
			madera = pieza
	await secuencia(run, carton, "carton")
	await secuencia(run, madera, "madera")
	var envoltorios: Array[Comida] = []
	for alimento in run.comidas.lista:
		if DibujoHallazgo.tiene_forma(alimento.forma):
			envoltorios.append(alimento)
	comprobar(envoltorios.size() == 3, "el fixture conserva los tres encuentros de papel de la Casa")
	for envoltorio in envoltorios:
		await secuencia_envoltorio(run, envoltorio)
	run.queue_free()
	await get_tree().process_frame
	print("Revisión sensación: %d fallas." % fallas)
	get_tree().quit(0 if fallas == 0 else 1)


func secuencia(run: Run, fuente: PiezaCasa, nombre: String) -> void:
	if not is_instance_valid(fuente):
		comprobar(false, "existe la fuente " + nombre)
		return
	comprobar(fuente.preparar_material(), nombre + ": la fixture prepara el atlas antes de las capturas")
	var punto := fuente.punto_mordida(Vector2.ZERO, run.radio_actual)
	var h := run.colonia._nacer("obrera", punto)
	h._dano = 10.0 # QA: una porción local sólida, nunca daño bulk.
	h._capacidad = 1
	h.estado = Hormiga.Estado.MORDIENDO
	h.comida = fuente
	h.rotation = (fuente.material_cercano(punto) - punto).angle()
	h._reloj_vida = 10.0
	h._reloj_mordida = h._intervalo_mordida * 0.2
	run.camara.zoom = Vector2.ONE * 3.4
	run.camara.position = fuente.position + Vector2(-25, 0)
	run.camara.force_update_scroll()
	h._actualizar_sprite()
	await captura(nombre + "_01_preparar")
	var posicion := h.position
	var vida_antes := fuente.vida
	h._reloj_mordida = 0
	h._morder(1.0 / 60)
	fuente._process(0.14)
	h._actualizar_sprite()
	comprobar(h.carga > 0 and fuente.vida < vida_antes and h._retazos.size() == 1, nombre + ": se desprende una porción real antes de animarla")
	if h._retazos.is_empty():
		h.queue_free()
		return
	var region := h._retazos[0]
	var tamano := h._tamanos_retazos[0]
	var credito_antes := Juego.migas_run
	await captura(nombre + "_02_desprender")
	h._reloj_vida += 0.08
	h._actualizar_sprite()
	await captura(nombre + "_03_levantar")
	h._reloj_vida += 0.3
	h._actualizar_sprite()
	await captura(nombre + "_04_transportar")
	comprobar(h.position == posicion and h._retazos[0] == region and h._tamanos_retazos[0] == tamano and Juego.migas_run == credito_antes, nombre + ": las poses conservan posición física, región, tamaño real y valor")
	var carga := h.carga
	for i in 720:
		if h.carga <= 0:
			break
		h._process(1.0 / 60)
		await get_tree().process_frame
	run.camara.position = h.position
	run.camara.force_update_scroll()
	h._actualizar_sprite()
	comprobar(h.carga == 0 and h._retazos.is_empty() and not h._carga_sprite.visible and is_equal_approx(Juego.migas_run - credito_antes, carga), nombre + ": sólo el regreso físico entrega y limpia la muestra")
	await captura(nombre + "_05_entregar")
	h.queue_free()
	await get_tree().process_frame


## Tres estados del mismo objeto nativo: cerrado, un retazo real y abierto.
## Se amplía sólo el buche del fixture para no simular viajes entre capturas;
## nunca se cambia vida, daño geométrico, tamaño de porción ni valor del papel.
func secuencia_envoltorio(run: Run, fuente: Comida) -> void:
	var id := fuente.id
	var nombre := "envoltorio_" + fuente.forma
	var pos := fuente.position
	comprobar(fuente.preparar_material(), nombre + ": máscara completa antes de la presentación")
	var punto := fuente.punto_mordida(Vector2.ZERO, run.radio_actual)
	var h := run.colonia._nacer("obrera", punto)
	h._capacidad = 1000 # Fixture de aspecto: conserva hasta tres muestras, no mil.
	h.estado = Hormiga.Estado.MORDIENDO
	h.comida = fuente
	h.rotation = (fuente.punto_contacto(punto) - punto).angle()
	h._reloj_vida = 10
	h._reloj_mordida = h._intervalo_mordida * 0.2
	run.camara.zoom = Vector2.ONE * 7.0
	run.camara.position = pos
	run.camara.force_update_scroll()
	h._actualizar_sprite()
	await captura(nombre + "_01_cerrado")
	var vida := fuente.vida
	for i in 32:
		if h.carga > 0:
			break
		h._reloj_mordida = 0
		h._morder(1.0 / 60)
		h._reloj_vida += h._intervalo_mordida
	fuente._process(0.1)
	comprobar(h.carga > 0 and fuente.vida < vida and not fuente.muerta and h._retazos.size() == 1, nombre + ": el papel pierde la misma porción que empieza a levantar la hormiga")
	if h._retazos.is_empty():
		h.queue_free()
		return
	h._reloj_vida = h._tiempos_retazos[0] + AspectoHormiga.DURACION_LEVANTADO * 0.5
	h._actualizar_sprite()
	await captura(nombre + "_02_desprender")
	var datos := CatalogoHallazgos.por_envoltorio(id)
	var completo := false
	for i in 1000:
		if not is_instance_valid(fuente) or fuente.muerta:
			completo = true
			break
		if h.estado == Hormiga.Estado.MORDIENDO:
			h._reloj_vida += h._intervalo_mordida
			h._reloj_mordida = 0
			h._morder(1.0 / 60)
		else:
			# El borde cambia cuando se vacía papel. Se llega al nuevo frente
			# por movimiento normal, no cambiando la posición desde la pose.
			h._process(1.0 / 60)
			await get_tree().process_frame
		if is_instance_valid(fuente):
			fuente._process(0.14)
	await get_tree().process_frame
	var contenido := false
	for comida in run.comidas.lista:
		contenido = contenido or (is_instance_valid(comida) and comida.id == datos.comida and comida.position.distance_to(pos) < 0.01)
	h._reloj_vida += 0.3
	h._actualizar_sprite()
	comprobar(completo and contenido and Juego.hallazgo_casa_abierto(datos.id) and h._retazos.size() <= 3, nombre + ": aparece su contenido real, el hallazgo queda recordado y el dibujo sigue limitado a tres retazos")
	await captura(nombre + "_03_abierto")
	h.queue_free()
	await get_tree().process_frame


func captura(nombre: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var imagen := get_viewport().get_texture().get_image()
	imagen.save_png("res://.godot/qa/sensacion_" + nombre + ".png")
	if nombre.begins_with("envoltorio_"):
		# El Full HD queda intacto; el detalle es sólo otro artefacto de QA.
		imagen.get_region(Rect2i(560, 240, 800, 600)).save_png("res://.godot/qa/sensacion_" + nombre + "_detalle.png")


func comprobar(ok: bool, mensaje: String) -> void:
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + mensaje)
