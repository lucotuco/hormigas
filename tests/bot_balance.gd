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
## si no, compra lo más barato (mejoras o castas).
##
## Ciclo de prestigio: cada colonia recorre los destinos en orden, cobrando
## las coronas de cada uno. Está "trabada" cuando pasan runs sin conquistar
## nada y sin mejorar al menos MEJORA_MINIMA su mejor run (una meseta real).
## Tras RUNS_TRABADO runs así, si fundar le daría bastante jalea (o tras
## RUNS_TRABADO_MAXIMO, aunque dé poca), funda y gasta la jalea en el nodo
## más barato del árbol de la reina.
const RUN := preload("res://mundo/run.tscn")
const VELOCIDAD := 8.0
const CLICS_POR_SEGUNDO := 3.0
const RUNS_TRABADO := 5          # runs sin conquistar antes de pensar en fundar
const RUNS_TRABADO_MAXIMO := 20  # funda igual, aunque dé poca jalea
const FRACCION_LEGADO := 0.25    # fundar si da al menos este % de la jalea histórica
const MEJORA_MINIMA := 1.10      # una run que supera la mejor en 10% cuenta como progreso

var trabado := 0
var mejor_run_colonia := 0.0

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
		trabado = int(d.get("trabado", 0))
		mejor_run_colonia = float(d.get("mejor_run_colonia", 0.0))
	for n in runs:
		elegir_destino()
		var cobradas := Juego.coronas_cobradas.size()
		var ganado: float = await jugar_run()
		if Juego.coronas_cobradas.size() > cobradas or ganado > mejor_run_colonia * MEJORA_MINIMA:
			trabado = 0
		else:
			trabado += 1
		mejor_run_colonia = maxf(mejor_run_colonia, ganado)
		registrar()
		if Juego.lugares_completados.size() == Mundos.ORDEN.size() and not vistos.has("FIN"):
			vistos["FIN"] = minutos
			anotar("FIN campaña completa en el minuto %.1f con %d fundaciones" % [minutos, Juego.fundaciones])
			guardar_estado()
			break
		if conviene_fundar():
			fundar()
		comprar()
		guardar_estado()
		if minutos > max_min:
			anotar("FIN se alcanzaron %d minutos" % int(max_min))
			break
	Juego.reiniciar_estado()
	get_tree().quit()


func jugar_run() -> float:
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
	# Daño hecho al gran objetivo en esta run (para calibrar vida_meta).
	var meta := run.objetivo_mapa
	var dano_meta := 0.0
	var vida_meta := 0.0
	if is_instance_valid(meta):
		vida_meta = meta.vida_max
		dano_meta = meta.vida_max - meta.vida
	elif run.objetivo_completado:
		dano_meta = INF
	run.queue_free()
	await get_tree().process_frame
	anotar("run %3d  min %6.1f  %-11s +%-8s banco %-8s obreras %3d  dieta %d  terr %4d  partes %3d  especialistas %d  jalea %d  meta %s/%s" % [
		Juego.runs_jugadas, minutos, Juego.lugar_actual, Juego.formatear(ganado), Juego.formatear(Juego.migas),
		int(Juego.stat("hormigas_iniciales")), int(Juego.stat("materiales")), int(Juego.stat("radio_territorio")),
		partes, Juego.total_especialistas(), Juego.legado,
		"conquistado" if dano_meta == INF else Juego.formatear(dano_meta), Juego.formatear(vida_meta)])
	return ganado


## Cada colonia recorre los destinos en orden: juega en el primero cuyas
## coronas todavía no cobró. Si ya cobró todo, juega en el último.
func elegir_destino() -> void:
	for id in Mundos.ORDEN:
		if not Juego.coronas_cobradas.has(id) and Juego.destino_desbloqueado(id):
			if Juego.lugar_actual != id:
				Juego.elegir_destino(id)
			return
	Juego.elegir_destino(Mundos.ORDEN.back())


func conviene_fundar() -> bool:
	if not Juego.puede_fundar() or trabado < RUNS_TRABADO:
		return false
	var minimo := maxi(2, ceili(Juego.legado * FRACCION_LEGADO))
	return Juego.jalea_por_fundar() >= minimo or trabado >= RUNS_TRABADO_MAXIMO


func fundar() -> void:
	var ganada := Juego.jalea_por_fundar()
	var donde := Juego.lugar_actual
	Juego.fundar_colonia()
	trabado = 0
	mejor_run_colonia = 0.0
	var compras := PackedStringArray()
	while true:
		var mejor := ""
		var precio := 1 << 62
		for nodo in Juego.nodos_jalea:
			if Juego.puede_comprar_jalea(nodo.id) and Juego.costo_jalea(nodo.id) < precio:
				precio = Juego.costo_jalea(nodo.id)
				mejor = nodo.id
		if mejor == "":
			break
		Juego.comprar_jalea(mejor)
		compras.append(mejor)
	anotar("<< fundación %d en el minuto %.1f (trabado en %s): +%d jalea, legado %d · compró %s" % [Juego.fundaciones, minutos, donde, ganada, Juego.legado, ", ".join(compras)])


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
			anotar(">> %s en el minuto %.1f (run %d, %d fundaciones)" % [clave, minutos, Juego.runs_jugadas, Juego.fundaciones])
			# Copia del estado al conquistar: permite recalibrar desde acá.
			if estado_ruta != "" and Mundos.INFO.has(clave):
				guardar_estado(estado_ruta.get_basename() + "_" + clave + ".json")


func guardar_estado(ruta := "") -> void:
	if ruta == "":
		ruta = estado_ruta
	if ruta == "":
		return
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	f.store_string(JSON.stringify({"partida": Juego.datos_partida(), "minutos": minutos, "vistos": vistos, "trabado": trabado, "mejor_run_colonia": mejor_run_colonia}))


func anotar(texto: String) -> void:
	print(texto)
	if log_ruta == "":
		return
	var f := FileAccess.open(log_ruta, FileAccess.READ_WRITE if FileAccess.file_exists(log_ruta) else FileAccess.WRITE)
	f.seek_end()
	f.store_line(texto)
