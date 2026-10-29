extends Node
## Aislamiento lógico del encuadre: sin generar comida, hormigas ni navegación.
var total := 0
var fallas := 0

class RunDeCamara extends Run:
	func _ready() -> void:
		activa = false
		set_process(false)

	func _process(_delta: float) -> void:
		pass


class CocinaInerte extends Cocina:
	func _ready() -> void:
		pass


class HUDInerte extends HUD:
	func _ready() -> void:
		pass


func _ready() -> void:
	Juego.guardado_habilitado = false
	Sonido.silenciado = true
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	for destino in Mundos.ORDEN:
		Juego.lugar_actual = destino
		await probar_destino(destino)
	print("Cámara y periferia: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func probar_destino(destino: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var run := RunDeCamara.new()
	run.process_mode = Node.PROCESS_MODE_DISABLED
	for dato in [["Comidas", Comidas.new()], ["Cocina", CocinaInerte.new()], ["Feromonas", Feromonas.new()], ["Hormiguero", Hormiguero.new()], ["Hormigas", Colonia.new()], ["Niebla", Niebla.new()], ["Efectos", Efectos.new()], ["HUD", HUDInerte.new()]]:
		var nodo: Node = dato[1]
		nodo.name = dato[0]
		run.add_child(nodo)
	var camara := Camara.new()
	camara.name = "Camara"
	run.add_child(camara)
	viewport.add_child(run)
	camara.set_process(false)
	camara.set_process_input(false)
	camara.set_process_unhandled_input(false)
	camara.ajustar_a_radio(620, true)
	verificar(not camara._manual and camara.position.is_equal_approx(Vector2.ZERO), "%s: el inicio sigue centrado en el hormiguero" % destino)
	verificar(vista_dentro(camara), "%s: el encuadre inicial cabe en el paisaje" % destino)
	var cursor := Vector2(1050, 480)
	var antes := camara.get_canvas_transform().affine_inverse() * cursor
	camara.zoom_hacia(1.8, cursor)
	var despues := camara.get_canvas_transform().affine_inverse() * cursor
	verificar(antes.distance_to(despues) < 0.1, "%s: el zoom interior conserva el mundo bajo el cursor" % destino)
	var zoom_manual := camara.zoom.x
	camara.ajustar_a_radio(1100)
	camara._process(1.0 / 60)
	verificar(is_equal_approx(camara.zoom.x, zoom_manual), "%s: ampliar territorio no pisa el zoom manual" % destino)
	camara.ver_casa()
	var jugable := PlanoCasa.limites()
	verificar(camara.position.is_equal_approx(jugable.get_center()) and area_visible(camara).encloses(jugable), "%s: H muestra todo el nuevo territorio jugable" % destino)
	verificar(vista_dentro(camara), "%s: H conserva paisaje en los cuatro bordes" % destino)
	camara.ver_objetivo()
	verificar(camara._manual and vista_dentro(camara), "%s: G enfoca el objetivo sin salir del paisaje" % destino)
	for tamano in [Vector2i(1920, 1080), Vector2i(1000, 620), Vector2i(2560, 1080), Vector2i(1080, 1920)]:
		viewport.size = tamano
		await get_tree().process_frame
		camara.zoom_hacia(0.0001, Vector2(tamano) * 0.5)
		var minimo := maxf(Camara.ZOOM_MINIMO, maxf(float(tamano.x) / PlanoCasa.limites_visuales().size.x, float(tamano.y) / PlanoCasa.limites_visuales().size.y))
		verificar(is_equal_approx(camara.zoom.x, minimo) and vista_dentro(camara), "%s %s: el mínimo depende del paisaje y la relación de aspecto" % [destino, tamano])
		var estable := camara.zoom.x
		for i in 40:
			camara.zoom_hacia(1.0 / Camara.PASO_ZOOM, Vector2(tamano) * 0.5)
		verificar(is_equal_approx(camara.zoom.x, estable) and vista_dentro(camara), "%s %s: insistir con la rueda no revela fondo vacío" % [destino, tamano])
		for direccion in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			camara.desplazar(direccion * 1.0e6)
			verificar(vista_dentro(camara), "%s %s: el arrastre extremo %s limita el área visible, no sólo el centro" % [destino, tamano, direccion])
		camara.zoom_hacia(3.0, Vector2(tamano) * 0.5)
		camara.desplazar(Vector2.ONE * 1.0e6)
		camara._sacudida = 24
		var temblor_dentro := true
		for i in 30:
			camara._process(1.0 / 60)
			temblor_dentro = temblor_dentro and vista_dentro(camara)
		verificar(temblor_dentro, "%s %s: el temblor tampoco descubre el exterior del paisaje" % [destino, tamano])
	camara.centrar()
	verificar(not camara._manual and not camara.arrastrando and vista_dentro(camara), "%s: R recupera el encuadre automático después de arrastrar" % destino)
	camara.ajustar_a_radio(1.0e6)
	for i in 120:
		camara._process(1.0 / 60)
	verificar(vista_dentro(camara), "%s: aun un territorio superior al plano no permite alejarse al vacío" % destino)
	viewport.queue_free()
	await get_tree().process_frame


func area_visible(camara: Camara) -> Rect2:
	var tamano := camara.get_viewport_rect().size / camara.zoom
	return Rect2(camara.position + camara.offset - tamano * 0.5, tamano)


func vista_dentro(camara: Camara) -> bool:
	# Precisión de float32 en coordenadas de miles de unidades, no margen visual.
	return PlanoCasa.limites_visuales().grow(0.02).encloses(area_visible(camara))


func verificar(condicion: bool, mensaje: String) -> void:
	total += 1
	if not condicion:
		fallas += 1
	print(("OK: " if condicion else "FALLA: ") + mensaje)
