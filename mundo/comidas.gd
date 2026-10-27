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


func generar() -> void:
	for c in lista:
		c.queue_free()
	lista.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMILLA_MAPA
	var ocupados: Array[Vector3] = []  # x, y, radio
	for tipo in Juego.comidas:
		var radio: float = tipo.radio
		var dmin: float = tipo.distancia_min
		var dmax: float = tipo.distancia_max
		for i in int(tipo.cantidad):
			for intento in INTENTOS:
				var angulo := rng.randf() * TAU
				# sqrt para que la densidad sea pareja en todo el anillo
				var distancia := sqrt(rng.randf_range(dmin * dmin, dmax * dmax))
				var pos := Vector2.from_angle(angulo) * distancia
				var zonas: String = tipo.get("zonas", "")
				if zonas != "":
					var opciones := zonas.split("|")
					var zona := PlanoCasa.rect_ambiente(opciones[rng.randi_range(0, opciones.size() - 1)]).grow(-60)
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
			_crear(tipo, PlanoCasa.BANQUETE, 101)


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
	comida.configurar(tipo, semilla)
	comida.destruida.connect(_on_destruida)
	lista.append(comida)


func _on_destruida(comida: Comida) -> void:
	lista.erase(comida)
	comida_destruida.emit(comida)


## ¿La comida está (al menos en parte) dentro del territorio?
static func en_territorio(comida: Comida, radio_territorio: float) -> bool:
	return comida.position.length() - comida.radio * 0.5 <= radio_territorio


## La comida viva más cercana a `pos` dentro de `alcance`, o null.
func buscar_cercana(pos: Vector2, alcance: float, radio_territorio: float, excluidas: Dictionary = {}) -> Comida:
	var mejor: Comida = null
	var mejor_distancia := INF
	for c in lista:
		if c.muerta or excluidas.has(c.get_instance_id()):
			continue
		var limite := alcance + c.radio
		var d := pos.distance_squared_to(c.position)
		if d < limite * limite and d < mejor_distancia and en_territorio(c, radio_territorio):
			mejor = c
			mejor_distancia = d
	return mejor


## La comida que está debajo del cursor (con un margen para que sea fácil acertar).
func comida_en(pos: Vector2, radio_territorio: float) -> Comida:
	var margen := 6.0 / maxf(get_viewport().get_canvas_transform().get_scale().x, 0.01)
	var mejor: Comida = null
	var mejor_distancia := INF
	for c in lista:
		if c.muerta or not en_territorio(c, radio_territorio):
			continue
		var limite := c.radio + margen
		var d := pos.distance_squared_to(c.position)
		if d < limite * limite and d < mejor_distancia:
			mejor = c
			mejor_distancia = d
	return mejor


func cantidad_en_territorio(radio_territorio: float) -> int:
	var total := 0
	for c in lista:
		if not c.muerta and en_territorio(c, radio_territorio):
			total += 1
	return total
