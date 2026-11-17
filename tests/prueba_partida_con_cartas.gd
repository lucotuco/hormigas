extends Node
## Las cartas de mutación se sacaron: una partida guardada mientras existían
## tiene que cargar igual y sin dejar rastros de ellas.
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	var datos := Juego.datos_partida()
	datos.migas = 4321.0
	datos.mutaciones_descubiertas = ["colmillos_brutales", "marea_negra"]
	datos.estadisticas = {"mayor_nivel": 6.0, "mutaciones_elegidas": 40.0, "mutaciones_legendarias": 2.0, "criticos": 300.0}
	datos.descubiertos = {"mutaciones": true}
	Juego.restaurar_partida(datos)
	verificar(is_equal_approx(Juego.migas, 4321.0), "una partida con datos de las cartas carga sus migas")
	verificar(not Juego.estadisticas.has("mayor_nivel") and not Juego.estadisticas.has("mutaciones_elegidas"), "las estadísticas de las cartas se descartan al cargar")
	verificar(not Juego.datos_partida().has("mutaciones_descubiertas"), "el guardado nuevo ya no escribe mutaciones descubiertas")
	verificar(not FileAccess.file_exists("res://datos/mutaciones.csv"), "no queda el CSV de mutaciones")
	Juego.reiniciar_estado()
	print("Partida con cartas: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)
