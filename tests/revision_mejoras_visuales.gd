extends Node
## GPU: comparación controlada, izquierda sin compras / derecha con compras.
## Las tres filas son depósito, corte y frenesí. No modifica la partida.
var total := 0
var fallas := 0
var base: Efectos
var mejorado: Efectos


class Tablero:
	extends Node2D

	static func centro(columna: int, fila: int) -> Vector2:
		return Vector2(480 + columna * 960, 220 + fila * 330)

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1920, 1080), Color("1c251f"))
		for columna in 2:
			for fila in 3:
				var c := centro(columna, fila)
				var r := Rect2(c - Vector2(420, 135), Vector2(840, 270))
				draw_style_box(Estilo.panel(12, 18), r.grow(3))
				draw_rect(r, Color("e5dcc4"))
				for x in range(0, 840, 70):
					draw_line(r.position + Vector2(x, 0), r.position + Vector2(x, 270), Color("d7ceb8"), 1.0)
				for y in range(0, 270, 70):
					draw_line(r.position + Vector2(0, y), r.position + Vector2(840, y), Color("d7ceb8"), 1.0)
				if fila == 1:
					draw_style_box(caja(Color("8c6842")), Rect2(c + Vector2(2, -48), Vector2(160, 102)))
					draw_style_box(caja(Color("b99460")), Rect2(c + Vector2(0, -54), Vector2(158, 100)))
					for i in 3:
						draw_line(c + Vector2(12, -36 + i * 30), c + Vector2(144, -38 + i * 30), Color("a78654"), 1.0, true)
				for i in 6:
					var a := i * TAU / 6.0 + 0.2
					var p := c + Vector2.from_angle(a) * (90.0 + (i % 2) * 18.0)
					draw_set_transform(p, a + PI, Vector2.ONE * 1.5)
					AspectoHormiga.dibujar(self, "obrera", Color("463c2f"), i * 1.2, fila == 0, Color("d8b77c"))
					draw_set_transform(Vector2.ZERO)

	static func caja(color: Color) -> StyleBoxFlat:
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = color
		estilo.set_corner_radius_all(8)
		return estilo


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
	add_child(Tablero.new())
	for columna in 2:
		for fila in [0, 2]:
			var entrada := Hormiguero.new()
			entrada.position = Tablero.centro(columna, fila)
			add_child(entrada)
	base = Efectos.new()
	mejorado = Efectos.new()
	add_child(base)
	add_child(mejorado)
	base.process_mode = Node.PROCESS_MODE_DISABLED
	mejorado.process_mode = Node.PROCESS_MODE_DISABLED
	base.configurar_mejoras({})
	mejorado.configurar_mejoras({"migas_brillantes": 1, "mandibulas_destello": 1, "pulso_colonia": 1})
	var saldo := Juego.migas
	var ingreso := Juego.migas_run
	var reposo := await captura("mejoras_visuales_00_reposo")
	for columna in 2:
		var e := base if columna == 0 else mejorado
		e.deposito(Tablero.centro(columna, 0), 0.125)
		e.mordida(Tablero.centro(columna, 1), Color("b99460"), 1, Vector2.LEFT)
		e.actualizar_frenesi(2.0, PackedVector2Array([Tablero.centro(columna, 2)]))
		e._process(0.075)
	var contacto := await captura("mejoras_visuales_01_compradas")
	verificar(base.halos_dibujados == 0 and mejorado.halos_dibujados == 1,
		"el renderer dibuja exactamente una entrada activa con compra y ninguna sin ella")
	for fila in 3:
		var a := Rect2i(Vector2i(Tablero.centro(0, fila)) - Vector2i(155, 110), Vector2i(310, 220))
		var b := Rect2i(Vector2i(Tablero.centro(1, fila)) - Vector2i(155, 110), Vector2i(310, 220))
		var cambio_base := diferencias(reposo, contacto, a)
		var cambio_mejorado := diferencias(reposo, contacto, b)
		verificar(cambio_mejorado > cambio_base + 12,
			"fila %d: la compra cambia píxeles reales además de las señales base (%d frente a %d)" % [fila, cambio_mejorado, cambio_base])
	base._process(0.15)
	mejorado._process(0.15)
	await captura("mejoras_visuales_02_desarrollo")
	base.limpiar()
	mejorado.limpiar()
	var final := await captura("mejoras_visuales_03_limpio")
	verificar(diferencias(reposo, final, Rect2i(Vector2i.ZERO, reposo.get_size())) == 0,
		"el cierre deja la imagen original sin auras, destellos ni trazos permanentes")
	verificar(Juego.migas == saldo and Juego.migas_run == ingreso, "la revisión gráfica no modifica economía")
	print("Revisión mejoras visuales: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


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
