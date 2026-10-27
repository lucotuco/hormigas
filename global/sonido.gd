extends Node
## Efectos de sonido (autoload "Sonido").
##
## Uso: Sonido.tocar("mordida", tono)
## Cada sonido tiene un intervalo mínimo para que 200 hormigas mordiendo
## a la vez no saturen el audio. M silencia / activa el sonido.

const SONIDOS := {
	"mordida":   {"volumen": -16.0, "intervalo": 0.045},
	"clic":      {"volumen": -8.0,  "intervalo": 0.02},
	"deposito":  {"volumen": -11.0, "intervalo": 0.035},
	"romper":    {"volumen": -3.0,  "intervalo": 0.06},
	"comprar":   {"volumen": -6.0,  "intervalo": 0.04},
	"no":        {"volumen": -9.0,  "intervalo": 0.15},
	"crecer":    {"volumen": -5.0,  "intervalo": 0.5},
	"tic":       {"volumen": -9.0,  "intervalo": 0.3},
	"fin":       {"volumen": -4.0,  "intervalo": 0.5},
}
const TAMANO_POOL := 16

var silenciado := false

var _reproductores: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _ultimo: Dictionary = {}
var _siguiente := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for nombre in SONIDOS:
		var ruta := "res://sonidos/%s.wav" % nombre
		if ResourceLoader.exists(ruta):
			_streams[nombre] = load(ruta)
		else:
			push_warning("Falta el sonido %s" % ruta)
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
		silenciado = not silenciado


## tono: 1.0 es normal, 2.0 una octava arriba. variacion: aleatoriedad del tono.
func tocar(nombre: String, tono: float = 1.0, variacion: float = 0.05) -> void:
	if silenciado or not _streams.has(nombre):
		return
	var ahora := Time.get_ticks_msec() / 1000.0
	var configuracion: Dictionary = SONIDOS[nombre]
	if ahora - float(_ultimo.get(nombre, -10.0)) < configuracion.intervalo:
		return
	_ultimo[nombre] = ahora
	var reproductor := _reproductores[_siguiente]
	_siguiente = (_siguiente + 1) % TAMANO_POOL
	reproductor.stream = _streams[nombre]
	reproductor.volume_db = configuracion.volumen
	reproductor.pitch_scale = maxf(0.1, tono * randf_range(1.0 - variacion, 1.0 + variacion))
	reproductor.play()
