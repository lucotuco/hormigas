extends Node
## Contenido nuevo, circulación real y límites de costo de los seis escenarios.
const ANTES := {"casa": 37, "restaurante": 25, "museo": 9, "obelisco": 14, "coliseo": 19, "eiffel": 17}
const METAS := {"casa": "mesa_comedor", "restaurante": "mesada", "museo": "escultura", "obelisco": "obelisco", "coliseo": "arco", "eiffel": "torre"}
const RESISTENCIAS := {"casa": 1000.0, "restaurante": 1500.0, "museo": 950.0, "obelisco": 7200.0, "coliseo": 2.3e5, "eiffel": 4.8e7}
const IDENTIDAD := {"casa": ["canasto", "carrito"], "restaurante": ["carrito", "mesa_comedor"], "museo": ["vitrina", "columna", "anfora"], "obelisco": ["colectivo", "taxi", "kiosco", "cartel"], "coliseo": ["columna", "anfora", "fuente"], "eiffel": ["kiosco", "farol", "banco", "fuente"]}
const PASEOS := {
	"casa": [Vector2(-200, 500), Vector2(2100, 1000), Vector2(4600, 600), Vector2(500, 1800), Vector2(1300, 3300), Vector2(2600, 3600), Vector2(5800, 4200)],
	"restaurante": [Vector2(300, -200), Vector2(400, 3300), Vector2(4100, 2800), Vector2(6200, 4200)],
	"museo": [Vector2(500, 700), Vector2(1300, 2700), Vector2(3900, 1000), Vector2(6000, 3100)],
	"obelisco": [Vector2(3500, -100), Vector2(1000, 1300), Vector2(6000, 3500), Vector2(3600, 2800)],
	"coliseo": [Vector2(1000, 1200), Vector2(4900, 1950), Vector2(3900, 3150)],
	"eiffel": [Vector2(1000, 500), Vector2(4500, 1800), Vector2(3000, 3500), Vector2(6200, 300)]}
const COMIDA_ANTES := {"miga": 120, "azucar": 55, "galletita": 70, "queso": 35, "sandwich": 35, "torta": 18, "cereal": 50, "fideo": 35, "frutilla": 35, "dona": 28, "pizza": 24, "banquete": 0, "ravioles": 50, "flan": 40, "pizza_entera": 26, "canape": 90, "bombon": 55, "torta_gala": 30, "alfajor": 90, "medialuna": 60, "choripan": 45, "aceituna": 90, "racimo": 60, "pan_romano": 34, "macaron": 90, "croissant": 50, "baguette": 32}
var total := 0
var fallas := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	verificar(Mundos.VERSION_CONTENIDO == 3, "los récords separan el terreno ampliado como versión3")
	var claves: Dictionary = {}
	for m in Graficos.catalogo_muebles():
		claves[Graficos.clave_mueble(m)] = true
	verificar(claves.size() <= 80, "el catálogo compartido queda acotado a80 acabados")
	for destino in Mundos.ORDEN:
		Juego.reiniciar_estado()
		Juego.lugar_actual = destino
		var plano := Mundos.plano(destino)
		var muebles: Array = plano.muebles
		print("POBLACION ", destino, " muebles ", ANTES[destino], " -> ", muebles.size())
		verificar(muebles.size() >= ANTES[destino] + 15 and muebles.size() <= 72, destino + ": interior y periferia conservan un máximo de72 muebles")
		var tipos: Dictionary = {}
		var catalogo_ok := true
		var limites_ok := true
		for m in muebles:
			tipos[m.tipo] = true
			catalogo_ok = catalogo_ok and claves.has(Graficos.clave_mueble(m)) and MaterialesCasa.NOMBRES.has(m.tipo)
			limites_ok = limites_ok and plano.limites.encloses(m.rect)
		verificar(catalogo_ok and limites_ok, destino + ": todos los objetos tienen material, nombre, arte y límites válidos")
		var identidad := true
		for tipo in IDENTIDAD[destino]:
			identidad = identidad and tipos.has(tipo)
		verificar(identidad, destino + ": contiene los objetos que dan identidad al lugar")
		var indice := int(String(plano.meta).get_slice(":", 1))
		verificar(indice >= 0 and indice < muebles.size() and muebles[indice].tipo == METAS[destino] and is_equal_approx(Mundos.vida_meta(destino), RESISTENCIAS[destino]), destino + ": gran objetivo y resistencia conservados")
		var cocina := Cocina.new()
		add_child(cocina)
		verificar(cocina.libre(Vector2.ZERO, 70), destino + ": el nido y su salida quedan libres")
		var circulacion := true
		for punto in PASEOS[destino]:
			var ruta := cocina.ruta(Vector2.ZERO, punto, 12000)
			var anterior := Vector2.ZERO
			var segura := not ruta.is_empty()
			for paso in ruta:
				segura = segura and cocina.segmento_libre(anterior, paso)
				anterior = paso
			segura = segura and anterior.distance_to(punto) < 1
			if not segura:
				print("SIN PASEO ", destino, " ", punto)
			circulacion = circulacion and segura
		verificar(circulacion, destino + ": las hormigas llegan a los sectores por pasos reales")
		var cruces := 0
		for i in muebles.size():
			for j in range(i + 1, muebles.size()):
				if not muebles[i].rect.intersects(muebles[j].rect):
					continue
				var solapado := false
				for a in SiluetaMueble.rectangulos(muebles[i]):
					for b in SiluetaMueble.rectangulos(muebles[j]):
						if a.intersection(b).get_area() > 16:
							solapado = true
				if solapado:
					cruces += 1
					print("SOLAPADO ", destino, " ", i, ":", muebles[i].tipo, " / ", j, ":", muebles[j].tipo)
		verificar(cruces == 0, destino + ": los objetos no se enciman ni crean barreras superpuestas")
		cocina.queue_free()
		await get_tree().process_frame
	var casa := Mundos.plano("casa")
	verificar(casa.muebles[6].get("perfil", "") == "silla_inicial" and casa.muebles.back().get("practica", false), "primera silla y cartón tutorial conservan identidad y orden")
	var cambios_validos := true
	var antes := 0
	var despues := 0
	for comida in Juego.comidas:
		var cantidad: int = COMIDA_ANTES[comida.id]
		antes += cantidad
		despues += comida.cantidad
		cambios_validos = cambios_validos and comida.cantidad >= cantidad and comida.cantidad <= ceili(cantidad * 1.20)
		if comida.vida >= 200:
			cambios_validos = cambios_validos and comida.cantidad == cantidad
	print("ALIMENTOS catálogo ", antes, " -> ", despues, "; acabados ", claves.size())
	verificar(cambios_validos, "sólo suben cantidades chicas hasta20%; alimentos grandes intactos")
	Juego.reiniciar_estado()
	print("Población de mapas: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)

func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", detalle)
