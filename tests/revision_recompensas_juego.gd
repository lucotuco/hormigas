extends Node
## Evidencia Full HD sobre la Run real: mapa, HUD, mordidas y retornos reales.
## La fixture sólo coloca obreras en el frente y seis migas nativas a igual
## distancia para controlar la tanda. Nunca fabrica carga ni llama depositar.
## El último buche se amplía a20 para observar consumir una miga completa;
## daño, HP, valor, tamaño de porción y movimiento conservan sus datos reales.
const PASO := 1.0 / 60.0
const ZOOM_NORMAL := 0.85
const ZOOM_ALEJADO := 0.3
var total := 0
var fallas := 0
var run: Run
var fuentes: Array[Comida] = []
var _habia_partida := false
var _huella_partida := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Juego.reiniciar_estado()
	_habia_partida = FileAccess.file_exists(Juego.RUTA_PARTIDA)
	_huella_partida = hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) if _habia_partida else 0
	if DisplayServer.get_name() == "headless":
		verificar(false, "la revisión de recompensas requiere renderer real")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	get_window().size = Vector2i(1920, 1080)
	if not Graficos.listo:
		await Graficos.preparado
	seed(20261104)
	run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true # QA de aspecto, no benchmark de preparación.
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	# Los mismos procesos normales se avanzan abajo y sólo se congelan durante
	# las capturas. No hay un tablero sustituto ni HUD pintado para la foto.
	run.colonia._activa = false
	run.colonia._por_salir = 0
	run.colonia._cola_castas.clear()
	run.eventos._reloj_amenaza = 1e9
	run.eventos._reloj_dorada = 1e9
	zoom(ZOOM_NORMAL)
	await primera_entrega()
	await avanzar_reposo(2.0)
	await tanda_de_entregas()
	await avanzar_reposo(2.0)
	await destruccion_real()
	await probar_cierre()
	run.queue_free()
	await get_tree().process_frame
	var intacta := _habia_partida == FileAccess.file_exists(Juego.RUTA_PARTIDA)
	if _habia_partida:
		intacta = intacta and _huella_partida == hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA))
	verificar(intacta and not Juego.guardado_habilitado, "las capturas y el cierre no modifican la partida personal")
	Juego.reiniciar_estado()
	print("Recompensas en juego real: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func zoom(valor: float) -> void:
	run.camara._manual = true
	run.camara._zoom_objetivo = valor
	run.camara.zoom = Vector2.ONE * valor
	run.camara.position = Vector2.ZERO
	run.camara.force_update_scroll()
	run.efectos.queue_redraw()


func miga_nativa(pos: Vector2, semilla: int) -> Comida:
	for datos in Juego.comidas:
		if datos.id == "miga":
			var c := run.comidas._crear(datos, pos, semilla)
			fuentes.append(c)
			return c
	return null


func obrera_con_bocado(fuente: Comida) -> Hormiga:
	verificar(is_instance_valid(fuente) and fuente.preparar_material(), "la fuente conserva cuerpo y preparación nativos")
	var punto := fuente.punto_mordida(Vector2.ZERO, run.radio_actual)
	var h := run.colonia._nacer("obrera", punto)
	h.comida = fuente
	h.estado = Hormiga.Estado.MORDIENDO
	h._reloj_mordida = 0
	var vida := fuente.vida
	h._morder(PASO)
	h._actualizar_sprite()
	var valor := fuente.recompensa * (vida - fuente.vida) / fuente.vida_max * Juego.stat("multiplicador_migas")
	verificar(h.carga > 0 and h.estado == Hormiga.Estado.VOLVIENDO and h._retazos.size() == 1
		and is_equal_approx(h.carga, valor), "la carga es exactamente el retazo que perdió el alimento, antes de cobrar")
	return h


func primera_entrega() -> void:
	var fuente: Comida
	for c in run.comidas.lista:
		if c.id == "miga" and c.position.length() < 180 and run.cocina.libre(c.position, 12):
			fuente = c
			break
	verificar(fuente != null, "la primera entrega usa una miga generada por el mapa, no un pago simulado")
	if fuente == null:
		return
	fuentes.append(fuente)
	var h := obrera_con_bocado(fuente)
	var carga := h.carga
	verificar(carga > 0 and carga < 1 and Juego.migas_run == 0,
		"la primera carga fraccional todavía no es ingreso mientras viaja")
	var antes := await captura("recompensas_00_carga_real")
	await retornar([h])
	# El contador interpola y las migas tienen una salida escalonada. Avanzar
	# sus cuadros normales permite leer ambos, sin fabricar ni redondear dinero.
	await avanzar_reposo(0.12)
	verificar(h.carga == 0 and is_equal_approx(Juego.migas_run, carga)
		and is_equal_approx(run.ingresos[0], carga), "sólo llegar físicamente al nido acredita el valor exacto de la primera carga")
	verificar(run.hud._lbl_ganancia.visible and run.hud._lbl_ganancia.text == "+" + Efectos.formatear_importe(carga)
		and run.hud._lbl_migas.text == Efectos.formatear_importe(carga), "HUD y pago muestran la primera fracción real sin redondearla a cero")
	var despues := await captura("recompensas_01_primera_entrega_normal")
	comprobar_numero("deposito", carga, 22.0)
	var entrada := Vector2i(run.a_pantalla(Vector2.ZERO))
	verificar(diferencias(antes, despues, Rect2i(entrada + Vector2i(-160, -160), Vector2i(320, 260))) > 40,
		"la primera entrega cambia píxeles de forma localizada y visible alrededor de la entrada")
	zoom(ZOOM_ALEJADO)
	await captura("recompensas_02_primera_entrega_alejada")
	comprobar_numero("deposito", carga, 22.0)
	zoom(ZOOM_NORMAL)


func tanda_de_entregas() -> void:
	var obreras: Array[Hormiga] = []
	var suma := 0.0
	for i in 6:
		var punto := Vector2.from_angle(TAU * i / 6.0) * 115.0
		var fuente := miga_nativa(punto, 710 + i)
		var h := obrera_con_bocado(fuente)
		obreras.append(h)
		suma += h.carga
	var antes := Juego.migas_run
	await captura("recompensas_03_tanda_transportando")
	await retornar(obreras)
	await avanzar_reposo(0.12) # Termina el tramo del contador sin congelar vuelos o racha.
	verificar(is_equal_approx(Juego.migas_run - antes, suma) and run.combo == 6
		and run.hud._lbl_migas.text == Efectos.formatear_importe(Juego.migas_run),
		"seis obreras entregan seis cargas físicas sin multiplicar el libro real por la racha")
	verificar(is_equal_approx(suma_depositos(), suma) and is_equal_approx(run.hud._ganancia_reciente, suma),
		"el número agrupado y el HUD suman exactamente las seis entregas, no la última ni un pago ficticio")
	verificar(run.hud._lbl_racha.visible and run.hud._racha_visible > 0
		and run.hud._lbl_racha.label_settings.font_size >= 30,
		"la racha real de cinco entregas produce un anuncio grande sobre el mapa")
	await captura("recompensas_04_racha_normal")
	comprobar_numero("deposito", suma, 22.0)
	zoom(ZOOM_ALEJADO)
	await captura("recompensas_05_racha_alejada")
	comprobar_numero("deposito", suma, 22.0)
	verificar(run.hud._vuelo_migas.cantidad > 0 and run.hud._vuelo_migas.cantidad <= VueloMigas.MAXIMO,
		"varias entregas conservan un vuelo perceptible con pool fijo de cuarenta migas")
	zoom(ZOOM_NORMAL)


func destruccion_real() -> void:
	var fuente := miga_nativa(Vector2(160, 60), 908)
	verificar(fuente.preparar_material(), "el bonus se prueba sobre otra miga de HP y valor nativos")
	var valor := fuente.recompensa * Juego.stat("multiplicador_migas")
	var bonus := valor * Juego.stat("bonus_destruir")
	var estado := {"destruida": false}
	fuente.destruida.connect(func(_c): estado.destruida = true)
	var punto := fuente.punto_mordida(Vector2.ZERO, run.radio_actual)
	var h := run.colonia._nacer("obrera", punto)
	h._capacidad = 20 # Estrés declarado del buche, no del daño ni del valor.
	h.comida = fuente
	h.estado = Hormiga.Estado.MORDIENDO
	h._reloj_mordida = 0
	var antes := Juego.migas_run
	for i in 1200:
		if estado.destruida:
			break
		await paso([h])
	verificar(estado.destruida and h.estado == Hormiga.Estado.VOLVIENDO
		and is_equal_approx(h.carga, valor) and is_equal_approx(Juego.migas_run - antes, bonus),
		"al agotarse el material, sólo se acredita el bonus: el valor del cuerpo aún viaja con la obrera")
	await captura("recompensas_06_bonus_normal")
	comprobar_numero("bonus", bonus, 32.0)
	zoom(ZOOM_ALEJADO)
	await captura("recompensas_07_bonus_alejado")
	comprobar_numero("bonus", bonus, 32.0)
	zoom(ZOOM_NORMAL)
	await retornar([h])
	verificar(is_equal_approx(Juego.migas_run - antes, valor + bonus),
		"la destrucción y el retorno posterior conservan exactamente cuerpo más bonus, sin doble ingreso")
	await captura("recompensas_08_regreso_final")


func paso(obreras: Array[Hormiga]) -> void:
	run._process(PASO)
	for h in obreras:
		if is_instance_valid(h) and h.estado != Hormiga.Estado.QUIETA:
			h._process(PASO)
	run.colonia._process(PASO)
	for c in fuentes:
		if is_instance_valid(c):
			c._process(PASO)
	run.efectos._process(PASO)
	run.hud._process(PASO)
	run.hud._vuelo_migas._process(PASO)
	await get_tree().process_frame


func retornar(obreras: Array[Hormiga]) -> void:
	for i in 720:
		var pendientes := 0
		for h in obreras:
			if h.carga > 0:
				pendientes += 1
			elif h.estado != Hormiga.Estado.QUIETA:
				h.detener()
		if pendientes == 0:
			return
		await paso(obreras)
	verificar(false, "todas las cargas llegan usando la navegación y velocidad normales")


func avanzar_reposo(segundos: float) -> void:
	for i in int(ceil(segundos / PASO)):
		await paso([])


func suma_depositos() -> float:
	var suma := 0.0
	for t in run.efectos._textos:
		if t.clase == "deposito":
			suma += t.cantidad
	return suma


func comprobar_numero(clase: String, cantidad: float, tamano_minimo: float) -> void:
	var valor := 0.0
	var visible := false
	var sin_ceros := true
	for t in run.efectos._textos:
		if t.clase == clase:
			valor += t.cantidad
			visible = visible or Efectos.tamano_numero_pantalla(t) >= tamano_minimo
			sin_ceros = sin_ceros and t.texto != "+0" and t.texto != "+0.0"
	var dibujado := run.efectos.depositos_dibujados > 0 if clase == "deposito" else not run.efectos._rect_textos.is_empty()
	if clase == "deposito" and cantidad < 1.0:
		dibujado = dibujado and run.efectos.fracciones_dibujadas > 0
	if clase == "bonus":
		# El contador de fracciones corresponde sólo a depósitos. Esta miga
		# pequeña no emite nombre, y se dejó vencer la tanda anterior: el único
		# texto vivo es el bonus y su único rectángulo proviene del draw real.
		dibujado = run.efectos._textos.size() == 1 and run.efectos._textos[0].clase == "bonus" \
			and run.efectos._rect_textos.size() == 1
	verificar(is_equal_approx(valor, cantidad) and visible and sin_ceros
		and dibujado,
		"%s: importe exacto sin+0 y mínimo%.0fpx en el renderer a zoom%.2f" % [clase, tamano_minimo, run.camara.zoom.x])


func probar_cierre() -> void:
	var e := run.efectos
	verificar(e._particulas.size() <= Efectos.MAX_PARTICULAS and e._ondas.size() <= Efectos.MAX_ONDAS
		and e._textos.size() <= Efectos.MAX_TEXTOS and e._rect_textos.size() <= Efectos.MAX_TEXTOS_VISIBLES
		and run.hud._vuelo_migas.migas.size() == VueloMigas.MAXIMO,
		"las entregas y la destrucción usan pools acotados, sin nodos por número o por miga")
	run._cerrar()
	var ingreso := Juego.migas_run
	e.deposito(Vector2.ZERO, 0.125, 99)
	run.hud.registrar_ganancia(0.125)
	verificar(e._textos.is_empty() and e._particulas.is_empty() and e._ondas.is_empty()
		and run.hud._vuelo_migas.cantidad == 0 and not run.hud._lbl_ganancia.visible
		and not run.hud._lbl_racha.visible and Juego.migas_run == ingreso,
		"el cierre y callbacks visuales tardíos no dejan números, vuelos ni pagos falsos")
	await captura("recompensas_09_cierre")


func captura(nombre: String) -> Image:
	for i in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var imagen := get_viewport().get_texture().get_image()
	verificar(imagen.get_size() == Vector2i(1920, 1080)
		and imagen.save_png("res://.godot/qa/" + nombre + ".png") == OK, "captura Run real Full HD: " + nombre)
	return imagen


func diferencias(a: Image, b: Image, rect: Rect2i) -> int:
	var cantidad := 0
	var limite := rect.intersection(Rect2i(Vector2i.ZERO, a.get_size()))
	for y in range(limite.position.y, limite.end.y, 2):
		for x in range(limite.position.x, limite.end.x, 2):
			cantidad += int(a.get_pixel(x, y) != b.get_pixel(x, y))
	return cantidad


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("OK " if ok else "FALLA ", mensaje)
