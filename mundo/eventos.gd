class_name Eventos
extends Node2D
signal botin_terminado
## Decide cuándo aparece la amenaza de cada destino y la miga dorada, recibe
## los clics (antes que la comida) y reparte los premios.
##
## - Amenazas: una por destino, para que cada lugar se juegue distinto. Desde
##   la sexta expedición (Juego.REVELABLES "amenazas").
## - Miga dorada: un premio al azar si la pisás antes de que desaparezca.
##   Desde la tercera expedición.

## La amenaza propia de cada destino.
const AMENAZAS := {"casa": "arana", "restaurante": "mozo", "museo": "aspiradora", "obelisco": "paloma", "coliseo": "gato", "eiffel": "rata"}
const PALOMAS_POR_BANDADA := 3
## Segundos hasta la primera aparición y entre apariciones (mínimo, máximo).
const PRIMERA_AMENAZA := Vector2(12.0, 18.0)
const ENTRE_AMENAZAS := Vector2(35.0, 50.0)
const PRIMERA_DORADA := Vector2(18.0, 28.0)
const ENTRE_DORADAS := Vector2(45.0, 70.0)
## Presión: cuánto avanzó la colonia. Cada destino suma 1 y cada
## NIVELES_POR_PRESION niveles de mejoras comprados en esta colonia suman 1
## (hasta MAX_PRESION_MEJORAS). Con más presión las amenazas vienen más
## seguido y pueden juntarse varias a la vez. Son las mismas amenazas, más.
const NIVELES_POR_PRESION := 40
const MAX_PRESION_MEJORAS := 4
const MAX_AMENAZAS := 4
## Cada punto de presión acorta la espera entre amenazas un 12%.
const ACORTA_POR_PRESION := 0.12
## Botín: la stat botin_eventos (parte de lo juntado en la expedición) con
## este mínimo, para que siempre valga.
const BOTIN_BASE := 50.0

var run: Run
var activos: Array[Evento] = []
var _reloj_amenaza := 0.0
var _reloj_dorada := 0.0


## 0 en la casa al empezar; hasta 9 en la Torre Eiffel con la colonia crecida.
static func presion() -> int:
	var niveles := 0
	for id in Juego.niveles:
		niveles += int(Juego.niveles[id])
	return maxi(0, Mundos.ORDEN.find(Juego.lugar_actual)) + mini(MAX_PRESION_MEJORAS, niveles / NIVELES_POR_PRESION)


## Cuántas amenazas puede haber a la vez (una bandada de palomas cuenta como una).
static func amenazas_simultaneas() -> int:
	return mini(MAX_AMENAZAS, 1 + presion() / 2)


static func espera_entre_amenazas() -> float:
	return randf_range(ENTRE_AMENAZAS.x, ENTRE_AMENAZAS.y) / (1.0 + ACORTA_POR_PRESION * presion())


func iniciar(r: Run) -> void:
	run = r
	_reloj_amenaza = randf_range(PRIMERA_AMENAZA.x, PRIMERA_AMENAZA.y) / (1.0 + ACORTA_POR_PRESION * presion())
	_reloj_dorada = randf_range(PRIMERA_DORADA.x, PRIMERA_DORADA.y) * Juego.stat("intervalo_doradas")


func _process(delta: float) -> void:
	if not is_instance_valid(run) or not run.activa:
		return
	if Juego.revelado("amenazas") and grupos_de_amenaza() < amenazas_simultaneas():
		_reloj_amenaza -= delta
		if _reloj_amenaza <= 0.0:
			_reloj_amenaza = espera_entre_amenazas()
			aparecer(AMENAZAS.get(Juego.lugar_actual, "arana"))
	if Juego.revelado("doradas"):
		_reloj_dorada -= delta
		if _reloj_dorada <= 0.0:
			_reloj_dorada = randf_range(ENTRE_DORADAS.x, ENTRE_DORADAS.y) * Juego.stat("intervalo_doradas")
			aparecer("dorada")


## Amenazas activas; una bandada de palomas cuenta como un grupo.
func grupos_de_amenaza() -> int:
	var cuenta := 0
	for e in activos:
		if is_instance_valid(e) and e.es_amenaza() and not e.resuelto:
			cuenta += 1
	return ceili(float(cuenta) / PALOMAS_POR_BANDADA) if Juego.lugar_actual == "obelisco" else cuenta


func hay_amenaza() -> bool:
	for e in activos:
		if is_instance_valid(e) and e.es_amenaza():
			return true
	return false


## Hace aparecer un evento ya (lo usan las pruebas y el bot de balance).
func aparecer(tipo: String) -> Array[Evento]:
	var nuevos: Array[Evento] = []
	var cantidad := PALOMAS_POR_BANDADA if tipo == "paloma" else 1
	for i in cantidad:
		var e := Evento.new()
		add_child(e)
		e.iniciar(run, tipo, _lugar_de_entrada(tipo))
		e.terminado.connect(_terminado)
		activos.append(e)
		nuevos.append(e)
	if tipo == "dorada":
		run.hud.mostrar_aviso(tr("¡Una miga dorada! Pisala antes de que desaparezca"))
	else:
		run.hud.mostrar_aviso(_aviso(tipo))
		Sonido.tocar("no", 0.7, 0.0)
	return nuevos


func _aviso(tipo: String) -> String:
	match tipo:
		"arana": return tr("¡Una araña! Pisala antes de que se lleve a tus hormigas")
		"mozo": return tr("¡Viene el mozo! Pisá su sombra para que tropiece")
		"aspiradora": return tr("¡La aspiradora del museo! Rompela antes de que se trague todo")
		"paloma": return tr("¡Palomas! Espantalas antes de que se coman lo mejor")
		"gato": return tr("Un gato duerme sobre la comida… no lo despiertes")
		"rata": return tr("¡Una rata! Quiere robarse lo más rico")
	return ""


func _lugar_de_entrada(tipo: String) -> Vector2:
	match tipo:
		"dorada":
			# Cerca de lo que el jugador está mirando, dentro del territorio.
			var vista := run.camara.get_screen_center_position()
			var p := vista + Vector2.from_angle(randf() * TAU) * randf_range(60.0, 260.0)
			return p.limit_length(run.radio_actual * 0.85)
		"mozo", "gato":
			return Vector2.ZERO
	return Vector2.from_angle(randf() * TAU) * (run.radio_actual + 40.0)


## Recibe un clic del jugador. Devuelve true si le pegó a algo (la comida de
## abajo no se pisa). Los pisotones automáticos no pasan por acá.
func pisar(pos: Vector2) -> bool:
	for i in range(activos.size() - 1, -1, -1):
		var e := activos[i]
		if is_instance_valid(e) and e.contiene(pos):
			e.golpear()
			return true
	return false


## El primer evento que conviene clickear y dónde (para el bot), o null.
func mas_urgente() -> Evento:
	var mejor: Evento = null
	for e in activos:
		if not is_instance_valid(e) or e.resuelto:
			continue
		if e.tipo == "mozo" and e.estado != "avisando":
			continue
		if mejor == null or (e.tipo == "dorada" and mejor.tipo != "dorada"):
			mejor = e
	return mejor


func punto_de_clic(e: Evento) -> Vector2:
	return e._objetivo if e.tipo == "mozo" else e.position


## Premio por vencer un evento. Devuelve las migas entregadas.
func premiar(e: Evento) -> float:
	var base := maxf(Juego.migas_run * Juego.stat("botin_eventos"), BOTIN_BASE * float(Mundos.INFO[Juego.lugar_actual].factor))
	var premio := 0.0
	if e.tipo == "dorada":
		Juego.sumar_estadistica("migas_doradas")
		match ["migas", "frenesi", "tiempo"].pick_random():
			"frenesi":
				run.frenesi_restante = maxf(run.frenesi_restante, 10.0)
				run.hud.mostrar_aviso(tr("¡Frenesí dorado! La colonia vuela"))
			"tiempo":
				run.tiempo_restante += 8.0
				run.duracion_total += 8.0
				run.hud.mostrar_aviso(tr("¡+8 segundos de expedición!"))
			_:
				premio = base * 2.5
				run.hud.mostrar_aviso(tr("¡Lluvia de migas! +%s") % Juego.formatear(premio))
	else:
		Juego.sumar_estadistica("amenazas_vencidas")
		premio = base + e.botin * 1.5
		match e.tipo:
			"mozo":
				# Tropieza y se le cae la bandeja entera.
				for i in 3:
					run.comidas.soltar_comida(e._comida_del_destino(), e._objetivo + Vector2.from_angle(i * TAU / 3) * 40.0)
				run.hud.mostrar_aviso(tr("¡El mozo tropezó! Se le cayó la bandeja"))
			"paloma":
				run.hud.mostrar_aviso(tr("¡Paloma espantada! +%s") % Juego.formatear(premio))
			"gato":
				run.hud.mostrar_aviso(tr("El gato se fue a dormir a otro lado. +%s") % Juego.formatear(premio))
			_:
				run.hud.mostrar_aviso(tr("¡Amenaza vencida! +%s") % Juego.formatear(premio))
	if premio > 0.0:
		run.registrar_ingreso(premio)
	return premio


func _terminado(e: Evento) -> void:
	activos.erase(e)
	if e.botin > 0:
		botin_terminado.emit()
