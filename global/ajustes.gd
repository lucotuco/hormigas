extends Node
## Configuración del jugador (autoload "Ajustes"): idioma, sonido, pantalla y
## comodidad. Se guarda aparte de la partida, en user://ajustes.cfg, así que
## borrar la partida no borra la configuración.
##
## Para cambiar algo desde la interfaz: Ajustes.cambiar("volumen", 0.5).

signal cambiaron

const RUTA := "user://ajustes.cfg"
## Las pruebas leen configuraciones de prueba desde otra ruta.
var ruta := RUTA
const CLAVES := ["idioma", "volumen", "sonido", "pantalla_completa", "temblor", "pausar_sin_foco"]

## "" = el idioma del sistema.
var idioma := ""
var volumen := 0.8
var sonido := true
var pantalla_completa := false
## Multiplica el temblor de cámara: 0 lo apaga.
var temblor := 1.0
## Pausa la expedición cuando la ventana pierde el foco.
var pausar_sin_foco := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cargar()
	aplicar()


func cargar() -> void:
	var archivo := ConfigFile.new()
	if archivo.load(ruta) != OK:
		return
	for clave in CLAVES:
		var valor = archivo.get_value("ajustes", clave, get(clave))
		if typeof(valor) == typeof(get(clave)) or (typeof(valor) in [TYPE_INT, TYPE_FLOAT] and typeof(get(clave)) in [TYPE_INT, TYPE_FLOAT]):
			set(clave, valor)
	volumen = clampf(volumen, 0.0, 1.0)
	temblor = clampf(temblor, 0.0, 1.0)
	if idioma not in Juego.IDIOMAS:
		idioma = ""


func guardar() -> void:
	# Las pruebas desactivan el guardado de la partida: tampoco tocan la configuración.
	if not Juego.guardado_habilitado:
		return
	var archivo := ConfigFile.new()
	for clave in CLAVES:
		archivo.set_value("ajustes", clave, get(clave))
	archivo.save(ruta)


func aplicar() -> void:
	Juego.usar_idioma(idioma if idioma != "" else Juego.idioma_del_sistema())
	Sonido.volumen = volumen
	Sonido.silenciado = not sonido
	# Dentro de la pestaña "Juego" del editor la ventana es del editor: cambiarle
	# el modo desacomoda el área de juego y el clic queda corrido del puntero.
	if DisplayServer.get_name() != "headless" and not Engine.is_embedded_in_editor():
		var modo := DisplayServer.WINDOW_MODE_FULLSCREEN if pantalla_completa else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != modo:
			DisplayServer.window_set_mode(modo)


func cambiar(clave: String, valor) -> void:
	if clave not in CLAVES:
		push_error("Ajuste desconocido: " + clave)
		return
	set(clave, valor)
	aplicar()
	guardar()
	cambiaron.emit()


func _unhandled_input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla and tecla.pressed and not tecla.echo and tecla.keycode == KEY_F11:
		cambiar("pantalla_completa", not pantalla_completa)
