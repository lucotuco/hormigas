extends Node
## Carga real de partes terminadas, sin daño artificial durante la captura.
## El renderer debe omitir el mismo material del cuerpo y de su sombra.
const CASOS := ["casa/carton_inicial", "restaurante_despensa/alacena",
	"museo_archivo/estante_norte", "museo_vitrinas/vitrina_oeste", "eiffel_fuente/fuente"]
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	if not Graficos.listo:
		await Graficos.preparado
	for id in CASOS:
		for restaurar in [false, true]:
			await mostrar(id, restaurar, "es", false)
	await mostrar("restaurante_despensa/alacena", true, "en", true)
	Juego.usar_idioma("es")
	Juego.reiniciar_estado()
	print("Revisión componentes: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func mostrar(id: String, restaurar: bool, idioma: String, hud_visible: bool) -> void:
	Juego.reiniciar_estado()
	Juego.usar_idioma(idioma)
	var datos := ComponentesProyecto.objetivo(id)
	verificar(not datos.is_empty(), "perfil visual válido: " + id)
	if datos.is_empty():
		return
	Juego.lugar_actual = datos.destino
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1, "excavar": 30}
	Juego._cache_stats.clear()
	if restaurar:
		Juego.registrar_componente_proyecto(datos.componentes[0].id)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.radio_actual = 12000
	run.niebla.hide()
	run.hud.visible = hud_visible
	var pieza: PiezaCasa
	for parte in run.comidas.partes:
		if parte.pieza.get("componentes_id", "") == id:
			pieza = parte
	verificar(is_instance_valid(pieza), "mueble visual presente: " + id)
	if is_instance_valid(pieza):
		run.camara.position = pieza.rect_mundo.get_center()
		run.camara.zoom = Vector2.ONE * minf(2.5, 650.0 / pieza.rect_mundo.size.y)
		run.camara.force_update_scroll()
		Input.warp_mouse(Vector2(5, 5))
		run.hud._process(0.3)
		run.hud.mostrar_inspeccion(pieza)
		verificar(pieza.mordiscos == null, "restauración visual sin crear R8: " + id)
		var nombre := "componentes_" + id.replace("/", "_") + ("_restaurado" if restaurar else "_intacto") + "_" + idioma
		await captura(nombre)
		if hud_visible:
			verificar("Parts kept: 1/" in run.hud._lbl_objetivo.text, "inspección inglesa muestra el componente guardado")
			get_window().size = Vector2i(1000, 620)
			await captura(nombre + "_1000")
			get_window().size = Vector2i(1920, 1080)
	run.queue_free()
	await get_tree().process_frame


func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	verificar(get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + ".png") == OK, "captura " + nombre)


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK " if ok else "FALLA ") + mensaje)
