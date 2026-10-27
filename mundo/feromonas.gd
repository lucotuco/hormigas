class_name Feromonas
extends Node2D
## El rastro de feromonas que dibuja el jugador manteniendo apretado el clic.
## Las hormigas que lo huelen lo siguen hacia la punta más nueva.
## Cada punto se borra cuando pasa más tiempo que la stat "feromona_duracion".

const DISTANCIA_ENTRE_PUNTOS := 10.0
const ADELANTO := 3                      # cuántos puntos adelante apunta una hormiga
const COLOR_RASTRO := Color(0.28, 0.72, 0.95)


class Trazo:
	var puntos: Array[Vector2] = []
	var tiempos: Array[float] = []


var trazos: Array[Trazo] = []

var _trazo_actual: Trazo = null
var _reloj := 0.0
var _mouse_apretado := false

@onready var run: Run = get_parent()


func _process(delta: float) -> void:
	_reloj += delta
	var dibujando := run.activa and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if dibujando:
		agregar_punto(get_global_mouse_position())
		_mouse_apretado = true
	elif _mouse_apretado:
		_mouse_apretado = false
		terminar_trazo()  # al soltar el clic, el próximo rastro es uno nuevo
	_caducar(Juego.stat("feromona_duracion"))
	queue_redraw()


## Agrega un punto al trazo actual (o empieza uno nuevo). Público para poder
## probarlo sin mouse.
func agregar_punto(pos: Vector2) -> void:
	pos = pos.limit_length(run.radio_actual)
	if _trazo_actual == null:
		_trazo_actual = Trazo.new()
		trazos.append(_trazo_actual)
	var puntos := _trazo_actual.puntos
	if puntos.is_empty() or puntos.back().distance_to(pos) >= DISTANCIA_ENTRE_PUNTOS:
		puntos.append(pos)
		_trazo_actual.tiempos.append(_reloj)


func terminar_trazo() -> void:
	_trazo_actual = null


func limpiar() -> void:
	trazos.clear()
	_trazo_actual = null


## Punto del rastro hacia el que tiene que caminar una hormiga en `pos`,
## o Vector2.INF si no hay rastro a menos de `alcance`.
func siguiente_punto(pos: Vector2, alcance: float) -> Vector2:
	var mejor_distancia := alcance * alcance
	var mejor_trazo: Trazo = null
	var mejor_indice := -1
	for trazo in trazos:
		var puntos := trazo.puntos
		for i in puntos.size():
			var d := pos.distance_squared_to(puntos[i])
			if d < mejor_distancia:
				mejor_distancia = d
				mejor_trazo = trazo
				mejor_indice = i
	if mejor_trazo == null:
		return Vector2.INF
	var indice := mini(mejor_indice + ADELANTO, mejor_trazo.puntos.size() - 1)
	return mejor_trazo.puntos[indice]


func _caducar(duracion: float) -> void:
	for i in range(trazos.size() - 1, -1, -1):
		var trazo := trazos[i]
		var quitar := 0
		while quitar < trazo.tiempos.size() and _reloj - trazo.tiempos[quitar] > duracion:
			quitar += 1
		if quitar > 0:
			trazo.puntos = trazo.puntos.slice(quitar)
			trazo.tiempos = trazo.tiempos.slice(quitar)
		if trazo.puntos.is_empty() and trazo != _trazo_actual:
			trazos.remove_at(i)


func _draw() -> void:
	var zoom := maxf(get_viewport().get_canvas_transform().get_scale().x, 0.01)
	var duracion := maxf(Juego.stat("feromona_duracion"), 0.01)
	for trazo in trazos:
		var cantidad := trazo.puntos.size()
		if cantidad < 2:
			continue
		var puntos := PackedVector2Array(trazo.puntos)
		var colores_brillo := PackedColorArray()
		var colores := PackedColorArray()
		for i in cantidad:
			var vida := clampf(1.0 - (_reloj - trazo.tiempos[i]) / duracion, 0.0, 1.0)
			colores_brillo.append(Color(COLOR_RASTRO, 0.22 * vida))
			colores.append(Color(COLOR_RASTRO.lightened(0.35), 0.9 * vida))
		draw_polyline_colors(puntos, colores_brillo, 9.0 / zoom, true)
		draw_polyline_colors(puntos, colores, 2.5 / zoom, true)
