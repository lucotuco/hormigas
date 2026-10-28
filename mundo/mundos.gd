class_name Mundos
extends RefCounted
## Planos acotados: viajar cambia el escenario, no multiplica el mundo en memoria.
const ORDEN := ["casa", "restaurante", "museo", "obelisco", "coliseo", "eiffel"]
const VERSION_CONTENIDO := 2
const INFO := {
	"casa": {"nombre": "La casa", "subtitulo": "De las migas a los muebles", "meta": "La gran mesa familiar", "factor": 1.0, "coronas": 1, "vida_meta": 1000.0},
	"restaurante": {"nombre": "El restaurante", "subtitulo": "Salón, barra y cocina industrial", "meta": "La barra del chef", "factor": 1.7, "coronas": 2, "vida_meta": 1500.0},
	"museo": {"nombre": "El museo", "subtitulo": "Galerías, vitrinas y una estatua monumental", "meta": "La gran escultura", "factor": 2.8, "coronas": 3, "vida_meta": 950.0},
	"obelisco": {"nombre": "Obelisco · Buenos Aires", "subtitulo": "La colonia conquista la avenida", "meta": "El Obelisco", "factor": 4.5, "coronas": 4, "vida_meta": 7200.0},
	"coliseo": {"nombre": "Coliseo · Roma", "subtitulo": "Arena, arcos y piedra antigua", "meta": "El gran arco imperial", "factor": 7.0, "coronas": 5, "vida_meta": 2.3e5},
	"eiffel": {"nombre": "Torre Eiffel · París", "subtitulo": "Jardines y una estructura de hierro", "meta": "La Torre Eiffel", "factor": 11.0, "coronas": 6, "vida_meta": 4.8e7},
}
static var _cache: Dictionary = {}
## Multiplicador de resistencia del gran objetivo cuando el destino no define
## "vida_meta".
const VIDA_META_BASE := 3.0
## Sólo para el bot de balance: fuerza la resistencia de un destino sin tocar INFO.
static var vida_meta_forzada: Dictionary = {}


static func vida_meta(id: String) -> float:
	return float(vida_meta_forzada.get(id, INFO[id].get("vida_meta", VIDA_META_BASE)))

const ESPECIALES := [
	{"tipo": "silla", "acabado": "carton", "rect": Rect2(0, 0, 110, 130), "color": Color("a6b194"), "frente": "sur"},
	{"tipo": "banco", "rect": Rect2(0, 0, 800, 220), "color": Color("aa815b")},
	{"tipo": "vitrina", "rect": Rect2(0, 0, 700, 350), "color": Color("8faeaa")},
	{"tipo": "escultura", "rect": Rect2(0, 0, 950, 1150), "color": Color("d4c9b0")},
	{"tipo": "obelisco", "rect": Rect2(0, 0, 650, 1650), "color": Color("dcd4bd")},
	{"tipo": "arco", "rect": Rect2(0, 0, 1300, 700), "color": Color("c8a47d")},
	{"tipo": "torre", "rect": Rect2(0, 0, 1550, 2100), "color": Color("8d7964")},
	{"tipo": "canasto", "rect": Rect2(0, 0, 260, 220), "color": Color("c4a575")},
	{"tipo": "carrito", "rect": Rect2(0, 0, 430, 320), "color": Color("ad8d64")},
	{"tipo": "kiosco", "rect": Rect2(0, 0, 720, 480), "color": Color("82947b")},
	{"tipo": "colectivo", "rect": Rect2(0, 0, 1300, 260), "color": Color("a76d58")},
	{"tipo": "taxi", "rect": Rect2(0, 0, 850, 250), "color": Color("47574d")},
	{"tipo": "farol", "rect": Rect2(0, 0, 130, 200), "color": Color("596c5b")},
	{"tipo": "papelera", "rect": Rect2(0, 0, 160, 180), "color": Color("819078")},
	{"tipo": "cartel", "rect": Rect2(0, 0, 260, 300), "color": Color("6f8a75")},
	{"tipo": "columna", "rect": Rect2(0, 0, 340, 340), "color": Color("cbbb9e")},
	{"tipo": "anfora", "rect": Rect2(0, 0, 360, 420), "color": Color("bf916d")},
	{"tipo": "fuente", "rect": Rect2(0, 0, 700, 650), "color": Color("b6b8a0")},
]

static func plano(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var p := {"limites": PlanoCasa.LIMITES, "ambientes": [], "muebles": [], "paredes": [], "ventanas": [], "banquete": Vector2(3900, 1040), "meta": "mueble:10"}
	if id == "casa":
		p.ambientes = PlanoCasa.AMBIENTES
		p.muebles = PlanoCasa.MUEBLES.duplicate()
		_poner(p, "silla", Rect2(-360, 190, 110, 130))
		p.muebles.back()["practica"] = true
		p.muebles.back()["acabado"] = "carton"
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
	_poner(p, "mesada", Rect2(-780, -450, 700, 300))
	_poner(p, "carrito", Rect2(1000, 500, 450, 350))
	_poner(p, "alacena", Rect2(-800, 900, 550, 430))
	_poner(p, "canasto", Rect2(600, 1050, 250, 250))
	_poner(p, "banco", Rect2(-650, 2900, 700, 180))
	_poner(p, "banco", Rect2(350, 2900, 700, 180))
	_poner(p, "mesita", Rect2(-600, 3500, 500, 350))
	_poner(p, "silla", Rect2(0, 3500, 200, 220))
	_poner(p, "silla", Rect2(-300, 3990, 200, 220), false, "norte")
	_poner(p, "carrito", Rect2(1100, 3750, 400, 350))
	_poner(p, "canasto", Rect2(1100, 1700, 350, 250))
	_poner(p, "carrito", Rect2(6200, 1250, 450, 450))
	for y in [0, 1600, 3200]:
		for x in [2500, 4800]:
			_poner(p, "mesa_comedor", Rect2(x, y, 1050, 600))
			_poner(p, "silla", Rect2(x + 120, y - 300, 200, 210))
			_poner(p, "silla", Rect2(x + 700, y - 300, 200, 210))
			_poner(p, "silla", Rect2(x + 120, y + 720, 200, 210), false, "norte")
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
	_poner(p, "kiosco", Rect2(-750, 300, 700, 420))
	p.muebles.back().acabado = "libros"
	_poner(p, "banco", Rect2(-750, -650, 700, 200))
	_poner(p, "planta", Rect2(1100, 500, 240, 260))
	_poner(p, "vitrina", Rect2(200, -200, 650, 280))
	for pos in [Vector2(1900, 300), Vector2(6200, 300), Vector2(1900, 2700), Vector2(6200, 2700)]:
		_poner(p, "columna", Rect2(pos, Vector2(340, 340)))
	for pos in [Vector2(2650, 1000), Vector2(5350, 1200)]:
		_poner(p, "anfora", Rect2(pos, Vector2(360, 420)))
	_poner(p, "vitrina", Rect2(2000, 2000, 750, 350))
	_poner(p, "vitrina", Rect2(5500, 2200, 750, 350))
	_poner(p, "vitrina", Rect2(4700, 400, 900, 300))
	_poner(p, "banco", Rect2(3500, 4000, 850, 200))
	_poner(p, "banco", Rect2(3700, 500, 850, 200))
	_poner(p, "carrito", Rect2(-650, 2100, 500, 330))
	_poner(p, "biblioteca", Rect2(1050, 1400, 360, 900))
	_poner(p, "biblioteca", Rect2(1050, 3300, 360, 900))
	_poner(p, "canasto", Rect2(-650, 3200, 250, 220))
	_poner(p, "planta", Rect2(6500, 4000, 240, 260))

static func _plaza(p: Dictionary) -> void:
	_zona(p, "cocina", "AVENIDA 9 DE JULIO", Rect2(-900, -950, 7800, 5500), "bfb9a9", 0)
	_poner(p, "obelisco", Rect2(2900, 950, 650, 1650), true)
	for x in [-600, 1200, 4800, 6300]:
		for y in [-650, 3700]:
			_poner(p, "planta", Rect2(x, y, 300, 320))
	for x in [500, 2000, 4400, 5900]:
		_poner(p, "banco", Rect2(x, 3100, 800, 220))
	_poner(p, "mesa", Rect2(800, 400, 650, 400))
	_poner(p, "kiosco", Rect2(-700, 600, 680, 500))
	_poner(p, "kiosco", Rect2(5500, 1400, 700, 500))
	_poner(p, "colectivo", Rect2(1600, -215, 1300, 250))
	_poner(p, "taxi", Rect2(4800, -220, 850, 250))
	for x in [-600, 1400, 4400, 6500]:
		_poner(p, "farol", Rect2(x, 150, 130, 200))
	for x in [-600, 1600, 4000, 6500]:
		_poner(p, "farol", Rect2(x, 3400, 130, 200))
	for pos in [Vector2(1350, 3400), Vector2(4200, 3300), Vector2(500, 1200), Vector2(6200, 2100)]:
		_poner(p, "papelera", Rect2(pos, Vector2(160, 180)))
	_poner(p, "cartel", Rect2(1800, 500, 260, 300))
	_poner(p, "cartel", Rect2(4550, 2250, 260, 300))
	_poner(p, "fuente", Rect2(800, 1700, 650, 650))
	p.banquete = Vector2(5200, 2000)

static func _coliseo(p: Dictionary) -> void:
	_zona(p, "cocina", "ACCESO A LA ARENA", Rect2(-900, -950, 2400, 5500), "cbb89a", 0)
	_zona(p, "comedor", "ARENA DEL COLISEO", Rect2(1500, -950, 5400, 5500), "d5b98a", 3)
	var centro := Vector2(3700, 1700)
	for i in 18:
		var a := TAU * i / 18
		var pos := centro + Vector2(cos(a) * 2350, sin(a) * 2050)
		_poner(p, "arco", Rect2(pos - Vector2(280, 160), Vector2(560, 320)))
	_poner(p, "arco", Rect2(3100, 1200, 1300, 700), true)
	for pos in [Vector2(-600, 700), Vector2(400, 600), Vector2(1900, 1000), Vector2(5200, 1000), Vector2(1900, 2400), Vector2(5200, 2400), Vector2(3300, 3000), Vector2(4200, 3000)]:
		_poner(p, "columna", Rect2(pos, Vector2(340, 340)))
		if p.muebles.size() % 3 == 0:
			p.muebles.back().acabado = "rota"
	for pos in [Vector2(700, 1600), Vector2(1100, 3700), Vector2(2500, 500), Vector2(4800, 500), Vector2(2800, 2600), Vector2(4800, 2650)]:
		_poner(p, "anfora", Rect2(pos, Vector2(360, 420)))
	_poner(p, "fuente", Rect2(100, 2400, 750, 650))
	_poner(p, "banco", Rect2(-650, 1500, 800, 180))
	_poner(p, "banco", Rect2(-650, 3600, 800, 180))
	_poner(p, "kiosco", Rect2(-700, -700, 780, 400))
	for pos in [Vector2(1000, 850), Vector2(200, 4000)]:
		_poner(p, "papelera", Rect2(pos, Vector2(160, 180)))
	p.banquete = Vector2(4200, 2700)

static func _paris(p: Dictionary) -> void:
	_zona(p, "cocina", "CHAMP DE MARS", Rect2(-900, -950, 7800, 5500), "9da37c", 4)
	_zona(p, "comedor", "ESPLANADA DE PARÍS", Rect2(1950, -950, 2600, 5500), "c7bfaa", 0)
	_poner(p, "torre", Rect2(2500, 750, 1550, 2100), true)
	for x in [-600, 900, 4900, 6300]:
		for y in [-600, 3400]:
			_poner(p, "planta", Rect2(x, y, 300, 320))
	for x in [200, 5200]:
		for y in [800, 2400]:
			_poner(p, "mesa", Rect2(x, y, 650, 400))
			_poner(p, "silla", Rect2(x + 200, y + 500, 200, 220), false, "norte")
	_poner(p, "kiosco", Rect2(-750, 600, 650, 450))
	p.muebles.back().acabado = "libros"
	_poner(p, "kiosco", Rect2(5400, -500, 650, 500))
	p.muebles.back().acabado = "libros"
	for pos in [Vector2(-400, 1800), Vector2(5300, 1800), Vector2(2000, 3800), Vector2(3550, 3800)]:
		_poner(p, "banco", Rect2(pos, Vector2(800, 180)))
	for x in [1600, 4550]:
		for y in [-400, 600, 3100, 4100]:
			_poner(p, "farol", Rect2(x, y, 130, 200))
	for x in [100, 6050]:
		for y in [1400, 3000]:
			_poner(p, "papelera", Rect2(x, y, 160, 180))
	_poner(p, "fuente", Rect2(2800, -600, 700, 650))
	_poner(p, "carrito", Rect2(700, 1900, 400, 250))
	p.banquete = Vector2(4400, 3300)
