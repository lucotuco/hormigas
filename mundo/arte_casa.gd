class_name ArteCasa
extends RefCounted
## Acabado cenital horneado UNA vez en Graficos. Sin luces ni nodos extra.
# Los originales quedan disponibles para revisar recortes y perfiles, pero el
# mobiliario cenital ya no obliga a subir esos dos atlas a la GPU al iniciar.
static var _fuente_muebles: Texture2D
static var _fuente_detalles: Texture2D
static var MUEBLES: Texture2D:
	get:
		if _fuente_muebles == null:
			_fuente_muebles = load("res://arte/realista/muebles.png")
		return _fuente_muebles
const DESTINOS := preload("res://arte/realista/destinos.png")
static var DETALLES: Texture2D:
	get:
		if _fuente_detalles == null:
			_fuente_detalles = load("res://arte/realista/detalles.png")
		return _fuente_detalles
const ALFOMBRAS := [Rect2(57, 75, 441, 333), Rect2(561, 74, 452, 332), Rect2(1045, 74, 455, 332)]
const ILUSTRADOS := ["mesa", "mesa_comedor", "ratona", "escritorio", "mesita", "sofa", "sillon", "cama", "pileta", "lavabo", "mesada", "cocina", "heladera", "biblioteca", "alacena", "aparador", "consola", "ropero", "banco", "television", "banera", "lavarropas", "vitrina", "silla", "planta", "inodoro", "canasto", "carrito", "kiosco", "colectivo", "taxi", "farol", "papelera", "cartel", "columna", "anfora", "fuente"]
# Recortes verificados sobre los originales de 1254 px, no una grilla supuesta.
const RECORTES := {
	"mesa": Rect2(18, 105, 309, 222),
	"mesa_comedor": Rect2(18, 105, 309, 222),
	"sofa": Rect2(331, 107, 309, 220),
	"cama": Rect2(649, 35, 288, 339),
	"escritorio": Rect2(943, 105, 309, 224),
	"silla": Rect2(75, 382, 221, 258),
	"planta": Rect2(330, 346, 300, 316),
	"ratona": Rect2(635, 412, 307, 228),
	"banera": Rect2(940, 374, 313, 269),
	"pileta": Rect2(13, 675, 326, 246),
	"cocina": Rect2(350, 665, 268, 258),
	"biblioteca": Rect2(627, 690, 313, 226),
	"banco": Rect2(943, 686, 310, 237),
	"inodoro": Rect2(72, 937, 221, 289),
	"lavarropas": Rect2(354, 945, 264, 284),
	"sillon": Rect2(640, 928, 296, 299),
	"mesada": Rect2(936, 947, 317, 277),
}
const OTROS := {
	"obelisco": Rect2(158, 22, 134, 503),
	"torre": Rect2(465, 9, 329, 522),
	"arco": Rect2(832, 155, 409, 357),
	"alacena": Rect2(54, 558, 334, 320),
	"ropero": Rect2(54, 558, 334, 320),
	"heladera": Rect2(514, 539, 226, 333),
	"television": Rect2(830, 636, 406, 220),
	"aparador": Rect2(26, 962, 416, 244),
	"consola": Rect2(26, 962, 416, 244),
	"mesita": Rect2(508, 898, 239, 321),
	"vitrina": Rect2(930, 864, 210, 370),
}

static func tiene(tipo: String) -> bool:
	return ILUSTRADOS.has(tipo) or RECORTES.has(tipo) or OTROS.has(tipo)

static func alfombra(l: CanvasItem, r: Rect2, color: Color) -> void:
	# Trama amplia y retenida, legible al acercarse sin estampados fotográficos.
	DibujoCasa.caja(l, r.grow(-10), color.lightened(0.035), Color.TRANSPARENT, 20)
	DibujoCasa.caja(l, r.grow(-45), Color.TRANSPARENT, Color(color.lightened(0.22), 0.5), 16)
	DibujoCasa.caja(l, r.grow(-65), Color.TRANSPARENT, Color(color.darkened(0.25), 0.25), 12)
	for i in 9:
		var x := r.position.x + r.size.x * (0.12 + i * 0.095)
		l.draw_line(Vector2(x, r.position.y + 85), Vector2(x, r.end.y - 85), Color(color.lightened(0.2), 0.10), 3)

static func dibujar(l: CanvasItem, m: Dictionary) -> bool:
	if m.tipo in ILUSTRADOS and m.get("acabado", "") != "carton":
		return false # El mismo dibujo cenital se hornea en el atlas compartido.
	if m.get("acabado", "") == "carton" or not tiene(m.tipo):
		return false
	var fuente: Texture2D = MUEBLES if RECORTES.has(m.tipo) else DESTINOS
	var recorte: Rect2 = RECORTES.get(m.tipo, OTROS.get(m.tipo, Rect2()))
	var r: Rect2 = m.rect
	if m.tipo == "lavabo":
		l.draw_texture_rect_region(DETALLES, r, Rect2(64, 548, 471, 302))
		return true
	# Sombras de apoyo cortas y horneadas con el sprite; no rectángulos oscuros
	# detrás de toda la transparencia del monumento ni luces por cuadro.
	if m.tipo == "obelisco":
		_apoyo(l, r, Vector2(0.51, 0.965), Vector2(0.48, 0.014))
	elif m.tipo == "torre":
		_apoyo(l, r, Vector2(0.15, 0.95), Vector2(0.12, 0.010))
		_apoyo(l, r, Vector2(0.84, 0.95), Vector2(0.12, 0.010))
	elif m.tipo == "arco":
		for x in [0.16, 0.50, 0.84]:
			_apoyo(l, r, Vector2(x, 0.93), Vector2(0.13, 0.018))
	var giro := 0.0
	if m.tipo == "silla":
		match m.get("frente", "sur"):
			"norte": giro = PI
			"este": giro = -PI * 0.5
			"oeste": giro = PI * 0.5
	elif m.tipo == "biblioteca" and r.size.y > r.size.x:
		giro = PI * 0.5
	var tam := r.size
	if absf(sin(giro)) > 0.5:
		tam = Vector2(tam.y, tam.x)
	var tinte := Color.WHITE
	if m.tipo == "silla":
		var c: Color = m.color
		if c.r > c.g * 1.1:
			tinte = Color(1.18, 0.83, 0.65) # tapizado cálido del comedor
		elif c.b > c.r:
			tinte = Color(0.92, 1.0, 1.18) # silla gris del estudio
	l.draw_set_transform(r.get_center(), giro)
	l.draw_texture_rect_region(fuente, Rect2(-tam * 0.5, tam), recorte, tinte)
	l.draw_set_transform(Vector2.ZERO)
	return true

static func _apoyo(l: CanvasItem, rect: Rect2, centro: Vector2, radio: Vector2) -> void:
	l.draw_set_transform(rect.position + rect.size * centro + Vector2(6, 5), 0, rect.size * radio)
	l.draw_circle(Vector2.ZERO, 1.18, Color(0.15, 0.13, 0.10, 0.06))
	l.draw_circle(Vector2.ZERO, 0.88, Color(0.15, 0.13, 0.10, 0.08))
	l.draw_set_transform(Vector2.ZERO)
