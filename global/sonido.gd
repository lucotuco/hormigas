extends Node
## Efectos de sonido (autoload "Sonido").
##
## Uso: Sonido.tocar("mordida", tono)
## Cada sonido tiene un intervalo mínimo para que 200 hormigas mordiendo
## a la vez no saturen el audio. M silencia / activa el sonido (ver Ajustes).

const SONIDOS := {
	"mordida":   {"volumen": -22.0, "intervalo": 0.13},
	"clic":      {"volumen": -8.0,  "intervalo": 0.02},
	"deposito":  {"volumen": -12.0, "intervalo": 0.09},
	"romper":    {"volumen": -8.0,  "intervalo": 0.1},
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	if ahora - float(_ultimo.get(nombre, -10.0)) < configuracion.intervalo:
		return
	_ultimo[nombre] = ahora
	var reproductor := _reproductores[_siguiente]
	_siguiente = (_siguiente + 1) % TAMANO_POOL
	reproductor.stream = _streams[nombre]
	reproductor.volume_db = configuracion.volumen + linear_to_db(volumen)
	reproductor.pitch_scale = clampf(tono * randf_range(1.0 - variacion, 1.0 + variacion), 0.65, 1.6)
	reproductor.play()
