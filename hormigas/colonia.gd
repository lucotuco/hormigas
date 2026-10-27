class_name Colonia
extends Node2D
## Hace nacer a las hormigas al empezar la run (y durante la run si hay "cría")
## y ajusta su tamaño en pantalla cuando la cámara se aleja.

const ESCENA_HORMIGA := preload("res://hormigas/hormiga.tscn")
const TIEMPO_SALIDA := 1.5   # segundos en los que salen todas las hormigas iniciales

var run: Run
var hormigas: Array[Hormiga] = []

var _activa := false
var _por_salir := 0
var _pausa_salida := 0.05
var _reloj_salida := 0.0
var _reloj_cria := 0.0
var _intervalo_cria := 0.0
var _escala := 1.0
var _cola_castas: Array[String] = []
var minis_nacidas := 0
var _reloj_visibilidad := 0.0
const LIMITE_MINIS := 120
const ESCALA_EN_PANTALLA := 1.5


func iniciar(r: Run) -> void:
	run = r
	_cola_castas.clear()
	var obreras := maxi(1, int(Juego.stat("hormigas_iniciales")))
	var tandas := obreras
	for c in Juego.castas:
		if c.comprable:
			tandas = maxi(tandas, Juego.cantidad_casta(c.id))
	# Salida intercalada: las especialistas participan desde el comienzo.
	for i in tandas:
		for c in Juego.castas:
			if c.comprable and i < Juego.cantidad_casta(c.id):
				_cola_castas.append(c.id)
		if i < obreras:
			_cola_castas.append("obrera")
	_por_salir = _cola_castas.size()
	_pausa_salida = clampf(TIEMPO_SALIDA / _por_salir, 0.01, 0.08)
	var cria := Juego.stat("cria")
	_intervalo_cria = 10.0 / cria if cria > 0.0 else 0.0
	_activa = true


func detener() -> void:
	_activa = false
	for h in hormigas:
		h.detener()


func cantidad() -> int:
	return hormigas.size()


func _process(delta: float) -> void:
	_reloj_visibilidad -= delta
	if _reloj_visibilidad <= 0:
		_reloj_visibilidad = 0.15
		_actualizar_escala()
	if not _activa:
		return
	if _por_salir > 0:
		_reloj_salida -= delta
		while _reloj_salida <= 0.0 and _por_salir > 0:
			_nacer(_cola_castas.pop_front())
			_por_salir -= 1
			_reloj_salida += _pausa_salida
	if _intervalo_cria > 0.0:
		_reloj_cria += delta
		while _reloj_cria >= _intervalo_cria:
			_reloj_cria -= _intervalo_cria
			_nacer()
			run.efectos.chispas(Vector2.ZERO, Color(1.0, 0.95, 0.7), 6)


func _nacer(tipo := "obrera", donde := Vector2.INF) -> Hormiga:
	var h: Hormiga = ESCENA_HORMIGA.instantiate()
	h.position = Vector2.from_angle(randf() * TAU) * 5.0 if donde == Vector2.INF else donde
	h.rotation = h.position.angle()
	h.scale = Vector2.ONE * _escala
	add_child(h)
	h.iniciar(run, tipo)
	h.scale = Vector2.ONE * _escala * h.escala_casta
	hormigas.append(h)
	return h


func desplegar_minis(pos: Vector2, cantidad_solicitada: int) -> int:
	if not _activa or not run.activa:
		return 0
	var cantidad_real := mini(cantidad_solicitada, LIMITE_MINIS - minis_nacidas)
	for i in cantidad_real:
		var lugar := pos
		for intento in 8:
			var candidato := (pos + Vector2.from_angle(randf() * TAU) * randf_range(3, 12)).limit_length(run.radio_actual - 6)
			if run.cocina.libre(candidato, Cocina.MARGEN):
				lugar = candidato
				break
		_nacer("mini", lugar)
	minis_nacidas += cantidad_real
	if cantidad_real > 0:
		run.efectos.chispas(pos, Color("c9a7df"), 6)
		run.efectos.texto(pos + Vector2(0, -12), "+%d miniobreras" % cantidad_real, Color("e1c1f3"), 0.8)
	return cantidad_real


func conteo_castas() -> Dictionary:
	var conteo := {}
	for h in hormigas:
		conteo[h.casta] = int(conteo.get(h.casta, 0)) + 1
	return conteo


## Cuando la cámara se aleja, las hormigas se agrandan un poco para seguir viéndose.
func _actualizar_escala() -> void:
	var zoom := maxf(get_viewport().get_canvas_transform().get_scale().x, 0.01)
	# 1.5: con la cámara alejada del arranque, las hormigas quedan de unos
	# 16 px en pantalla (antes ~10 px), suficiente para leer qué hacen.
	var nueva := clampf(ESCALA_EN_PANTALLA / zoom, 1.0, 5.0)
	var cambiar := absf(nueva - _escala) >= 0.03
	_escala = nueva
	var inversa := get_viewport().get_canvas_transform().affine_inverse()
	var vista := Rect2(inversa * Vector2.ZERO, get_viewport_rect().size / zoom).grow(90)
	for h in hormigas:
		if cambiar:
			h.scale = Vector2.ONE * _escala * h.escala_casta
		h.en_pantalla = vista.has_point(h.position)
		h.visible = h.en_pantalla
