class_name Hormiga
extends Node2D
## Una hormiga obrera.
##
## Máquina de estados simple:
##   EXPLORANDO     camina al azar por el territorio buscando comida
##   SIGUIENDO      se acerca al llamado que el jugador mantiene bajo el cursor
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
const COLOR_CUERPO := Color(0.16, 0.1, 0.07)

var estado := Estado.EXPLORANDO
var run: Run
var objetivo := Vector2.ZERO
var comida: Comida = null
var carga := 0.0          # migas que lleva encima
var bocados := 0
var casta := "obrera"
var escala_casta := 1.0
var _color := COLOR_CUERPO
var _reloj_reina := 0.0
var _minis_creadas := 0
const INTERVALO_REINA := 6.0
const MINIS_POR_TANDA := 2
const LIMITE_MINIS_REINA := 24

var _recuerdo: Comida = null    # la comida a la que vuelve después de descargar
var _color_carga := Color.WHITE
var _reloj_pensar := 0.0
var _reloj_mordida := 0.0
var _reloj_vagar := 0.0
var _ruta := PackedVector2Array()
var _meta_ruta := Vector2.INF
var _siguiendo_llamado := false
var _comidas_sin_ruta: Dictionary = {}
var _reloj_vida := 0.0
var _fase := 0.0
var _reloj_progreso := 0.0
var _ultima_pos := Vector2.ZERO

# Stats copiadas al nacer (no cambian durante la run).
var _velocidad := 60.0
var _olfato := 45.0
var _dano := 1.0
var _intervalo_mordida := 0.6
var _capacidad := 1


func iniciar(r: Run, tipo := "obrera") -> void:
	run = r
	casta = tipo
	var datos: Dictionary = Juego.castas_por_id[tipo]
	var stats := Juego.stats_casta(tipo)
	_color = datos.color
	escala_casta = datos.escala
	_velocidad = stats.velocidad * randf_range(0.9, 1.1)
	_olfato = stats.olfato
	_dano = stats.dano
	_intervalo_mordida = stats.intervalo_mordida
	_capacidad = stats.capacidad
	if casta == "voladora":
		z_index = 2
	_reloj_pensar = randf() * INTERVALO_PENSAR
	_fase = randf() * TAU
	_elegir_destino_al_azar()


func detener() -> void:
	estado = Estado.QUIETA


func _process(delta: float) -> void:
	if estado == Estado.QUIETA:
		return
	_reloj_vida += delta
	if casta == "reina" and run.activa:
		_reloj_reina += delta
		while _reloj_reina >= INTERVALO_REINA and _minis_creadas < LIMITE_MINIS_REINA:
			_reloj_reina -= INTERVALO_REINA
			_minis_creadas += run.colonia.desplegar_minis(global_position, mini(MINIS_POR_TANDA, LIMITE_MINIS_REINA - _minis_creadas))
	_fase += delta * _velocidad * 0.24
	queue_redraw()
	_reloj_pensar -= delta
	if _reloj_pensar <= 0.0:
		_reloj_pensar += INTERVALO_PENSAR
		_pensar()
	if estado == Estado.MORDIENDO:
		_morder(delta)
	else:
		_caminar(delta)
	# Recuperación ante objetivos inaccesibles o un cambio de territorio.
	_reloj_progreso += delta
	if _reloj_progreso >= 1.2:
		if estado != Estado.MORDIENDO and estado != Estado.SIGUIENDO and global_position.distance_to(_ultima_pos) < 3.0:
			_meta_ruta = Vector2.INF
			if estado != Estado.VOLVIENDO:
				comida = null
				estado = Estado.EXPLORANDO
				_elegir_destino_al_azar()
		_ultima_pos = global_position
		_reloj_progreso = 0.0


func _pensar() -> void:
	for id in _comidas_sin_ruta.keys():
		if _comidas_sin_ruta[id] <= _reloj_vida:
			_comidas_sin_ruta.erase(id)
	if estado == Estado.VOLVIENDO:
		return
	if carga > 0:
		if estado == Estado.MORDIENDO:
			return
		_volver()
		return
	if run.feromonas.llama_a(self):
		_siguiendo_llamado = true
		var elegida := run.comidas.comida_en(run.feromonas.posicion, run.radio_actual)
		if _comida_valida(elegida) and global_position.distance_to(elegida.global_position) <= elegida.radio + 3:
			comida = elegida
			if estado != Estado.MORDIENDO:
				_reloj_mordida = _intervalo_mordida * 0.4
			estado = Estado.MORDIENDO
			return
		comida = null
		estado = Estado.SIGUIENDO
		objetivo = run.feromonas.posicion
		return
	if _siguiendo_llamado:
		_siguiendo_llamado = false
		if estado == Estado.SIGUIENDO:
			estado = Estado.EXPLORANDO
			_elegir_destino_al_azar()
	if estado == Estado.MORDIENDO:
		return
	if not _comida_valida(comida):
		comida = null
		if carga > 0.0:
			_volver()
			return
		comida = run.comidas.buscar_cercana(global_position, _olfato, run.radio_actual, _comidas_sin_ruta)
	if comida != null:
		estado = Estado.YENDO_A_COMIDA
		objetivo = comida.global_position
		return
	if estado != Estado.EXPLORANDO:
		estado = Estado.EXPLORANDO
		_elegir_destino_al_azar()


func _caminar(delta: float) -> void:
	if estado == Estado.EXPLORANDO:
		_reloj_vagar -= delta
		if _reloj_vagar <= 0.0 or global_position.distance_squared_to(objetivo) < 64.0:
			_elegir_destino_al_azar()

	# El desplazamiento sigue una ruta; la orientación visual gira suavemente.
	# Así una hormiga rápida no orbita una miga ni sobrepasa el hormiguero.
	var meta := run.cocina.ajustar_destino(objetivo, run.radio_actual, casta == "voladora")
	if meta == Vector2.INF:
		return
	if _meta_ruta == Vector2.INF or _meta_ruta.distance_squared_to(meta) > 16.0:
		_ruta = run.cocina.ruta(global_position, meta, run.radio_actual, casta == "voladora")
		_meta_ruta = meta
	if _ruta.is_empty():
		_meta_ruta = Vector2.INF
		if estado == Estado.SIGUIENDO:
			return
		if estado != Estado.VOLVIENDO:
			if _comida_valida(comida):
				_comidas_sin_ruta[comida.get_instance_id()] = _reloj_vida + 3
			comida = null
			estado = Estado.EXPLORANDO
			_elegir_destino_al_azar()
		return
	var presupuesto := _velocidad * delta
	while presupuesto > 0.0 and not _ruta.is_empty():
		var destino := _ruta[0]
		var distancia := global_position.distance_to(destino)
		if distancia > 0.01:
			rotation = rotate_toward(rotation, (destino - global_position).angle(), VELOCIDAD_GIRO * delta)
		if distancia <= presupuesto:
			global_position = destino
			presupuesto -= distancia
			_ruta.remove_at(0)
		else:
			global_position = global_position.move_toward(destino, presupuesto)
			presupuesto = 0.0
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
	if casta == "roja" and not actual.muerta:
		actual.aplicar_veneno(_dano * 0.8, 3.0, run)
	bocados += 1
	_color_carga = actual.color
	run.efectos.chispas(global_position + Vector2.from_angle(rotation) * 4.0, actual.color, 2)
	Sonido.tocar("mordida", randf_range(0.8, 1.3), 0.0)
	if bocados >= _capacidad or actual.muerta:
		_volver()


func _volver() -> void:
	_siguiendo_llamado = false
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
	for intento in 12:
		var direccion := Vector2.from_angle(rotation + randf_range(-1.8, 1.8))
		var candidato := (global_position + direccion * randf_range(40.0, 110.0)).limit_length(run.radio_actual - 10.0)
		if run.cocina.libre(candidato, Cocina.MARGEN, casta == "voladora"):
			objetivo = candidato
			break
	_meta_ruta = Vector2.INF
	_reloj_vagar = randf_range(0.8, 2.0)


## Sin tipo a propósito: la comida pudo haber sido destruida (liberada) y un
## parámetro tipado tiraría error al recibir un objeto liberado.
func _comida_valida(c) -> bool:
	return is_instance_valid(c) and not c.muerta


func _draw() -> void:
	AspectoHormiga.dibujar(self, casta, _color, _fase, carga > 0.0, _color_carga)
