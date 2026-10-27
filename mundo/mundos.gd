class_name Mundos
extends RefCounted
## Planos acotados: viajar cambia el escenario, no multiplica el mundo en memoria.
const ORDEN := ["casa", "restaurante", "museo", "obelisco", "coliseo", "eiffel"]
const INFO := {
	"casa": {"nombre": "La casa", "subtitulo": "De las migas a los muebles", "meta": "La gran mesa familiar", "factor": 1.0, "coronas": 1},
	"restaurante": {"nombre": "El restaurante", "subtitulo": "Salón, barra y cocina industrial", "meta": "La barra del chef", "factor": 1.7, "coronas": 2},
	"museo": {"nombre": "El museo", "subtitulo": "Galerías, vitrinas y una estatua monumental", "meta": "La gran escultura", "factor": 2.8, "coronas": 3},
	"obelisco": {"nombre": "Obelisco · Buenos Aires", "subtitulo": "La colonia conquista la avenida", "meta": "El Obelisco", "factor": 4.5, "coronas": 4},
	"coliseo": {"nombre": "Coliseo · Roma", "subtitulo": "Arena, arcos y piedra antigua", "meta": "El gran arco imperial", "factor": 7.0, "coronas": 5},
	"eiffel": {"nombre": "Torre Eiffel · París", "subtitulo": "Jardines y una estructura de hierro", "meta": "La Torre Eiffel", "factor": 11.0, "coronas": 6},
}
static var _cache: Dictionary = {}
const ESPECIALES := [
	{"tipo": "vitrina", "rect": Rect2(0, 0, 700, 350), "color": Color("8faeaa")},
	{"tipo": "escultura", "rect": Rect2(0, 0, 950, 1150), "color": Color("d4c9b0")},
	{"tipo": "obelisco", "rect": Rect2(0, 0, 650, 1650), "color": Color("dcd4bd")},
	{"tipo": "arco", "rect": Rect2(0, 0, 1300, 700), "color": Color("c8a47d")},
	{"tipo": "torre", "rect": Rect2(0, 0, 1550, 2100), "color": Color("8d7964")},
]

static func plano(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var p := {"limites": PlanoCasa.LIMITES, "ambientes": [], "muebles": [], "paredes": [], "ventanas": [], "banquete": Vector2(3900, 1040), "meta": "mueble:10"}
	if id == "casa":
		p.ambientes = PlanoCasa.AMBIENTES
		p.muebles = PlanoCasa.MUEBLES
		p.paredes = PlanoCasa.PAREDES
		p.ventanas = PlanoCasa.VENTANAS
	else:
		p.paredes = [Rect2(-950, -1000, 7900, 50), Rect2(-950, -1000, 50, 5600), Rect2(6900, -1000, 50, 5600), Rect2(-950, 4550, 7900, 50)]
		match id:
			"restaurante": _restaurante(p)
			"museo": _museo(p)
			"obelisco": _plaza(p)
			"coliseo": _coliseo(p)
			"eiffel": _paris(p)
	_cache[id] = p
	return p

static func _zona(p: Dictionary, id: String, nombre: String, rect: Rect2, color: String, patron: int) -> void:
	p.ambientes.append({"id": id, "nombre": nombre, "rect": rect, "color": Color(color), "patron": patron})

static func _poner(p: Dictionary, tipo: String, rect: Rect2, meta := false, frente := "sur") -> void:
	var base: Dictionary = {}
	for m in PlanoCasa.MUEBLES + ESPECIALES:
		if m.tipo == tipo:
			base = m.duplicate(true)
			break
	assert(not base.is_empty())
	base.rect = rect
	if tipo == "silla":
		base.frente = frente
	if meta:
		p.meta = "mueble:%d" % p.muebles.size()
	p.muebles.append(base)

static func _restaurante(p: Dictionary) -> void:
	_zona(p, "cocina", "COCINA INDUSTRIAL", Rect2(-900, -950, 2600, 2500), "d9d3bd", 0)
	_zona(p, "comedor", "EL SALÓN", Rect2(1700, -950, 5200, 5500), "ad8762", 1)
	_zona(p, "estudio", "LA BARRA", Rect2(-900, 1550, 2600, 3000), "bca587", 1)
	p.paredes.append_array([Rect2(1675, -950, 50, 1050), Rect2(1675, 700, 50, 1450), Rect2(1675, 2750, 50, 1800)])
	_poner(p, "pileta", Rect2(-850, -900, 650, 250))
	_poner(p, "cocina", Rect2(-150, -900, 540, 250))
	_poner(p, "heladera", Rect2(1100, -850, 450, 650))
	_poner(p, "mesada", Rect2(-700, 2100, 1850, 450), true)
	for y in [0, 1600, 3200]:
		for x in [2500, 4800]:
			_poner(p, "mesa_comedor", Rect2(x, y, 1050, 600))
			_poner(p, "silla", Rect2(x + 120, y - 300, 200, 210))
			_poner(p, "silla", Rect2(x + 700, y + 720, 200, 210), false, "norte")
	for pos in [Vector2(1900, 4000), Vector2(6400, -800), Vector2(-750, 4000)]:
		_poner(p, "planta", Rect2(pos, Vector2(230, 240)))

static func _museo(p: Dictionary) -> void:
	_zona(p, "cocina", "VESTÍBULO", Rect2(-900, -950, 2600, 2000), "dcd8c8", 0)
	_zona(p, "comedor", "GALERÍA PRINCIPAL", Rect2(1700, -950, 5200, 5500), "c8baa0", 0)
	_zona(p, "estudio", "ARCHIVO", Rect2(-900, 1050, 2600, 3500), "b79b7d", 1)
	p.paredes.append_array([Rect2(1675, -950, 50, 900), Rect2(1675, 600, 50, 1700), Rect2(1675, 2900, 50, 1650)])
	_poner(p, "escultura", Rect2(3600, 1500, 950, 1150), true)
	for pos in [Vector2(2200, -500), Vector2(5400, -500), Vector2(2200, 3400), Vector2(5400, 3400)]:
		_poner(p, "vitrina", Rect2(pos, Vector2(950, 400)))
	for y in [1400, 2800, 4100]:
		_poner(p, "biblioteca", Rect2(-700, y, 1600, 270))
	_poner(p, "consola", Rect2(600, -650, 800, 250))

static func _plaza(p: Dictionary) -> void:
	_zona(p, "cocina", "AVENIDA 9 DE JULIO", Rect2(-900, -950, 7800, 5500), "bfb9a9", 0)
	_poner(p, "obelisco", Rect2(2900, 950, 650, 1650), true)
	for x in [-600, 1200, 4800, 6300]:
		for y in [-650, 3700]:
			_poner(p, "planta", Rect2(x, y, 300, 320))
	for x in [500, 2000, 4400, 5900]:
		_poner(p, "consola", Rect2(x, 3100, 800, 220))
	_poner(p, "mesa", Rect2(800, 400, 650, 400))
	p.banquete = Vector2(5200, 2000)

static func _coliseo(p: Dictionary) -> void:
	_zona(p, "cocina", "ACCESO A LA ARENA", Rect2(-900, -950, 2400, 5500), "cbb89a", 0)
	_zona(p, "comedor", "ARENA DEL COLISEO", Rect2(1500, -950, 5400, 5500), "d5b98a", 0)
	var centro := Vector2(3700, 1700)
	for i in 18:
		var a := TAU * i / 18
		var pos := centro + Vector2(cos(a) * 2350, sin(a) * 2050)
		_poner(p, "arco", Rect2(pos - Vector2(280, 160), Vector2(560, 320)))
	_poner(p, "arco", Rect2(3100, 1200, 1300, 700), true)
	p.banquete = Vector2(4200, 2700)

static func _paris(p: Dictionary) -> void:
	_zona(p, "cocina", "CHAMP DE MARS", Rect2(-900, -950, 7800, 5500), "9da37c", 2)
	_zona(p, "comedor", "ESPLANADA DE PARÍS", Rect2(1950, -950, 2600, 5500), "c7bfaa", 0)
	_poner(p, "torre", Rect2(2500, 750, 1550, 2100), true)
	for x in [-600, 900, 4900, 6300]:
		for y in [-600, 3400]:
			_poner(p, "planta", Rect2(x, y, 300, 320))
	for x in [200, 5200]:
		for y in [800, 2400]:
			_poner(p, "mesa", Rect2(x, y, 650, 400))
			_poner(p, "silla", Rect2(x + 200, y + 500, 200, 220), false, "norte")
	p.banquete = Vector2(4400, 3300)
