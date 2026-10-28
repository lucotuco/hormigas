extends Node
## Menú principal, configuración, pausa y estadísticas.
##   godot --headless --fixed-fps 60 --path . res://tests/prueba_menu.tscn
const RUTA_PRUEBA := "user://ajustes_prueba.cfg"
var fallas := 0
var total := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")  # las verificaciones leen textos en español
	Sonido.silenciado = true
	await probar_menu()
	probar_ajustes()
	await probar_estadisticas()
	await probar_pausa()
	await probar_paneles()
	get_tree().paused = false
	Ajustes.ruta = Ajustes.RUTA
	Ajustes.temblor = 1.0
	Juego.usar_idioma("es")
	Juego.reiniciar_estado()
	print("Menú, configuración y estadísticas: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func probar_menu() -> void:
	Juego.reiniciar_estado()
	verificar(ProjectSettings.get_setting("application/run/main_scene") == "res://ui/menu.tscn", "el juego arranca en el menú")
	var menu: Control = preload("res://ui/menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	var textos := _textos(menu)
	verificar("Jugar" in textos and "Estadísticas" in textos and "Configuración" in textos and "Salir" in textos, "el menú tiene Jugar, Estadísticas, Configuración y Salir")
	verificar(menu.escena_de_jugar() == "res://mundo/run.tscn", "la primera vez, Jugar entra directo a la casa")
	menu.queue_free()
	await get_tree().process_frame
	Juego.runs_jugadas = 3
	menu = preload("res://ui/menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	textos = _textos(menu)
	verificar("Continuar" in textos, "con una partida empezada, el botón dice Continuar")
	verificar(menu.escena_de_jugar() == "res://ui/tienda.tscn", "con partida empezada, Continuar lleva al hormiguero")
	verificar("3 expediciones" in textos, "el menú resume la partida")
	menu.abrir_configuracion()
	await get_tree().process_frame
	verificar(menu.get_children().any(func(n: Node) -> bool: return n is PanelConfiguracion), "Configuración abre su ventana")
	menu.abrir_estadisticas()
	await get_tree().process_frame
	var abiertas := menu.get_children().filter(func(n: Node) -> bool: return n is VentanaModal and not n.is_queued_for_deletion())
	verificar(abiertas.size() == 1 and abiertas[0] is PanelEstadisticas, "abrir otra ventana reemplaza la anterior")
	menu.queue_free()
	await get_tree().process_frame


func probar_ajustes() -> void:
	var archivo := ConfigFile.new()
	archivo.set_value("ajustes", "idioma", "en")
	archivo.set_value("ajustes", "volumen", 0.35)
	archivo.set_value("ajustes", "sonido", false)
	archivo.set_value("ajustes", "temblor", 7.0)
	archivo.set_value("ajustes", "pausar_sin_foco", "cualquier cosa")
	archivo.save(RUTA_PRUEBA)
	Ajustes.ruta = RUTA_PRUEBA
	Ajustes.pausar_sin_foco = true
	Ajustes.cargar()
	Ajustes.aplicar()
	verificar(Juego.idioma == "en" and tr("Mejoras") == "Upgrades", "la configuración guardada elige el idioma")
	verificar(is_equal_approx(Sonido.volumen, 0.35) and Sonido.silenciado, "la configuración guardada fija volumen y sonido")
	verificar(is_equal_approx(Ajustes.temblor, 1.0), "un temblor fuera de rango se acota a 100%")
	verificar(Ajustes.pausar_sin_foco, "un valor de otro tipo en el archivo se ignora")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA_PRUEBA))
	Ajustes.ruta = Ajustes.RUTA
	Ajustes.cambiar("idioma", "es")
	verificar(Juego.idioma == "es" and tr("Mejoras") == "Mejoras", "cambiar el idioma se aplica al instante")
	Ajustes.cambiar("volumen", 0.6)
	verificar(is_equal_approx(Sonido.volumen, 0.6), "cambiar el volumen se aplica al instante")
	Ajustes.cambiar("sonido", true)
	verificar(not Sonido.silenciado, "activar el sonido se aplica al instante")
	Sonido.silenciado = true


func probar_estadisticas() -> void:
	Juego.reiniciar_estado()
	verificar(Juego.estadistica("pisotones") == 0.0, "una partida nueva arranca sin estadísticas")
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	await get_tree().process_frame
	var pisadas := 0
	for c in run.comidas.lista:
		if pisadas >= 5:
			break
		if is_instance_valid(c) and not c is PiezaCasa and c.en_territorio(run.radio_actual):
			run.pisar(c.global_position, true) # la estadística corresponde a la mejora automática
			pisadas += 1
	Engine.time_scale = 8.0
	var cuadros := 0
	while not run.terminada and cuadros < 6000:
		await get_tree().process_frame
		cuadros += 1
	Engine.time_scale = 1.0
	verificar(Juego.estadistica("pisotones") >= 5, "cuenta los pisotones (%d)" % Juego.estadistica("pisotones"))
	verificar(Juego.estadistica("migas_totales") > 0 and is_equal_approx(Juego.estadistica("migas_totales"), Juego.migas), "suma las migas de la expedición")
	verificar(Juego.estadistica("hormigas_nacidas") >= Juego.stat("hormigas_iniciales"), "cuenta las hormigas nacidas")
	verificar(Juego.estadistica("mayor_colonia") >= Juego.stat("hormigas_iniciales"), "registra la colonia más grande")
	verificar(Juego.estadistica("tiempo_en_runs") >= Juego.stat("duracion_run") * 0.9, "suma el tiempo de expedición (%.1f s)" % Juego.estadistica("tiempo_en_runs"))
	run.queue_free()
	await get_tree().process_frame
	Juego.migas = 1e6
	var gastadas_antes := Juego.estadistica("migas_gastadas")
	Juego.comprar_lote("mandibulas", 3)
	verificar(Juego.estadistica("niveles_comprados") == 3 and Juego.estadistica("migas_gastadas") > gastadas_antes, "cuenta niveles comprados y migas invertidas")
	var datos := Juego.datos_partida()
	verificar(datos.has("estadisticas"), "las estadísticas se guardan con la partida")
	var pisotones := Juego.estadistica("pisotones")
	Juego.coronas = 2
	Juego.fundar_colonia()
	verificar(Juego.estadistica("pisotones") == pisotones, "fundar una colonia no borra las estadísticas")
	Juego.restaurar_partida({"version": 4, "migas": 10.0, "migas_colonia": 5e5})
	verificar(Juego.estadistica("migas_totales") == 5e5 and Juego.estadistica("pisotones") == 0.0, "una partida vieja sin estadísticas carga sin errores")
	Juego.restaurar_partida({"estadisticas": {"pisotones": 12, "inventada": 3, "derrumbes": "mucho"}})
	verificar(Juego.estadistica("pisotones") == 12 and not Juego.estadisticas.has("inventada") and Juego.estadistica("derrumbes") == 0.0, "las estadísticas guardadas se validan al cargar")
	verificar(PanelEstadisticas.duracion(3725) == "1 h 02 min" and PanelEstadisticas.duracion(95) == "1 min 35 s", "las duraciones se leen bien")


func probar_pausa() -> void:
	Juego.reiniciar_estado()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	await get_tree().process_frame
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	run._unhandled_input(esc)
	verificar(get_tree().paused and run.hud.pausado() and run.activa, "Esc pausa la expedición en vez de terminarla")
	var tiempo := run.tiempo_restante
	for i in 10:
		await get_tree().process_frame
	verificar(is_equal_approx(run.tiempo_restante, tiempo), "en pausa el tiempo no corre")
	verificar("Seguir" in _textos(run.hud) and "Salir al menú" in _textos(run.hud), "la pausa ofrece seguir y salir al menú")
	run.hud._abrir_configuracion()
	await get_tree().process_frame
	verificar(get_tree().paused and run.hud._ventana is PanelConfiguracion, "desde la pausa se abre la configuración sin reanudar")
	run.hud._ventana.cerrar()
	await get_tree().process_frame
	verificar(get_tree().paused and "Seguir" in _textos(run.hud), "al cerrar la configuración se vuelve a la pausa")
	run.hud.reanudar()
	verificar(not get_tree().paused and run.activa, "Seguir reanuda la expedición")
	Ajustes.pausar_sin_foco = true
	run.hud._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	verificar(get_tree().paused, "al perder el foco la expedición se pausa")
	run.hud._terminar_desde_pausa()
	for i in 3:
		await get_tree().process_frame
	verificar(not get_tree().paused and run.terminada, "Terminar la expedición la cierra y suma lo juntado")
	run.camara._sacudida = 0.0
	Ajustes.temblor = 0.0
	run.camara.sacudir(10.0)
	verificar(run.camara._sacudida == 0.0, "con el temblor apagado la cámara no tiembla")
	Ajustes.temblor = 1.0
	run.queue_free()
	await get_tree().process_frame


func probar_paneles() -> void:
	Juego.reiniciar_estado()
	Juego.estadisticas = {"migas_totales": 1.5e6, "pisotones": 42}
	var panel := PanelEstadisticas.new()
	add_child(panel)
	await get_tree().process_frame
	verificar(panel._valores.migas_totales.text == "1.50M" and panel._valores.pisotones.text == "42", "la pantalla de estadísticas muestra los valores")
	panel.cerrar()
	var config := PanelConfiguracion.new()
	add_child(config)
	await get_tree().process_frame
	var cambio := [false]
	config.idioma_cambiado.connect(func() -> void: cambio[0] = true)
	config.find_child("Idioma_en", true, false).pressed.emit()
	verificar(Juego.idioma == "en" and cambio[0], "elegir English cambia el idioma y avisa a la pantalla")
	Ajustes.cambiar("idioma", "es")
	config.queue_free()
	var tienda: Control = preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	await get_tree().process_frame
	var textos := _textos(tienda)
	verificar("Estadísticas" in textos and "Configuración" in textos and "Menú" in textos, "el hormiguero tiene accesos a estadísticas, configuración y menú")
	tienda.abrir_estadisticas()
	await get_tree().process_frame
	verificar(tienda._ventana is PanelEstadisticas, "las estadísticas se abren desde el hormiguero")
	tienda.queue_free()
	await get_tree().process_frame


func _textos(nodo: Node) -> String:
	var salida := ""
	if nodo is Label or nodo is Button:
		salida += nodo.text + "\n"
	for hijo in nodo.get_children():
		salida += _textos(hijo)
	return salida


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)
