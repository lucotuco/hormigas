class_name MaterialesCasa
extends RefCounted
## La geometría conserva su arte; estos datos definen qué se puede devorar y cuándo.
const NIVELES := ["Comida del piso", "Madera y telas", "Materiales resistentes", "Paredes"]
const MADERA := ["silla", "mesa", "mesa_comedor", "ratona", "escritorio", "mesita", "sofa", "sillon", "cama", "biblioteca", "ropero", "alacena", "aparador", "consola", "planta"]
const NOMBRES := {"silla": "Silla", "mesa": "Mesa de cocina", "mesa_comedor": "Mesa del comedor", "ratona": "Mesa ratona", "escritorio": "Escritorio", "mesita": "Mesa de luz", "sofa": "Sofá", "sillon": "Sillón", "cama": "Cama", "biblioteca": "Biblioteca", "ropero": "Ropero", "alacena": "Alacena", "aparador": "Aparador", "consola": "Consola", "planta": "Maceta", "pileta": "Pileta", "mesada": "Mesada", "cocina": "Cocina", "heladera": "Heladera", "television": "Televisor", "banera": "Bañera", "lavabo": "Lavabo", "inodoro": "Inodoro", "lavarropas": "Lavarropas", "pared": "Tramo de pared"}

static func definir(tipo: String, rect: Rect2, color: Color) -> Dictionary:
	var nivel := 3 if tipo in ["pared", "arco", "escultura", "obelisco", "torre"] else (1 if tipo in MADERA else 2)
	var escala := clampf(rect.get_area() / 32000.0, 1, 18)
	var vida := (700.0 if nivel == 1 else (4200.0 if nivel == 2 else 14000.0)) * sqrt(escala)
	return {"id": tipo, "nombre": NOMBRES.get(tipo, tipo.capitalize()), "forma": "casa", "color": color, "vida": vida, "recompensa": vida * (3.0 if nivel == 1 else 5.0), "radio": rect.size.length() * 0.5, "nivel": nivel}

static func piezas() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var muebles := PlanoCasa.muebles()
	for i in muebles.size():
		var m: Dictionary = muebles[i]
		var clave := "mueble:%d" % i
		resultado.append({"clave": clave, "tipo": m.tipo, "rect": m.rect, "color": m.color, "mueble": i, "pared": false, "dibujo": m, "meta": clave == Mundos.plano(Juego.lugar_actual).meta})
	# Los muros se comen por tramos; no desaparece una habitación de un bocado.
	var paredes := PlanoCasa.paredes()
	for i in paredes.size():
		var pared: Rect2 = paredes[i]
		var horizontal := pared.size.x > pared.size.y
		var largo := pared.size.x if horizontal else pared.size.y
		var cantidad := ceili(largo / 420.0)
		for j in cantidad:
			var tam := Vector2(largo / cantidad, pared.size.y) if horizontal else Vector2(pared.size.x, largo / cantidad)
			var pos := pared.position + (Vector2(tam.x * j, 0) if horizontal else Vector2(0, tam.y * j))
			resultado.append({"clave": "pared:%d:%d" % [i, j], "tipo": "pared", "rect": Rect2(pos, tam), "color": Color("ede7d6"), "mueble": -1, "pared": true})
	return resultado
