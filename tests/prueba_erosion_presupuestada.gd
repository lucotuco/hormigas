extends Node
## Conservación y ciclo de vida de erosión compartida, no medición de FPS.
const RUN := preload("res://mundo/run.tscn")
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	var existia := FileAccess.file_exists(Juego.RUTA_PARTIDA)
	var huella := hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) if existia else 0
	probar_credito_separado()
	probar_admision_con_credito_previo()
	await probar_turnos_y_duracion()
	await probar_pieza_y_valor()
	await probar_frentes_reales_y_origen_aparcado()
	await probar_barrera()
	await probar_limpieza_al_drenar()
	await probar_referencias_y_cancelacion()
	Juego.reiniciar_estado()
	var intacta := FileAccess.file_exists(Juego.RUTA_PARTIDA) == existia
	if existia:
		intacta = intacta and hash(FileAccess.get_file_as_bytes(Juego.RUTA_PARTIDA)) == huella
	verificar(not Juego.guardado_habilitado and intacta, "la erosión de prueba no altera la partida personal")
	print("Erosión presupuestada: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func crear_run() -> Run:
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var r: Run = RUN.instantiate()
	r.preparacion_sincrona = true # Aísla el presupuesto de erosión de la preparación.
	add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	return r


func comida(r: Run, vida := 10000.0, valor := 1000.0, radio := 32.0) -> Comida:
	var c := Comida.new()
	c._usar_cache = false
	r.comidas.add_child(c)
	c.configurar({"id": "erosion_fixture", "nombre": "Comida de prueba", "forma": "miga", "color": Color.BROWN, "vida": vida, "recompensa": valor, "radio": radio}, 1)
	c.rotation = 0
	c.position = Vector2(-700, 400)
	r.comidas.lista.append(c)
	c.destruida.connect(r.comidas._on_destruida)
	return c


func drenar(r: Run, max_pasos := 1) -> int:
	var vueltas := 0
	while r.cola_erosion.tiene_pendientes() and vueltas < 12000:
		r.cola_erosion.procesar(100000000, max_pasos)
		vueltas += 1
	return vueltas


func credito(m: MordiscosMaterial) -> float:
	var suma := 0.0
	for valor in m._credito_erosion:
		suma += valor
	return suma


func probar_credito_separado() -> void:
	var rect := Rect2(0, 0, 64, 64)
	var m := MordiscosMaterial.new()
	var referencia := MordiscosMaterial.new()
	m.configurar(rect, Vector2i.ONE, [[rect]], PackedFloat64Array([4096]))
	referencia.configurar(rect, Vector2i.ONE, [[rect]], PackedFloat64Array([4096]))
	var desde := Vector2(-2, 32)
	var esperado := referencia.recortar_frente(0, 1000, desde)
	var real := m.recortar_frente_paso(0, 1000, desde)
	verificar(real > 0 and real < esperado and m.ultima_porcion.size.x <= 16 and m.ultima_porcion.size.y <= 16, "un servicio sólo retira una porción16u, no todo el trabajo de veneno")
	var despues := m.area_total()
	verificar(m.recortar_local(0, 0.1, desde, 6) == 0 and m.area_total() == despues and credito(m) > 0, "una hormiga no puede llevarse el crédito ambiental todavía pendiente")
	var pasos := 1
	while m.erosion_pagable(0) and pasos < 1000:
		real += m.recortar_frente_paso(0, 0, desde)
		pasos += 1
	verificar(real == esperado and m._pixeles == referencia._pixeles and m._arbol == referencia._arbol and m._frontera_arbol == referencia._frontera_arbol and credito(m) == 0, "reanudar con daño0 conserva exactamente el daño, la máscara y el frente del veneno síncrono")
	verificar(is_equal_approx(m._credito[0], 0.1), "el crédito de mordida se mantiene separado del crédito de erosión")


func probar_admision_con_credito_previo() -> void:
	var m := MordiscosMaterial.new()
	var rect := Rect2(0, 0, 20, 10)
	m.configurar(rect, Vector2i(2, 1), [[Rect2(0, 0, 10, 10)], [Rect2(10, 0, 10, 10)]], PackedFloat64Array([10, 10]))
	m.recortar_frente(0, 0.03, Vector2(-2, 5))
	var retirado := m.recortar_frente(0, 15, Vector2(-2, 5))
	var admitido := m.ultimo_trabajo_frente
	retirado += m.recortar_frente(1, 15 - admitido, Vector2(-2, 5))
	var pendiente := 0.0
	for valor in m._credito:
		pendiente += valor
	verificar(is_equal_approx(admitido, 9.97) and is_equal_approx(retirado + pendiente, 15.03), "saturar una celda con crédito previo sólo consume el trabajo admitido; el resto pasa a otra celda sin perder HP")


func probar_turnos_y_duracion() -> void:
	var r := crear_run()
	var a := comida(r)
	var b := comida(r)
	var desde := a.position + Vector2(-34, 0)
	r.cola_erosion.encolar(a, 4000, desde)
	r.cola_erosion.encolar(b, 4000, desde)
	verificar(a.vida == a.vida_max and b.vida == b.vida_max and Juego.migas_run == 0, "encolar trabajo no quita HP ni cobra recursos")
	r.cola_erosion.procesar(100000000, 2)
	verificar(a.vida < a.vida_max and b.vida < b.vida_max and r.cola_erosion.operaciones_ultimo_cuadro == 2 and r.cola_erosion.tiene_pendientes(), "dos turnos reparten una porción a cada recurso sin vaciar el primero")
	drenar(r)
	verificar(r.cola_erosion.max_operaciones_cuadro <= 2 and not r.cola_erosion.tiene_pendientes(), "el límite determinista por servicio se respeta hasta terminar")
	r.queue_free()
	await get_tree().process_frame
	r = crear_run()
	var c := comida(r)
	c.aplicar_veneno(1600, 1.25, r, c.position + Vector2(-34, 0))
	c._procesar_veneno(0.5)
	c.aplicar_veneno(100, c.veneno_restante, r, c.position + Vector2(34, 0))
	c._procesar_veneno(0.5)
	c._procesar_veneno(0.25)
	verificar(c.veneno_restante == 0 and c._veneno_dps == 0 and r.cola_erosion.tiene_pendientes() and c.vida == c.vida_max, "el veneno expira sin perder los ticks y la cola continúa después")
	var vueltas := drenar(r)
	var retirado := c.vida_max - c.vida
	verificar(vueltas > 1 and is_equal_approx(retirado + credito(c.mordiscos), 2000) and is_equal_approx(r.cola_erosion.trabajo_emitido, 2000), "duración1,25s y renovación más débil conservan DPS1600 y todo el trabajo ganado")
	verificar(is_equal_approx(Juego.migas_run, retirado / c.vida_max * c.recompensa * Juego.stat("multiplicador_migas")), "sólo el material efectivamente retirado se acredita una vez")
	verificar(not r.cola_erosion.encolar(c, INF, c.position) and not r.cola_erosion.encolar(c, 1, Vector2.INF), "valores no finitos no crean trabajos ni ingresos")
	r.queue_free()
	await get_tree().process_frame


func pieza(r: Run, clave: String) -> PiezaCasa:
	var p := PiezaCasa.new()
	r.comidas.add_child(p)
	var datos := {"clave": clave, "tipo": "mesada", "rect": Rect2(-850, -800, 260, 200), "color": Color.GRAY, "pared": false}
	datos.dibujo = datos.duplicate(true)
	p.iniciar(datos, r.cocina)
	r.comidas.partes.append(p)
	p.destruida.connect(r.comidas._on_destruida)
	return p


func valor_fragmentos(r: Run) -> float:
	var valor := 0.0
	for f in r.comidas.fragmentos:
		if is_instance_valid(f) and not f.muerta:
			valor += f.recompensa
	return valor


func probar_pieza_y_valor() -> void:
	var r := crear_run()
	var p := pieza(r, "erosion:pieza")
	var referencia := pieza(r, "erosion:referencia")
	var desde := p.rect_mundo.position + Vector2(-2, 40)
	var valor_referencia := referencia.morder_veneno(1000, desde)
	var fragmentos_previos := valor_fragmentos(r)
	var saldo := Juego.migas_run
	r.cola_erosion.encolar(p, 1000, desde)
	drenar(r)
	verificar(is_equal_approx(p.vida, referencia.vida) and p.mordiscos._pixeles == referencia.mordiscos._pixeles, "una pieza presupuestada conserva HP y máscara de la erosión síncrona")
	var valor_real := p.recompensa * (p.vida_max - p.vida) / p.vida_max * Juego.stat("multiplicador_migas")
	verificar(is_equal_approx(Juego.migas_run - saldo, valor_referencia) and is_equal_approx(Juego.migas_run - saldo, valor_real * 0.65), "el65% ambiental se cobra únicamente por la extracción real")
	verificar(is_equal_approx(valor_fragmentos(r) - fragmentos_previos, valor_real * 0.35), "el35% restante queda transportable sin duplicar recursos")
	r.queue_free()
	await get_tree().process_frame


func pieza_real(r: Run, datos: Dictionary) -> PiezaCasa:
	var copia := datos.duplicate(true)
	# Las dos referencias no escriben progreso de campaña ni restauran
	# componentes del mismo proyecto: se compara únicamente la erosión.
	for campo in ["objetivo_proyecto", "proyecto_id", "proyecto_vida"]:
		copia.erase(campo)
	var p := PiezaCasa.new()
	r.comidas.add_child(p)
	p.iniciar(copia, r.cocina)
	return p


func probar_frentes_reales_y_origen_aparcado() -> void:
	for destino in ["museo", "eiffel"]:
		var r := crear_run_destino(destino)
		var vistos: Dictionary = {}
		for datos: Dictionary in MaterialesCasa.piezas():
			if datos.tipo not in ["biblioteca", "anfora", "torre"] or vistos.has(datos.tipo):
				continue
			vistos[datos.tipo] = true
			var p := pieza_real(r, datos)
			var referencia := pieza_real(r, datos)
			var centro := p.rect_mundo.get_center()
			var origenes: Array[Vector2] = [Vector2(p.rect_mundo.position.x - 4, centro.y), Vector2(p.rect_mundo.end.x + 4, centro.y), Vector2(centro.x, p.rect_mundo.position.y - 4)]
			var torre_aparcada := false
			for lado in origenes.size():
				var dano := p.vida_max * 0.27
				var antes := p.vida
				referencia.morder_veneno(dano, origenes[lado])
				r.cola_erosion.encolar(p, dano, origenes[lado])
				drenar(r)
				var igual := is_equal_approx(p.vida, referencia.vida) and p.mordiscos._pixeles == referencia.mordiscos._pixeles and p.mordiscos._arbol == referencia.mordiscos._arbol and p.mordiscos._frontera_arbol == referencia.mordiscos._frontera_arbol
				verificar(igual and not r.cola_erosion.tiene_pendientes(), "%s/%s lado%d: crédito reanudado conserva HP, máscara y frontera exactas del síncrono" % [destino, datos.tipo, lado])
				if datos.tipo == "torre" and lado == 0:
					torre_aparcada = r.cola_erosion._latentes.has(p.get_instance_id())
				if datos.tipo == "torre" and lado == 1:
					verificar(torre_aparcada and p.vida < antes, "un tramo izquierdo sin contacto no bloquea el veneno nuevo que llega desde la derecha")
			if datos.tipo == "torre":
				var pagado := Juego.migas_run
				r._iniciar_retirada()
				verificar(r.retirando and not r.cerrando_erosion and Juego.migas_run == pagado, "sólo trabajo aparcado sin frontera no bloquea el cierre ni se convierte en recursos")
			p.queue_free()
			referencia.queue_free()
		r.queue_free()
		await get_tree().process_frame


func crear_run_destino(destino: String) -> Run:
	Juego.reiniciar_estado()
	Juego.lugar_actual = destino
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var r: Run = RUN.instantiate()
	r.preparacion_sincrona = true
	add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	return r


func probar_barrera() -> void:
	var r := crear_run()
	var c := comida(r, 1000000, 1000, 100)
	c.aplicar_veneno(1000000, 10, r, c.position + Vector2(-102, 0))
	c._procesar_veneno(0.2)
	var restante := r.tiempo_restante
	var jugado := r.tiempo_jugado
	r._iniciar_retirada()
	verificar(r.cerrando_erosion and not r.activa and not r.retirando and not r.terminada and c.veneno_restante == 0 and r.cola_erosion.trabajo_emitido == 200000, "cerrar captura sólo0,2s ya ganados, no los segundos futuros del veneno")
	verificar(r.colonia.process_mode == Node.PROCESS_MODE_DISABLED and r.eventos.process_mode == Node.PROCESS_MODE_DISABLED and not get_tree().paused, "la barrera congela colonia y amenazas sin pausar UI ni árbol")
	r.hud._process(0)
	verificar(r.hud._lbl_tiempo.text == "Terminando corrosión…", "el HUD distingue la barrera del reloj de recolección")
	r.hud.pausar()
	verificar(get_tree().paused and r.hud.pausado() and r.cola_erosion.tiene_pendientes(), "pausar durante la barrera conserva todo el trabajo pendiente")
	r.hud.reanudar()
	verificar(not get_tree().paused and not r.hud.pausado() and r.cerrando_erosion and r.cola_erosion.tiene_pendientes(), "reanudar mantiene la barrera y su cola, sin cerrarla ni reiniciarla")
	r._process(0.25)
	verificar(r.tiempo_restante == restante and is_equal_approx(r.tiempo_jugado - jugado, 0.25) and is_equal_approx(r.tiempo_espera_erosion, 0.25), "la espera se contabiliza sin regalar segundos activos de recolección")
	r.cola_erosion.procesar(100000000, 1)
	verificar(r.cerrando_erosion and c.vida > 800000 and Juego.migas_run > 0, "el cierre sigue no bloqueante y cobra sólo la primera porción")
	drenar(r)
	await get_tree().process_frame
	verificar(not r.cerrando_erosion and r.retirando and not r.terminada and is_equal_approx(c.vida_max - c.vida + credito(c.mordiscos), 200000), "drenar el trabajo completo continúa exactamente una retirada normal")
	var pagado := Juego.migas_run
	r._on_erosion_drenada()
	verificar(Juego.migas_run == pagado and r.retirando, "notificar otra vez la barrera drenada no duplica pagos ni cierres")
	r.queue_free()
	await get_tree().process_frame
	r = crear_run()
	c = comida(r)
	c.aplicar_veneno(0.1, 1, r, c.position + Vector2(-34, 0))
	c._procesar_veneno(0.2)
	r._cerrar()
	drenar(r)
	await get_tree().process_frame
	verificar(r.terminada and not r.cerrando_erosion and Juego.migas_run == 0 and c.vida == c.vida_max, "un residuo subpíxel cierra sin espera infinita ni recursos inventados")
	var runs := Juego.runs_jugadas
	r._cerrar()
	verificar(Juego.runs_jugadas == runs, "el cierre posterior al drenaje cobra la expedición una sola vez")
	r.queue_free()
	await get_tree().process_frame


func probar_referencias_y_cancelacion() -> void:
	var r := crear_run()
	var c := comida(r)
	r.cola_erosion.encolar(c, 4000, c.position + Vector2(-34, 0))
	c.morder(c.vida_max * 2)
	var pagado := Juego.migas_run
	drenar(r)
	verificar(not r.cola_erosion.tiene_pendientes() and Juego.migas_run == pagado, "si otra extracción destruye el objetivo la cola no paga su material otra vez")
	var liberada := comida(r)
	r.cola_erosion.encolar(liberada, 4000, liberada.position + Vector2(-34, 0))
	liberada.queue_free()
	await get_tree().process_frame
	drenar(r)
	verificar(not r.cola_erosion.tiene_pendientes() and Juego.migas_run == pagado, "una referencia liberada se descarta sin acceso inválido ni cobro")
	var pendiente := comida(r)
	r.cola_erosion.encolar(pendiente, 4000, pendiente.position + Vector2(-34, 0))
	r.queue_free()
	await get_tree().process_frame
	verificar(Juego.migas_run == pagado, "destruir la escena cancela trabajo sin convertir crédito en ingreso")


func probar_limpieza_al_drenar() -> void:
	for bloqueo in ["ninguno", "fragmentos y tesoro", "botin", "cadena", "colonia perdida", "cierre forzado"]:
		var r := crear_run()
		# Escenario unitario explícito: un recurso final, no una campaña vaciada
		# por daño de prueba ni una medición de producción.
		for grupo in [r.comidas.lista, r.comidas.partes, r.comidas.fragmentos]:
			for recurso in grupo:
				recurso.queue_free()
			grupo.clear()
		r.comidas._indice.clear()
		r.comidas._pilas.clear()
		r._hubo_objetivos = true
		r._colonia_operativa = true
		r.colonia._por_salir = 0
		r.tiempo_restante = 0
		var c := comida(r, 1000, 10)
		c.position = Vector2(70, 0)
		if bloqueo == "fragmentos y tesoro":
			r.comidas.soltar_fragmento(Vector2(160, 0), 10, 1)
			var alijo := comida(r, 1000, 10)
			alijo.position = Vector2(120, 0)
		elif bloqueo == "botin":
			var evento := Evento.new()
			evento.visible = false
			evento.tipo = "paloma"
			evento.run = r
			evento.botin = 10
			r.eventos.add_child(evento)
			r.eventos.activos.append(evento)
		elif bloqueo == "cadena":
			r.reglas._pendientes.append({})
		elif bloqueo == "colonia perdida":
			r.colonia_perdida = true
		r.cola_erosion.encolar(c, c.vida_max, c.position + Vector2(-34, 0))
		if bloqueo == "cierre forzado":
			r._cerrar()
		else:
			r._iniciar_retirada()
		r._process(0.3)
		var instante := r.tiempo_jugado
		drenar(r)
		await get_tree().process_frame
		await get_tree().process_frame
		if bloqueo == "ninguno":
			verificar(r.limpieza_lograda and r.limpieza_completa and r.retirando and is_equal_approx(r.tiempo_limpieza, instante) and instante >= 0.3, "la última comida erosionada al vencer el reloj clasifica limpieza real e incluye la espera")
		else:
			verificar(not r.limpieza_lograda and not r.limpieza_registrada, bloqueo + ": drenar no inventa limpieza ni un récord")
		r.queue_free()
		await get_tree().process_frame


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", detalle)
