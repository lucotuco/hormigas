extends Node
## Contratos de gesto y timbre; no afirma agrado humano ni mide rendimiento
## con headless. Sólo reutiliza datos reales y síntesis local determinista.
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	var habia_partida := FileAccess.file_exists(Juego.RUTA_PARTIDA)
	var huella := hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) if habia_partida else 0
	probar_gesto()
	probar_timbres()
	probar_definicion()
	var intacta := habia_partida == FileAccess.file_exists(Juego.RUTA_PARTIDA)
	if habia_partida:
		intacta = intacta and huella == hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA))
	verificar(intacta and not Juego.guardado_habilitado, "la revisión no modifica la partida personal")
	print("Dirección de material: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func probar_gesto() -> void:
	var neutra := AspectoHormiga.postura_bocado(0, 0, 0, false, 0)
	var apoyar := AspectoHormiga.postura_bocado(1, 0, 0, false, 0)
	var extraer := AspectoHormiga.postura_bocado(0, 1, 0, true, 0, 1)
	var entregar := AspectoHormiga.postura_bocado(0, 0, 1, false, 0)
	verificar(neutra.origin == Vector2.ZERO and neutra.x.is_equal_approx(Vector2(1.0 / 3.0, 0)),
		"la postura neutra conserva exactamente el cuerpo de escala nativa")
	verificar(apoyar.origin.x > 0 and extraer.origin.x < -1.8 and entregar.origin.x > 0,
		"apoyo, tirón y descarga tienen direcciones corporales distintas")
	verificar(apoyar.x.length() < neutra.x.length() and apoyar.y.length() > neutra.y.length(),
		"el esfuerzo comprime el cuerpo, sin ampliar la hormiga física ni el material")
	var acotadas := true
	for material in range(-1, 5):
		for i in range(13):
			var t := i / 12.0
			var pose := AspectoHormiga.postura_bocado(t, 1.0 - t, t, true, i * 0.7, material)
			acotadas = acotadas and pose.is_finite() and pose.origin.length() < 3.5
			acotadas = acotadas and pose.x.length() * 3.0 <= 1.026 and pose.y.length() * 3.0 <= 1.046
	verificar(acotadas, "todos los materiales conservan gestos pequeños y finitos independientes del zoom")
	verificar(AspectoHormiga.pulso_bocado(0.08, 0.19) > 0.65
		and AspectoHormiga.pulso_bocado(0.25, 0.19) == 0
		and AspectoHormiga.pulso_bocado(0, 0) == 0,
		"el tirón se lee en el siguiente tick visual y termina sin un pulso infinito")
	var origen := Vector2(-7, 1)
	var pinza := Vector2(5.8, 0)
	var medio := AspectoHormiga.levantar_retazo(origen, pinza, AspectoHormiga.DURACION_LEVANTADO * 0.5)
	verificar(AspectoHormiga.levantar_retazo(origen, pinza, 0) == origen
		and AspectoHormiga.levantar_retazo(origen, pinza, AspectoHormiga.DURACION_LEVANTADO) == pinza
		and medio.x > origen.x and medio.x < pinza.x and medio.y < 0.0,
		"la porción une origen real y pinza con un arco corto, no se inventa otra pieza")
	verificar(AspectoHormiga.DURACION_LEVANTADO * 12 >= 3
		and AspectoHormiga.DURACION_LEVANTADO < 0.35,
		"el levantado dura tres ticks visuales sin imponer una espera al reloj de extracción")


func probar_timbres() -> void:
	seed(58912)
	var azar_esperado := randf()
	seed(58912)
	var audios := {}
	var firmas := {}
	var nodos_antes := Sonido.get_child_count()
	for nombre: String in AudioSuave.TEXTURAS:
		var audio := AudioSuave.crear(nombre)
		audios[nombre] = audio
		firmas[hash(audio.data)] = true
		var pico := 0
		for i in range(0, audio.data.size(), 2):
			pico = maxi(pico, absi(audio.data.decode_s16(i)))
		verificar(audio.mix_rate == 22050 and audio.format == AudioStreamWAV.FORMAT_16_BITS
			and pico > 100 and pico < 32767
			and audio.get_length() <= (0.151 if nombre == "deposito" else 0.1)
			and absi(audio.data.decode_s16(0)) < 2
			and absi(audio.data.decode_s16(audio.data.size() - 2)) < 120,
			nombre + ": textura breve, con ataque/salida suaves y sin clipping")
	verificar(firmas.size() == AudioSuave.TEXTURAS.size() and randf() == azar_esperado,
		"las siete texturas son distintas sin consumir el azar de la simulación")
	verificar(AudioSuave.crear("mordida_madera").data == audios.mordida_madera.data,
		"el banco se reproduce de forma determinista sin descargas ni archivos")
	verificar(energia_frecuencia(audios.mordida_metal, 710) > energia_frecuencia(audios.mordida_metal, 107) * 3.0
		and energia_frecuencia(audios.mordida_madera, 190) > energia_frecuencia(audios.mordida_madera, 710) * 3.0,
		"metal y madera no sólo cambian de nombre: tienen resonancias físicas separadas")
	verificar(energia_frecuencia(audios.deposito, 392) > energia_frecuencia(audios.deposito, 107) * 3.0
		and energia_frecuencia(audios.mordida_carton, 392) < energia_frecuencia(audios.deposito, 392),
		"el roce de cartón deja espacio tonal para la confirmación de entrega")
	var ultimo: Dictionary = Sonido._ultimo.duplicate()
	Sonido._ultimo.clear()
	var inicios := 0
	var familias := ["mordida", "mordida_carton", "mordida_madera", "mordida_metal", "mordida_piedra", "levantar"]
	for i in range(1000):
		var nombre: String = familias[i % familias.size()]
		if Sonido._admitir(nombre, i / 1000.0):
			inicios += 1
	verificar(inicios <= 6 and Sonido._ultimo.size() == 1,
		"todos los crujidos/recogidas comparten seis inicios por segundo como máximo")
	Sonido._ultimo = ultimo
	var voz := Sonido._siguiente
	for i in range(1000):
		Sonido.entrega(i)
	verificar(Sonido.get_child_count() == nodos_antes and Sonido._reproductores.size() == 16
		and Sonido._siguiente == voz and Sonido._ultimo == ultimo,
		"el banco mantiene 16 voces y silenciar no inicia sonidos ni consume puertas")


func energia_frecuencia(audio: AudioStreamWAV, frecuencia: float) -> float:
	var real := 0.0
	var imaginaria := 0.0
	var muestras := audio.data.size() >> 1
	for i in range(muestras):
		var fase := TAU * frecuencia * i / audio.mix_rate
		var muestra := audio.data.decode_s16(i * 2) / 32767.0
		real += muestra * cos(fase)
		imaginaria += muestra * sin(fase)
	return real * real + imaginaria * imaginaria


func probar_definicion() -> void:
	var claves := {}
	var mejoradas := {}
	var escalas_validas := true
	for datos: Dictionary in Graficos.catalogo_muebles():
		var clave := Graficos.clave_mueble(datos)
		if claves.has(clave):
			continue
		claves[clave] = true
		var base := Graficos.escala_mueble(datos, false)
		var actual := Graficos.escala_mueble(datos)
		escalas_validas = escalas_validas and actual > 0 and is_finite(actual) and actual >= base
		if actual > base:
			mejoradas[clave] = true
	verificar(mejoradas.size() == 10 and escalas_validas,
		"el catálogo conserva escalas estables y finitas al repartir la definición")
	var sillas_nitidas := true
	for datos: Dictionary in Graficos.catalogo_muebles():
		if datos.tipo != "silla" or datos.get("acabado", "") == "carton":
			continue
		var rect: Rect2 = datos.rect
		var encuadre := Graficos.rect_horneado_mueble(datos)
		sillas_nitidas = sillas_nitidas and encuadre.size == rect.size + Vector2(8, 8)
		if datos.color == Color("a6b194"):
			sillas_nitidas = sillas_nitidas and Graficos.escala_mueble(datos) == 3.0
	verificar(sillas_nitidas, "las sillas cercanas tienen tres texeles por unidad, sin el antiguo margen de 150 unidades")
	var estimador: Variant = load("res://global/graficos.gd").new()
	var pendientes: Array[Dictionary] = [
		{"clave": "ancho", "rect": Rect2(0, 0, 400, 200), "escala": 1.4, "escala_base": 0.8},
		{"clave": "alto", "rect": Rect2(0, 0, 280, 600), "escala": 0.8, "escala_base": 0.8}]
	estimador._pendientes.assign(pendientes)
	estimador._presupuestar_detalle()
	var presupuesto: Dictionary = estimador.presupuesto_atlas
	verificar(presupuesto.regiones_mejoradas == 1
		and presupuesto.bytes_actual <= presupuesto.bytes_base + Graficos.MAX_BYTES_DETALLE_CASA
		and presupuesto.actual.x == 2048,
		"el preflight calcula el montaje sin crear texturas y respeta el límite de memoria adicional")
	estimador.free()
	probar_empaquetado()


func probar_empaquetado() -> void:
	var empaquetado := preload("res://global/empaquetado_atlas.gd")
	var entradas: Array[Dictionary] = []
	for i in 120:
		var tam := Vector2(72, 72) if i < 90 else Vector2(70 + (i % 7) * 40, 100 + (i % 5) * 55)
		entradas.append({"clave": "prueba:%03d" % i, "rect": Rect2(Vector2.ZERO, tam), "escala": 1.0, "escala_base": 0.8})
	var plan: Dictionary = empaquetado.calcular(entradas, true)
	verificar(plan.exito and plan.posiciones.size() == entradas.size(), "el plan publica todas las regiones del catálogo irregular")
	var reservas: Array[Rect2i] = []
	var separadas := bool(plan.exito)
	if plan.exito:
		var limite := Rect2i(Vector2i.ZERO, plan.medidas)
		for entrada: Dictionary in entradas:
			var reserva := Rect2i(plan.posiciones[entrada.clave] - Vector2i(4, 4), Vector2i(entrada.rect.size) + Vector2i(8, 8))
			separadas = separadas and limite.encloses(reserva)
			for otra: Rect2i in reservas:
				separadas = separadas and not reserva.intersects(otra)
			reservas.append(reserva)
	verificar(separadas, "ninguna región solapa otra ni pierde el margen contra sangrado del atlas")
	entradas.reverse()
	var repetido: Dictionary = empaquetado.calcular(entradas, true)
	verificar(plan.medidas == repetido.medidas and plan.posiciones == repetido.posiciones,
		"el montaje es idéntico aunque cambie el orden de creación de nodos")
	entradas.append(entradas[0])
	var duplicado: Dictionary = empaquetado.calcular(entradas, true)
	verificar(not duplicado.exito and duplicado.posiciones.is_empty(), "una clave duplicada no publica un atlas parcial")
	var enorme: Array[Dictionary] = [{"clave": "enorme", "rect": Rect2(0, 0, 200, 9000), "escala": 1.0, "escala_base": 1.0}]
	var rechazado: Dictionary = empaquetado.calcular(enorme, true)
	verificar(not rechazado.exito and rechazado.medidas == Vector2i.ZERO,
		"una región fuera del límite se rechaza antes de reservar memoria GPU")


func verificar(condicion: bool, mensaje: String) -> void:
	total += 1
	if not condicion:
		fallas += 1
	print("OK " if condicion else "FALLA ", mensaje)
