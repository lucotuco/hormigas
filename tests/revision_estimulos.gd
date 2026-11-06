extends Node
## Comparación GPU controlada: el mismo material y las mismas hormigas antes,
## durante y después de los gestos. Declara importes de presentación; no extrae
## recursos ni cambia la economía. La integración sobre Run real tiene su suite.
## Capturas 1920×1080 en .godot/qa/estimulos_*.png; sin mover el mouse.
var total := 0
var fallas := 0
var tablero: Tablero
var efectos: Efectos


class Tablero:
	extends Node2D
	const TITULOS := ["Mordida · alimento", "Mordida · madera", "Entrega · una obrera", "Destrucción / hito", "Aviso / impacto / repelido", "Ráfaga / racha real"]
	const DETALLES := ["Contacto local, no un brillo sobre todo el objeto", "Astilla corta del color del material", "El movimiento termina dentro de la entrada", "Polvo y fragmentos; la celebración es distinta", "Tres intenciones; ninguna inventa botín", "Acentos breves; las hormigas siguen siendo legibles"]
	var multitud := false

	static func origen(indice: int) -> Vector2:
		return Vector2(20 + (indice % 3) * 315, 70 + (indice / 3) * 210)

	static func centro(indice: int) -> Vector2:
		return origen(indice) + Vector2(147, 103)

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 960, 540), Color("1c251f"))
		var fuente := ThemeDB.fallback_font
		draw_string(fuente, Vector2(22, 28), tr("Estímulos · revisión visual"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f4e7c9"))
		draw_string(fuente, Vector2(22, 48), tr("Importes reales legibles · contraste y tamaño de pantalla · un lienzo y pools limitados"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("b7bca6"))
		for i in 6:
			var p := origen(i)
			var c := centro(i)
			draw_rect(Rect2(p, Vector2(295, 183)), Color("e5dcc4"))
			for x in range(0, 295, 32):
				draw_line(p + Vector2(x, 30), p + Vector2(x, 183), Color("cdc4ad"), 0.5)
			for y in range(30, 183, 32):
				draw_line(p + Vector2(0, y), p + Vector2(295, y), Color("cdc4ad"), 0.5)
			draw_rect(Rect2(p, Vector2(295, 30)), Color("343b2f"))
			draw_string(fuente, p + Vector2(10, 20), tr(TITULOS[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f4e7c9"))
			draw_string(fuente, p + Vector2(7, 174), tr(DETALLES[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("575948"))
			if i == 0:
				Graficos.dibujar(self, "comida:galletita", c + Vector2(8, 0))
			elif i == 1:
				draw_rect(Rect2(c + Vector2(0, -25), Vector2(66, 50)), Color("9c784d"))
				draw_rect(Rect2(c + Vector2(2, -23), Vector2(62, 46)), Color("b99460"))
				for y in 3:
					draw_line(c + Vector2(6, -15 + y * 14), c + Vector2(58, -16 + y * 14), Color("a78554"), 0.6)
			elif i == 3:
				for j in 6:
					Graficos.dibujar(self, "comida:miga", c + Vector2.from_angle(j * TAU / 6) * 25)
			if i != 4:
				var cantidad := 36 if multitud else (9 if i == 5 else 3)
				for j in cantidad:
					var a := j * 2.4 + i * 0.31
					var r := 32.0 + (j % 5) * 8.0
					var pos := c + Vector2.from_angle(a) * r
					draw_set_transform(pos, a + PI)
					AspectoHormiga.dibujar(self, "obrera", Color("463c2f"), j * 1.2, i == 2, Color("d8b77c"))
					draw_set_transform(Vector2.ZERO)


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	DirAccess.make_dir_recursive_absolute("res://.godot/qa")
	if not Graficos.listo and DisplayServer.get_name() != "headless":
		await Graficos.preparado
	get_window().size = Vector2i(1920, 1080)
	await cuadros(2)
	# Zoom real de la cámara/canvas: el grosor usa el mismo camino que la run.
	get_viewport().canvas_transform = Transform2D(0.0, Vector2.ONE * 2.0, 0.0, Vector2.ZERO)
	tablero = Tablero.new()
	add_child(tablero)
	var entrada := Hormiguero.new()
	entrada.position = Tablero.centro(2)
	add_child(entrada)
	for i in 3:
		var enemigo := Evento.new()
		enemigo.process_mode = Node.PROCESS_MODE_DISABLED
		enemigo.tipo = "escarabajo"
		enemigo.golpes = 2
		enemigo.golpes_max = 2
		enemigo.position = Tablero.centro(4) + Vector2((i - 1) * 75, 0)
		add_child(enemigo)
		var etiqueta := Label.new()
		etiqueta.text = tr(["Aviso", "Impacto", "Repelido"][i])
		etiqueta.position = enemigo.position + Vector2(-20, 38)
		etiqueta.add_theme_font_size_override("font_size", 9)
		etiqueta.add_theme_color_override("font_color", Color("575948"))
		add_child(etiqueta)
	efectos = Efectos.new()
	add_child(efectos)
	efectos.process_mode = Node.PROCESS_MODE_DISABLED
	var saldo := Juego.migas
	var ingreso := Juego.migas_run
	var reposo := await captura("estimulos_00_reposo")
	emitir_muestra()
	var contacto := await captura("estimulos_01_contacto")
	verificar(efectos.depositos_dibujados >= 1 and efectos.fracciones_dibujadas >= 1,
		"la fracción de entrega fue dibujada realmente, no sólo guardada en el pool")
	var separados := true
	for i in efectos._rect_textos.size():
		for j in range(i + 1, efectos._rect_textos.size()):
			separados = separados and not efectos._rect_textos[i].intersects(efectos._rect_textos[j])
	verificar(separados and efectos._rect_textos.size() <= Efectos.MAX_TEXTOS_VISIBLES,
		"los números grandes se reparten sin superposición dentro del presupuesto compartido")
	for i in 6:
		var rect := Rect2i(Vector2i(Tablero.origen(i) * 2.0), Vector2i(590, 366))
		var cambiados := diferencias(reposo, contacto, rect)
		verificar(cambiados > 5 and cambiados < rect.get_area() / 10,
			"panel %d: señal visible y localizada, sin cubrir el material ni la pantalla (%d muestras)" % [i, cambiados])
	efectos._process(0.14)
	await captura("estimulos_02_estelas")
	efectos._process(0.3)
	await captura("estimulos_03_disipacion")
	tablero.multitud = true
	tablero.queue_redraw()
	efectos._process(3.0)
	for i in 1000:
		efectos.deposito(Tablero.centro(2), 0.125, 64, 0)
		efectos.mordida(Tablero.centro(0), Color("d8b477"), 0, Vector2.LEFT)
		efectos.amenaza(Tablero.centro(4), "aviso", 24)
		efectos.rafaga(Tablero.centro(5), 42)
		efectos.racha(Tablero.centro(5), 4)
	efectos._process(0.045)
	verificar(efectos._particulas.size() <= Efectos.MAX_PARTICULAS and efectos._ondas.size() <= Efectos.MAX_ONDAS and efectos.get_child_count() == 0,
		"el enjambre conserva los límites y cero emisores por hormiga")
	await captura("estimulos_04_enjambre")
	tablero.multitud = false
	tablero.queue_redraw()
	efectos.limpiar()
	var limpio := await captura("estimulos_05_limpio")
	verificar(diferencias(reposo, limpio, Rect2i(Vector2i.ZERO, reposo.get_size())) == 0,
		"al limpiar no quedan trazos, halos ni restos sobre el material original")
	verificar(Juego.migas == saldo and Juego.migas_run == ingreso, "la demostración visual no genera premios ni modifica economía")
	print("Revisión estímulos: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func emitir_muestra() -> void:
	efectos.mordida(Tablero.centro(0) + Vector2(-4, 0), Color("d8b477"), 0, Vector2.LEFT)
	efectos._process(0.04)
	efectos.mordida(Tablero.centro(1), Color("b99460"), 1, Vector2.LEFT)
	efectos.deposito(Tablero.centro(2), 0.125, 1, 0)
	efectos.explosion(Tablero.centro(3), Color("bc9568"), 22)
	efectos.epico(Tablero.centro(3), Color("d8be79"), 38)
	efectos.numero(Tablero.centro(3), 0.75, Color("ffe29a"), 1.5)
	efectos.amenaza(Tablero.centro(4) + Vector2(-75, 0), "aviso", 24, Vector2.RIGHT, 1.5)
	efectos.amenaza(Tablero.centro(4), "impacto", 23)
	efectos.amenaza(Tablero.centro(4) + Vector2(75, 0), "repelido", 23, Vector2.RIGHT)
	efectos.rafaga(Tablero.centro(5), 45)
	efectos.racha(Tablero.centro(5) + Vector2(0, -5), 2)
	efectos._process(0.05)


func diferencias(a: Image, b: Image, rect: Rect2i) -> int:
	var cantidad := 0
	for y in range(rect.position.y, mini(rect.end.y, a.get_height()), 2):
		for x in range(rect.position.x, mini(rect.end.x, a.get_width()), 2):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				cantidad += 1
	return cantidad


func cuadros(cantidad: int) -> void:
	for i in cantidad:
		await get_tree().process_frame


func captura(nombre: String) -> Image:
	await cuadros(2)
	await RenderingServer.frame_post_draw
	var imagen := get_viewport().get_texture().get_image()
	verificar(imagen.save_png("res://.godot/qa/" + nombre + ".png") == OK, "captura " + nombre)
	return imagen


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)
