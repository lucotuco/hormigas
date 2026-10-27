class_name Comidas
extends Node2D
## Genera y administra toda la comida del mapa.
##
## El mapa se genera siempre con la misma semilla, así que es el mismo en cada
## run: lo que cambia es cuánto del mapa está dentro del territorio.
## Los tipos de comida, cuántas hay y a qué distancia aparecen se definen en
## datos/comidas.csv.

signal comida_destruida(comida: Comida)

const ESCENA_COMIDA := preload("res://mundo/comida.tscn")
const SEMILLA_MAPA := 20261026
const SEPARACION := 6.0
const INTENTOS := 30

var lista: Array[Comida] = []
var partes: Array[PiezaCasa] = []
var fragmentos: Array[FragmentoCasa] = []
var _pilas: Dictionary = {}
var _tesoros := 0
const MAX_FRAGMENTOS := 64
var _indice: Dictionary = {}
const CELDA_BUSQUEDA := 192.0


func generar() -> void:
	for c in lista:
		c.queue_free()
	lista.clear()
	for parte in partes:
		parte.queue_free()
	partes.clear()
	for fragmento in fragmentos:
		fragmento.queue_free()
	fragmentos.clear()
	_pilas.clear()
	_tesoros = 0
	_indice.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMILLA_MAPA
	var ocupados: Array[Vector3] = []  # x, y, radio
	for tipo in Juego.comidas:
		var radio: float = tipo.radio
		var dmin: float = tipo.distancia_min
		var dmax: float = tipo.distancia_max
		var cantidad := int(tipo.cantidad) if Juego.lugar_actual == "casa" else ceili(tipo.cantidad * 0.65)
		for i in cantidad:
			for intento in INTENTOS:
				var angulo := rng.randf() * TAU
				# sqrt para que la densidad sea pareja en todo el anillo
				var distancia := sqrt(rng.randf_range(dmin * dmin, dmax * dmax))
				var pos := Vector2.from_angle(angulo) * distancia
				var zonas: String = tipo.get("zonas", "")
				if zonas != "":
					var opciones := zonas.split("|")
					var zona := PlanoCasa.rect_ambiente(opciones[rng.randi_range(0, opciones.size() - 1)])
					if not zona.has_area():
						var ambientes := PlanoCasa.ambientes()
						zona = ambientes[rng.randi_range(0, ambientes.size() - 1)].rect
					zona = zona.grow(-60)
					pos = Vector2(rng.randf_range(zona.position.x, zona.end.x), rng.randf_range(zona.position.y, zona.end.y))
					if pos.length() < dmin or pos.length() > dmax:
						continue
				if _hay_lugar(pos, radio, ocupados):
					ocupados.append(Vector3(pos.x, pos.y, radio))
					_crear(tipo, pos, rng.randi())
					break
	# Meta fija sobre el plato: siempre existe y puede descubrirse desde la niebla.
	for tipo in Juego.comidas:
		if tipo.id == "banquete":
			_crear(tipo, PlanoCasa.banquete(), 101)
	for datos in get_parent().cocina.piezas:
		var parte := PiezaCasa.new()
		add_child(parte)
		parte.iniciar(datos, get_parent().cocina)
		parte.destruida.connect(_on_destruida)
		partes.append(parte)
		_indexar(parte)


func _hay_lugar(pos: Vector2, radio: float, ocupados: Array[Vector3]) -> bool:
	if pos.length() < 30.0 + radio:  # no tapar el hormiguero
		return false
	if not get_parent().cocina.libre(pos, radio + 12.0):
		return false
	for o in ocupados:
		var minimo := radio + o.z + SEPARACION
		if pos.distance_squared_to(Vector2(o.x, o.y)) < minimo * minimo:
			return false
	return true


func _crear(tipo: Dictionary, pos: Vector2, semilla: int) -> void:
	var comida: Comida = ESCENA_COMIDA.instantiate()
	comida.position = pos
	add_child(comida)
	var balance := tipo.duplicate()
	balance.recompensa *= float(Mundos.INFO[Juego.lugar_actual].factor)
	comida.configurar(balance, semilla)
	comida.destruida.connect(_on_destruida)
	lista.append(comida)
	_indexar(comida)

func _rect_objetivo(c: Comida) -> Rect2:
	if c is PiezaCasa:
		return c.rect_mundo
	return Rect2(c.position - Vector2.ONE * c.radio, Vector2.ONE * c.radio * 2)

func _celdas(rect: Rect2) -> Array[Vector2i]:
	var celdas: Array[Vector2i] = []
	for x in range(floori(rect.position.x / CELDA_BUSQUEDA), floori(rect.end.x / CELDA_BUSQUEDA) + 1):
		for y in range(floori(rect.position.y / CELDA_BUSQUEDA), floori(rect.end.y / CELDA_BUSQUEDA) + 1):
			celdas.append(Vector2i(x, y))
	return celdas

func _indexar(c: Comida) -> void:
	for celda in _celdas(_rect_objetivo(c)):
		if not _indice.has(celda):
			_indice[celda] = []
		_indice[celda].append(c)

func _candidatas(pos: Vector2, alcance: float) -> Array[Comida]:
	var resultado: Array[Comida] = []
	var vistas: Dictionary = {}
	for celda in _celdas(Rect2(pos, Vector2.ZERO).grow(alcance)):
		for c in _indice.get(celda, []):
			if is_instance_valid(c) and not c.muerta and not vistas.has(c.get_instance_id()):
				vistas[c.get_instance_id()] = true
				resultado.append(c)
	return resultado


func _on_destruida(comida: Comida) -> void:
	lista.erase(comida)
	for celda in _celdas(_rect_objetivo(comida)):
		if _indice.has(celda):
			_indice[celda].erase(comida)
	if comida is PiezaCasa:
		get_parent().cocina.quitar_pieza(comida.pieza.clave)
		partes.erase(comida)
	elif comida is FragmentoCasa:
		fragmentos.erase(comida)
		_pilas.erase(comida.clave_apilado)
	comida_destruida.emit(comida)

func soltar_fragmento(pos: Vector2, valor: float, material_tipo: int) -> void:
	if valor <= 0.0001:
		return
	var clave := "%s:%d" % [Vector2i(pos / 96), material_tipo]
	if _pilas.has(clave) and is_instance_valid(_pilas[clave]) and not _pilas[clave].muerta:
		_pilas[clave].sumar(valor)
		return
	if fragmentos.size() >= MAX_FRAGMENTOS:
		var mejor := fragmentos[0]
		var mismo_material := false
		for f in fragmentos:
			if f.material_id == material_tipo and not mismo_material:
				mejor = f
				mismo_material = true
			elif (not mismo_material or f.material_id == material_tipo) and f.position.distance_squared_to(pos) < mejor.position.distance_squared_to(pos):
				mejor = f
		mejor.sumar(valor, material_tipo)
		return
	var run: Run = get_parent()
	pos = run.cocina.ajustar_destino(pos, run.radio_actual)
	if pos == Vector2.INF:
		pos = Vector2.ZERO
	var fragmento := FragmentoCasa.new()
	add_child(fragmento)
	fragmento.iniciar(pos, valor, material_tipo)
	fragmento.clave_apilado = clave
	fragmento.destruida.connect(_on_destruida)
	fragmentos.append(fragmento)
	_pilas[clave] = fragmento
	_indexar(fragmento)

func revelar_tesoro(pos: Vector2, nivel: int) -> void:
	if _tesoros >= 24:
		return
	var run: Run = get_parent()
	for i in 3:
		var lugar := run.cocina.ajustar_destino(pos + Vector2.from_angle(i * TAU / 3) * 65, run.radio_actual)
		if lugar != Vector2.INF:
			_crear(Juego.comidas[2 if nivel == 1 else 4], lugar, 405 + i)
			_tesoros += 1
	if Juego.obtener_hito("primer_tesoro"):
		run.hud.mostrar_aviso("¡Hallazgo! Olfato +10 permanente")


## ¿La comida está (al menos en parte) dentro del territorio?
static func en_territorio(comida: Comida, radio_territorio: float) -> bool:
	return comida.en_territorio(radio_territorio)


## La comida viva más cercana a `pos` dentro de `alcance`, o null.
func buscar_cercana(pos: Vector2, alcance: float, radio_territorio: float, excluidas: Dictionary = {}, casta := "") -> Comida:
	var mejor: Comida = null
	var mejor_distancia := INF
	for c in _candidatas(pos, alcance):
		if not c.disponible() or excluidas.has(c.get_instance_id()):
			continue
		var d := c.distancia_a(pos)
		var afinidad := 1.0
		if casta != "":
			afinidad = RolesHormiga.afinidad(casta, c)
			var categoria := "alimentos" if not c is PiezaCasa else ("estructuras" if c.nivel_requerido >= 3 else "muebles")
			if Juego.prioridad != "automatico":
				afinidad *= 3.0 if categoria == Juego.prioridad else 0.35
		if afinidad <= 0:
			continue
		var puntaje := d / afinidad
		if d < alcance and puntaje < mejor_distancia and en_territorio(c, radio_territorio):
			mejor = c
			mejor_distancia = puntaje
	return mejor


## La comida que está debajo del cursor (con un margen para que sea fácil acertar).
func comida_en(pos: Vector2, radio_territorio: float, incluir_bloqueadas := false) -> Comida:
	var margen := 6.0 / maxf(get_viewport().get_canvas_transform().get_scale().x, 0.01)
	var mejor: Comida = null
	var mejor_distancia := INF
	for c in _candidatas(pos, margen):
		if (not incluir_bloqueadas and not c.disponible()) or not en_territorio(c, radio_territorio):
			continue
		var d := c.distancia_a(pos)
		if c.contiene_punto(pos, margen) and d < mejor_distancia:
			mejor = c
			mejor_distancia = d
	return mejor


func cantidad_en_territorio(radio_territorio: float) -> int:
	var total := 0
	for c in lista:
		if not c.muerta and en_territorio(c, radio_territorio):
			total += 1
	return total
