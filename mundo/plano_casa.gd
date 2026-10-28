class_name PlanoCasa
extends RefCounted
## Plano único para dibujo, suelos, comida, límites y navegación.
const LIMITES := Rect2(-950, -1000, 7900, 5600)
const BANQUETE := Vector2(3900, 1040)
const VENTANAS := [Rect2(-650, -1010, 840, 65), Rect2(5000, -1010, 1060, 65), Rect2(-400, 4530, 960, 65), Rect2(5700, 4530, 780, 65)]
const AMBIENTES := [
	{"id": "cocina", "nombre": "COCINA", "rect": Rect2(-900, -950, 2600, 2300), "color": Color("e5ddc9"), "patron": 0},
	{"id": "comedor", "nombre": "COMEDOR", "rect": Rect2(1700, -950, 2600, 2300), "color": Color("bb936d"), "patron": 1},
	{"id": "living", "nombre": "LIVING", "rect": Rect2(4300, -950, 2600, 3500), "color": Color("c6a17b"), "patron": 1},
	{"id": "pasillo", "nombre": "PASILLO", "rect": Rect2(-900, 1350, 5200, 700), "color": Color("c8bda7"), "patron": 0},
	{"id": "dormitorio", "nombre": "DORMITORIO", "rect": Rect2(-900, 2050, 3000, 2500), "color": Color("d5bca2"), "patron": 1},
	{"id": "estudio", "nombre": "ESTUDIO", "rect": Rect2(2100, 2050, 2200, 2500), "color": Color("bfa489"), "patron": 1},
	{"id": "bano", "nombre": "BAÑO Y LAVADERO", "rect": Rect2(4300, 2550, 2600, 2000), "color": Color("c0d3cf"), "patron": 2},
]
const PAREDES := [
	Rect2(-950, -1000, 7900, 50), Rect2(-950, -1000, 50, 5600),
	Rect2(6900, -1000, 50, 5600), Rect2(-950, 4550, 7900, 50),
	Rect2(1675, -950, 50, 850), Rect2(1675, 350, 50, 1000),
	Rect2(-900, 1325, 800, 50), Rect2(350, 1325, 2400, 50), Rect2(3250, 1325, 1050, 50),
	Rect2(4275, -950, 50, 1350), Rect2(4275, 1000, 50, 2450), Rect2(4275, 3950, 50, 600),
	Rect2(-900, 2025, 1100, 50), Rect2(700, 2025, 1900, 50), Rect2(3100, 2025, 1200, 50),
	Rect2(2075, 2050, 50, 2500),
	Rect2(4300, 2525, 900, 50), Rect2(5700, 2525, 1200, 50),
]
const MUEBLES := [
	{"tipo": "pileta", "rect": Rect2(-850, -900, 650, 250), "color": Color("839e96")},
	{"tipo": "mesada", "rect": Rect2(-200, -900, 680, 250), "color": Color("839e96")},
	{"tipo": "cocina", "rect": Rect2(480, -900, 540, 250), "color": Color("d8dfd5")},
	{"tipo": "heladera", "rect": Rect2(1240, -870, 360, 650), "color": Color("d6dfd5")},
	{"tipo": "alacena", "rect": Rect2(-850, 800, 500, 470), "color": Color("879989")},
	{"tipo": "mesa", "rect": Rect2(400, 160, 700, 440), "color": Color("ba8b59")},
	# La primera silla enseña la madera sin cambiar la resistencia de la casa.
	{"tipo": "silla", "rect": Rect2(180, -100, 140, 190), "color": Color("a6b194"), "frente": "este", "perfil": "silla_inicial"},
	{"tipo": "silla", "rect": Rect2(580, -80, 190, 180), "color": Color("a6b194")},
	{"tipo": "silla", "rect": Rect2(650, 680, 200, 190), "color": Color("a6b194"), "frente": "norte"},
	{"tipo": "silla", "rect": Rect2(1180, 300, 170, 210), "color": Color("a6b194"), "frente": "oeste"},
	{"tipo": "mesa_comedor", "rect": Rect2(2480, -150, 1350, 780), "color": Color("a87e57")},
	{"tipo": "silla", "rect": Rect2(2680, -480, 230, 250), "color": Color("af8862")},
	{"tipo": "silla", "rect": Rect2(3320, -480, 230, 250), "color": Color("af8862")},
	{"tipo": "silla", "rect": Rect2(2680, 720, 230, 250), "color": Color("af8862"), "frente": "norte"},
	{"tipo": "silla", "rect": Rect2(3320, 720, 230, 250), "color": Color("af8862"), "frente": "norte"},
	{"tipo": "aparador", "rect": Rect2(1890, -850, 1400, 300), "color": Color("8b7257")},
	{"tipo": "planta", "rect": Rect2(3940, -820, 220, 240), "color": Color("77926c")},
	{"tipo": "sofa", "rect": Rect2(4750, -520, 1450, 440), "color": Color("78978b")},
	{"tipo": "sillon", "rect": Rect2(6350, 100, 370, 520), "color": Color("b79374")},
	{"tipo": "ratona", "rect": Rect2(5160, 300, 800, 450), "color": Color("be966d")},
	{"tipo": "television", "rect": Rect2(4900, 1400, 1400, 270), "color": Color("705f50")},
	{"tipo": "biblioteca", "rect": Rect2(6500, 1700, 280, 650), "color": Color("a58667")},
	{"tipo": "planta", "rect": Rect2(4440, 2040, 230, 260), "color": Color("6d8d64")},
	{"tipo": "consola", "rect": Rect2(1050, 1490, 1000, 230), "color": Color("a3886b")},
	{"tipo": "cama", "rect": Rect2(-600, 2500, 1500, 1500), "color": Color("929ab3")},
	{"tipo": "mesita", "rect": Rect2(1040, 2600, 430, 390), "color": Color("b99b7b")},
	{"tipo": "ropero", "rect": Rect2(1250, 3700, 600, 650), "color": Color("b4977c")},
	{"tipo": "planta", "rect": Rect2(-730, 4210, 230, 230), "color": Color("809767")},
	{"tipo": "escritorio", "rect": Rect2(2450, 2400, 1300, 560), "color": Color("b08e67")},
	{"tipo": "silla", "rect": Rect2(2930, 3060, 280, 320), "color": Color("8f9a9b"), "frente": "norte"},
	{"tipo": "biblioteca", "rect": Rect2(2260, 4120, 1800, 300), "color": Color("a38565")},
	{"tipo": "planta", "rect": Rect2(3870, 2300, 220, 260), "color": Color("77926c")},
	{"tipo": "banera", "rect": Rect2(4510, 2900, 1080, 740), "color": Color("ecebdc")},
	{"tipo": "lavabo", "rect": Rect2(5820, 2700, 850, 410), "color": Color("e7e8dd")},
	{"tipo": "inodoro", "rect": Rect2(6230, 3700, 400, 650), "color": Color("edeee4")},
	{"tipo": "lavarropas", "rect": Rect2(4700, 3930, 650, 540), "color": Color("c4d3cf")},
	# Grupos secundarios: guardado, vajilla y textiles. Se conserva el orden
	# inicial para el gran objetivo y la primera silla de la colonia.
	{"tipo": "mesada", "rect": Rect2(-850, -450, 420, 360), "color": Color("b8c0af")},
	{"tipo": "canasto", "rect": Rect2(-700, 350, 220, 200), "color": Color("c4a575")},
	{"tipo": "carrito", "rect": Rect2(1120, 850, 420, 330), "color": Color("ad8d64")},
	{"tipo": "canasto", "rect": Rect2(3360, -800, 250, 200), "color": Color("c4a575")},
	{"tipo": "aparador", "rect": Rect2(1880, 340, 460, 380), "color": Color("a88765")},
	{"tipo": "carrito", "rect": Rect2(3940, 300, 320, 380), "color": Color("ad8d64")},
	{"tipo": "consola", "rect": Rect2(4450, 1350, 330, 240), "color": Color("a3886b")},
	{"tipo": "biblioteca", "rect": Rect2(6500, 1050, 280, 440), "color": Color("a58667")},
	{"tipo": "canasto", "rect": Rect2(6000, 2050, 250, 210), "color": Color("c4a575")},
	{"tipo": "sillon", "rect": Rect2(4900, 1950, 400, 410), "color": Color("a99b7d")},
	{"tipo": "mesita", "rect": Rect2(5350, 2110, 300, 260), "color": Color("b99b7b")},
	{"tipo": "canasto", "rect": Rect2(-650, 2140, 250, 240), "color": Color("c4a575")},
	{"tipo": "consola", "rect": Rect2(1020, 3100, 800, 150), "color": Color("b3977b")},
	{"tipo": "mesita", "rect": Rect2(-850, 2700, 190, 240), "color": Color("b99b7b")},
	{"tipo": "biblioteca", "rect": Rect2(3250, 3880, 850, 180), "color": Color("a38565")},
	{"tipo": "carrito", "rect": Rect2(3700, 3450, 400, 300), "color": Color("ad8d64")},
	{"tipo": "canasto", "rect": Rect2(5600, 3200, 400, 350), "color": Color("c4a575")},
	{"tipo": "alacena", "rect": Rect2(6520, 3210, 250, 350), "color": Color("a0b09a")},
]

static func ambiente_en(pos: Vector2) -> String:
	for a in ambientes():
		if a.rect.has_point(pos):
			return a.id
	return ""

static func rect_ambiente(id: String) -> Rect2:
	for a in ambientes():
		if a.id == id:
			return a.rect
	return Rect2()

static func ambientes() -> Array:
	return Mundos.plano(Juego.lugar_actual).ambientes
static func muebles() -> Array:
	return Mundos.plano(Juego.lugar_actual).muebles
static func paredes() -> Array:
	return Mundos.plano(Juego.lugar_actual).paredes
static func ventanas() -> Array:
	return Mundos.plano(Juego.lugar_actual).ventanas
static func limites() -> Rect2:
	return Mundos.plano(Juego.lugar_actual).limites
static func banquete() -> Vector2:
	return Mundos.plano(Juego.lugar_actual).banquete
