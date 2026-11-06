extends Node
## Néctar, niveles, eclosiones y mutaciones de la run (mundo/evolucion_run.gd).
## Todo vale sólo durante la run: al cobrarla, las stats vuelven a ser las de
## la tienda y el guardado no se entera.
var total := 0
var fallas := 0
const RUN := preload("res://mundo/run.tscn")


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	seed(907)
	probar_datos()
	await probar_niveles()
	await probar_eleccion_del_jugador()
	await probar_efectos()
	await probar_cofre_y_horda()
	await probar_fin_de_run()
	EvolucionRun.modo_automatico = "auto"
	get_tree().paused = false
	Juego.reiniciar_estado()
	print("Mutaciones: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func verificar(ok: bool, texto: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", texto)


func crear(runs := 1) -> Run:
	Juego.reiniciar_estado()
	Juego.runs_jugadas = runs
	if runs > 0:
		Juego.sumar_estadistica("niveles_comprados")
	Juego.lugar_actual = "casa"
	var r: Run = RUN.instantiate()
	add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	r.radio_actual = 12000
	return r


func cerrar(r: Run) -> void:
	get_tree().paused = false
	r.queue_free()
	await get_tree().process_frame


func probar_datos() -> void:
	verificar(Juego.mutaciones.size() >= 12, "las mutaciones salen de datos/mutaciones.csv (%d)" % Juego.mutaciones.size())
	var rarezas := {}
	for m in Juego.mutaciones:
		rarezas[m.rareza_minima] = true
		verificar(String(m.descripcion).contains("{v}"), "%s muestra su valor en la descripción" % m.id)
	verificar(rarezas.size() == 4, "hay mutaciones de las cuatro rarezas")


func probar_niveles() -> void:
	EvolucionRun.modo_automatico = "mejor"
	var primera := crear(0)
	for i in 30:
		primera.depositar(1.0, Vector2.ZERO)
	verificar(not primera.evolucion.habilitada and primera.evolucion.nivel == 0, "la primera expedición es la obrera sola: todavía sin néctar")
	await cerrar(primera)
	var r := crear()
	var e := r.evolucion
	verificar(e != null and e.nivel == 0, "la run empieza en nivel 0")
	verificar(e.necesario >= EvolucionRun.NECTAR_MINIMO, "el primer nivel pide un mínimo de entregas")
	var antes := r.colonia.cantidad()
	for i in ceili(e.necesario):
		r.depositar(1.0, Vector2.ZERO)
	verificar(e.nivel == 1, "llenar el néctar con entregas reales sube de nivel")
	verificar(r.colonia.cantidad() > antes, "cada nivel eclosiona obreras (%d → %d)" % [antes, r.colonia.cantidad()])
	verificar(e.pendientes == 1, "queda una mutación por elegir")
	var primero := e.necesario
	r.process_mode = Node.PROCESS_MODE_INHERIT
	for i in 120:
		await get_tree().process_frame
		if e.pendientes == 0:
			break
	r.process_mode = Node.PROCESS_MODE_DISABLED
	verificar(e.pendientes == 0 and e.historial.size() == 1, "la política automática elige sola sin trabar la run")
	e.sumar_nectar(e.necesario)
	verificar(e.nivel == 2 and e.necesario > primero, "cada nivel pide más néctar que el anterior")
	# Un pico de entregas puede saltar varios niveles: quedan en cola.
	e.sumar_nectar(e.necesario * 6.0)
	verificar(e.nivel >= 4 and e.pendientes >= 2, "varios niveles juntos se encolan (nivel %d, %d por elegir)" % [e.nivel, e.pendientes])
	# Rareza: el valor escala desde la rareza mínima.
	var m: Dictionary = Juego.mutaciones_por_id["mandibulas_sierra"]
	verificar(is_equal_approx(e.carta(m, "legendaria").valor, roundf(m.valor * 4.0)), "una legendaria vale ×4 la común")
	var pesos := e.pesos_rareza(10)
	verificar(pesos.legendaria > e.pesos_rareza(0).legendaria and pesos.comun < e.pesos_rareza(0).comun, "con más nivel salen mejores rarezas")
	# Las que tienen tope dejan de ofrecerse.
	var tope: Dictionary = Juego.mutaciones_por_id["buche_elastico"]
	e.elegidas[tope.id] = tope.max
	var ofrecida := false
	for i in 200:
		for c in e.generar_oferta():
			if c.id == tope.id:
				ofrecida = true
	verificar(not ofrecida, "una mutación con tope no vuelve a ofrecerse")
	var oferta := e.generar_oferta()
	var ids := {}
	for c in oferta:
		ids[c.id] = true
	verificar(oferta.size() == EvolucionRun.CARTAS_POR_OFERTA and ids.size() == oferta.size(), "cada oferta trae tres cartas distintas")
	await cerrar(r)



func probar_eleccion_del_jugador() -> void:
	EvolucionRun.modo_automatico = "jugador"
	var r := crear()
	var e := r.evolucion
	e.sumar_nectar(e.necesario)
	e._demora_oferta = -1.0
	e._ofrecer()
	verificar(e.eligiendo and get_tree().paused, "subir de nivel pausa la run para elegir")
	var ui: EleccionMutacion = e._ui
	verificar(is_instance_valid(ui) and ui.visible and ui._cartas.size() == 3, "se muestran tres cartas")
	r.hud.pausar()
	verificar(not is_instance_valid(r.hud._ventana), "la pausa no se abre encima de las cartas")
	var revolver := e.revolver_restante
	ui._revolver()
	verificar(e.revolver_restante == revolver - 1 and ui._cartas.size() == 3, "revolver cambia la oferta una vez")
	verificar(not e.revolver(), "no se puede revolver más de lo permitido")
	e.elegir(0)
	verificar(not e.eligiendo and not get_tree().paused and e.historial.size() == 1, "elegir aplica la mutación y despausa")
	await cerrar(r)


func probar_efectos() -> void:
	EvolucionRun.modo_automatico = "mejor"
	var r := crear()
	var e := r.evolucion
	var dano := r.multiplicador_dano_activo()
	e.aplicar(e.carta(Juego.mutaciones_por_id["mandibulas_sierra"], "comun"))
	verificar(is_equal_approx(r.multiplicador_dano_activo(), dano * 1.15), "Mandíbulas de sierra suma 15% de daño")
	var paso := r.factor_paso()
	e.aplicar(e.carta(Juego.mutaciones_por_id["patas_de_grillo"], "comun"))
	verificar(r.factor_paso() > paso, "la velocidad de la run acelera el paso")
	var migas := Juego.stat("multiplicador_migas")
	e.aplicar(e.carta(Juego.mutaciones_por_id["hocico_dorado"], "rara"))
	verificar(is_equal_approx(Juego.stat("multiplicador_migas"), migas * 1.16), "Hocico dorado multiplica las migas sólo en esta run")
	var h := r.colonia._nacer()
	var capacidad: int = h._capacidad
	e.aplicar(e.carta(Juego.mutaciones_por_id["buche_elastico"], "rara"))
	verificar(h._capacidad == capacidad + 1, "el buche crece también en las hormigas que ya salieron")
	var reloj := r.tiempo_restante
	e.aplicar(e.carta(Juego.mutaciones_por_id["reloj_de_arena"], "rara"))
	verificar(is_equal_approx(r.tiempo_restante, reloj + 4.0), "Reloj de arena suma segundos a la expedición")
	verificar(is_equal_approx(r.tirada_critica(Vector2.ZERO), 1.0), "sin mutaciones no hay críticos")
	e.prob_critico = 1.0
	verificar(r.tirada_critica(Vector2.ZERO) == EvolucionRun.MULT_CRITICO_BASE and e.criticos == 1, "una crítica multiplica el daño de la mordida")
	var cuantas := r.colonia.cantidad()
	e.aplicar(e.carta(Juego.mutaciones_por_id["marea_negra"], "legendaria"))
	verificar(r.colonia.cantidad() > cuantas, "Marea negra hace nacer hormigas al instante")
	# Fuerza del enjambre: el daño crece con la colonia viva.
	for i in 120:
		r.colonia._nacer()
	e.aplicar(e.carta(Juego.mutaciones_por_id["fuerza_enjambre"], "rara"))
	var con_enjambre := e.multiplicador_dano()
	verificar(is_equal_approx(con_enjambre, 1.15 + 0.04 * 2), "Fuerza del enjambre suma por cada 50 hormigas (%.3f con %d)" % [con_enjambre, r.colonia.cantidad()])
	await cerrar(r)


func probar_cofre_y_horda() -> void:
	EvolucionRun.modo_automatico = "jugador"
	var r := crear()
	var e := r.evolucion
	verificar(e.abrir_cofre() and e.cofres == 1 and e.pendientes == 1, "una miga dorada puede abrir un cofre de mutación")
	e._demora_oferta = -1.0
	e._ofrecer()
	var sin_comunes := true
	for c in e.oferta:
		sin_comunes = sin_comunes and c.rareza != "comun"
	verificar(e.oferta_cofre and sin_comunes, "el cofre no trae cartas comunes")
	verificar(e._ui._titulo.text == "¡COFRE DORADO!", "la pantalla del cofre tiene su propio título")
	e.elegir(0)
	verificar(e.cofres == 0 and e.nivel == 0 and not get_tree().paused, "abrir el cofre no gasta néctar ni sube de nivel")
	# Hitos de la horda: sólo lo que creció en esta run.
	r.colonia._por_salir = 0
	for i in 30:
		r.colonia._nacer()
	e._celebrar_horda()
	verificar(e._hito_horda == 1, "los hitos ya superados al salir no se festejan")
	for i in 25:
		r.colonia._nacer()
	e._celebrar_horda()
	verificar(e._hito_horda == 2 and r.hud._lbl_racha.text == "¡50 HORMIGAS!", "pasar 50 hormigas se festeja con un cartel")
	await cerrar(r)


func probar_fin_de_run() -> void:
	EvolucionRun.modo_automatico = "mejor"
	var r := crear()
	var e := r.evolucion
	var base := Juego.stat("multiplicador_migas")
	e.aplicar(e.carta(Juego.mutaciones_por_id["hocico_dorado"], "legendaria"))
	verificar(Juego.stat("multiplicador_migas") > base, "la mutación cambia la stat durante la run")
	var datos := JSON.stringify(Juego.datos_partida())
	verificar(not datos.contains("hocico_dorado") and not datos.contains("mods_run"), "las mutaciones no se guardan en la partida")
	r._cerrar()
	verificar(is_equal_approx(Juego.stat("multiplicador_migas"), base), "al cobrar la run las stats vuelven a las de la tienda")
	verificar(Juego.estadistica("mayor_nivel") >= 0, "el mayor nivel queda en las estadísticas")
	await cerrar(r)
