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


func iniciar(r: Run) -> void:
	run = r
	_por_salir = maxi(1, int(Juego.stat("hormigas_iniciales")))
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
	_actualizar_escala()
	if not _activa:
		return
	if _por_salir > 0:
		_reloj_salida -= delta
		while _reloj_salida <= 0.0 and _por_salir > 0:
			_nacer()
			_por_salir -= 1
			_reloj_salida += _pausa_salida
	if _intervalo_cria > 0.0:
		_reloj_cria += delta
		while _reloj_cria >= _intervalo_cria:
			_reloj_cria -= _intervalo_cria
			_nacer()
			run.efectos.chispas(Vector2.ZERO, Color(1.0, 0.95, 0.7), 6)


func _nacer() -> void:
	var h: Hormiga = ESCENA_HORMIGA.instantiate()
	h.position = Vector2.from_angle(randf() * TAU) * 5.0
	h.rotation = h.position.angle()
	h.scale = Vector2.ONE * _escala
	add_child(h)
	h.iniciar(run)
	hormigas.append(h)


## Cuando la cámara se aleja, las hormigas se agrandan un poco para seguir viéndose.
func _actualizar_escala() -> void:
	var zoom := maxf(get_viewport().get_canvas_transform().get_scale().x, 0.01)
	var nueva := clampf(0.9 / zoom, 1.0, 5.0)
	if absf(nueva - _escala) < 0.03:
		return
	_escala = nueva
	for h in hormigas:
		h.scale = Vector2.ONE * _escala
