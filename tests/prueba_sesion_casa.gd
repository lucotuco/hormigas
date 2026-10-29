extends Node
## El ensayo sólo cambia estado en memoria. Nunca crea, borra ni reescribe
## el archivo personal; compara su hash sin exponerlo en el informe/salida.
const REGISTRO := preload("res://tests/registro_sesion_casa.gd")
class ExportacionInerte extends "res://tests/registro_sesion_casa.gd":
	var intentos_escritura := 0
	func _escribir_json(_ruta: String) -> bool:
		intentos_escritura += 1
		return true

var total := 0
var fallas := 0
var _partida_antes := ""
var _ajustes_antes := ""

func _ready() -> void:
	_partida_antes = huella(Juego.RUTA_PARTIDA)
	_ajustes_antes = huella(Ajustes.RUTA)
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	await probar_arranque()
	await probar_registro()
	await probar_pausa_y_atajos()
	verificar(huella(Juego.RUTA_PARTIDA) == _partida_antes, "el archivo personal conserva exactamente su contenido o su ausencia")
	verificar(huella(Ajustes.RUTA) == _ajustes_antes, "la configuración personal tampoco se escribe durante el ensayo")
	Juego.reiniciar_estado()
	print("Sesión aislada de casa: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)

func huella(ruta: String) -> String:
	return FileAccess.get_sha256(ruta) if FileAccess.file_exists(ruta) else "ausente"

func nuevo_registro() -> Node:
	var registro := REGISTRO.new()
	add_child(registro)
	registro.set_process(false)
	return registro

func probar_arranque() -> void:
	Juego.migas = 777
	Juego.niveles.mandibulas = 3
	# Instanciar todavía no llama ready ni permite jugar; el primer _init
	# ya debe haber bloqueado las escrituras, antes del reinicio en memoria.
	Juego.guardado_habilitado = true
	var lanzador := preload("res://tests/sesion_casa.tscn").instantiate()
	verificar(not Juego.guardado_habilitado and Juego.migas == 777, "la escena F6 desactiva guardado antes de reiniciar o permitir interacción")
	lanzador.free()
	Juego.reiniciar_estado()
	verificar(Juego.migas == 0 and Juego.niveles.is_empty() and Juego.lugar_actual == "casa", "el ensayo empieza desde cero sin usar el progreso personal cargado")
	var registro := nuevo_registro()
	verificar(registro.get_parent() == self and registro.process_mode == Node.PROCESS_MODE_ALWAYS, "el observador es un nodo común persistible y funciona en pausa")
	verificar(registro._dialogo == null and registro.eventos.size() <= 2, "arrancar no abre exportadores ni escribe un informe automáticamente")
	registro.queue_free()
	await get_tree().process_frame

func probar_registro() -> void:
	Juego.reiniciar_estado()
	var registro := nuevo_registro()
	Juego.migas = 1000000
	verificar(Juego.comprar_lote("mandibulas", 4) == 4 and Juego.comprar("mordida_rapida") and Juego.comprar("mordida_madera"), "las compras reales del juego siguen funcionando con guardado deshabilitado")
	verificar(registro.primeros.has("primera_compra") and registro.primeros.has("madera"), "las señales registran compras y dieta antes del muestreo de 0,1 s")
	verificar(Juego.comprar_casta("veloz") and registro.primeros.has("primera_casta"), "la primera especialista se registra por la señal real de compra")
	Juego.obtener_hito("primera_silla")
	Juego.completar_destino()
	verificar(registro.primeros.has("primera_silla") and registro.primeros.has("casa_conquistada"), "silla y conquista se toman del progreso real, sin inspeccionar el mapa")
	verificar(Juego.fundar_colonia() and registro.primeros.has("primera_fundacion"), "la primera fundación se detecta inmediatamente sin inventar el hito")
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	registro._observar_escena(run)
	Juego.migas_run = 23
	registro._observar_run()
	verificar(registro.primeros.has("primer_ingreso_observado") and not registro.primeros.has("primera_entrega"), "el primer ingreso observado no se confunde con una entrega de hormiga")
	run.tiempo_jugado = 3
	run.tiempo_retirada = 0.5
	run.ingresos.assign([13.0, 10.0, 0.0])
	run._cerrar()
	registro._observar_run()
	verificar(registro.expediciones.size() == 1 and registro.expediciones[0].migas == 23 and registro.expediciones[0].duracion == 3, "el cierre real produce un resumen único con duración e ingreso observados")
	registro._observar_run()
	verificar(registro.expediciones.size() == 1, "los muestreos posteriores no duplican una expedición terminada")
	run.queue_free()
	await get_tree().process_frame
	var entrada := {"lista": [1, 2]}
	registro._agregar_evento("control", entrada)
	entrada.lista.append(3)
	verificar(registro.eventos.back().datos.lista.size() == 2, "el registro copia sus datos de entrada en profundidad")
	for i in 300:
		registro._agregar_evento("control", {"indice": i})
	for i in 40:
		registro._guardar_resumen({"indice": i})
	verificar(registro.eventos.size() == 256 and registro.eventos_omitidos > 0 and registro.expediciones.size() == 32, "la sesión conserva como máximo 256 eventos y 32 expediciones")
	var copia: Dictionary = registro.informe()
	copia.eventos.clear()
	copia.expediciones.clear()
	copia.primeros.madera.datos.nivel = 999
	verificar(registro.eventos.size() == 256 and registro.expediciones.size() == 32 and registro.primeros.madera.datos.nivel == 1, "el informe devuelve una copia profunda sin exponer estado mutable")
	var reporte := JSON.stringify(registro.informe())
	verificar(not "user://" in reporte and not "nombre_jugador" in reporte and not "niveles_jalea" in reporte, "el reporte no contiene rutas personales ni una copia de la partida")
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	var ruta := "res://.godot/qa/sesion_casa_prueba.json"
	verificar(registro._exportar_a(ruta), "la exportación explícita funciona en una ruta de pruebas ignorada")
	var leido = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	verificar(leido is Dictionary and leido.formato == "hormigas_sesion_casa" and leido.guardado_personal == false, "el JSON exportado es sólo el informe de sesión")
	# Las rutas personales se prueban con una escritura inerte: incluso si
	# fallara su protección, la prueba jamás podría sobrescribir al jugador.
	var inerte := ExportacionInerte.new()
	var protegidos := not inerte._exportar_a(Juego.RUTA_PARTIDA) and not inerte._exportar_a(Ajustes.RUTA)
	protegidos = protegidos and not inerte._exportar_a(ProjectSettings.globalize_path(Juego.RUTA_PARTIDA).to_upper().replace("/", "\\"))
	verificar(protegidos and inerte.intentos_escritura == 0, "ni la exportación manual permite pisar partida o configuración personal")
	inerte.free()
	registro.queue_free()
	await get_tree().process_frame

func probar_pausa_y_atajos() -> void:
	Juego.reiniciar_estado()
	var registro := nuevo_registro()
	Juego.migas = 321
	for codigo in [KEY_F1, KEY_F2, KEY_F9]:
		var tecla := InputEventKey.new()
		tecla.keycode = codigo
		tecla.pressed = true
		Input.parse_input_event(tecla)
		await get_tree().process_frame
	# tiempo_total sigue avanzando normalmente durante estos cuadros; sólo se
	# comparan las variables que esos atajos pueden modificar/reiniciar.
	verificar(Juego.migas == 321 and Juego.niveles.is_empty() and Juego.runs_jugadas == 0, "F1 F2 y F9 no alteran el ensayo ni reinician su progreso")
	get_tree().paused = false
	Ajustes.pausar_sin_foco = true
	var f7 := InputEventKey.new()
	f7.keycode = KEY_F7
	f7.pressed = true
	Input.parse_input_event(f7)
	await get_tree().process_frame
	verificar(get_tree().paused and is_instance_valid(registro._panel), "F7 abre un informe modal y pausa el juego")
	verificar(not Ajustes.pausar_sin_foco, "el informe no permite que una captura o el selector creen otra pausa del HUD debajo")
	verificar(registro._dialogo == null, "ver el informe no crea una exportación ni abre archivos")
	f7.pressed = false
	Input.parse_input_event(f7)
	f7 = f7.duplicate()
	f7.pressed = true
	Input.parse_input_event(f7)
	await get_tree().process_frame
	verificar(not get_tree().paused, "cerrar el informe devuelve una partida activa a su estado anterior")
	verificar(Ajustes.pausar_sin_foco, "cerrar restaura la preferencia de foco sólo en memoria")
	Ajustes.pausar_sin_foco = false
	get_tree().paused = true
	registro.abrir_informe()
	registro._panel.cerrar()
	await get_tree().process_frame
	verificar(get_tree().paused, "abrir y cerrar desde una pausa no reanuda el juego por accidente")
	registro._process(1)
	var activo: float = registro.informe().tiempo_activo
	registro._process(1)
	verificar(registro.informe().tiempo_activo == activo, "el reloj activo no avanza mientras el árbol está pausado")
	get_tree().paused = false
	registro._process(1)
	verificar(registro.informe().tiempo_activo == activo + 1, "el reloj activo vuelve a avanzar al reanudar")
	registro.queue_free()
	await get_tree().process_frame

func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)
