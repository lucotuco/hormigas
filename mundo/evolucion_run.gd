class_name EvolucionRun
extends Node
## Néctar, niveles y mutaciones de la expedición, al estilo de los roguelites
## de hordas: cada entrega real suma néctar; al llenar la barra la colonia sube
## de nivel, eclosiona una tanda de obreras y se elige una de tres mutaciones
## con rareza. Todo vale sólo en esta run (Juego.mods_run y los multiplicadores
## que lee la hormiga por mordida); el hormiguero no cambia.
##
## El trabajo es por entrega y por elección, nunca por hormiga y cuadro: los
## multiplicadores quedan cacheados y el enjambre se recalcula a 2 Hz.

signal nivel_subido(nivel: int)
signal oferta_lista(cartas: Array[Dictionary])
signal mutacion_elegida(carta: Dictionary)

const CARTAS_POR_OFERTA := 3
## Néctar del nivel n = max(NECTAR_MINIMO, hormigas × NECTAR_POR_HORMIGA) × (1 + CRECE_POR_NIVEL × n).
## Atarlo a la colonia mantiene parecida la cantidad de niveles por run con
## una obrera o con quinientas; el tiempo entre niveles crece dentro de la run.
const NECTAR_MINIMO := 6.0
const NECTAR_POR_HORMIGA := 1.2
const CRECE_POR_NIVEL := 0.8
## Cada nivel eclosiona esta parte de la colonia (al menos una obrera).
const ECLOSION := 0.15
const HORMIGAS_POR_ENJAMBRE := 50.0
const DANO_POR_DESBORDE := 0.05
const PROB_CRITICO_MAX := 0.75
const MULT_CRITICO_BASE := 3.0
const REVOLVER_POR_RUN := 1
## Niveles de suerte extra al tirar las rarezas de un cofre dorado.
const SUERTE_COFRE := 6
## Celebraciones de la horda: al pasar estas cantidades de hormigas vivas.
const HITOS_HORDA := [25, 50, 100, 150, 200, 300, 400, 500]
## Las cartas aparecen un instante después del nivel: primero se ve la eclosión.
const DEMORA_OFERTA := 0.45
const MAX_TEXTOS_CRITICO_POR_SEGUNDO := 6.0
const COLORES_RAREZA := {"comun": Color("c9cfc0"), "rara": Color("6fb6ff"), "epica": Color("c486ff"), "legendaria": Color("ffc847")}

## "jugador" pausa y espera la elección; "mejor" o "azar" eligen solos (pruebas
## y bots). "auto": "mejor" en headless (nada se traba) y "jugador" con ventana.
static var modo_automatico := "auto"

var run: Run
## Las primeras expediciones son la obrera sola: el néctar aparece después de
## la primera compra (Juego.REVELABLES "mutaciones").
var habilitada := false
var nivel := 0
var nectar := 0.0
var necesario := NECTAR_MINIMO
var pendientes := 0
## Cofres por abrir (parte de `pendientes`): se ofrecen antes que los niveles.
var cofres := 0
var oferta_cofre := false
var eligiendo := false
var oferta: Array[Dictionary] = []
var revolver_restante := REVOLVER_POR_RUN
var elegidas: Dictionary = {}
var historial: Array[Dictionary] = []
var criticos := 0
var desbordes := 0
var nacidas_por_nivel := 0

var prob_critico := 0.0
var mult_critico := MULT_CRITICO_BASE
var _suma_dano := 0.0
var _suma_ritmo := 0.0
var _suma_paso := 0.0
var _suma_migas := 0.0
var _suma_botin := 0.0
var _suma_capacidad := 0
var _suma_cria := 0.0
var _bonus_enjambre := 0.0
var _bonus_furia := 0.0
var _bonus_eclosion := 0.0
var _bonus_nectar := 0.0
var _prob_hermana := 0.0
var _mult_dano := 1.0
var _demora_oferta := -1.0
var _reloj_enjambre := 0.0
var _creditos_texto := MAX_TEXTOS_CRITICO_POR_SEGUNDO
var _rng := RandomNumberGenerator.new()
var _ui: Node


func iniciar(r: Run) -> void:
	run = r
	_rng.randomize()
	necesario = _necesario_para(0)
	habilitada = Juego.revelado("mutaciones")
	if not habilitada:
		set_process(false)
		return
	run.entrega_real.connect(_on_entrega)
	_recalcular()
	var barra := BarraNectar.new()
	barra.evolucion = self
	run.hud.add_child(barra)


## "" cuando elige el jugador; si no, la política automática.
func automatico() -> String:
	if modo_automatico == "auto":
		return "mejor" if DisplayServer.get_name() == "headless" else ""
	return "" if modo_automatico == "jugador" else modo_automatico


# =====================================================================
# Néctar y niveles
# =====================================================================

func en_juego() -> bool:
	return is_instance_valid(run) and run.activa and not run.retirando and not run.terminada


func _on_entrega(_cantidad: float, _categoria: int) -> void:
	if not en_juego():
		return
	if _prob_hermana > 0.0 and _rng.randf() < _prob_hermana:
		if run.colonia.eclosionar(1, false) > 0:
			nacidas_por_nivel += 1
	sumar_nectar(1.0 + _bonus_nectar)


func sumar_nectar(cantidad: float) -> void:
	nectar += cantidad
	while nectar >= necesario:
		nectar -= necesario
		_subir_nivel()


## Miga dorada: una oferta extra, sin gastar néctar, con rareza rara o mejor.
func abrir_cofre() -> bool:
	if not habilitada or not en_juego():
		return false
	cofres += 1
	pendientes += 1
	run.efectos.rafaga(Vector2.ZERO, 100)
	Sonido.tocar("legendaria", 1.1, 0.0)
	if _demora_oferta < 0.0 and not eligiendo:
		_demora_oferta = DEMORA_OFERTA
	return true


func progreso() -> float:
	return clampf(nectar / maxf(necesario, 0.001), 0.0, 1.0)


func _necesario_para(n: int) -> float:
	var hormigas := float(run.colonia.cantidad()) if is_instance_valid(run) else 1.0
	return maxf(NECTAR_MINIMO, hormigas * NECTAR_POR_HORMIGA) * (1.0 + CRECE_POR_NIVEL * n)


func _subir_nivel() -> void:
	nivel += 1
	Juego.registrar_maximo("mayor_nivel", nivel)
	var deseadas := maxi(1, roundi(run.colonia.cantidad() * ECLOSION * (1.0 + _bonus_eclosion)))
	var nacidas := run.colonia.eclosionar(deseadas)
	nacidas_por_nivel = nacidas
	if nacidas < deseadas:
		desbordes += 1
		_recalcular()
	necesario = _necesario_para(nivel)
	pendientes += 1
	run.efectos.rafaga(Vector2.ZERO, 120)
	run.efectos.texto(Vector2(0, -40), tr("¡NIVEL %d!") % nivel, COLORES_RAREZA.legendaria, 1.7)
	if nacidas > 0:
		run.efectos.texto(Vector2(0, -14), tr("¡Eclosión! +%d hormigas") % nacidas, Color("ffe7a8"), 1.0)
	else:
		run.efectos.texto(Vector2(0, -14), tr("¡Colonia desbordada! +%d%% de daño") % roundi(DANO_POR_DESBORDE * 100), Color("ffb08a"), 1.0)
	Sonido.tocar("nivel", 1.0 + minf(nivel, 10) * 0.02, 0.0)
	nivel_subido.emit(nivel)
	if _demora_oferta < 0.0 and not eligiendo:
		_demora_oferta = DEMORA_OFERTA


func _process(delta: float) -> void:
	if not is_instance_valid(run):
		return
	_creditos_texto = minf(MAX_TEXTOS_CRITICO_POR_SEGUNDO, _creditos_texto + delta * MAX_TEXTOS_CRITICO_POR_SEGUNDO)
	_reloj_enjambre -= delta
	if _reloj_enjambre <= 0.0:
		_reloj_enjambre = 0.5
		_recalcular()
		_celebrar_horda()
	if _demora_oferta >= 0.0:
		_demora_oferta -= delta
		if _demora_oferta < 0.0:
			_ofrecer()


# =====================================================================
# Ofertas
# =====================================================================

func _ofrecer() -> void:
	if pendientes <= 0 or eligiendo:
		return
	if not en_juego():
		pendientes = 0
		return
	oferta_cofre = cofres > 0
	oferta = generar_oferta(oferta_cofre)
	if oferta.is_empty():
		pendientes = 0
		cofres = 0
		return
	eligiendo = true
	var modo := automatico()
	if modo != "":
		elegir(_eleccion_automatica(modo))
		return
	_mostrar_ui()
	oferta_lista.emit(oferta)


func pesos_rareza(n: int) -> Dictionary:
	return {
		"comun": maxf(30.0, 62.0 - 3.0 * n),
		"rara": 27.0 + 1.5 * n,
		"epica": 9.0 + 1.0 * n,
		"legendaria": 2.0 + 0.5 * n,
	}


func _tirar_rareza(suerte := 0) -> String:
	var pesos := pesos_rareza(nivel + suerte)
	var total := 0.0
	for r in Juego.RAREZAS:
		total += float(pesos[r])
	var tiro := _rng.randf() * total
	for r in Juego.RAREZAS:
		tiro -= float(pesos[r])
		if tiro <= 0.0:
			return r
	return "comun"


func disponible(m: Dictionary) -> bool:
	return m.max <= 0 or int(elegidas.get(m.id, 0)) < m.max


## Un cofre tira con más suerte y nunca trae comunes.
func generar_oferta(de_cofre := false) -> Array[Dictionary]:
	var cartas: Array[Dictionary] = []
	var usadas := {}
	for i in CARTAS_POR_OFERTA:
		var rareza := _tirar_rareza(SUERTE_COFRE if de_cofre else 0)
		if de_cofre and rareza == "comun":
			rareza = "rara"
		var candidatas: Array[Dictionary] = []
		# Si no hay ninguna de esa rareza, baja de a un escalón.
		var indice := Juego.RAREZAS.find(rareza)
		while candidatas.is_empty() and indice >= 0:
			rareza = Juego.RAREZAS[indice]
			for m in Juego.mutaciones:
				if usadas.has(m.id) or not disponible(m):
					continue
				if Juego.RAREZAS.find(m.rareza_minima) <= indice:
					candidatas.append(m)
			indice -= 1
		if candidatas.is_empty():
			break
		var m: Dictionary = candidatas[_rng.randi() % candidatas.size()]
		usadas[m.id] = true
		cartas.append(carta(m, rareza))
	return cartas


func carta(m: Dictionary, rareza: String) -> Dictionary:
	var factor: float = Juego.FACTOR_RAREZA[rareza] / Juego.FACTOR_RAREZA[m.rareza_minima]
	var valor: float = m.valor * factor
	if m.efecto in ["capacidad", "tiempo", "cria"]:
		valor = maxf(1.0, roundf(valor))
	elif m.efecto == "critico_mult":
		valor = snappedf(valor, 0.1)
	else:
		valor = roundf(valor)
	return {"id": m.id, "nombre": m.nombre, "descripcion": m.descripcion, "efecto": m.efecto,
		"rareza": rareza, "valor": valor, "veces": int(elegidas.get(m.id, 0))}


static func texto_valor(c: Dictionary) -> String:
	if c.efecto == "critico_mult":
		return ("%.1f" % c.valor).trim_suffix(".0")
	return str(int(c.valor))


static func descripcion_carta(c: Dictionary) -> String:
	return TranslationServer.translate(c.descripcion).replace("{v}", texto_valor(c))


func revolver() -> bool:
	if not eligiendo or revolver_restante <= 0:
		return false
	revolver_restante -= 1
	oferta = generar_oferta(oferta_cofre)
	Sonido.tocar("carta", 0.9, 0.0)
	oferta_lista.emit(oferta)
	return true


func elegir(indice: int) -> void:
	if not eligiendo or indice < 0 or indice >= oferta.size():
		return
	var c: Dictionary = oferta[indice]
	aplicar(c)
	elegidas[c.id] = int(elegidas.get(c.id, 0)) + 1
	historial.append(c)
	Juego.sumar_estadistica("mutaciones_elegidas")
	if c.rareza == "legendaria":
		Juego.sumar_estadistica("mutaciones_legendarias")
	pendientes = maxi(0, pendientes - 1)
	if oferta_cofre:
		cofres = maxi(0, cofres - 1)
	oferta_cofre = false
	eligiendo = false
	oferta.clear()
	mutacion_elegida.emit(c)
	if pendientes > 0:
		_ofrecer()
	else:
		_cerrar_ui()


## Puntaje de la política automática: rareza primero, después lo que más
## rinde en una run corta. Sin pesos de nivel: el bot tiene que ser estable.
const PREFERENCIA_BOT := {"todo": 9, "marea": 9, "hermanas": 8, "dano": 7, "furia": 7, "enjambre": 6,
	"ritmo": 6, "velocidad": 6, "capacidad": 5, "tiempo": 5, "critico": 5, "critico_mult": 4,
	"migas": 5, "cria": 4, "eclosion": 4, "nectar": 3, "botin": 2}

func _eleccion_automatica(modo: String) -> int:
	if modo == "azar":
		return _rng.randi() % oferta.size()
	var mejor := 0
	var puntaje := -1.0
	for i in oferta.size():
		var c: Dictionary = oferta[i]
		var p := Juego.RAREZAS.find(c.rareza) * 10.0 + float(PREFERENCIA_BOT.get(c.efecto, 1))
		if p > puntaje:
			puntaje = p
			mejor = i
	return mejor


# =====================================================================
# Efectos
# =====================================================================

func aplicar(c: Dictionary) -> void:
	var v: float = c.valor
	match c.efecto:
		"dano": _suma_dano += v / 100.0
		"velocidad": _suma_paso += v / 100.0
		"ritmo": _suma_ritmo += v / 100.0
		"critico": prob_critico = minf(PROB_CRITICO_MAX, prob_critico + v / 100.0)
		"critico_mult": mult_critico += v
		"migas":
			_suma_migas += v / 100.0
			Juego.fijar_en_run("multiplicador_migas", 0.0, 1.0 + _suma_migas)
		"botin":
			_suma_botin += v / 100.0
			Juego.fijar_en_run("bonus_destruir", _suma_botin)
		"eclosion": _bonus_eclosion += v / 100.0
		"nectar": _bonus_nectar += v / 100.0
		"enjambre": _bonus_enjambre += v / 100.0
		"furia": _bonus_furia += v / 100.0
		"hermanas": _prob_hermana += v / 100.0
		"capacidad":
			_suma_capacidad += int(v)
			Juego.fijar_en_run("capacidad", _suma_capacidad)
			for h in run.colonia.hormigas:
				h.refrescar_capacidad()
		"tiempo":
			run.tiempo_restante += v
			run.duracion_total += v
		"cria":
			_suma_cria += v
			Juego.fijar_en_run("cria", _suma_cria)
			run.colonia.recalcular_cria()
		"todo":
			_suma_dano += v / 100.0
			_suma_paso += v / 100.0
			_suma_migas += v / 100.0
			Juego.fijar_en_run("multiplicador_migas", 0.0, 1.0 + _suma_migas)
		"marea":
			run.colonia.eclosionar(maxi(1, roundi(run.colonia.cantidad() * v / 100.0)))
	_recalcular()
	run.efectos.rafaga(Vector2.ZERO, 90)
	Sonido.tocar("legendaria" if c.rareza == "legendaria" else "carta", 1.0, 0.0)


func _recalcular() -> void:
	var enjambres := floorf(float(run.colonia.cantidad()) / HORMIGAS_POR_ENJAMBRE) if is_instance_valid(run) else 0.0
	_mult_dano = 1.0 + _suma_dano + _bonus_enjambre * enjambres + _bonus_furia * nivel + DANO_POR_DESBORDE * desbordes


## Pasar 100, 200… hormigas vivas en la run se festeja una vez. Los hitos
## que ya se tenían al salir del nido no cuentan: sólo lo que creció acá.
var _hito_horda := -1

func _celebrar_horda() -> void:
	if not en_juego() or run.colonia._por_salir > 0:
		return
	var vivas := run.colonia.cantidad()
	if _hito_horda < 0:
		_hito_horda = 0
		while _hito_horda < HITOS_HORDA.size() and vivas >= HITOS_HORDA[_hito_horda]:
			_hito_horda += 1
		return
	var alcanzado := -1
	while _hito_horda < HITOS_HORDA.size() and vivas >= HITOS_HORDA[_hito_horda]:
		alcanzado = HITOS_HORDA[_hito_horda]
		_hito_horda += 1
	if alcanzado < 0:
		return
	run.hud.mostrar_horda(alcanzado)
	run.efectos.racha(Vector2.ZERO, mini(8, _hito_horda + 1))
	run.camara.sacudir(4.0 + _hito_horda)
	Sonido.tocar("crecer", 1.0 + _hito_horda * 0.03, 0.0)


func multiplicador_dano() -> float:
	return _mult_dano


func multiplicador_ritmo() -> float:
	return 1.0 + _suma_ritmo


func multiplicador_paso() -> float:
	return 1.0 + _suma_paso


## Una tirada por mordida (no por cuadro). Devuelve el multiplicador de daño.
func tirada_critica(pos: Vector2) -> float:
	if prob_critico <= 0.0 or _rng.randf() >= prob_critico:
		return 1.0
	criticos += 1
	if _creditos_texto >= 1.0:
		_creditos_texto -= 1.0
		run.efectos.texto(pos + Vector2(0, -8), tr("¡CRÍTICO!"), Color("ff8a5c"), 0.75)
		run.efectos.chispas(pos, Color("ffcf6b"), 4)
		Sonido.tocar("critico", 1.0, 0.08)
	return mult_critico


## Para el resumen del final y las pruebas.
func resumen() -> Dictionary:
	return {"nivel": nivel, "mutaciones": historial.size(), "criticos": criticos, "desbordes": desbordes}


func cerrar() -> void:
	if criticos > 0:
		Juego.sumar_estadistica("criticos", criticos)
		criticos = 0
	if eligiendo:
		eligiendo = false
		oferta.clear()
	pendientes = 0
	cofres = 0
	_demora_oferta = -1.0
	_cerrar_ui()


# =====================================================================
# Interfaz
# =====================================================================

func _mostrar_ui() -> void:
	if not is_instance_valid(_ui):
		_ui = EleccionMutacion.new()
		_ui.evolucion = self
		run.hud.add_child(_ui)
	run.feromonas.soltar()
	run.cancelar_colocacion_entrada()
	run.camara.arrastrando = false
	get_tree().paused = true
	_ui.mostrar(oferta)


func _cerrar_ui() -> void:
	if is_instance_valid(_ui):
		_ui.ocultar()
	if is_inside_tree() and get_tree().paused and not run.hud.pausado():
		get_tree().paused = false
