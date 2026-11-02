extends Node
## Efectos de sonido (autoload "Sonido").
##
## Uso: Sonido.tocar("mordida", tono)
## Cada sonido tiene un intervalo mínimo para que 200 hormigas mordiendo
## a la vez no saturen el audio. M silencia / activa el sonido (ver Ajustes).

const SONIDOS := {
	"mordida":   {"volumen": -24.0, "intervalo": 0.18},
	"mordida_carton": {"volumen": -25.0, "intervalo": 0.18},
	"mordida_madera": {"volumen": -25.0, "intervalo": 0.18},
	"mordida_metal": {"volumen": -28.0, "intervalo": 0.18},
	"mordida_piedra": {"volumen": -25.0, "intervalo": 0.18},
	"levantar": {"volumen": -29.0, "intervalo": 0.18},
	"clic":      {"volumen": -8.0,  "intervalo": 0.02},
	"deposito":  {"volumen": -17.0, "intervalo": 0.11},
	"romper":    {"volumen": -13.0, "intervalo": 0.12},
	"comprar":   {"volumen": -6.0,  "intervalo": 0.04},
	"no":        {"volumen": -9.0,  "intervalo": 0.15},
	"crecer":    {"volumen": -5.0,  "intervalo": 0.5},
	"tic":       {"volumen": -9.0,  "intervalo": 0.3},
	"fin":       {"volumen": -4.0,  "intervalo": 0.5},
}
const TAMANO_POOL := 16

var silenciado := false:
	set(valor):
		silenciado = valor
		if valor:
			for reproductor in _reproductores:
				reproductor.stop()
var volumen := 0.8

var _reproductores: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _ultimo: Dictionary = {}
var _siguiente := 0
var _azar_audio := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_azar_audio.seed = 4173 # La variación del audio no consume el azar de la IA.
	for nombre in SONIDOS:
		_streams[nombre] = AudioSuave.crear(nombre)
	for i in TAMANO_POOL:
		var reproductor := AudioStreamPlayer.new()
		add_child(reproductor)
		_reproductores.append(reproductor)


func _exit_tree() -> void:
	for reproductor in _reproductores:
		reproductor.stop()
		reproductor.stream = null


func _unhandled_input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla and tecla.pressed and not tecla.echo and tecla.keycode == KEY_M:
		Ajustes.cambiar("sonido", silenciado)  # si estaba silenciado, vuelve el sonido


## tono: 1.0 es normal, 2.0 una octava arriba. variacion: aleatoriedad del tono.
func tocar(nombre: String, tono: float = 1.0, variacion: float = 0.05) -> void:
	if silenciado or volumen <= 0.001 or not _streams.has(nombre):
		return
	var ahora := Time.get_ticks_msec() / 1000.0
	var configuracion: Dictionary = SONIDOS[nombre]
	if not _admitir(nombre, ahora):
		return
	var reproductor := _reproductores[_siguiente]
	_siguiente = (_siguiente + 1) % TAMANO_POOL
	reproductor.stream = _streams[nombre]
	reproductor.volume_db = configuracion.volumen + linear_to_db(volumen)
	var factor := _azar_audio.randf_range(1.0 - variacion, 1.0 + variacion) if variacion > 0 else 1.0
	reproductor.pitch_scale = clampf(tono * factor, 0.65, 1.6)
	reproductor.play()


## Todos los crujidos y levantados comparten como máximo seis inicios por
## segundo; cambiar de material no multiplica voces. UI y entrega conservan
## sus puertas independientes, para que siempre se entienda una compra.
func _admitir(nombre: String, ahora: float) -> bool:
	if not SONIDOS.has(nombre):
		return false
	var canal := "mordida" if nombre.begins_with("mordida") or nombre == "levantar" else nombre
	if ahora - float(_ultimo.get(canal, -10.0)) < float(SONIDOS[nombre].intervalo):
		return false
	_ultimo[canal] = ahora
	return true


## Al principio el sonido ayuda a leer la única obrera incluso sin acercar
## la cámara. Una colonia grande y lejana no produce una lluvia de crujidos.
static func detalle_material(zoom: float, poblacion: int) -> bool:
	return zoom >= 0.28 or poblacion <= 12
