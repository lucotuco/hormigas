extends Node
## F6 real → menú → expedición → informe y diálogo, sin archivo personal.
var fallas := 0
var total := 0
var registro: Node
var idioma := "es"
var partida_antes := ""
var ajustes_antes := ""

func _ready() -> void:
	Juego.guardado_habilitado = false
	partida_antes = huella(Juego.RUTA_PARTIDA)
	ajustes_antes = huella(Ajustes.RUTA)
	idioma = "en" if OS.get_environment("IDIOMA") == "en" else "es"
	Juego.usar_idioma(idioma)
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	_iniciar.call_deferred()

func _iniciar() -> void:
	# La revisión continúa en raíz, fuera de la escena que sustituye el menú.
	get_tree().current_scene = null
	var lanzador := preload("res://tests/sesion_casa.tscn").instantiate()
	get_tree().root.add_child(lanzador)
	get_tree().current_scene = lanzador
	for i in 5:
		await get_tree().process_frame
	registro = get_tree().root.get_node("RegistroSesionCasa")
	verificar(registro.get_parent() == get_tree().root and not Juego.guardado_habilitado, "el observador F6 persiste en raíz y conserva guardado deshabilitado")
	if not Graficos.listo:
		await Graficos.preparado
	get_window().size = Vector2i(1920, 1080)
	await captura("sesion_menu_1920")
	var menu := get_tree().current_scene
	verificar(menu.scene_file_path == "res://ui/menu.tscn" and Juego.migas == 0 and Juego.niveles.is_empty(), "el arranque real presenta menú normal desde cero")
	menu.jugar()
	for i in 5:
		await get_tree().process_frame
	var run: Run = get_tree().current_scene
	for dimensiones in [Vector2i(1920, 1080), Vector2i(1000, 620)]:
		get_window().size = dimensiones
		for i in 5:
			await get_tree().process_frame
		await captura("sesion_casa_%d" % dimensiones.x)
		var aviso: Rect2 = registro._aviso.get_global_rect()
		verificar(not aviso.intersects(run.hud._lbl_tiempo.get_global_rect()) and not aviso.intersects(run.hud._caja_migas.get_global_rect()) and not aviso.intersects(run.hud._lbl_composicion.get_global_rect()), "el aviso no tapa tiempo, migas ni composición a %d" % dimensiones.x)
		var f7 := InputEventKey.new()
		f7.keycode = KEY_F7
		f7.pressed = true
		Input.parse_input_event(f7)
		await captura("sesion_informe_%d" % dimensiones.x)
		verificar(get_tree().paused and is_instance_valid(registro._panel), "F7 pausa y abre informe real a %d" % dimensiones.x)
		verificar(get_viewport().get_visible_rect().encloses(registro._panel._panel.get_global_rect()), "el informe entra completo a %d" % dimensiones.x)
		registro._pedir_exportacion()
		await captura("sesion_exportar_%d" % dimensiones.x)
		verificar(registro._dialogo.visible, "el selector aparece sólo al pedir exportar a %d" % dimensiones.x)
		registro._dialogo.hide()
		registro._panel.cerrar()
		await get_tree().process_frame
		verificar(not get_tree().paused, "cerrar devuelve la expedición activa a %d" % dimensiones.x)
		f7.pressed = false
		Input.parse_input_event(f7)
	var ruta := "res://.godot/qa/sesion_casa_revision_%s.json" % idioma
	verificar(registro._exportar_a(ruta), "exportación explícita sólo a .godot/qa")
	var datos = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	verificar(datos is Dictionary and datos.formato == "hormigas_sesion_casa" and datos.expediciones_comenzadas == 1, "el informe exportado pertenece a la sesión nueva")
	verificar(huella(Juego.RUTA_PARTIDA) == partida_antes and huella(Ajustes.RUTA) == ajustes_antes, "partida y configuración personales permanecen idénticas")
	print("REVISIÓN SESIÓN %s: %d verificaciones; %d fallas." % [idioma, total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)

func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/%s_%s.png" % [nombre, idioma])

func huella(ruta: String) -> String:
	return FileAccess.get_sha256(ruta) if FileAccess.file_exists(ruta) else "ausente"

func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)
