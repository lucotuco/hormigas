extends Node
## Observabilidad del ensayo F6. La única prueba de entrega usa una miga
## generada normalmente, extracción local y regreso físico; no mide ritmo.
## Los casos administrativos de compras/estado declaran sus saldos y marcas.
const REGISTRO := preload("res://tests/registro_sesion_casa.gd")
const RUN := preload("res://mundo/run.tscn")
const PASO := 1.0 / 60.0
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	var partida := huella(Juego.RUTA_PARTIDA)
	var ajustes := huella(Ajustes.RUTA)
	await probar_descubrimientos()
	await probar_compras_y_metas()
	await probar_entrega_fisica()
	verificar(partida == huella(Juego.RUTA_PARTIDA) and ajustes == huella(Ajustes.RUTA),
		"ni la entrega ni el observador escriben partida o configuración personal")
	Juego.reiniciar_estado()
	print("Registro de percepción: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func huella(ruta: String) -> String:
	return FileAccess.get_sha256(ruta) if FileAccess.file_exists(ruta) else "ausente"


func crear_registro() -> Node:
	var registro := REGISTRO.new()
	add_child(registro)
	registro.set_process(false)
	return registro


func eventos(registro: Node, tipo: String) -> int:
	var cantidad := 0
	for evento: Dictionary in registro.eventos:
		cantidad += int(evento.tipo == tipo)
	return cantidad


func probar_descubrimientos() -> void:
	Juego.reiniciar_estado()
	# Marca administrativa anterior a la sesión: no simula un hallazgo nuevo.
	Juego.registrar_hallazgo_casa("sobre_azucar")
	var registro := crear_registro()
	verificar(not registro.primeros.has("primer_paquete") and eventos(registro, "paquete_abierto") == 0,
		"el progreso existente al comenzar no se atribuye al participante")
	var componente := "casa/carton_inicial#solapa_izquierda"
	var dinero := Juego.migas
	Juego.registrar_componente_proyecto(componente)
	Juego.registrar_componente_proyecto(componente)
	Juego.registrar_hallazgo_casa("bolsa_cereal")
	Juego.registrar_hallazgo_casa("bolsa_cereal")
	Juego.registrar_tesoro_proyecto("casa/alacena_cocina")
	registro._observar_descubrimientos()
	registro._observar_descubrimientos()
	verificar(eventos(registro, "componente_completo") == 1 and eventos(registro, "paquete_abierto") == 1
		and eventos(registro, "escondite_abierto") == 1, "partes, paquetes y escondites tienen un solo evento por descubrimiento")
	verificar(registro.primeros.has("primer_componente") and registro.primeros.has("primer_paquete")
		and registro.primeros.has("primer_escondite") and Juego.migas == dinero,
		"observar las consecuencias no acredita recursos ni modifica su persistencia")
	# La restauración y fundación conservan historia; observar no vuelve a pagar
	# ni a contar las mismas partes. No es una fundación obtenida jugando.
	var guardada := Juego.datos_partida()
	Juego.restaurar_partida(guardada)
	Juego.coronas = 1
	verificar(Juego.fundar_colonia(), "la fixture administrativa puede fundar con su corona declarada")
	registro._observar_descubrimientos()
	verificar(eventos(registro, "componente_completo") == 1 and eventos(registro, "paquete_abierto") == 1
		and eventos(registro, "escondite_abierto") == 1 and Juego.lugar_actual == "casa",
		"restaurar y fundar no fabrican otro hallazgo ni cambian el retorno a casa")
	registro.queue_free()
	await get_tree().process_frame


func probar_compras_y_metas() -> void:
	Juego.reiniciar_estado()
	var registro := crear_registro()
	var antes := eventos(registro, "proxima_meta")
	for i in 50:
		Juego.migas = float(i) * 0.1
		registro._observar_meta()
	verificar(eventos(registro, "proxima_meta") == antes,
		"actualizar el saldo no llena el informe con cincuenta cambios de la misma meta")
	# Sólo la prueba del registro recibe presupuesto: no representa un piloto
	# de balance ni el tiempo requerido para la primera compra.
	Juego.migas = Juego.costo("mas_obreras")
	verificar(Juego.comprar("mas_obreras"), "la compra administrativa usa el método y precio reales")
	var compra: Dictionary = {}
	for evento: Dictionary in registro.eventos:
		if evento.tipo == "compra_mejora" and evento.datos.id == "mas_obreras":
			compra = evento.datos
	verificar(not compra.is_empty() and compra.capacidades.obreras == 2 and compra.capacidades.capacidad == Juego.stat("capacidad")
		and compra.capacidades.llamado == Juego.stat("feromona_cantidad"),
		"la compra registra capacidades reales para contrastarlas con lo que la persona notó")
	registro._observar_meta()
	var despues := eventos(registro, "proxima_meta")
	registro._observar_meta()
	verificar(despues >= antes and eventos(registro, "proxima_meta") == despues,
		"cada cambio de intención se registra una sola vez, sin repetir el progreso")
	var informe: Dictionary = registro.informe()
	var json := JSON.stringify(informe)
	verificar(informe.version == 2 and informe.guardado_personal == false and not "user://" in json
		and not "nombre_jugador" in json and not "niveles_jalea" in json,
		"el informe v2 conserva anonimato local sin rutas ni snapshot de la partida")
	registro.queue_free()
	await get_tree().process_frame


func probar_entrega_fisica() -> void:
	Juego.reiniciar_estado()
	seed(417)
	var run: Run = RUN.instantiate()
	run.preparacion_sincrona = true # QA de señal, no benchmark de preparación.
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.colonia._activa = false
	run.colonia._por_salir = 0
	run.colonia._cola_castas.clear()
	var registro := crear_registro()
	registro._observar_escena(run)
	verificar(run.has_signal("entrega_real"), "la Run ofrece una señal de entrega, distinta del ingreso por premios")
	if not run.has_signal("entrega_real"):
		registro.queue_free()
		run.queue_free()
		await get_tree().process_frame
		return
	# Un bonus legítimo no es una entrega. No se usa para comprar ni se mezcla
	# con la cantidad física que extraemos y transportamos después.
	run.registrar_ingreso(0.125)
	registro._observar_run()
	verificar(registro.primeros.has("primer_ingreso_observado") and not registro.primeros.has("primera_entrega"),
		"un premio puede ser primer ingreso, pero nunca primera entrega de una hormiga")
	var fuente: Comida
	for comida in run.comidas.lista:
		if comida.id == "miga" and comida.position.length() < 180 and run.cocina.libre(comida.position, 12):
			fuente = comida
			break
	verificar(fuente != null and fuente.preparar_material(), "la muestra usa una miga nativa accesible, sin moverla ni cambiar HP/valor")
	if fuente == null:
		registro.queue_free()
		run.queue_free()
		await get_tree().process_frame
		return
	# Sólo posicionamos la trabajadora en un frente para aislar observabilidad.
	# No llamamos Run.depositar ni inventamos carga o destrucciones.
	var h := run.colonia._nacer("obrera", fuente.punto_mordida(Vector2.ZERO, run.radio_actual))
	h.comida = fuente
	h.estado = Hormiga.Estado.MORDIENDO
	h._reloj_mordida = 0
	h._morder(PASO)
	var carga := h.carga
	var saldo := Juego.migas_run
	verificar(carga > 0 and not registro.primeros.has("primera_entrega"), "el bocado en viaje todavía no dispara entrega ni cobro")
	for i in 720:
		if h.carga <= 0:
			break
		run._process(PASO)
		h._process(PASO)
		registro._observar_run()
		await get_tree().process_frame
	verificar(h.carga == 0 and is_equal_approx(Juego.migas_run - saldo, carga),
		"el regreso real acredita exactamente la porción extraída al alcanzar la entrada")
	verificar(registro.primeros.has("primera_entrega") and registro._entregas_observadas == 1
		and is_equal_approx(registro._valor_entregado, carga)
		and is_equal_approx(registro.primeros.primera_entrega.datos.migas, carga),
		"la señal registra una sola entrega exacta aunque ya hubiera otro ingreso")
	run._cerrar()
	registro._observar_run()
	verificar(registro.expediciones.size() == 1 and registro.expediciones[0].entregas_observadas == 1
		and is_equal_approx(registro.expediciones[0].valor_transportado, carga),
		"el resumen separa transporte observado de bonus e ingresos ambientales")
	var cantidad: int = registro._entregas_observadas
	registro._al_entrega_real(123.0)
	verificar(registro._entregas_observadas == cantidad, "los callbacks tardíos de una Run terminada no agregan entregas al ensayo")
	registro.queue_free()
	run.queue_free()
	await get_tree().process_frame


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("OK " if ok else "FALLA ", mensaje)
