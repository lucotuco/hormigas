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
##   BOT_INICIO   snapshot de entrada de sólo lectura; si se usa, BOT_ESTADO
##                puede apuntar a otra salida sin sobreescribir la muestra.
##   BOT_LOG      archivo donde agregar el registro (además de imprimirlo)
##   BOT_CALIBRAR si existe, modo calibración (ver más abajo)
##   BOT_FACTOR   factor de calibración (por defecto FACTOR_CALIBRACION)
##   BOT_TRABADO  runs sin progreso antes de pensar en fundar (por defecto RUNS_TRABADO)
##   BOT_ORDEN    "materiales" dirige primero al material recién aprendido;
##                "cercania" conserva el piloto histórico (por defecto).
##   BOT_RETORNO  si existe, corta tras esta cantidad de runs de la segunda
##                colonia; permite medir casa → primer rebirth sin campaña tardía.
##   BOT_FUNDAR_CASA si existe, elige la primera fundación al conquistar la casa;
##                la política histórica espera al restaurante o a una meseta.
##   BOT_JALEA    "retorno" prueba Cuadrilla (memoria, obreras y daño; seis de
##                jalea), o sólo Memoria si no alcanza; "memoria" elige sólo
##                ese atajo. Ambos conservan el resto de la jalea.
##
## Cómo juega: dos órdenes por segundo, sin daño manual a la comida.
## Atiende eventos y dirige al tutorial o al gran objetivo cuando puede comerlo.
## Entre runs ahorra para la próxima dieta si ya tiene la mitad;
## si no, compra lo más barato (mejoras o castas).
##
## Ciclo de prestigio: cada colonia recorre los destinos en orden, cobrando
## las coronas de cada uno. Está "trabada" cuando pasan runs sin conquistar
## nada y sin mejorar al menos MEJORA_MINIMA su mejor run (una meseta real).
## Tras RUNS_TRABADO runs así, si fundar le daría bastante jalea (o tras
## RUNS_TRABADO_MAXIMO, aunque dé poca), funda. También funda, aunque siga
## creciendo, cuando fundar duplicaría su jalea. Gasta la jalea en el nodo
## más barato del árbol de la reina.
##
## Modo calibración (BOT_CALIBRAR): los destinos después de la casa empiezan
## invulnerables. Cuando la colonia decide fundar estando en un destino sin
## calibrar, fija su vida_meta en FACTOR_CALIBRACION × el máximo daño que le
## hizo esa colonia, y funda: la colonia siguiente lo conquista. Así cada
## destino pide una colonia más. Los valores salen en el registro como
## "calibrado" y al final; se copian a mundo/mundos.gd.
const RUN := preload("res://mundo/run.tscn")
const VELOCIDAD := 1.0
## Una persona no clickea 3 veces por segundo durante horas; con la pisada
## automática tampoco hace falta.
const CLICS_POR_SEGUNDO := 2.0
const RUNS_TRABADO := 4          # runs sin conquistar antes de pensar en fundar
## Decreto que elige al fundar: el bot se traba en grandes objetivos, que piden
## daño de mordida sostenido, y para eso conviene una colonia numerosa.
const DECRETO := "numerosa"
const RUNS_TRABADO_MAXIMO := 20  # funda igual, aunque dé poca jalea
const FRACCION_LEGADO := 0.25    # fundar si da al menos este % de la jalea histórica
const MEJORA_MINIMA := 1.10      # una run que supera la mejor en 10% cuenta como progreso
## Regla clásica de prestigio: fundar cuando duplica la jalea acumulada
## (con la colonia madura y una ganancia mínima, para no fundar al empezar).
const RUNS_COLONIA_MADURA := 10
const GANANCIA_MINIMA_DOBLE := 20

var trabado := 0
var runs_trabado := RUNS_TRABADO
## Cuánto más fuerte tiene que ser la colonia siguiente que la que se trabó.
## Con 3 la campaña duraba ~11 h de bot; con 1,3, cada destino pide una
## fundación y no dos o cuatro (~3 h 53 min, ver README).
const FACTOR_CALIBRACION := 1.3
var factor_calibracion := FACTOR_CALIBRACION
const INVULNERABLE := 1e40
var calibrar := false
var calibrado: Dictionary = {}
var max_dano_destino := 0.0
var _dano_meta := 0.0
var _base_meta := 0.0
var mejor_run_colonia := 0.0
var runs_colonia := 0

var estado_ruta := ""
var log_ruta := ""
var minutos := 0.0
var vistos := {}
var orden_materiales := false
var runs_retorno := -1
var fundar_en_casa := false
var jalea_retorno := false
var solo_memoria := false
var _run_observada: Run
var _piezas_observadas: Dictionary = {}
var _bonus_muebles := 0.0


func _ready() -> void:
	estado_ruta = OS.get_environment("BOT_ESTADO")
	log_ruta = OS.get_environment("BOT_LOG")
	orden_materiales = OS.get_environment("BOT_ORDEN") == "materiales"
	fundar_en_casa = OS.has_environment("BOT_FUNDAR_CASA")
	jalea_retorno = OS.get_environment("BOT_JALEA") in ["retorno", "memoria"]
	solo_memoria = OS.get_environment("BOT_JALEA") == "memoria"
	if OS.has_environment("BOT_RETORNO"):
		runs_retorno = maxi(0, int(OS.get_environment("BOT_RETORNO")))
	var runs := int(OS.get_environment("BOT_RUNS")) if OS.has_environment("BOT_RUNS") else 200
	var max_min := float(OS.get_environment("BOT_MAX_MIN")) if OS.has_environment("BOT_MAX_MIN") else 240.0
	var inicio_ruta := OS.get_environment("BOT_INICIO") if OS.has_environment("BOT_INICIO") else estado_ruta
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")  # las verificaciones leen textos en español
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	seed(417)
	anotar("(piloto paso 1/60 s, tiempo ×1, orden %s; los tiempos incluyen retirada y no incluyen la tienda)" % ("materiales" if orden_materiales else "cercania"))
	# Para calibrar: un vida_meta.json junto al estado fuerza resistencias.
	var forzada := estado_ruta.get_base_dir().path_join("vida_meta.json") if estado_ruta != "" else ""
	if forzada != "" and FileAccess.file_exists(forzada):
		var valores = JSON.parse_string(FileAccess.get_file_as_string(forzada))
		if valores is Dictionary:
			Mundos.vida_meta_forzada = valores
			anotar("(vida_meta forzada: %s)" % str(valores))
	calibrar = OS.has_environment("BOT_CALIBRAR")
	if OS.has_environment("BOT_TRABADO"):
		runs_trabado = int(OS.get_environment("BOT_TRABADO"))
	if OS.has_environment("BOT_FACTOR"):
		factor_calibracion = float(OS.get_environment("BOT_FACTOR"))
	if inicio_ruta != "" and FileAccess.file_exists(inicio_ruta):
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(inicio_ruta))
		Juego.restaurar_partida(d.partida)
		minutos = d.minutos
		vistos = d.vistos
		trabado = int(d.get("trabado", 0))
		mejor_run_colonia = float(d.get("mejor_run_colonia", 0.0))
		runs_colonia = int(d.get("runs_colonia", 0))
		calibrado = d.get("calibrado", {})
		max_dano_destino = float(d.get("max_dano_destino", 0.0))
	if calibrar:
		for id in Mundos.ORDEN:
			if id != "casa":
				Mundos.vida_meta_forzada[id] = float(calibrado.get(id, INVULNERABLE))
		anotar("(modo calibración: %s)" % str(calibrado))
	# Un snapshot de conquista se guarda antes de fundar. Al retomarlo en el
	# modo casa no debe jugar primero un restaurante por haber saltado el cierre.
	if fundar_en_casa and Juego.fundaciones == 0 and Juego.coronas_cobradas.has("casa") and Juego.puede_fundar():
		fundar()
	for n in runs:
		elegir_destino()
		var cobradas := Juego.coronas_cobradas.size()
		var donde := Juego.lugar_actual
		var ganado: float = await jugar_run()
		if calibrar and donde != "casa" and not calibrado.has(donde):
			max_dano_destino = maxf(max_dano_destino, _dano_meta)
		if Juego.coronas_cobradas.size() > cobradas or ganado > mejor_run_colonia * MEJORA_MINIMA:
			trabado = 0
		else:
			trabado += 1
		mejor_run_colonia = maxf(mejor_run_colonia, ganado)
		runs_colonia += 1
		registrar()
		if Juego.lugares_completados.size() == Mundos.ORDEN.size() and not vistos.has("FIN"):
			vistos["FIN"] = minutos
			anotar("FIN campaña completa en el minuto %.1f con %d fundaciones" % [minutos, Juego.fundaciones])
			if calibrar:
				anotar("CALIBRADO %s" % JSON.stringify(calibrado))
			guardar_estado()
			break
		if conviene_fundar():
			if calibrar and donde != "casa" and not calibrado.has(donde) and max_dano_destino > 0.0 and _base_meta > 0.0:
				calibrado[donde] = factor_calibracion * max_dano_destino / _base_meta
				Mundos.vida_meta_forzada[donde] = calibrado[donde]
				anotar("== calibrado %s: vida_meta %s (máximo daño de la colonia %s)" % [donde, str(calibrado[donde]), Juego.formatear(max_dano_destino)])
			fundar()
			max_dano_destino = 0.0
		comprar()
		# Las compras ocurren entre expediciones. Registrarlas acá evita fechar
		# una dieta al terminar la run siguiente, como hacía el piloto anterior.
		registrar()
		guardar_estado()
		if runs_retorno >= 0 and Juego.fundaciones >= 1 and runs_colonia >= runs_retorno:
			anotar("FIN primer rebirth y %d expediciones de regreso a casa" % runs_colonia)
			break
		if minutos > max_min:
			anotar("FIN se alcanzaron %d minutos" % int(max_min))
			break
	Juego.reiniciar_estado()
	get_tree().quit()


func jugar_run() -> float:
	_dano_meta = 0.0
	var run: Run = RUN.instantiate()
	add_child(run)
	_run_observada = run
	_piezas_observadas.clear()
	_bonus_muebles = 0.0
	for parte in run.comidas.partes:
		_piezas_observadas[parte.get_instance_id()] = parte.vivas.size()
	run.comidas.comida_destruida.connect(_registrar_destruccion)
	Engine.max_fps = 0
	Engine.time_scale = VELOCIDAD
	var reloj := 0.0
	while not run.terminada:
		await get_tree().process_frame
		reloj += get_process_delta_time()
		if reloj >= 1.0 / CLICS_POR_SEGUNDO and run.activa:
			reloj = 0.0
			_observar_materiales(run)
			# Un jugador activo atiende primero las amenazas y las migas doradas.
			var evento := run.eventos.mas_urgente()
			if evento != null:
				run.pisar(run.eventos.punto_de_clic(evento))
				continue
			var mejor: Comida = null
			for c in run.comidas.lista:
				if not c.muerta and c.en_territorio(run.radio_actual) and (mejor == null or c.position.length() < mejor.position.length()):
					mejor = c
			var meta := run.objetivo_mapa
			if is_instance_valid(meta) and not meta.muerta and meta.disponible() and meta.en_territorio(run.radio_actual):
				var punto := meta.punto_mordida(Vector2.ZERO, run.radio_actual)
				if punto != Vector2.INF:
					run.feromonas.mantener_en(punto)
			elif is_instance_valid(run.objetivo_practica) and not run.objetivo_practica.muerta:
				run.feromonas.mantener_en(run.objetivo_practica.position)
			else:
				var parte := _material_cercano(run) if orden_materiales else null
				if parte != null:
					run.feromonas.mantener_en(parte.punto_mordida(Vector2.ZERO, run.radio_actual))
				elif mejor:
					run.feromonas.mantener_en(mejor.position)
				else:
					run.feromonas.soltar()
	Engine.time_scale = 1.0
	minutos += (run.tiempo_jugado + run.tiempo_retirada) / 60.0
	var ganado := Juego.migas_run
	var partes := Juego.partes_destruidas_run
	anotar("   producción %.1f/s · ingresos comida/muebles/estructura (incluyen bonus) %s · cargas sin entregar %s · fin %s" % [run.produccion_run, JSON.stringify(run.ingresos), Juego.formatear(run.cargas_pendientes), "limpieza" if run.limpieza_lograda else "tiempo"])
	# Daño hecho al gran objetivo en esta run (para calibrar vida_meta).
	var meta := run.objetivo_mapa
	var dano_meta := 0.0
	var vida_meta := 0.0
	if is_instance_valid(meta):
		vida_meta = meta.vida_max
		dano_meta = meta.dano_recibido
		_dano_meta = dano_meta
		_base_meta = meta.vida_max / Mundos.vida_meta(Juego.lugar_actual)
	elif run.objetivo_completado:
		dano_meta = INF
	run.queue_free()
	await get_tree().process_frame
	_run_observada = null
	anotar("run %3d  min %6.1f  %-11s +%-8s banco %-8s obreras %3d  dieta %d  terr %4d  partes %3d  especialistas %d  jalea %d  meta %s/%s" % [
		Juego.runs_jugadas, minutos, Juego.lugar_actual, Juego.formatear(ganado), Juego.formatear(Juego.migas),
		int(Juego.stat("hormigas_iniciales")), int(Juego.stat("materiales")), int(Juego.stat("radio_territorio")),
		partes, Juego.total_especialistas(), Juego.legado,
		"conquistado" if dano_meta == INF else Juego.formatear(dano_meta), Juego.formatear(vida_meta)])
	return ganado


## Diagnóstico del bot, no trabajo de la simulación: recorre piezas sólo dos
## veces por segundo. Fechas por colonia permiten comparar el primer retorno.
func _observar_materiales(run: Run) -> void:
	# El bonus de destruir una pieza se acredita de inmediato y no es una
	# entrega. El cartón además comparte esa columna con muebles; descontarlo
	# evita presentar la recompensa del tutorial como transporte de madera.
	if run.ingresos[1] > _bonus_muebles + 0.001:
		_marcar("muebles_transportados", run.tiempo_jugado)
	for parte in run.comidas.partes:
		if parte.muerta or parte.nivel_requerido < 1:
			continue
		var anteriores := int(_piezas_observadas.get(parte.get_instance_id(), parte.vivas.size()))
		if parte.vivas.size() < anteriores:
			_marcar("primer_corte_dieta_%d" % parte.nivel_requerido, run.tiempo_jugado)


func _registrar_destruccion(comida) -> void:
	if not is_instance_valid(_run_observada) or not comida is PiezaCasa:
		return
	if comida.nivel_requerido < 3:
		_bonus_muebles += comida.recompensa * Run.BONUS_DESTRUIR * Juego.stat("multiplicador_migas")
	if comida.pieza.get("practica", false):
		_marcar("carton", _run_observada.tiempo_jugado)
	elif comida.pieza.get("meta", false):
		_marcar("gran_objetivo_%s" % Juego.lugar_actual, _run_observada.tiempo_jugado)
	elif comida.pieza.tipo == "silla":
		_marcar("silla", _run_observada.tiempo_jugado)
	else:
		_marcar("pieza_dieta_%d" % comida.nivel_requerido, _run_observada.tiempo_jugado)


func _marcar(hito: String, segundos_run := 0.0) -> void:
	var clave := "colonia_%d/%s" % [Juego.fundaciones, hito]
	if vistos.has(clave):
		return
	var instante := minutos + segundos_run / 60.0
	vistos[clave] = instante
	var numero_run := Juego.runs_jugadas + (1 if is_instance_valid(_run_observada) else 0)
	anotar(">> %s en el minuto %.2f (run %d, segundo %.1f)" % [clave, instante, numero_run, segundos_run])


## Un material recién aprendido debe poder probarse con una orden explícita.
## No hace daño por clic ni llama a toda la colonia: usa el llamado real.
func _material_cercano(run: Run) -> PiezaCasa:
	var elegida: PiezaCasa
	var distancia := INF
	var dieta := int(Juego.stat("materiales"))
	for parte in run.comidas.partes:
		if parte.nivel_requerido != dieta or not parte.disponible() or not parte.en_territorio(run.radio_actual):
			continue
		var punto := parte.punto_mordida(Vector2.ZERO, run.radio_actual)
		if punto == Vector2.INF:
			continue
		var d := punto.length_squared()
		if d < distancia:
			distancia = d
			elegida = parte
	return elegida


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
	if not Juego.puede_fundar():
		return false
	if fundar_en_casa and Juego.fundaciones == 0 and Juego.coronas_cobradas.has("casa"):
		return true
	var ganada := Juego.jalea_por_fundar()
	if runs_colonia >= RUNS_COLONIA_MADURA and ganada >= maxi(GANANCIA_MINIMA_DOBLE, 2 * Juego.legado):
		return true
	if trabado < runs_trabado:
		return false
	var minimo := maxi(2, ceili(Juego.legado * FRACCION_LEGADO))
	return Juego.jalea_por_fundar() >= minimo or trabado >= RUNS_TRABADO_MAXIMO


func fundar() -> void:
	var ganada := Juego.jalea_por_fundar()
	var donde := Juego.lugar_actual
	var preparacion: Array[String] = []
	if jalea_retorno:
		var deseadas := ["herencia_madera"] if solo_memoria else ["herencia_madera", "obreras_reales", "jalea_dano"]
		for id in deseadas:
			if Juego.nivel_jalea(id) < 1:
				preparacion.append(id)
	var cotizacion := Juego.cotizar_preparacion_fundar(preparacion)
	if not cotizacion.valido:
		preparacion.clear()
		if jalea_retorno and Juego.nivel_jalea("herencia_madera") < 1:
			preparacion.append("herencia_madera")
		cotizacion = Juego.cotizar_preparacion_fundar(preparacion)
		anotar("(plan de seis no alcanzable; prueba memoria sola si alcanza)")
	if not cotizacion.valido:
		preparacion.clear()
		cotizacion = Juego.cotizar_preparacion_fundar(preparacion)
	Juego.fundar_colonia(DECRETO, preparacion)
	trabado = 0
	mejor_run_colonia = 0.0
	runs_colonia = 0
	var compras := PackedStringArray()
	for compra in cotizacion.compras:
		compras.append(compra.id)
	while not jalea_retorno:
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
	if estado_ruta != "":
		guardar_estado(estado_ruta.get_basename() + "_fundacion_%d.json" % Juego.fundaciones)


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
		var lograda_en_colonia: bool = Juego.coronas_cobradas.has(clave) if Mundos.INFO.has(clave) else logros[clave]
		if lograda_en_colonia:
			_marcar(clave)
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
	f.store_string(JSON.stringify({"partida": Juego.datos_partida(), "minutos": minutos, "vistos": vistos, "trabado": trabado, "mejor_run_colonia": mejor_run_colonia, "runs_colonia": runs_colonia, "calibrado": calibrado, "max_dano_destino": max_dano_destino}))


func anotar(texto: String) -> void:
	print(texto)
	if log_ruta == "":
		return
	var f := FileAccess.open(log_ruta, FileAccess.READ_WRITE if FileAccess.file_exists(log_ruta) else FileAccess.WRITE)
	f.seek_end()
	f.store_line(texto)
