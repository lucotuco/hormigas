extends Node
## Sugerir fundar cuando la colonia no avanza sobre el gran objetivo
## (Juego.conviene_fundar). Sin esto, un jugador que no sabe que tiene que
## fundar queda golpeando la misma mesa del restaurante para siempre.
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	probar_trabado()
	probar_ahorrando_no_cuenta()
	probar_partida_vieja()
	Juego.reiniciar_estado()
	print("Sugerir fundar: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


## Colonia en el restaurante, con todas las dietas y la corona de la casa.
func preparar_restaurante() -> void:
	Juego.reiniciar_estado()
	for id in Juego.DIETAS:
		Juego.niveles[id] = 1
	Juego.coronas_cobradas["casa"] = true
	Juego.lugares_completados["casa"] = true
	Juego.coronas = 3
	Juego.descubiertos["legado"] = true
	Juego.lugar_actual = "restaurante"
	Juego._cache_stats.clear()


func probar_trabado() -> void:
	preparar_restaurante()
	verificar(Juego.proxima_meta().tipo in ["objetivo", "proyecto"], "la colonia preparada ya puede atacar el restaurante (%s)" % Juego.proxima_meta().tipo)
	Juego.registrar_record(10.0, 0.40)
	verificar(Juego.runs_sin_avance() == 0 and not Juego.conviene_fundar(), "avanzar no es estar trabado")
	Juego.registrar_record(10.0, 0.41)
	Juego.registrar_record(10.0, 0.39)
	verificar(Juego.runs_sin_avance() == 2 and not Juego.conviene_fundar(), "dos expediciones sin avance todavía no sugieren fundar")
	Juego.registrar_record(10.0, 0.415)
	verificar(Juego.runs_sin_avance() == 3 and Juego.conviene_fundar(), "a la tercera expedición sin avance conviene fundar")
	var guardado := Juego.datos_partida()
	Juego.registrar_record(10.0, 0.50)
	verificar(Juego.runs_sin_avance() == 0 and not Juego.conviene_fundar(), "volver a avanzar apaga la sugerencia")
	Juego.restaurar_partida(guardado)
	verificar(Juego.runs_sin_avance() == 3, "el contador se guarda con la partida")
	verificar(Juego.fundar_colonia(), "se puede fundar")
	Juego.lugar_actual = "restaurante"
	verificar(Juego.runs_sin_avance() == 0 and Juego.mejor_avance.is_empty(), "la colonia nueva empieza sin intentos")
	preparar_restaurante()
	for i in 4:
		Juego.registrar_record(10.0, 0.3)
	Juego.coronas = 0
	verificar(not Juego.conviene_fundar(), "sin jalea para ganar no se sugiere fundar")
	Juego.coronas = 3
	Juego.coronas_cobradas["restaurante"] = true
	Juego.registrar_record(10.0, 1.0)
	verificar(Juego.runs_sin_avance() == 0 and not Juego.conviene_fundar(), "conquistado el destino no hay nada trabado")


func probar_ahorrando_no_cuenta() -> void:
	preparar_restaurante()
	Juego.niveles.erase("mordida_muros")
	Juego._cache_stats.clear()
	for i in 5:
		Juego.registrar_record(10.0, 0.1)
	verificar(Juego.runs_sin_avance() == 0, "juntando migas para una dieta no se cuenta como trabado")


func probar_partida_vieja() -> void:
	preparar_restaurante()
	var datos := Juego.datos_partida()
	datos.erase("mejor_avance")
	datos.erase("runs_sin_avance")
	Juego.restaurar_partida(datos)
	verificar(Juego.runs_sin_avance() == 0 and Juego.mejor_avance.is_empty(), "una partida sin estos campos carga igual")
	datos["mejor_avance"] = {"restaurante": "basura", "marte": 0.5}
	datos["runs_sin_avance"] = []
	Juego.restaurar_partida(datos)
	verificar(Juego.mejor_avance.is_empty(), "datos dañados se descartan")


func verificar(condicion: bool, texto: String) -> void:
	total += 1
	if condicion:
		print("  OK   " + texto)
	else:
		fallas += 1
		print("  FALLA " + texto)
