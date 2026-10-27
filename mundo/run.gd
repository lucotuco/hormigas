class_name Run
extends Node2D
## Una run: la colonia tiene un tiempo limitado para comer todo lo que pueda.
##
## Este nodo coordina las piezas de la escena (comida, hormigas, feromonas,
## efectos, cámara y HUD) y decide cuándo empieza y termina la run.
## Convención: el hormiguero está en (0, 0) y todas las piezas cuelgan de
## nodos ubicados en el origen, así que posición local = posición global.

const ESCENA_TIENDA := "res://ui/tienda.tscn"
const DURACION_EXPANSION := 1.8   # segundos que tarda en crecer el territorio al empezar
const VENTANA_COMBO := 1.2        # segundos entre depósitos para que el combo siga
const PROPORCION_CLIC := 0.5      # el clic da la mitad de migas que una mordida de hormiga
const BONUS_DESTRUIR := 0.25      # migas extra al destruir una comida (proporción de su recompensa)

@onready var comidas: Comidas = $Comidas
@onready var feromonas: Feromonas = $Feromonas
@onready var hormiguero: Hormiguero = $Hormiguero
@onready var colonia: Colonia = $Hormigas
@onready var niebla: Niebla = $Niebla
@onready var efectos: Efectos = $Efectos
@onready var camara: Camara = $Camara
@onready var hud: HUD = $HUD

## Radio del territorio en este momento (se anima al empezar si creció).
var radio_actual: float = 0.0
var tiempo_restante: float = 0.0
var duracion_total: float = 0.0
var activa := false
var terminada := false
var combo := 0

var _reloj := 0.0
var _ultimo_deposito := -100.0
var _ultimo_tic := -1


func _ready() -> void:
	Engine.time_scale = 1.0
	Juego.iniciar_run()
	duracion_total = Juego.stat("duracion_run")
	tiempo_restante = duracion_total

	var radio_objetivo := Juego.stat("radio_territorio")
	var radio_inicio := radio_objetivo
	if Juego.radio_visto > 0.0:
		radio_inicio = minf(Juego.radio_visto, radio_objetivo)
	radio_actual = radio_inicio

	comidas.generar()
	comidas.comida_destruida.connect(_on_comida_destruida)
	niebla.radio = radio_actual
	camara.ajustar_a_radio(radio_actual, true)

	if radio_objetivo > radio_inicio + 1.0:
		var tween := create_tween()
		tween.tween_interval(0.4)
		tween.tween_property(self, "radio_actual", radio_objetivo, DURACION_EXPANSION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		hud.mostrar_aviso("¡El territorio creció!")
		Sonido.tocar("crecer", 1.0, 0.0)

	colonia.iniciar(self)
	activa = true


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	_reloj += delta
	niebla.radio = radio_actual
	camara.ajustar_a_radio(radio_actual)
	if not activa:
		return
	tiempo_restante -= delta
	var segundos := int(ceil(tiempo_restante))
	if segundos <= 5 and segundos != _ultimo_tic and segundos > 0:
		_ultimo_tic = segundos
		Sonido.tocar("tic", 1.0 + (5 - segundos) * 0.08, 0.0)
	if tiempo_restante <= 0.0:
		tiempo_restante = 0.0
		_terminar()


func _unhandled_input(event: InputEvent) -> void:
	if not activa:
		return
	var boton := event as InputEventMouseButton
	if boton and boton.pressed and boton.button_index == MOUSE_BUTTON_LEFT:
		_clic_en(get_global_mouse_position())
	var tecla := event as InputEventKey
	if tecla and tecla.pressed and not tecla.echo and tecla.keycode == KEY_ESCAPE:
		tiempo_restante = 0.0  # termina la run en el próximo cuadro


# =====================================================================
# Eventos del juego
# =====================================================================

## Lo llaman las hormigas al llegar al hormiguero con comida.
func depositar(cantidad: float) -> void:
	if cantidad <= 0.0 or terminada:
		return
	Juego.sumar_migas_run(cantidad)
	if _reloj - _ultimo_deposito <= VENTANA_COMBO:
		combo += 1
	else:
		combo = 1
	_ultimo_deposito = _reloj
	Juego.mejor_combo_run = maxi(Juego.mejor_combo_run, combo)

	hormiguero.latir()
	var pos := hormiguero.global_position + Vector2(randf_range(-14.0, 14.0), -12.0)
	efectos.numero(pos, cantidad, Color(1.0, 0.93, 0.6))
	hud.migas_voladoras(a_pantalla(hormiguero.global_position), 1)
	hud.mostrar_combo(combo)
	Sonido.tocar("deposito", 1.0 + minf(combo, 40) * 0.025, 0.0)


func _clic_en(pos: Vector2) -> void:
	var comida := comidas.comida_en(pos, radio_actual)
	if comida == null:
		return
	var color := comida.color
	var migas := comida.morder(Juego.stat("dano_clic")) * PROPORCION_CLIC
	if migas > 0.0:
		Juego.sumar_migas_run(migas)
		efectos.numero(pos, migas, Color(1.0, 0.97, 0.8), 0.9)
		hud.migas_voladoras(a_pantalla(pos), 1)
	efectos.chispas(pos, color, 5)
	camara.sacudir(1.5)
	Sonido.tocar("clic", randf_range(0.9, 1.15), 0.0)


func _on_comida_destruida(comida: Comida) -> void:
	Juego.comidas_destruidas_run += 1
	var bonus := comida.recompensa * BONUS_DESTRUIR * Juego.stat("multiplicador_migas")
	Juego.sumar_migas_run(bonus)

	var pos := comida.global_position
	efectos.explosion(pos, comida.color, comida.radio)
	efectos.numero(pos, bonus, Color(1.0, 0.82, 0.3), clampf(0.9 + comida.radio / 30.0, 1.0, 2.4))
	if comida.radio >= 12.0:
		efectos.texto(pos + Vector2(0, -comida.radio - 10.0), "¡%s!" % comida.nombre, Color.WHITE, 1.1)
	hud.migas_voladoras(a_pantalla(pos), int(clampf(comida.radio / 2.5, 2, 16)))
	camara.sacudir(clampf(comida.radio * 0.35, 2.0, 18.0))
	Sonido.tocar("romper", clampf(1.7 - comida.radio / 45.0, 0.5, 1.7))


func _terminar() -> void:
	activa = false
	terminada = true
	colonia.detener()
	Juego.terminar_run()
	Sonido.tocar("fin", 1.0, 0.0)
	# Cámara lenta un instante antes de mostrar el resultado.
	Engine.time_scale = 0.3
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_interval(0.8)
	tween.tween_callback(_mostrar_fin)


func _mostrar_fin() -> void:
	Engine.time_scale = 1.0
	hud.mostrar_fin()


func ir_a_tienda() -> void:
	get_tree().change_scene_to_file(ESCENA_TIENDA)


## Convierte una posición del mundo a coordenadas de pantalla (para el HUD).
func a_pantalla(pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * pos
