extends Node
## Contactos comparados con el alfa del arte y capturas Full HD del acabado.
var total := 0
var fallas := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Ajustes.pausar_sin_foco = false
	Sonido.silenciado = true
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	if not Graficos.listo:
		await Graficos.preparado
	var destinos: Array = ["obelisco", "eiffel", "coliseo", "casa"]
	if OS.has_environment("DESTINO_QA"):
		destinos = [OS.get_environment("DESTINO_QA")]
	for destino in destinos:
		Juego.reiniciar_estado()
		Juego.lugar_actual = destino
		Juego.runs_jugadas = 30
		Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
		Juego._cache_stats.clear()
		seed(617)
		var r: Run = preload("res://mundo/run.tscn").instantiate()
		add_child(r)
		r.set_process(false)
		r.camara.set_process(false)
		r.colonia.set_process(false)
		r.eventos.set_process(false)
		r.eventos.hide()
		r.radio_actual = 12000
		r.niebla.radio = 12000
		r.hud.hide()
		var meta := r.objetivo_mapa
		if destino != "casa":
			var imagen := ArteCasa.DESTINOS.get_image()
			var contactos_validos := true
			for i in 24:
				var desde := meta.position + Vector2.from_angle(TAU * i / 24) * meta.rect_mundo.size.length()
				var p := meta.punto_mordida(desde, 12000)
				var valido := p != Vector2.INF and meta.alcanza_desde(p) and opaco_cerca(meta, meta.material_cercano(p), imagen)
				if not valido:
					print("CONTACTO SIN MATERIAL ", destino, " dirección ", i, " destino ", p, " material ", meta.material_cercano(p), " alcance ", meta.distancia_a(p))
				contactos_validos = contactos_validos and valido
			verificar(contactos_validos, destino + ": los contactos llegan a material opaco del PNG")
			for i in 64:
				var h := r.colonia._nacer("obrera" if i % 5 else "roja")
				var desde := meta.position + Vector2.from_angle(TAU * i / 64) * meta.rect_mundo.size * 0.8
				h.position = r.cocina.ajustar_destino(desde, 12000)
				h.comida = meta
				h.estado = Hormiga.Estado.YENDO_A_COMIDA
				h.objetivo = meta.punto_trabajo(h.position, 12000, false, i)
				h._reloj_pensar = 100
				h._velocidad = 350
				h._capacidad = 100000
				h._dano = 0.01
			r.camara.mirar(meta.position, meta.rect_mundo.size)
			for i in 190:
				await get_tree().process_frame
			meta.corrosion = 1
			meta._process(0.1)
			await captura("acabado_" + destino)
			if destino == "obelisco":
				for h in r.colonia.hormigas:
					h.carga = 0
				r.feromonas.mantener_en(meta.position)
				r.hud.show()
				r.hud._process(0.2)
				await captura("acabado_obelisco_llamado")
				r.hud.hide()
				r.feromonas.limpiar()
			meta.morder_en(meta.vida_max * 0.18, meta.material_cercano(meta.position + Vector2(-2000, 0)))
			meta._process(0.1)
			await captura("acabado_" + destino + "_rotura")
		r.camara.ver_casa()
		await captura("acabado_" + destino + "_plano")
		r.queue_free()
		await get_tree().process_frame
	print("Siluetas render: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)

func opaco_cerca(pieza: PiezaCasa, punto: Vector2, imagen: Image) -> bool:
	var recorte: Rect2 = ArteCasa.OTROS[pieza.pieza.tipo]
	var uv := (punto - pieza.rect_mundo.position) / pieza.rect_mundo.size
	var pixel := Vector2i(recorte.position + uv * recorte.size)
	var tolerancia := Vector2i((Vector2.ONE * 22 / pieza.rect_mundo.size * recorte.size).ceil())
	for y in range(pixel.y - tolerancia.y, pixel.y + tolerancia.y + 1):
		for x in range(pixel.x - tolerancia.x, pixel.x + tolerancia.x + 1):
			if Rect2i(recorte).has_point(Vector2i(x, y)) and imagen.get_pixel(x, y).a > 0.4:
				return true
	return false

func captura(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/qa/" + nombre + ".png")
	print("CAPTURA ", nombre)

func verificar(valor: bool, mensaje: String) -> void:
	total += 1
	if not valor:
		fallas += 1
	print(("OK " if valor else "FALLA ") + mensaje)
