extends Node
## Efectos de sonido (autoload "Sonido").
##
## Uso: Sonido.tocar("mordida", tono)
## Cada sonido tiene un intervalo mínimo para que 200 hormigas mordiendo
## a la vez no saturen el audio. M silencia / activa el sonido (ver Ajustes).

const SONIDOS := {
	"mordida":   {"volumen": -23.0, "intervalo": 0.18},
	"mordida_carton": {"volumen": -23.0, "intervalo": 0.18},
	"mordida_madera": {"volumen": -23.0, "intervalo": 0.18},
	"mordida_metal": {"volumen": -27.0, "intervalo": 0.18},
	"mordida_piedra": {"volumen": -23.0, "intervalo": 0.18},
	"levantar": {"volumen": -29.0, "intervalo": 0.18},
	"clic":      {"volumen": -8.0,  "intervalo": 0.02},
	"deposito":  {"volumen": -17.0, "intervalo": 0.11},
	"epico": {"volumen": -10.0, "intervalo": 0.9},
	"aviso": {"volumen": -16.0, "intervalo": 0.7},
	"espantar": {"volumen": -19.0, "intervalo": 0.10},
	"impacto": {"volumen": -19.0, "intervalo": 0.10},
	"racha": {"volumen": -17.0, "intervalo": 0.55},
	"poder": {"volumen": -13.0, "intervalo": 0.9},
	"romper":    {"volumen": -13.0, "intervalo": 0.12},
	"comprar":   {"volumen": -6.0,  "intervalo": 0.04},
	"no":        {"volumen": -9.0,  "intervalo": 0.15},
	"crecer":    {"volumen": -5.0,  "intervalo": 0.5},
	"tic":       {"volumen": -9.0,  "intervalo": 0.3},
	"fin":       {"volumen": -4.0,  "intervalo": 0.5},
	"nivel":     {"volumen": -7.0,  "intervalo": 0.25},
	"carta":     {"volumen": -11.0, "intervalo": 0.08},
	"legendaria": {"volumen": -6.0, "intervalo": 0.4},
	"critico":   {"volumen": -21.0, "intervalo": 0.12},
}
const TAMANO_POOL := 16
const VOCES_MUNDO := 10
const ESCALA_ENTREGA := [0.8, 0.9, 1.0, 1.2, 4.0 / 3.0]

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
var _voces: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_azar_audio.seed = 4173 # La variación del audio no consume el azar de la IA.
	for nombre in SONIDOS:
		_streams[nombre] = AudioSuave.crear(nombre)
	for i in TAMANO_POOL:
		var reproductor := AudioStreamPlayer.new()
		add_child(reproductor)
		_reproductores.append(reproductor)
		_voces.append({"prioridad": -1, "inicio": -10.0, "mundo": false})


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
	if silenciado or volumen <= 0.001 or not _streams.has(nombre) or not is_finite(tono) or not is_finite(variacion):
		return
	var ahora := Time.get_ticks_msec() / 1000.0
	var configuracion: Dictionary = SONIDOS[nombre]
	if not _admitir(nombre, ahora):
		return
	var prioridad := _prioridad(nombre)
	var indice := _elegir_voz(nombre, prioridad)
	if indice < 0:
		return
	var reproductor := _reproductores[indice]
	_siguiente = (indice + 1) % TAMANO_POOL
	_voces[indice] = {"prioridad": prioridad, "inicio": ahora, "mundo": _es_mundo(nombre)}
	reproductor.stream = _streams[nombre]
	reproductor.volume_db = configuracion.volumen + linear_to_db(clampf(volumen, 0.0, 1.0))
	var amplitud := clampf(variacion, 0.0, 0.08)
	var factor := _azar_audio.randf_range(1.0 - amplitud, 1.0 + amplitud) if amplitud > 0 else 1.0
	reproductor.pitch_scale = clampf(tono * factor, 0.65, 1.6)
	reproductor.play()


## Cinco peldaños cálidos, sin subir indefinidamente con un combo enorme.
## La extracción tiene su gesto propio; acá se confirma la entrega REAL.
func entrega(combo := 0, especial := false) -> void:
	if especial:
		tocar("epico", 1.0, 0.012)
	else:
		tocar("deposito", ESCALA_ENTREGA[maxi(0, combo - 1) % ESCALA_ENTREGA.size()], 0.012)


func _es_mundo(nombre: String) -> bool:
	return nombre.begins_with("mordida") or nombre in ["levantar", "deposito", "romper", "aviso", "espantar", "impacto", "racha", "poder", "critico"]


func _prioridad(nombre: String) -> int:
	if nombre in ["epico", "crecer", "fin", "poder", "nivel", "legendaria"]:
		return 3
	if nombre == "carta":
		return 2
	if nombre in ["comprar", "no", "clic"]:
		return 2
	return 0 if nombre.begins_with("mordida") or nombre == "levantar" else 1


## UI y celebraciones tienen seis voces reservadas. Una mordida nunca corta
## la compra que confirma el jugador; tampoco se crea un reproductor nuevo.
func _elegir_voz(nombre: String, prioridad: int) -> int:
	var reservada := prioridad >= 2
	var inicio := VOCES_MUNDO if reservada else 0
	var fin := TAMANO_POOL if reservada else VOCES_MUNDO
	var candidata := -1
	var mas_vieja := INF
	for i in range(inicio, fin):
		if not _reproductores[i].playing:
			return i
		if int(_voces[i].prioridad) <= prioridad and float(_voces[i].inicio) < mas_vieja:
			mas_vieja = float(_voces[i].inicio)
			candidata = i
	return candidata


## Cerrar/cambiar de escena no deja mordidas ni avisos de la run anterior.
## El acorde de cierre y la interfaz pueden terminar de sonar normalmente.
func detener_mundo() -> void:
	for i in _reproductores.size():
		if _voces[i].mundo:
			_reproductores[i].stop()
			_reproductores[i].stream = null
			_voces[i].mundo = false
	for canal in ["mordida", "deposito", "romper", "aviso", "espantar", "impacto", "racha", "poder"]:
		_ultimo.erase(canal)


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
