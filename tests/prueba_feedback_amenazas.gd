extends Node
## Contratos de presentación y contrajuego. No mide FPS ni demuestra que un
## timbre resulte agradable: eso requiere escucha y una sesión humana.
var total := 0
var fallas := 0
var _ruta_audios := ""


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	if OS.get_environment("EXPORTAR_AUDIO_QA") == "1":
		_ruta_audios = ProjectSettings.globalize_path("res://.godot/qa/audio_feedback")
		verificar(DirAccess.make_dir_recursive_absolute(_ruta_audios) == OK,
			"la exportación audible usa sólo el directorio QA ignorado")
	var habia_partida := FileAccess.file_exists(Juego.RUTA_PARTIDA)
	var huella := hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) if habia_partida else 0
	probar_audio()
	probar_efectos()
	await probar_amenazas()
	var intacta := habia_partida == FileAccess.file_exists(Juego.RUTA_PARTIDA)
	if habia_partida:
		intacta = intacta and huella == hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA))
	verificar(intacta and not Juego.guardado_habilitado, "la prueba no escribe la partida personal")
	Juego.reiniciar_estado()
	print("Feedback y amenazas: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func verificar(condicion: bool, mensaje: String) -> void:
	total += 1
	if not condicion:
		fallas += 1
	print("OK " if condicion else "FALLA ", mensaje)


func probar_audio() -> void:
	var firmas: Dictionary = {}
	for nombre: String in Sonido.SONIDOS:
		var audio := AudioSuave.crear(nombre)
		var pico := 0
		for i in range(0, audio.data.size(), 2):
			pico = maxi(pico, absi(audio.data.decode_s16(i)))
		verificar(audio.format == AudioStreamWAV.FORMAT_16_BITS and audio.mix_rate == 22050
			and pico > 100 and pico < 32767 and audio.get_length() <= 0.9
			and absi(audio.data.decode_s16(0)) < 2
			and absi(audio.data.decode_s16(audio.data.size() - 2)) < 120,
			nombre + ": síntesis propia corta, sin clipping y sin discontinuidad de inicio/final")
		firmas[hash(audio.data)] = true
		if _ruta_audios != "":
			verificar(audio.save_to_wav(_ruta_audios.path_join(nombre + ".wav")) == OK,
				nombre + ": exportación WAV de la misma síntesis usada por el juego")
	verificar(firmas.size() == Sonido.SONIDOS.size(), "cada gesto tiene un timbre diferente")
	verificar(AudioSuave.crear("deposito").data == AudioSuave.crear("deposito").data,
		"el banco se genera de forma determinista sin archivos externos")
	var ultimo := Sonido._ultimo.duplicate()
	Sonido._ultimo.clear()
	var material := 0
	var familias := ["mordida", "mordida_carton", "mordida_madera", "levantar", "mordida_metal"]
	for i in 1000:
		if Sonido._admitir(familias[i % familias.size()], i / 1000.0):
			material += 1
	verificar(material <= 6 and material >= 5, "los materiales comparten seis inicios por segundo como máximo")
	verificar(Sonido._admitir("deposito", 1.0) and Sonido._admitir("comprar", 1.0)
		and Sonido._admitir("epico", 1.0) and not Sonido._admitir("epico", 1.1),
		"entrega/UI/épico son independientes y el épico no admite spam")
	Sonido._ultimo = ultimo
	verificar(Sonido._elegir_voz("comprar", 2) >= Sonido.VOCES_MUNDO
		and Sonido._elegir_voz("mordida", 0) < Sonido.VOCES_MUNDO
		and Sonido._reproductores.size() == Sonido.TAMANO_POOL,
		"la interfaz tiene voces reservadas dentro de un pool fijo")
	var voz := Sonido._siguiente
	for i in 100:
		Sonido.entrega(i)
		Sonido.entrega(i, true)
	verificar(Sonido._siguiente == voz and Sonido._ultimo == ultimo,
		"silenciar no inicia voces ni consume puertas de audio")
	verificar(Sonido.ESCALA_ENTREGA.size() == 5 and Sonido.ESCALA_ENTREGA[0] == 0.8
		and Sonido.ESCALA_ENTREGA[0] * 0.988 > 0.65
		and Sonido.ESCALA_ENTREGA.back() * 1.012 < 1.6,
		"la entrega usa cinco grados pentatónicos sin chocar el clamp ni subir infinitamente")
	Sonido.detener_mundo()
	var detenido := true
	for i in Sonido._reproductores.size():
		if i < Sonido.VOCES_MUNDO:
			detenido = detenido and not Sonido._reproductores[i].playing
	verificar(detenido, "cerrar detiene las voces del mundo sin crear nodos")


func probar_efectos() -> void:
	var e := Efectos.new()
	add_child(e)
	verificar(not e.is_processing() and e.get_child_count() == 0, "un único lienzo vacío no procesa ni crea emisores")
	var saldo := Juego.migas
	seed(717)
	var azar_esperado := randf()
	seed(717)
	for i in 1000:
		e.entrega(Vector2.ZERO, 1.0, 32)
	verificar(e._particulas.size() == 8 and e._ondas.size() == 1,
		"mil entregas simultáneas producen un solo pulso acotado")
	e.epico(Vector2.ZERO, Color("f0d277"), 70.0)
	var particulas := e._particulas.size()
	for i in 100:
		e.epico(Vector2.ZERO, Color.WHITE)
	verificar(e._particulas.size() == particulas and e._ondas.size() == 3,
		"la celebración no multiplica ráfagas por callback repetido")
	verificar(randf() == azar_esperado and Juego.migas == saldo,
		"el feedback no consume azar de la IA ni acredita dinero")
	e._process(2.0)
	e._process(0.0)
	verificar(e._particulas.is_empty() and e._ondas.is_empty() and not e.is_processing(),
		"al agotarse los efectos el lienzo vuelve a reposo")
	var libres := e._libres.size()
	e.chispas(Vector2.ZERO, Color.WHITE, 5, 1)
	verificar(e._libres.size() == libres - 5 and e._particulas.size() == 5,
		"las chispas reutilizan objetos del pool liberado")
	e.chispas(Vector2.ZERO, Color.WHITE, 10000)
	verificar(e._particulas.size() == Efectos.MAX_PARTICULAS
		and e._particulas.size() + e._libres.size() <= Efectos.MAX_PARTICULAS
		and e.get_child_count() == 0, "el estrés respeta el techo de memoria y cero nodos por partícula")
	e.numero(Vector2.ZERO, 2, Color.WHITE)
	e.limpiar()
	e.entrega(Vector2.ZERO, 1)
	e.epico(Vector2.ZERO, Color.WHITE)
	e.chispas(Vector2.ZERO, Color.WHITE, 6)
	e.texto(Vector2.ZERO, "fixture", Color.WHITE)
	e.habilidad(Vector2.ZERO, Vector2.ONE, Color.WHITE)
	verificar(e._particulas.is_empty() and e._ondas.is_empty() and e._textos.is_empty()
		and e._marcas.is_empty() and not e.is_processing(), "limpiar es terminal incluso ante callbacks tardíos")
	e.queue_free()


func probar_amenazas() -> void:
	Juego.reiniciar_estado()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.colonia._nacer("obrera", Vector2(80, 0))
	verificar(run.colonia.cantidad() == 1, "el contrajuego conserva una trabajadora real, sin población ficticia")
	for lugar: String in Mundos.ORDEN:
		Juego.lugar_actual = lugar
		var esperas_validas := true
		for i in 20:
			var segundos := Eventos.espera_entre_amenazas()
			esperas_validas = esperas_validas and segundos >= Eventos.parametro("espera_min") and segundos <= Eventos.parametro("espera_max")
		verificar(esperas_validas, lugar + ": cadencia dentro de sus límites de CSV, sin intervalo por hormiga")
	Juego.lugar_actual = "casa"
	var eventos := run.eventos
	verificar(eventos._proxima_amenaza() == "arana" and eventos._proxima_amenaza() == "cucaracha"
		and eventos._proxima_amenaza() == "arana", "las variantes alternan con la identidad original del destino")
	var bandada := eventos.aparecer("paloma")
	verificar(bandada.size() == 3 and eventos.amenazas_activas() == 3
		and eventos.grupos_de_amenaza() == 1, "la bandada cuenta tres individuos y un grupo")
	var restante := eventos.aparecer("cucaracha")
	verificar(restante.size() == 1 and eventos.amenazas_activas() == Eventos.MAX_AMENAZAS
		and eventos.aparecer("paloma").is_empty() and eventos.aparecer("cucaracha").is_empty(),
		"bandada y variante ocupan los cuatro lugares reales, sin atravesar el límite")
	for enemigo in restante:
		enemigo._terminar()
	for ave in bandada:
		ave._terminar()
	for tipo in ["cucaracha", "escarabajo"]:
		var enemigo: Evento = eventos.aparecer(tipo)[0]
		var pos := enemigo.position
		enemigo._process(0.5)
		verificar(enemigo.position == pos and enemigo.botin == 0 and enemigo.atrapadas == 0
			and enemigo._aviso_restante > 0, tipo + ": primero se muestra el aviso, sin robo ni movimiento")
		verificar(enemigo.radio() == float(Evento.DATOS[tipo].radio),
			tipo + ": el tamaño y el área de clic no crecen al alejar la cámara")
		enemigo._aviso_restante = 0.0
		enemigo._atrapar(run.colonia.hormigas.duplicate())
		verificar(run.colonia.cantidad() == 1 and enemigo.atrapadas == 0,
			tipo + ": la última trabajadora no se pierde por una amenaza")
		var golpeadas := Juego.estadistica("amenazas_vencidas")
		var saldo := Juego.migas
		var ingreso := Juego.migas_run
		for i in enemigo.golpes_max:
			enemigo.golpear()
		var despues := Juego.migas_run
		enemigo.golpear()
		verificar(enemigo.resuelto and enemigo.premio_cobrado and despues > ingreso
			and eventos.premiar(enemigo) == 0.0 and Juego.migas_run == despues and Juego.migas == saldo
			and Juego.estadistica("amenazas_vencidas") == golpeadas + 1,
			tipo + ": la victoria se celebra y paga sólo una vez")
	probar_robo_real(run)
	probar_approach_formas(run)
	probar_ultima_porcion_y_origen(run)
	var pendiente: Evento = eventos.aparecer("cucaracha")[0]
	var tardia := run.comidas._crear(alimento_nativo("azucar"), Vector2(280, 100), 517)
	var masa := run.resistencia_extraida
	var saldo := Juego.migas
	var ingreso_cierre := Juego.migas_run
	run._detener_extraccion()
	verificar(tardia.retirar_por_amenaza() == 0 and not tardia.muerta and tardia.vida == tardia.vida_max
		and run.resistencia_extraida == masa and Juego.migas_run == ingreso_cierre,
		"el retiro entero también rechaza callbacks tras el silbato sin tocar masa ni dinero")
	verificar(not pendiente.golpear() and not eventos.pisar(pendiente.position)
		and eventos.premiar(pendiente) == 0 and eventos.aparecer("rata").is_empty(),
		"cerrada la extracción, ni clics ni spawns ni premios siguen trabajando")
	eventos.cerrar()
	verificar(eventos.activos.is_empty() and not eventos.is_processing()
		and eventos.mas_urgente() == null and Juego.migas == saldo,
		"el cierre vacía enemigos sin fabricar una victoria")
	run.queue_free()
	await get_tree().process_frame


func probar_robo_real(run: Run) -> void:
	# Sólo la fixture permite preparación síncrona sobre un alimento pequeño;
	# ni daño ni extracción se simulan y la fuente conserva su silueta nativa.
	run.preparacion_sincrona = true
	var datos: Dictionary = {}
	for alimento in Juego.comidas:
		if alimento.id == "azucar":
			datos = alimento
			break
	var fuente := run.comidas._crear(datos, Vector2(250, 250), 171)
	var cucaracha: Evento = run.eventos.aparecer("cucaracha")[0]
	cucaracha._comida = fuente
	cucaracha._aviso_restante = 0
	cucaracha.position = fuente.position + Vector2(-32, 0)
	for i in 600:
		if cucaracha.estado == "cargando":
			break
		cucaracha._recolector(1.0 / 60.0)
	var aire_real := fuente.mordiscos != null and fuente.mordiscos.aire_exterior(fuente.to_local(cucaracha.position))
	verificar(cucaracha.estado == "cargando" and aire_real and fuente.alcanza_desde(cucaracha.position),
		"cucaracha: camina hasta un puesto real de aire exterior sobre el azúcar girado")
	var vida := fuente.vida
	var ingreso := Juego.migas_run
	var saldo := Juego.migas
	cucaracha._recolector(Evento.AVISO_ROBO - 0.1)
	verificar(cucaracha.botin == 0 and fuente.vida == vida,
		"cucaracha: el aviso de carga no retira material por anticipado")
	for i in 600:
		if cucaracha.botin > 0 or cucaracha.resuelto:
			break
		cucaracha._recolector(1.0 / 60.0)
	var retirado := vida - fuente.vida
	var valor_real := fuente.recompensa * retirado / fuente.vida_max * Juego.stat("multiplicador_migas")
	var porcion := fuente._porcion_reciente
	print("ROBO QA: posicion=", cucaracha.position, " rotacion_fuente=", fuente.rotation,
		" aire=", aire_real, " preparado=", fuente.mordiscos != null, " hp_retirado=", retirado,
		" porcion=", porcion, " botin=", cucaracha.botin, " valor_real=", valor_real,
		" ingreso_antes=", ingreso, " ingreso_despues=", Juego.migas_run, " estado=", cucaracha.estado)
	verificar(retirado > 0 and retirado < vida and porcion.has_area()
		and porcion.size.x <= 6.00001 and porcion.size.y <= 6.00001
		and is_equal_approx(cucaracha.botin, valor_real),
		"cucaracha: roba sólo la porción real de seis por lado, con valor proporcional al HP retirado")
	verificar(Juego.migas_run == ingreso and Juego.migas == saldo and cucaracha.estado == "huyendo",
		"cucaracha: robar no acredita al jugador y no convierte el resto del alimento en dinero")
	cucaracha._terminar()
	verificar(Juego.migas_run == ingreso, "cucaracha: escapar sin victoria no regala botín")
	run.comidas.soltar_fragmento(Vector2(260, 260), 37.5, 0)
	var resto: FragmentoCasa = run.comidas.fragmentos.back()
	var valor_resto := resto.recompensa
	var escarabajo: Evento = run.eventos.aparecer("escarabajo")[0]
	escarabajo._comida = resto
	escarabajo._aviso_restante = 0
	escarabajo.estado = "cargando"
	escarabajo._reloj_accion = Evento.AVISO_ROBO
	escarabajo.position = resto.position + Vector2(-resto.radio - 2, 0)
	escarabajo._recolector(Evento.AVISO_ROBO - 0.1)
	verificar(not resto.muerta and escarabajo.botin == 0,
		"escarabajo: el montón sigue disponible durante el aviso")
	escarabajo._recolector(0.2)
	verificar(resto.muerta and not run.comidas.fragmentos.has(resto)
		and is_equal_approx(escarabajo.botin, valor_resto) and Juego.migas_run == ingreso,
		"escarabajo: el mismo montón deja el suelo y pasa al botín, sin pago automático")
	var premio := maxf(ingreso * Juego.stat("botin_eventos"), Eventos.BOTIN_BASE) + valor_resto * 1.5
	for i in escarabajo.golpes_max:
		escarabajo.golpear()
	verificar(is_equal_approx(Juego.migas_run - ingreso, premio) and Juego.migas == saldo,
		"escarabajo: ganar recupera el botín y el premio declarado exactamente una vez")
	var despues := Juego.migas_run
	var lista := run.comidas.lista.duplicate()
	var fragmentos := run.comidas.fragmentos.duplicate()
	run.comidas.lista.clear()
	run.comidas.fragmentos.clear()
	for tipo in ["cucaracha", "escarabajo"]:
		var vacio: Evento = run.eventos.aparecer(tipo)[0]
		vacio._aviso_restante = 0
		vacio._comida = null
		vacio._recolector(5.0)
		verificar(vacio.botin == 0 and vacio.estado == "huyendo" and Juego.migas_run == despues,
			tipo + ": sin fuente real no inventa un recurso, una extracción ni un premio")
		vacio._terminar()
	run.comidas.lista.assign(lista)
	run.comidas.fragmentos.assign(fragmentos)


func probar_approach_formas(run: Run) -> void:
	for id in ["frutilla", "queso"]:
		for angulo in [0.71, 2.29]:
			var datos: Dictionary = {}
			for alimento in Juego.comidas:
				if alimento.id == id:
					datos = alimento
					break
			var fuente := run.comidas._crear(datos, Vector2(300, 200), 271)
			fuente.rotation = angulo # Rota el cuerpo real; nunca la máscara a otro punto.
			var enemigo: Evento = run.eventos.aparecer("cucaracha")[0]
			enemigo._comida = fuente
			enemigo._aviso_restante = 0
			enemigo.position = fuente.position + Vector2(-60, 0)
			var vida := fuente.vida
			var ingreso := Juego.migas_run
			for i in 600:
				if enemigo.estado == "cargando" or enemigo.resuelto:
					break
				enemigo._recolector(1.0 / 60.0)
			var exterior := fuente.mordiscos != null and fuente.mordiscos.aire_exterior(fuente.to_local(enemigo.position))
			verificar(enemigo.estado == "cargando" and exterior and fuente.alcanza_desde(enemigo.position),
				"%s rotada %.2f: approach hasta un puesto accesible de la silueta real" % [id, angulo])
			enemigo._recolector(Evento.AVISO_ROBO - 0.1)
			verificar(enemigo.botin == 0 and fuente.vida == vida and Juego.migas_run == ingreso,
				"%s rotada %.2f: el aviso no anticipa daño ni cobro" % [id, angulo])
			for i in 600:
				if enemigo.botin > 0 or enemigo.resuelto:
					break
				enemigo._recolector(1.0 / 60.0)
			var retirado := vida - fuente.vida
			var valor_real := fuente.recompensa * retirado / fuente.vida_max * Juego.stat("multiplicador_migas")
			var porcion := fuente._porcion_reciente
			print("ROBO QA ", id, " rotacion=", angulo, " exterior=", exterior,
				" hp=", retirado, " region=", porcion, " botin=", enemigo.botin,
				" esperado=", valor_real, " estado=", enemigo.estado)
			verificar(retirado > 0 and retirado < vida and porcion.has_area()
				and porcion.size.x <= 6.00001 and porcion.size.y <= 6.00001
				and is_equal_approx(enemigo.botin, valor_real) and enemigo.estado == "huyendo"
				and Juego.migas_run == ingreso,
				"%s rotada %.2f: una porción local conserva el valor y el resto del recurso" % [id, angulo])
			enemigo._terminar()


func alimento_nativo(id: String) -> Dictionary:
	for datos in Juego.comidas:
		if datos.id == id:
			return datos
	return {}


func ultimo_pixel(run: Run, semilla: int) -> Comida:
	var fuente := run.comidas._crear(alimento_nativo("miga"), Vector2(250, 100), semilla)
	fuente.preparar_material()
	var hp_pixel := fuente.vida_max / float(fuente.mordiscos._vivos[0])
	for i in 8192:
		if fuente.mordiscos._vivos[0] <= 1:
			break
		var contacto := fuente.punto_mordida(fuente.position + Vector2(-30, 0), run.radio_actual, false)
		fuente.morder_local(hp_pixel, contacto)
	verificar(not fuente.muerta and fuente.mordiscos._vivos[0] == 1,
		"el último píxel de la fixture se alcanza mediante extracción real, sin falsear HP")
	return fuente


func probar_ultima_porcion_y_origen(run: Run) -> void:
	verificar(Juego.stat("bonus_destruir") > 0, "los retiros se prueban con bonus positivo, no desactivándolo")
	for tipo in ["cucaracha", "paloma"]:
		var fuente := ultimo_pixel(run, 417)
		var valor := fuente.recompensa * fuente.vida / fuente.vida_max * Juego.stat("multiplicador_migas")
		var saldo := Juego.migas_run
		var destruidas := Juego.comidas_destruidas_run
		var senales := {"cantidad": 0}
		fuente.destruida.connect(func(_c): senales.cantidad += 1)
		var enemigo: Evento = run.eventos.aparecer(tipo)[0]
		# La bandada está cubierta aparte; acá se aísla un solo picotazo.
		if tipo == "paloma":
			for otro in run.eventos.activos.duplicate():
				if otro != enemigo and otro.tipo == "paloma":
					otro._terminar()
		enemigo._comida = fuente
		enemigo._aviso_restante = 0
		if tipo == "cucaracha":
			enemigo.position = fuente.position + Vector2(-32, 0)
			for i in 1000:
				if enemigo.botin > 0 or enemigo.resuelto:
					break
				enemigo._recolector(1.0 / 60.0)
		else:
			enemigo.estado = "comiendo"
			enemigo._reloj_accion = 0
			enemigo._paloma(0.1)
		verificar(fuente.muerta and fuente.vida <= 0.001 and senales.cantidad == 1
			and is_equal_approx(enemigo.botin, valor) and Juego.migas_run == saldo
			and Juego.comidas_destruidas_run == destruidas,
			tipo + ": robar el último píxel sólo retira la fuente, sin bonus ni victoria de la colonia")
		enemigo._terminar()
	var entera := run.comidas._crear(alimento_nativo("azucar"), Vector2(260, 100), 417)
	var rata: Evento = run.eventos.aparecer("rata")[0]
	rata._comida = entera
	rata._aviso_restante = 0
	rata.position = entera.position
	var saldo := Juego.migas_run
	var destruidas := Juego.comidas_destruidas_run
	rata._rata(0.1)
	verificar(entera.muerta and is_equal_approx(rata.botin, entera.recompensa * Juego.stat("multiplicador_migas"))
		and Juego.migas_run == saldo and Juego.comidas_destruidas_run == destruidas,
		"rata: retirar el alimento entero tampoco dispara el bonus ni cuenta como comida de la colonia")
	rata._terminar()
	# Un robo parcial no deja una marca pegada que anule la futura victoria
	# auténtica de la colonia sobre el mismo alimento.
	var parcial := run.comidas._crear(alimento_nativo("azucar"), Vector2(270, 100), 417)
	parcial.preparar_material()
	var contacto := parcial.punto_mordida(parcial.position + Vector2(-40, 0), run.radio_actual, false)
	var robado := parcial.morder_por_amenaza(parcial.vida_max, contacto)
	verificar(robado > 0 and not parcial.muerta and not parcial.retiro_amenaza and Juego.migas_run == saldo,
		"una extracción enemiga parcial restaura el origen sin pagar")
	for i in 1000:
		if parcial.muerta:
			break
		contacto = parcial.punto_mordida(parcial.position + Vector2(-40, 0), run.radio_actual, false)
		parcial.morder_local(parcial.vida_max, contacto)
	var bonus := parcial.recompensa * Juego.stat("bonus_destruir") * Juego.stat("multiplicador_migas")
	verificar(parcial.muerta and is_equal_approx(Juego.migas_run - saldo, bonus)
		and Juego.comidas_destruidas_run == destruidas + 1,
		"después del robo parcial, completar con trabajo normal conserva su bonus real")
	var envoltorio: Comida
	for comida in run.comidas.lista:
		if run.comidas._hallazgos.has(comida.get_instance_id()):
			envoltorio = comida
			break
	verificar(is_instance_valid(envoltorio), "la regresión del paquete usa un envoltorio real generado")
	if is_instance_valid(envoltorio):
		var reservado: Dictionary = run.comidas._hallazgos[envoltorio.get_instance_id()]
		var pos := envoltorio.position
		saldo = Juego.migas_run
		envoltorio.retirar_por_amenaza()
		var contenido_real := false
		for comida in run.comidas.lista:
			if comida.id == reservado.contenido.id and comida.position == pos:
				contenido_real = is_equal_approx(comida.recompensa, float(reservado.contenido.recompensa))
		verificar(contenido_real and Juego.migas_run == saldo and not Juego.hallazgo_casa_abierto(reservado.id),
			"un enemigo destapa el contenido físico sin cobrar bonus ni adjudicar el hallazgo al jugador")
