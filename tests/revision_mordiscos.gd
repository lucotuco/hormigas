extends Node
## Recortes reales en GPU y transporte del mismo atlas, sin partida personal.
var fallas := 0

class Muestra extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-64, -64, 128, 128), Color("b88b59"))


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	if not Graficos.listo:
		await Graficos.preparado
	await probar_mascara_gpu()
	get_window().size = Vector2i(1920, 1080)
	Juego.niveles = {"mordida_madera": 1}
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.hud.hide()
	run.niebla.hide()
	await probar_caja_real(run)
	var silla: PiezaCasa
	for parte in run.comidas.partes:
		if parte.pieza.clave == "mueble:6":
			silla = parte
	run.camara.position = silla.position + Vector2(-90, 0)
	run.camara.zoom = Vector2.ONE * 2.5
	run.camara.force_update_scroll()
	var punto := silla.punto_mordida(Vector2.ZERO, run.radio_actual)
	var h := run.colonia._nacer("obrera", punto)
	h.scale = Vector2.ONE * 1.5
	h._dano = 3.0
	h._capacidad = 1
	h.estado = Hormiga.Estado.MORDIENDO
	h.comida = silla
	h.rotation = (silla.material_cercano(punto) - punto).angle()
	h._actualizar_sprite()
	await captura("bocados_silla_intacta")
	h._reloj_mordida = 0
	h._morder(1.0 / 60.0)
	var region := silla.region_bocado()
	comprobar(region.has_area() and h._retazos.size() == 1 and h._retazos[0] == region, "la carga copia el retazo retirado del atlas del mueble")
	comprobar(h.carga > 0 and silla.vida < silla.vida_max, "una mordida produce carga y quita resistencia")
	silla._process(0.08)
	h._actualizar_sprite()
	await captura("bocados_silla_desprendimiento")
	h._reloj_vida += 0.3
	h._actualizar_sprite()
	await captura("bocados_silla_carga")
	var antes := silla.mordiscos.textura_mascara().get_image()
	silla.morder_en(30, silla.rect_mundo.end + Vector2(20, 0))
	silla._process(0.08)
	var despues := silla.mordiscos.textura_mascara().get_image()
	comprobar(no_reaparece(antes, despues), "morder del otro lado nunca repone los agujeros anteriores")
	await captura("bocados_silla_dos_frentes")
	# La carga no depende de que el Node de origen siga vivo.
	silla.queue_free()
	await get_tree().process_frame
	h._actualizar_sprite()
	comprobar(h._carga_sprite.region_rect == region and h._carga_sprite.visible, "el retazo sobrevive a liberar la fuente")
	h._descargar()
	h._actualizar_sprite()
	comprobar(h._retazos.is_empty() and not h._carga_sprite.visible, "depositar limpia la muestra sin dejar cargas fantasma")
	await probar_alimento(run, h)
	probar_siluetas_alimentos(run)
	run.queue_free()
	await get_tree().process_frame
	var tienda := preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	tienda._seleccionar_mejora("mas_obreras")
	await captura("bocados_ficha_breve")
	print("REVISIÓN BOCADOS: %d fallas" % fallas)
	get_tree().quit(1 if fallas else 0)


func probar_alimento(run: Run, h: Hormiga) -> void:
	var alimento := Comida.new()
	var datos: Dictionary
	for tipo in Juego.comidas:
		if tipo.id == "galletita":
			datos = tipo.duplicate()
	datos.vida = 12
	alimento.configurar(datos, 17)
	run.comidas.add_child(alimento)
	alimento.position = Vector2(-100, -100)
	alimento.rotation = PI * 0.5
	h.position = alimento.punto_mordida(alimento.position + Vector2(0, -alimento.radio * 3), run.radio_actual)
	h.comida = alimento
	h.estado = Hormiga.Estado.MORDIENDO
	h._reloj_mordida = 0
	h._morder(1.0 / 60.0)
	var region := alimento.region_bocado()
	comprobar(region.has_area() and Graficos.regiones["comida:galletita"].encloses(region), "la comida rotada recorta dentro de su región del atlas")
	comprobar(h._retazos.size() == 1 and h._retazos[0] == region, "el alimento también viaja como un trozo de su propio dibujo")
	run.camara.position = alimento.position
	run.camara.zoom = Vector2.ONE * 5.0
	run.camara.force_update_scroll()
	alimento._process(0.08)
	h._reloj_vida += 0.3
	h._actualizar_sprite()
	await captura("bocados_alimento")


func probar_siluetas_alimentos(run: Run) -> void:
	# Sólo QA lee el atlas para verificar los píxeles de las muestras.
	var atlas := Graficos.textura.get_image()
	var casos := 0
	var correctos := 0
	for tipo in Juego.comidas:
		for lado in 4:
			var alimento := Comida.new()
			run.comidas.add_child(alimento)
			alimento.configurar(tipo, 123)
			alimento.position = Vector2(-200, -200)
			alimento.rotation = 0
			var direccion := Vector2.from_angle(lado * PI * 0.5)
			# El trabajo menor a un píxel no inventa una carga transparente.
			for intento in 32:
				if alimento.morder_local(maxf(1, alimento.vida_max * 0.02), alimento.position + direccion * alimento.radio * 2, 6) > 0:
					break
			var region := alimento.region_bocado()
			var opaca := false
			if region.has_area():
				for y in range(floori(region.position.y), ceili(region.end.y)):
					for x in range(floori(region.position.x), ceili(region.end.x)):
						if atlas.get_pixel(x, y).a > 0.55:
							opaca = true
			casos += 1
			correctos += int(opaca)
			if not opaca:
				print("FALLA RETAZO: %s lado %d región %s" % [tipo.id, lado, region])
			alimento.queue_free()
	comprobar(correctos == casos, "los %d primeros bocados del catálogo desde cuatro lados retiran material visible (%d correctos)" % [casos, correctos])


func probar_mascara_gpu() -> void:
	var visor := SubViewport.new()
	visor.size = Vector2i(128, 128)
	visor.transparent_bg = true
	visor.disable_3d = true
	visor.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	visor.world_2d = World2D.new()
	add_child(visor)
	var muestra := Muestra.new()
	muestra.position = Vector2(64, 64)
	var desgaste := MordiscosMaterial.new()
	var rect := Rect2(-64, -64, 128, 128)
	desgaste.configurar(rect, Vector2i.ONE, [[rect]], PackedFloat64Array([100]))
	var mascara := ShaderMaterial.new()
	mascara.shader = preload("res://mundo/recorte_bocados.gdshader")
	mascara.set_shader_parameter("tamano", Vector2(128, 128))
	mascara.set_shader_parameter("grilla", Vector2i.ONE)
	mascara.set_shader_parameter("mascara_bocados", desgaste.textura_mascara())
	mascara.set_shader_parameter("usar_mascara", true)
	muestra.material = mascara
	visor.add_child(muestra)
	await cuadros(2)
	await RenderingServer.frame_post_draw
	var intacta := visor.get_texture().get_image()
	# Presupuesto de esta porción exacta; la caja real de abajo prueba DPS
	# enorme. Aquí no se deja prepago para las dos operaciones bulk posteriores.
	desgaste.recortar_local(0, 100.0 * 36.0 / (128.0 * 128.0), Vector2(-80, 0), 6)
	var area_trozo := desgaste.ultima_porcion.get_area()
	desgaste.actualizar_textura()
	await cuadros(2)
	await RenderingServer.frame_post_draw
	var primera := visor.get_texture().get_image()
	var desaparecidos := 0
	for y in 128:
		for x in 128:
			desaparecidos += int(intacta.get_pixel(x, y).a > 0.5 and primera.get_pixel(x, y).a < 0.5)
	comprobar(desaparecidos > 0 and absf(desaparecidos - area_trozo) < 0.001 and area_trozo <= 36, "los píxeles realmente borrados en GPU miden exactamente el trozo transportable, no una franja oculta")
	desgaste.recortar(0, 22, Vector2(-80, 0))
	desgaste.actualizar_textura()
	await cuadros(2)
	await RenderingServer.frame_post_draw
	var antes := visor.get_texture().get_image()
	desgaste.recortar(0, 21, Vector2(80, 0))
	desgaste.actualizar_textura()
	await cuadros(2)
	await RenderingServer.frame_post_draw
	var despues := visor.get_texture().get_image()
	var monotona := true
	var visible := 0
	var quitado := 0
	for y in 128:
		for x in 128:
			var a := antes.get_pixel(x, y).a
			var b := despues.get_pixel(x, y).a
			monotona = monotona and b <= a + 0.005
			visible += int(b > 0.5)
			quitado += int(a > b + 0.1)
	comprobar(monotona and visible > 0 and quitado > 0, "el shader real sólo quita material al cambiar de frente")
	print("Máscara GPU: %d píxeles presentes, %d retirados, monotónica=%s" % [visible, quitado, monotona])
	visor.queue_free()
	await get_tree().process_frame


func no_reaparece(antes: Image, despues: Image) -> bool:
	for y in antes.get_height():
		for x in antes.get_width():
			if despues.get_pixel(x, y).r > antes.get_pixel(x, y).r + 0.001:
				return false
	return true


func probar_caja_real(run: Run) -> void:
	var caja: PiezaCasa = run.objetivo_practica
	run.camara.position = caja.position
	run.camara.zoom = Vector2.ONE * 3.5
	run.camara.force_update_scroll()
	var punto := caja.rect_mundo.end + Vector2(11, -caja.rect_mundo.size.y * 0.4)
	var h := run.colonia._nacer("obrera", punto)
	h.scale = Vector2.ONE * 1.5
	h._dano = 1e6
	h._capacidad = 1
	h.estado = Hormiga.Estado.MORDIENDO
	h.comida = caja
	h.rotation = (caja.material_cercano(punto) - punto).angle()
	await captura("bocados_caja_antes")
	h._reloj_mordida = 0
	h._morder(1.0 / 60.0)
	caja._process(0.08)
	h._reloj_vida += 0.3
	h._actualizar_sprite()
	var trozo := caja.tamano_bocado()
	comprobar(trozo.x <= 6.001 and trozo.y <= 6.001 and trozo.x > 0 and trozo.y > 0, "incluso daño un millón arranca un solo trozo de hasta 6×6 del cartón gigante")
	comprobar(h._tamanos_retazos.size() == 1 and h._tamanos_retazos[0].is_equal_approx(trozo), "la hormiga lleva el tamaño real del agujero sin miniaturizarlo")
	comprobar(caja.vida > caja.vida_max * 0.99 and caja.vivas.size() == caja._celdas_ocupadas, "tras un viaje queda más del 99% de la caja sin desaparecer una celda entera")
	await captura("bocados_caja_un_trozo")
	for i in 31:
		caja.morder_local(1e6, punto, 6)
	caja._process(0.08)
	await captura("bocados_caja_32_trozos")
	h.queue_free()
	await get_tree().process_frame


func cuadros(cantidad: int) -> void:
	for i in cantidad:
		await get_tree().process_frame


func captura(nombre: String) -> void:
	await cuadros(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/%s.png" % nombre)


func comprobar(ok: bool, detalle: String) -> void:
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)
