extends Node
## F6: recorrido real desde cero, aislado del archivo personal. No es la
## escena principal ni un modo publicado del juego. El observador vive en raíz.
const REGISTRO := preload("res://tests/registro_sesion_casa.gd")

func _init() -> void:
	# Los autoloads ya se cargaron, pero ninguna interacción del ensayo puede
	# guardar. Se descarta enseguida el progreso cargado, sólo en memoria.
	Juego.guardado_habilitado = false

func _ready() -> void:
	Juego.reiniciar_estado()
	Juego.cantidad_compra = 1
	get_tree().paused = false
	Engine.time_scale = 1
	_iniciar.call_deferred()

func _iniciar() -> void:
	var registro := REGISTRO.new()
	registro.name = "RegistroSesionCasa"
	get_tree().root.add_child(registro)
	get_tree().change_scene_to_file("res://ui/menu.tscn")
