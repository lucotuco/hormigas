class_name VistaCompra
extends Control
## Comparación retenida de una compra: no crea hormigas, rutas ni economía.
## El tamaño del bocado no aumenta para representar capacidad o daño.
const ICONOS_MAXIMOS := 8
var datos: Dictionary = {}
var _izquierda: Label
var _derecha: Label
var _valor_izquierdo: Label
var _valor_derecho: Label
var _nota: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(322, 126)
	for nombre in ["_izquierda", "_derecha", "_valor_izquierdo", "_valor_derecho", "_nota"]:
		var es_valor: bool = nombre.begins_with("_valor")
		var etiqueta := Estilo.etiqueta("", 14 if es_valor else 11, Estilo.VERDE if es_valor else Estilo.TEXTO_SUAVE)
		etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(etiqueta)
		set(nombre, etiqueta)
	resized.connect(_acomodar)
	_actualizar_textos()


func mostrar(modelo: Dictionary) -> void:
	if datos == modelo:
		visible = not modelo.is_empty()
		return
	datos = modelo.duplicate(true)
	visible = not datos.is_empty()
	if is_node_ready():
		_actualizar_textos()
	queue_redraw()


func _actualizar_textos() -> void:
	if datos.is_empty():
		return
	_izquierda.text = datos.izquierda
	_derecha.text = datos.derecha
	_valor_izquierdo.text = datos.valor_izquierdo
	_valor_derecho.text = datos.valor_derecho
	_nota.text = datos.nota
	_acomodar()


func _acomodar() -> void:
	if not is_instance_valid(_izquierda):
		return
	var ancho := (size.x - 32.0) * 0.5
	for par in [[_izquierda, 5.0], [_derecha, size.x - ancho - 5.0]]:
		par[0].position = Vector2(par[1], 6)
		par[0].size = Vector2(ancho, 18)
	for par in [[_valor_izquierdo, 5.0], [_valor_derecho, size.x - ancho - 5.0]]:
		par[0].position = Vector2(par[1], 81)
		par[0].size = Vector2(ancho, 20)
	_nota.position = Vector2(4, 105)
	_nota.size = Vector2(size.x - 8, 18)
	queue_redraw()


func _draw() -> void:
	if datos.is_empty():
		return
	draw_style_box(Estilo.caja(Color("171e18"), 8, Color("3b4838"), 1, 0), Rect2(Vector2.ZERO, size))
	var medio := size.x * 0.5
	draw_line(Vector2(medio - 6, 52), Vector2(medio + 6, 52), Color("9ab685"), 2, true)
	draw_polyline(PackedVector2Array([Vector2(medio + 1, 47), Vector2(medio + 6, 52), Vector2(medio + 1, 57)]), Color("9ab685"), 2, true)
	_dibujar_lado(Vector2(medio * 0.5 - 3, 53), false)
	_dibujar_lado(Vector2(medio * 1.5 + 3, 53), true)


func _dibujar_lado(centro: Vector2, despues: bool) -> void:
	var valor: float = datos.despues if despues else datos.antes
	var tipo: String = datos.tipo_despues if despues else datos.tipo_antes
	match datos.modo:
		"colonia":
			var cuenta := mini(ICONOS_MAXIMOS, maxi(0, int(valor)))
			for i in cuenta:
				var fila := i / 4
				var columna := i % 4
				var ancho_fila := mini(4, cuenta - fila * 4)
				_hormiga(centro + Vector2((columna - (ancho_fila - 1) * 0.5) * 27, (fila - (0.5 if cuenta > 4 else 0.0)) * 22), "obrera", 1.7)
		"carga":
			_hormiga(centro + Vector2(-23, 0), tipo, 2.0)
			for i in mini(ICONOS_MAXIMOS, maxi(1, int(valor))):
				# Una ficha por bocado: la escala del fragmento es idéntica.
				var punto := centro + Vector2(3 + (i % 4) * 8, -8 + (i / 4) * 9)
				draw_rect(Rect2(punto, Vector2(5, 5)), Color("c5a16a"))
		"madera":
			_mueble(centro + Vector2(14, 0), valor >= 1)
			_hormiga(centro + Vector2(-28, 6), "obrera", 1.8)
			if valor < 1:
				draw_line(centro + Vector2(3, -20), centro + Vector2(33, 20), Color("a68d7b"), 2, true)
		"dano":
			_mueble(centro + Vector2(20, 0), true)
			_hormiga(centro + Vector2(-24, 2), tipo, 2.1)
		"entrada":
			var rect := Rect2(centro - Vector2(51, 23), Vector2(102, 46))
			draw_rect(rect, Color("394536"), false, 1)
			var nido := centro + Vector2(-37, 0)
			var comida := centro + Vector2(36, 0)
			var entrega := centro + Vector2(19, 11) if valor >= 1 else nido
			draw_line(comida, entrega, Color("d8c88b"), 1.5, true)
			_agujero(nido)
			for i in mini(6, maxi(0, int(valor))):
				_agujero(centro + Vector2(19 - (i % 3) * 17, 11 - (i / 3) * 22))
			draw_circle(comida, 3, Color("e5c27c"))


func _hormiga(centro: Vector2, tipo: String, escala: float) -> void:
	# Fondo claro sólo en la ficha: las obreras oscuras se deben reconocer
	# también al reducir la ventana, conservando su dibujo y color reales.
	draw_circle(centro, 12, Color("bba781"))
	draw_set_transform(centro, 0, Vector2.ONE * escala)
	AspectoHormiga.dibujar(self, tipo, Juego.castas_por_id[tipo].color, 0)
	draw_set_transform(Vector2.ZERO)


func _mueble(centro: Vector2, mordido: bool) -> void:
	var contorno := Color("a7814f")
	var cuerpo := Color("c9a56a")
	draw_rect(Rect2(centro - Vector2(13, 17), Vector2(26, 34)), contorno)
	draw_rect(Rect2(centro - Vector2(11, 15), Vector2(22, 30)), cuerpo)
	draw_line(centro - Vector2(1, 13), centro + Vector2(-1, 13), contorno, 1)
	if mordido:
		# Una sola muesca de borde; nunca un cuarto del mueble ni su sombra.
		draw_rect(Rect2(centro + Vector2(-13, 3), Vector2(5, 4)), Color("171e18"))
		draw_rect(Rect2(centro + Vector2(-20, 5), Vector2(5, 4)), cuerpo)


func _agujero(centro: Vector2) -> void:
	draw_circle(centro, 6, Color("88704e"))
	draw_circle(centro, 4, Color("17100c"))


## Sólo lectura. El lote respeta la cotización actual, incluyendo Máx y topes.
static func comparar(id: String) -> Dictionary:
	var modelo := {"modo": "", "antes": 0.0, "despues": 0.0, "tipo_antes": "obrera", "tipo_despues": "obrera",
		"izquierda": Juego.tr("Antes"), "derecha": Juego.tr("Después"), "valor_izquierdo": "", "valor_derecho": "", "nota": ""}
	if Juego.mejoras_por_id.has(id):
		var m: Dictionary = Juego.mejoras_por_id[id]
		var oferta := Juego.cotizar_mejora(id, Juego.cantidad_compra)
		modelo.antes = Juego.stat(m.stat)
		modelo.despues = Juego.stat_tras_comprar(id, maxi(1, oferta.cantidad))
		match m.stat:
			"hormigas_iniciales":
				modelo.modo = "colonia"
				modelo.valor_izquierdo = Juego.tr("%d al salir") % int(modelo.antes)
				modelo.valor_derecho = Juego.tr("%d al salir") % int(modelo.despues)
				modelo.nota = Juego.tr("Más manos desde la primera miga.")
			"capacidad":
				modelo.modo = "carga"
				modelo.valor_izquierdo = _bocados(int(modelo.antes))
				modelo.valor_derecho = _bocados(int(modelo.despues))
				modelo.nota = Juego.tr("Mismo bocado; menos viajes de vuelta.")
			"materiales":
				modelo.modo = "madera"
				# Esta vista sólo demuestra el acceso a madera; no promete dañar
				# resistentes ni muros con una compra distinta.
				if id != "mordida_madera" or int(modelo.antes) >= 1:
					return {}
				modelo.valor_izquierdo = Juego.tr("Madera bloqueada")
				modelo.valor_derecho = Juego.tr("Madera disponible") if modelo.despues >= 1 else Juego.tr("Madera bloqueada")
				modelo.nota = Juego.tr("Mordés el borde y transportás el trozo.")
			"entradas":
				modelo.modo = "entrada"
				modelo.antes = mini(6, int(modelo.antes))
				modelo.despues = mini(6, int(modelo.despues))
				modelo.valor_izquierdo = Juego.tr("%d accesos extra") % int(modelo.antes)
				modelo.valor_derecho = Juego.tr("%d accesos extra") % int(modelo.despues)
				modelo.nota = Juego.tr("N: elegís dónde acortar la vuelta.")
			_: return {}
	elif id in ["cargadora", "carpintera"]:
		var obrera := Juego.stats_casta("obrera")
		var casta := Juego.stats_casta(id)
		modelo.izquierda = Juego.tr("Obrera")
		modelo.derecha = Juego.tr(Juego.castas_por_id[id].nombre)
		modelo.tipo_despues = id
		if id == "cargadora":
			modelo.modo = "carga"
			modelo.antes = obrera.capacidad
			modelo.despues = casta.capacidad
			modelo.valor_izquierdo = _bocados(int(modelo.antes))
			modelo.valor_derecho = _bocados(int(modelo.despues))
			modelo.nota = Juego.tr("Retira primero los restos del grupo.")
		else:
			modelo.modo = "dano"
			modelo.antes = obrera.dano * RolesHormiga.dano("obrera", 1)
			modelo.despues = casta.dano * RolesHormiga.dano(id, 1)
			modelo.valor_izquierdo = Juego.tr("%s en madera") % _numero(modelo.antes)
			modelo.valor_derecho = Juego.tr("%s en madera") % _numero(modelo.despues)
			modelo.nota = Juego.tr("Más daño; el trozo no se agranda.")
	else:
		return {}
	return modelo


static func aviso_llamado(id: String) -> String:
	if not Juego.mejoras_por_id.has(id) or Juego.mejoras_por_id[id].stat != "feromona_cantidad":
		return ""
	# La tienda conoce la población de salida, no futuras crías o miniobreras.
	var poblacion := mini(Colonia.MAX_HORMIGAS, maxi(1, int(Juego.stat("hormigas_iniciales"))) + Juego.total_especialistas())
	var actual := maxi(0, int(Juego.stat("feromona_cantidad")))
	var oferta := Juego.cotizar_mejora(id, Juego.cantidad_compra)
	var luego := maxi(0, int(Juego.stat_tras_comprar(id, maxi(1, oferta.cantidad))))
	if luego <= poblacion or luego <= actual:
		return ""
	if actual >= poblacion:
		return Juego.tr("Colonia inicial: %d. Ya responden todas; rinde al sumar hormigas.") % poblacion
	return Juego.tr("Al salir responderán %d de %d disponibles. El resto de la capacidad queda para futuras crías.") % [mini(luego, poblacion), poblacion]


static func _bocados(cantidad: int) -> String:
	return Juego.tr("1 bocado") if cantidad == 1 else Juego.tr("%d bocados") % cantidad


static func _numero(valor: float) -> String:
	if valor >= 1000:
		return Juego.formatear(valor)
	return ("%.2f" % valor).trim_suffix("0").trim_suffix("0").trim_suffix(".")
