extends Node
## Bot de balance: juega runs seguidas como un jugador activo y anota el
## minuto de juego en que llega a cada desbloqueo y a cada destino.
## No es una prueba (no corre en CI): sirve para medir el ritmo después de
## tocar los CSV o las constantes de balance.
##
##   godot --headless --fixed-fps 60 --path . res://tests/bot_balance.tscn
##
## Variables de entorno opcionales:
##   BOT_RUNS     runs a jugar en esta tanda (por defecto 200)
##   BOT_MAX_MIN  corta al pasar estos minutos de juego (por defecto 240)
##   BOT_ESTADO   archivo donde guardar/retomar el estado entre tandas
##                (por defecto no guarda: empieza siempre de cero)
##   BOT_LOG      archivo donde agregar el registro (además de imprimirlo)
##
## Cómo juega: 3 pisotones por segundo sobre la comida más cercana al
## hormiguero; cuando el gran objetivo se puede comer, mantiene el llamado
## sobre él. Entre runs ahorra para la próxima dieta si ya tiene la mitad;
## si no, compra lo más barato (mejoras o castas). Al conquistar un destino
## viaja al siguiente. No funda colonias.
const RUN := preload("res://mundo/run.tscn")
const VELOCIDAD := 8.0
const CLICS_POR_SEGUNDO := 3.0

var estado_ruta := ""
var log_ruta := ""
var minutos := 0.0
var vistos := {}


func _ready() -> void:
	estado_ruta = OS.get_environment("BOT_ESTADO")
	log_ruta = OS.get_environment("BOT_LOG")
	var runs := int(OS.get_environment("BOT_RUNS")) if OS.has_environment("BOT_RUNS") else 200
	var max_min := float(OS.get_environment("BOT_MAX_MIN")) if OS.has_environment("BOT_MAX_MIN") else 240.0
	Juego.guardado_habilitado = false
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	if estado_ruta != "" and FileAccess.file_exists(estado_ruta):
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(estado_ruta))
		Juego.restaurar_partida(d.partida)
		minutos = d.minutos
		vistos = d.vistos
	for n in runs:
		await jugar_run()
		comprar()
		registrar()
		guardar_estado()
		if Juego.lugares_completados.has(Juego.lugar_actual):
			var i := Mundos.ORDEN.find(Juego.lugar_actual)
			if i + 1 >= Mundos.ORDEN.size():
				anotar("FIN campaña completa")
				break
			Juego.elegir_destino(Mundos.ORDEN[i + 1])
			anotar("-> viaja a %s" % Juego.lugar_actual)
		if minutos > max_min:
			anotar("FIN se alcanzaron %d minutos" % int(max_min))
			break
	Juego.reiniciar_estado()
	get_tree().quit()


func jugar_run() -> void:
	var run: Run = RUN.instantiate()
	add_child(run)
	Engine.max_fps = 0
	Engine.time_scale = VELOCIDAD
	var reloj := 0.0
	while not run.terminada:
		await get_tree().process_frame
		reloj += get_process_delta_time()
		if reloj >= 1.0 / CLICS_POR_SEGUNDO and run.activa:
			reloj = 0.0
			var mejor: Comida = null
			for c in run.comidas.lista:
				if not c.muerta and c.en_territorio(run.radio_actual) and (mejor == null or c.position.length() < mejor.position.length()):
					mejor = c
			if mejor:
				run.pisar(mejor.position)
			var meta := run.objetivo_mapa
			if is_instance_valid(meta) and not meta.muerta and meta.disponible() and meta.en_territorio(run.radio_actual):
				var punto := meta.punto_mordida(Vector2.ZERO, run.radio_actual)
				if punto != Vector2.INF:
					run.feromonas.mantener_en(punto)
			elif run.feromonas.activa:
				run.feromonas.soltar()
	Engine.time_scale = 1.0
	minutos += run.duracion_total / 60.0
	var ganado := Juego.migas_run
	var partes := Juego.partes_destruidas_run
	run.queue_free()
	await get_tree().process_frame
	anotar("run %3d  min %6.1f  %-11s +%-8s banco %-8s obreras %3d  dieta %d  terr %4d  partes %3d  especialistas %d" % [
		Juego.runs_jugadas, minutos, Juego.lugar_actual, Juego.formatear(ganado), Juego.formatear(Juego.migas),
		int(Juego.stat("hormigas_iniciales")), int(Juego.stat("materiales")), int(Juego.stat("radio_territorio")),
		partes, Juego.total_especialistas()])


func comprar() -> void:
	for vuelta in 300:
		if Juego.proxima_meta().tipo == "migas":
			for id in Juego.DIETAS:
				if Juego.nivel_de(id) == 0:
					if Juego.comprar(id):
						continue
					if Juego.migas >= Juego.costo(id) * 0.5:
						return
					break
		var mejor := ""
		var es_casta := false
		var precio := INF
		for m in Juego.mejoras:
			if m.id in Juego.DIETAS:
				continue
			var o := Juego.cotizar_mejora(m.id, 1)
			if o.puede and o.costo < precio:
				precio = o.costo
				mejor = m.id
				es_casta = false
		if Juego.revelado("castas"):
			for c in Juego.castas:
				var o := Juego.cotizar_casta(c.id, 1)
				if o.puede and o.costo < precio:
					precio = o.costo
					mejor = c.id
					es_casta = true
		if mejor == "":
			return
		if es_casta:
			Juego.comprar_casta(mejor)
		else:
			Juego.comprar(mejor)


func registrar() -> void:
	var logros := {
		"mandibulas_4": Juego.nivel_de("mandibulas") >= 4,
		"madera": Juego.stat("materiales") >= 1,
		"resistentes": Juego.stat("materiales") >= 2,
		"muros": Juego.stat("materiales") >= 3,
		"primera_casta": Juego.total_especialistas() > 0,
	}
	for id in Mundos.ORDEN:
		logros[id] = Juego.lugares_completados.has(id)
	for clave in logros:
		if logros[clave] and not vistos.has(clave):
			vistos[clave] = minutos
			anotar(">> %s en el minuto %.1f (run %d)" % [clave, minutos, Juego.runs_jugadas])


func guardar_estado() -> void:
	if estado_ruta == "":
		return
	var f := FileAccess.open(estado_ruta, FileAccess.WRITE)
	f.store_string(JSON.stringify({"partida": Juego.datos_partida(), "minutos": minutos, "vistos": vistos}))


func anotar(texto: String) -> void:
	print(texto)
	if log_ruta == "":
		return
	var f := FileAccess.open(log_ruta, FileAccess.READ_WRITE if FileAccess.file_exists(log_ruta) else FileAccess.WRITE)
	f.seek_end()
	f.store_line(texto)
