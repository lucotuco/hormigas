extends Node
## Evoluciones por contenido: misma extracción, tesoros y transporte existentes.
var total := 0
var fallas := 0
const NUEVAS := ["sondeo", "cantera", "puente"]
const RUN := preload("res://mundo/run.tscn")


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	seed(871)
	probar_desbloqueos()
	await probar_sondeo()
	await probar_cantera()
	await probar_puente()
	Juego.reiniciar_estado()
	verificar(not Juego.guardado_habilitado, "las evoluciones se prueban sin guardar la partida personal")
	print("Evoluciones de viaje: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func preparar_requisitos() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mandibulas": 8, "mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego.reclutadas = {"voladora": 3, "demoledora": 1}
	Juego._cache_stats.clear()
	Juego.actualizar_evoluciones()


func terminar_proyecto(id: String) -> void:
	for objetivo in ProyectosCampana.por_id(id).objetivos:
		Juego.registrar_objetivo_proyecto(objetivo.id)


func equipar(ids: Array) -> void:
	for actual in Juego.evoluciones_equipadas.duplicate():
		Juego.alternar_evolucion(actual)
	for id in ids:
		Juego.alternar_evolucion(id)


func probar_desbloqueos() -> void:
	preparar_requisitos()
	var proyectos_tempranos := {"sondeo": "restaurante_despensa", "cantera": "museo_galeria", "puente": "obelisco_parada"}
	for id in NUEVAS:
		verificar(EvolucionesHormiga.DATOS[id].proyecto == proyectos_tempranos[id], "%s se aprende antes de Roma y París para tener recorrido útil" % id)
		verificar(not Juego.evoluciones_desbloqueadas.has(id), "%s no se desbloquea sólo con mandíbulas y reclutas" % id)
	for id in NUEVAS:
		var proyecto := ProyectosCampana.por_id(EvolucionesHormiga.DATOS[id].proyecto)
		for i in range(proyecto.objetivos.size() - 1):
			Juego.registrar_objetivo_proyecto(proyecto.objetivos[i].id)
		verificar(not Juego.evoluciones_desbloqueadas.has(id), "%s exige todos los objetos de su proyecto" % id)
		Juego.registrar_objetivo_proyecto(proyecto.objetivos.back().id)
		verificar(Juego.evoluciones_desbloqueadas.has(id), "registrar el último objeto desbloquea %s sin comprar de nuevo" % id)
	verificar(Juego.evoluciones_equipadas.size() == 2 and not Juego.alternar_evolucion("puente"), "las nuevas conductas conservan el límite de dos equipadas")
	verificar(Juego.alternar_evolucion("sondeo") and Juego.alternar_evolucion("puente") and Juego.evolucion_activa("cantera") and Juego.evolucion_activa("puente"), "cambiar de equipo sigue siendo gratuito y explícito")
	var datos: Dictionary = JSON.parse_string(JSON.stringify(Juego.datos_partida()))
	Juego.reiniciar_estado()
	Juego.restaurar_partida(datos)
	verificar(Juego.evoluciones_desbloqueadas.size() == 3 and Juego.evolucion_activa("cantera") and Juego.evolucion_activa("puente"), "desbloqueos por viaje y equipo sobreviven al roundtripJSON")
	Juego.coronas = 1
	verificar(Juego.fundar_colonia() and Juego.evolucion_activa("puente") and Juego.proyecto_completo("obelisco_parada"), "fundar conserva proyectos y evoluciones aunque reinicie los reclutas")
	Juego.restaurar_partida({"version": 7, "evoluciones": {"corte": true, "contagio": true, "barrido": true, "camada": true}, "equipadas": ["corte", "camada"]})
	verificar(Juego.evoluciones_desbloqueadas.size() == 4 and Juego.evolucion_activa("corte") and Juego.evolucion_activa("camada"), "una partida anterior conserva sus cuatro evoluciones sin requisitos nuevos")
	verificar(not Juego.evoluciones_desbloqueadas.has("sondeo") and not Juego.evoluciones_desbloqueadas.has("cantera") and not Juego.evoluciones_desbloqueadas.has("puente"), "la migración no regala conductas de proyectos no conquistados")


func crear_run(evoluciones: Array) -> Run:
	preparar_requisitos()
	for id in evoluciones:
		terminar_proyecto(EvolucionesHormiga.DATOS[id].proyecto)
	equipar(evoluciones)
	var run: Run = RUN.instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.radio_actual = 12000
	run.colonia._activa = false
	run.cocina.limite_rutas_por_cuadro = 0 # Pasos manuales en un mismo cuadro de prueba.
	return run


func crear_pieza(run: Run, tipo: String, pos := Vector2(-230, -240)) -> PiezaCasa:
	var rect := Rect2(pos, Vector2(110, 130))
	var datos := {"clave": "evolucion:" + tipo + str(run.comidas.partes.size()), "tipo": tipo,
		"rect": rect, "color": Color.WHITE, "pared": tipo == "pared",
		"dibujo": {"tipo": tipo, "rect": rect, "color": Color.WHITE}}
	var parte := PiezaCasa.new()
	run.comidas.add_child(parte)
	parte.iniciar(datos, run.cocina)
	parte.destruida.connect(run.comidas._on_destruida)
	run.comidas.partes.append(parte)
	parte._preparar_mordiscos()
	return parte


func preparar_boca(h: Hormiga, parte: PiezaCasa, dano: float) -> void:
	h.position = parte.punto_mordida(Vector2.ZERO, h.run.radio_actual, h.casta == "voladora")
	h.comida = parte
	h.estado = Hormiga.Estado.MORDIENDO
	h._dano = dano
	h._reloj_mordida = 0


func probar_sondeo() -> void:
	var run := crear_run(["sondeo"])
	var parte := crear_pieza(run, "heladera")
	var h := run.colonia._nacer("voladora")
	verificar(h._sondeo and not h._cantera, "la voladora copia Sondeo al nacer, sin decidir habilidades por cuadro")
	preparar_boca(h, parte, 1.0e-12)
	var vida := parte.vida
	var area := parte.mordiscos.area_total()
	h._morder(0.1)
	verificar(parte.vida == vida and parte.mordiscos.area_total() == area and not parte._tesoro_abierto and run.comidas._tesoros == 0, "trabajo menor a un píxel no abre un escondite ni inventa carga")
	preparar_boca(h, parte, 25.0)
	h._morder(0.1)
	verificar(parte._tesoro_abierto and run.comidas._tesoros > 0 and h.carga > 0 and parte.vida > vida * 0.99, "una porción real abre antes el escondite, manteniendo más del99% del cuerpo")
	verificar(parte.mordiscos.area_total() < area and parte._porcion_reciente.size.x <= 6.0001 and parte._porcion_reciente.size.y <= 6.0001 and Juego.migas_run == 0, "Sondeo conserva bocado y carga reales sin acreditar el tesoro antes de transportarlo")
	var tesoros := run.comidas._tesoros
	vida = parte.vida
	area = parte.mordiscos.area_total()
	verificar(not parte.abrir_escondite() and run.comidas._tesoros == tesoros and parte.vida == vida and parte.mordiscos.area_total() == area, "el escondite ya abierto no se duplica ni retira más cuerpo")
	var mesa := crear_pieza(run, "mesa", Vector2(-500, -240))
	verificar(not mesa.abrir_escondite() and not mesa._tesoro_abierto, "Sondeo no agrega escondites a muebles que nunca los tuvieron")
	var otra := crear_pieza(run, "biblioteca", Vector2(-700, -300))
	run.comidas._tesoros = 23
	vida = otra.vida
	verificar(otra.abrir_escondite() and run.comidas._tesoros <= 24 and otra.vida == vida, "abrir anticipadamente respeta el máximo compartido de24 alimentos ocultos")
	var limitada := crear_pieza(run, "vitrina", Vector2(-850, -300))
	run.comidas._tesoros = 24
	verificar(not limitada.abrir_escondite() and run.comidas._tesoros == 24, "un cupo de tesoros agotado no genera nuevos recursos")
	run.queue_free()
	await get_tree().process_frame


func valor_restos(run: Run) -> float:
	var valor := 0.0
	for resto in run.comidas.fragmentos:
		if is_instance_valid(resto) and not resto.muerta:
			valor += resto.recompensa
	return valor


func probar_cantera() -> void:
	var run := crear_run(["cantera"])
	for tipo in ["mesada", "pared"]:
		var parte := crear_pieza(run, tipo)
		var h := run.colonia._nacer("demoledora")
		preparar_boca(h, parte, 100.0)
		var vida := parte.vida
		var area := parte.mordiscos.area_total()
		var saldo := Juego.migas_run
		var anteriores := valor_restos(run)
		h._morder(0.1)
		var extraido := parte.recompensa * (vida - parte.vida) / parte.vida_max * Juego.stat("multiplicador_migas")
		verificar(h._cantera and extraido > 0 and h.carga == 0 and h.bocados == 0 and h.estado == Hormiga.Estado.MORDIENDO, "Cantera mantiene a la demoledora trabajando sin viajar con %s" % tipo)
		verificar(is_equal_approx(valor_restos(run) - anteriores, extraido) and Juego.migas_run == saldo, "Cantera deja exactamente el valor real extraído de %s, sin otro 35%% ni cobro directo" % tipo)
		var porcion := parte._porcion_reciente
		verificar(porcion.has_area() and porcion.size.x <= 6.0001 and porcion.size.y <= 6.0001 and is_equal_approx(area - parte.mordiscos.area_total(), porcion.get_area()), "Cantera conserva una porción local sólida y el área retirada de %s" % tipo)
		var resto: FragmentoCasa = run.comidas.fragmentos.back()
		verificar(resto.material_id == parte.nivel_requerido and is_equal_approx(resto.recompensa, extraido), "el fragmento de %s conserva su material y recompensa" % tipo)
		var cargadora := run.colonia._nacer("cargadora", resto.position)
		cargadora._velocidad = 700
		cargadora.comida = resto
		cargadora.estado = Hormiga.Estado.MORDIENDO
		cargadora._reloj_mordida = 0
		cargadora._morder(0.1)
		verificar(is_equal_approx(cargadora.carga, extraido) and Juego.migas_run == saldo, "la cargadora recoge todo el material de %s sin acreditarlo todavía" % tipo)
		for i in 240:
			if cargadora.carga <= 0:
				break
			cargadora._process(0.05)
		verificar(cargadora.carga == 0 and is_equal_approx(Juego.migas_run - saldo, extraido), "sólo el regreso real de la cargadora acredita una vez el material de %s" % tipo)
	var madera := crear_pieza(run, "mesa")
	var demo := run.colonia._nacer("demoledora")
	preparar_boca(demo, madera, 100.0)
	var restos := valor_restos(run)
	demo._morder(0.1)
	verificar(demo.carga > 0 and valor_restos(run) == restos, "Cantera no convierte madera en una extracción continua que corresponde a carpinteras")
	run.queue_free()
	await get_tree().process_frame


func crear_resto(run: Run, material_id: int, pos: Vector2, valor: float) -> FragmentoCasa:
	var resto := FragmentoCasa.new()
	run.comidas.add_child(resto)
	resto.iniciar(pos, valor, material_id)
	resto.destruida.connect(run.comidas._on_destruida)
	run.comidas.fragmentos.append(resto)
	run.comidas._indexar(resto)
	return resto


func probar_puente() -> void:
	var run := crear_run([])
	run.comidas._indice.clear()
	var metal := crear_resto(run, 2, Vector2(-110, -120), 23.0)
	var h := run.colonia._nacer("voladora", metal.position)
	h.comida = metal
	h.estado = Hormiga.Estado.MORDIENDO
	h._reloj_mordida = 0
	h._morder(0.1)
	verificar(RolesHormiga.peso_maximo("voladora") == 1 and RolesHormiga.afinidad("voladora", metal) == 0 and h.carga == 0 and not metal.muerta, "sin Puente la voladora no selecciona ni recoge material resistente")
	run.queue_free()
	await get_tree().process_frame
	run = crear_run(["puente"])
	run.comidas._indice.clear()
	metal = crear_resto(run, 2, Vector2(-110, -120), 23.0)
	var muro := crear_resto(run, 3, Vector2(-150, -120), 41.0)
	verificar(metal.peso == 2 and muro.peso == 2 and RolesHormiga.peso_maximo("voladora") == int(Juego.stat("peso_voladora_alzada")), "Puente conserva los pesos originales y usa su capacidad declarada en balance")
	verificar(RolesHormiga.afinidad("voladora", metal) > 0 and RolesHormiga.afinidad("voladora", muro) == 0, "dos montones de peso2 se distinguen por material: resistentes sí, muros no")
	verificar(run.comidas.buscar_cercana(metal.position, 5, run.radio_actual, {}, "voladora") == metal and run.comidas.buscar_cercana(muro.position, 5, run.radio_actual, {}, "voladora") == null, "la búsqueda espacial usa la misma autorización de materiales que la recogida")
	h = run.colonia._nacer("voladora", muro.position)
	h.comida = muro
	h.estado = Hormiga.Estado.MORDIENDO
	h._reloj_mordida = 0
	h._morder(0.1)
	verificar(h.carga == 0 and not muro.muerta, "un objetivo manual no permite a Puente levantar paredes")
	h.position = metal.position
	h.comida = metal
	h.estado = Hormiga.Estado.MORDIENDO
	h._reloj_mordida = 0
	h._morder(0.1)
	verificar(metal.muerta and is_equal_approx(h.carga, 23.0) and Juego.migas_run == 0 and h.casta == "voladora", "Puente recoge el valor existente sin cambiar rutas de vuelo ni cobrar antes de volver")
	var mezcla := crear_resto(run, 2, Vector2(-180, -120), 12.0)
	mezcla.sumar(5.0, 3)
	verificar(not RolesHormiga.puede_cargar("voladora", mezcla) and RolesHormiga.puede_cargar("cargadora", mezcla), "un montón mezclado con muro sigue requiriendo transporte terrestre")
	run.queue_free()
	await get_tree().process_frame


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", detalle)
