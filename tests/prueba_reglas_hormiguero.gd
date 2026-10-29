extends Node
## Reglas que usan las cámaras del hormiguero: requisitos que piden castas,
## límite y fuerza de especialistas, y stats nuevas para frenesí, botín,
## derrumbes y migas doradas. Sin mejoras compradas valen lo mismo que antes.
##   godot --headless --fixed-fps 60 --path . res://tests/prueba_reglas_hormiguero.tscn
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	probar_valores_base()
	probar_requisito_de_casta()
	probar_limite_y_fuerza()
	await probar_run()
	_quitar_mejoras_de_prueba()
	Juego.reiniciar_estado()
	print("Reglas del hormiguero: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func probar_valores_base() -> void:
	verificar(Juego.stat("frenesi_duracion") == 6 and Juego.stat("frenesi_ritmo") == 1.5, "sin mejoras el frenesí sigue durando seis segundos a ×1,5")
	verificar(Juego.stat("bonus_destruir") == 0.25 and is_equal_approx(Juego.stat("botin_eventos"), 0.12), "el bonus por destruir y el botín conservan sus valores")
	verificar(Juego.stat("intervalo_doradas") == 1 and Juego.stat("fuerza_especialistas") == 1 and Juego.stat("limite_castas") == 0, "doradas, fuerza y límite de castas empiezan neutros")


func probar_requisito_de_casta() -> void:
	var m := _mejora_de_prueba("prueba_escuela", "dano", "veloz:2|mandibulas:1")
	verificar(m.requisitos.size() == 2 and m.requisitos[0].id == "veloz", "una mejora puede pedir unidades de una casta")
	Juego.niveles = {"mandibulas": 1}
	Juego.reclutadas = {"veloz": 1}
	verificar(not Juego.esta_desbloqueada(m.id), "con una sola veloz sigue cerrada")
	var faltan := Juego.requisitos_faltantes(m.requisitos)
	verificar(faltan.size() == 1 and Juego.texto_requisitos(faltan) == "Requiere 2 en la colonia: Exploradora veloz", "el requisito de casta se explica por unidades")
	Juego.reclutadas = {}
	verificar(Juego.texto_requisitos([{"id": "veloz", "nivel": 1}]) == "Requiere reclutar: Exploradora veloz", "una sola unidad se pide como reclutar")
	Juego.niveles = {}
	verificar(Juego.texto_requisitos(Juego.requisitos_faltantes(m.requisitos)) == "Requiere: Exploradora veloz ×2 + Mandíbulas fuertes nivel 1", "castas y mejoras se piden juntas")
	Juego.niveles = {"mandibulas": 1}
	Juego.reclutadas = {"veloz": 2}
	verificar(Juego.esta_desbloqueada(m.id), "con las dos veloces se abre")
	Juego.niveles = {}
	Juego.reclutadas = {}


func probar_limite_y_fuerza() -> void:
	var limite := _mejora_de_prueba("prueba_cuarteles", "limite_castas", "")
	limite.tipo = "suma"
	limite.valor = 2
	var fuerza := _mejora_de_prueba("prueba_fuerza", "fuerza_especialistas", "")
	fuerza.tipo = "multiplica"
	fuerza.valor = 1.5
	Juego.niveles = {}
	Juego._cache_stats.clear()
	var reinas := Juego.maximo_casta("reina")
	verificar(reinas == Juego.castas_por_id.reina.maximo and Juego.maximo_casta("mini") == 0, "sin mejoras el límite es el de castas.csv y las minis no se reclutan")
	Juego.niveles = {"prueba_cuarteles": 1}
	Juego._cache_stats.clear()
	verificar(Juego.maximo_casta("reina") == reinas + 2, "limite_castas suma unidades a cada casta")
	Juego.migas = 1e9
	verificar(Juego.comprar_castas_lote("reina", 0) == reinas + 2 and Juego.cantidad_casta("reina") == reinas + 2, "Máx recluta hasta el límite ampliado")
	var guardada := Juego.datos_partida().duplicate(true)
	Juego.restaurar_partida(guardada)
	verificar(Juego.cantidad_casta("reina") == reinas + 2, "cargar la partida no recorta las unidades del límite ampliado")
	Juego.niveles = {}
	Juego.reclutadas = {}
	Juego._cache_stats.clear()
	var antes_veloz: float = Juego.stats_casta("veloz").dano
	var antes_obrera: float = Juego.stats_casta("obrera").dano
	Juego.niveles = {"prueba_fuerza": 2}
	Juego._cache_stats.clear()
	verificar(is_equal_approx(Juego.stats_casta("veloz").dano, antes_veloz * 2.25), "fuerza_especialistas multiplica el daño de las especialistas")
	verificar(is_equal_approx(Juego.stats_casta("obrera").dano, antes_obrera) and is_equal_approx(Juego.stats_casta("mini").dano, Juego.stat("dano") * Juego.castas_por_id.mini.dano), "obreras y miniobreras no cambian")
	Juego.niveles = {}
	Juego._cache_stats.clear()


func probar_run() -> void:
	var frenesi := _mejora_de_prueba("prueba_frenesi", "frenesi_duracion", "")
	frenesi.tipo = "suma"
	frenesi.valor = 2
	var ritmo := _mejora_de_prueba("prueba_ritmo", "frenesi_ritmo", "")
	ritmo.tipo = "suma"
	ritmo.valor = 0.25
	var doradas := _mejora_de_prueba("prueba_doradas", "intervalo_doradas", "")
	doradas.tipo = "multiplica"
	doradas.valor = 0.5
	var botin := _mejora_de_prueba("prueba_botin", "botin_eventos", "")
	botin.tipo = "suma"
	botin.valor = 0.08
	Juego.niveles = {"prueba_frenesi": 1, "prueba_ritmo": 2, "prueba_doradas": 1, "prueba_botin": 1}
	Juego._cache_stats.clear()
	Juego.runs_jugadas = 3
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	for i in 20:
		run.depositar(1)
	verificar(run.frenesi_restante == 8 and is_equal_approx(run.factor_ritmo(), 2.0), "las mejoras alargan y aceleran el frenesí")
	run.eventos.iniciar(run)
	verificar(run.eventos._reloj_dorada <= Eventos.PRIMERA_DORADA.y * 0.5 + 0.01, "las doradas aparecen antes con intervalo_doradas")
	Juego.migas_run = 1000
	var dorada := Evento.new()
	dorada.tipo = "paloma"
	var premio := run.eventos.premiar(dorada)
	verificar(is_equal_approx(premio, 200.0), "el botín usa la parte de la run de botin_eventos (%.1f)" % premio)
	dorada.free()
	run.queue_free()
	await get_tree().process_frame
	Juego.niveles = {}
	Juego._cache_stats.clear()


var _ids_prueba: Array[String] = []


func _mejora_de_prueba(id: String, stat: String, requiere: String) -> Dictionary:
	var m: Dictionary = Juego.mejoras_por_id.mandibulas.duplicate(true)
	m.id = id
	m.stat = stat
	m.bonus_cada = 0
	m.tope_por_destino = 0
	m.destino = ""
	m.nivel_max = 10
	m.requisitos = Juego._leer_requisitos(requiere)
	Juego.mejoras.append(m)
	Juego.mejoras_por_id[id] = m
	_ids_prueba.append(id)
	return m


func _quitar_mejoras_de_prueba() -> void:
	for id in _ids_prueba:
		Juego.mejoras.erase(Juego.mejoras_por_id[id])
		Juego.mejoras_por_id.erase(id)
	Juego._cache_stats.clear()


func verificar(valor: bool, mensaje: String) -> void:
	total += 1
	if not valor:
		fallas += 1
	print(("OK: " if valor else "FALLA: ") + mensaje)
