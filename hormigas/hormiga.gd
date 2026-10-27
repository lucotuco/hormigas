class_name Hormiga
extends Node2D
## Una hormiga obrera.
##
## Máquina de estados simple:
##   EXPLORANDO     camina al azar por el territorio buscando comida
##   SIGUIENDO      huele un rastro de feromonas y lo sigue hacia la punta
##   YENDO_A_COMIDA vio comida y va hacia ella
##   MORDIENDO      muerde hasta llenar el buche (stat "capacidad")
##   VOLVIENDO      lleva la carga al hormiguero; después vuelve a la misma comida
##   QUIETA         la run terminó
##
## Las decisiones caras (buscar comida, oler feromonas) se toman cada
## INTERVALO_PENSAR segundos, no en cada cuadro, para que entren cientos.

enum Estado { EXPLORANDO, SIGUIENDO, YENDO_A_COMIDA, MORDIENDO, VOLVIENDO, QUIETA }

const INTERVALO_PENSAR := 0.15
const VELOCIDAD_GIRO := 9.0          # radianes por segundo
const ALCANCE_FEROMONA_EXTRA := 30.0 # huelen el rastro un poco más lejos que la comida
const COLOR_CUERPO := Color(0.16, 0.1, 0.07)
const COLOR_PATAS := Color(0.16, 0.1, 0.07, 0.8)

var estado := Estado.EXPLORANDO
var run: Run
var objetivo := Vector2.ZERO
var comida: Comida = null
var carga := 0.0          # migas que lleva encima
var bocados := 0

var _recuerdo: Comida = null    # la comida a la que vuelve después de descargar
var _color_carga := Color.WHITE
var _reloj_pensar := 0.0
var _reloj_mordida := 0.0
var _reloj_vagar := 0.0

# Stats copiadas al nacer (no cambian durante la run).
var _velocidad := 60.0
var _olfato := 45.0
var _dano := 1.0
var _intervalo_mordida := 0.6
var _capacidad := 1


func iniciar(r: Run) -> void:
	run = r
	_velocidad = Juego.stat("velocidad") * randf_range(0.9, 1.1)
	_olfato = Juego.stat("olfato")
	_dano = Juego.stat("dano")
	_intervalo_mordida = maxf(0.05, Juego.stat("intervalo_mordida"))
	_capacidad = maxi(1, int(Juego.stat("capacidad")))
	_reloj_pensar = randf() * INTERVALO_PENSAR
	_elegir_destino_al_azar()


func detener() -> void:
	estado = Estado.QUIETA


func _process(delta: float) -> void:
	if estado == Estado.QUIETA:
		return
	_reloj_pensar -= delta
	if _reloj_pensar <= 0.0:
		_reloj_pensar += INTERVALO_PENSAR
		_pensar()
	if estado == Estado.MORDIENDO:
		_morder(delta)
	else:
		_caminar(delta)


func _pensar() -> void:
	if estado == Estado.VOLVIENDO or estado == Estado.MORDIENDO:
		return
	if not _comida_valida(comida):
		comida = null
		if carga > 0.0:
			_volver()
			return
		comida = run.comidas.buscar_cercana(global_position, _olfato, run.radio_actual)
	if comida != null:
		estado = Estado.YENDO_A_COMIDA
		objetivo = comida.global_position
		return
	var punto := run.feromonas.siguiente_punto(global_position, _olfato + ALCANCE_FEROMONA_EXTRA)
	if punto != Vector2.INF:
		estado = Estado.SIGUIENDO
		objetivo = punto + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
		return
	if estado != Estado.EXPLORANDO:
		estado = Estado.EXPLORANDO
		_elegir_destino_al_azar()


func _caminar(delta: float) -> void:
	if estado == Estado.EXPLORANDO:
		_reloj_vagar -= delta
		if _reloj_vagar <= 0.0 or global_position.distance_squared_to(objetivo) < 64.0:
			_elegir_destino_al_azar()

	var zigzag := 0.5 if estado == Estado.EXPLORANDO else 0.15
	var angulo := (objetivo - global_position).angle() + randf_range(-zigzag, zigzag)
	rotation = rotate_toward(rotation, angulo, VELOCIDAD_GIRO * delta)
	global_position += Vector2.from_angle(rotation) * _velocidad * delta

	var limite := run.radio_actual - 4.0
	if global_position.length() > limite:
		global_position = global_position.limit_length(limite)
		if estado == Estado.EXPLORANDO:
			_elegir_destino_al_azar()

	match estado:
		Estado.YENDO_A_COMIDA:
			if not _comida_valida(comida):
				comida = null
				estado = Estado.EXPLORANDO
				_elegir_destino_al_azar()
			elif global_position.distance_to(comida.global_position) <= comida.radio + 3.0:
				estado = Estado.MORDIENDO
				_reloj_mordida = _intervalo_mordida * randf_range(0.3, 1.0)
		Estado.VOLVIENDO:
			if global_position.length() <= Hormiguero.RADIO_ENTRADA:
				_descargar()


func _morder(delta: float) -> void:
	if not _comida_valida(comida):
		comida = null
		if carga > 0.0:
			_volver()
		else:
			estado = Estado.EXPLORANDO
			_elegir_destino_al_azar()
		return
	var hacia := (comida.global_position - global_position).angle()
	rotation = rotate_toward(rotation, hacia, VELOCIDAD_GIRO * delta)
	_reloj_mordida -= delta
	if _reloj_mordida > 0.0:
		return
	_reloj_mordida += _intervalo_mordida
	var actual := comida
	carga += actual.morder(_dano)
	bocados += 1
	_color_carga = actual.color
	run.efectos.chispas(global_position + Vector2.from_angle(rotation) * 4.0, actual.color, 2)
	Sonido.tocar("mordida", randf_range(0.8, 1.3), 0.0)
	if bocados >= _capacidad or actual.muerta:
		_volver()


func _volver() -> void:
	_recuerdo = comida
	comida = null
	estado = Estado.VOLVIENDO
	objetivo = Vector2.ZERO
	queue_redraw()


func _descargar() -> void:
	run.depositar(carga)
	carga = 0.0
	bocados = 0
	queue_redraw()
	# Vuelve a la misma comida si sigue ahí: así se forman las filas de hormigas.
	if _comida_valida(_recuerdo) and Comidas.en_territorio(_recuerdo, run.radio_actual):
		comida = _recuerdo
		estado = Estado.YENDO_A_COMIDA
		objetivo = comida.global_position
	else:
		estado = Estado.EXPLORANDO
		_elegir_destino_al_azar()
	_recuerdo = null


func _elegir_destino_al_azar() -> void:
	var direccion := Vector2.from_angle(randf() * TAU)
	objetivo = (global_position + direccion * randf_range(40.0, 110.0)).limit_length(run.radio_actual - 10.0)
	_reloj_vagar = randf_range(0.8, 2.0)


## Sin tipo a propósito: la comida pudo haber sido destruida (liberada) y un
## parámetro tipado tiraría error al recibir un objeto liberado.
func _comida_valida(c) -> bool:
	return is_instance_valid(c) and not c.muerta


func _draw() -> void:
	for i in 3:
		var x := -1.4 + i * 1.9
		draw_line(Vector2(x, 0), Vector2(x - 1.2, -3.8), COLOR_PATAS, 0.7)
		draw_line(Vector2(x, 0), Vector2(x - 1.2, 3.8), COLOR_PATAS, 0.7)
	draw_circle(Vector2(-3.4, 0), 2.2, COLOR_CUERPO)   # abdomen
	draw_circle(Vector2(0, 0), 1.35, COLOR_CUERPO)     # tórax
	draw_circle(Vector2(2.5, 0), 1.6, COLOR_CUERPO)    # cabeza
	draw_line(Vector2(3.5, -0.6), Vector2(5.4, -2.2), COLOR_CUERPO, 0.55)
	draw_line(Vector2(3.5, 0.6), Vector2(5.4, 2.2), COLOR_CUERPO, 0.55)
	if carga > 0.0:
		draw_circle(Vector2(5.0, 0), 1.9, _color_carga)
		draw_arc(Vector2(5.0, 0), 1.9, 0, TAU, 12, Color(0, 0, 0, 0.35), 0.5)
