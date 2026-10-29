class_name PlanoHormiguero
extends RefCounted
## Plano del hormiguero de mejoras: dónde está cada cámara y por dónde pasan
## sus túneles. Es dibujo, no balance: los efectos y requisitos están en
## datos/mejoras.csv y datos/castas.csv. Coordenadas del corte de 1700 × 1900,
## con la superficie arriba (y = 0 a 40) y la reina en el centro.
##
## Cada cámara es una mejora o una casta (las castas se reclutan con un clic).
## Tres cámaras son secciones: viajes (en la boca), castas (fichas y
## evoluciones) y legado (la reina y la jalea real, en el centro).
## Un túnel que llega a una mejora o casta sale siempre de uno de sus
## requisitos (lo verifica tests/prueba_nido). Los túneles de las secciones
## y las galerías hacia la sala de castas son sólo del dibujo.

const TAMANO := Vector2(1700, 1900)
const BOCA := Vector2(850, 22)
const SECCIONES := ["viajes", "castas", "legado"]
## Ramas de primer anillo: salen de la cámara de la reina.
const RAICES := ["veloz", "rastro_persistente", "excavar", "mandibulas", "buche", "mas_obreras", "reservas"]

## id: [x, y, ancho, alto]
const CAMARAS := {
	"viajes": [850, 112, 320, 64],
	"castas": [850, 340, 96, 54],
	"legado": [850, 900, 260, 146],
	# Castas
	"veloz": [1025, 753, 103, 65],
	"roja": [1118, 656, 104, 67],
	"cargadora": [1174, 527, 92, 60],
	"voladora": [1255, 625, 99, 64],
	"carpintera": [1243, 426, 82, 52],
	"reina": [1315, 517, 85, 53],
	"demoledora": [1274, 334, 71, 45],
	"escuela": [1384, 403, 71, 46],
	"cuarteles": [1456, 496, 77, 49],
	# Feromonas
	"rastro_persistente": [1082, 908, 77, 77],
	"antenas": [1197, 989, 64, 64],
	"alarma": [1327, 835, 61, 61],
	"pisoton": [1327, 967, 67, 67],
	"rastro_azucar": [1442, 963, 59, 59],
	"curadora": [1439, 1072, 69, 69],
	"feromona_colmena": [1547, 718, 60, 60],
	"antenas_largas": [1562, 829, 58, 58],
	"senderos_quimicos": [1555, 959, 66, 66],
	"mapa_olores": [1555, 1073, 57, 57],
	# Territorio
	"excavar": [1014, 1064, 119, 43],
	"entradas": [1076, 1195, 116, 43],
	"saqueo": [1170, 1266, 99, 37],
	"galerias": [1315, 1279, 100, 36],
	"socavones": [1230, 1370, 99, 36],
	"exploradoras": [1454, 1298, 88, 32],
	"derrumbe_cadena": [1387, 1386, 97, 36],
	"botin_escondido": [1284, 1465, 96, 35],
	"guardianas": [1540, 1376, 81, 30],
	"calzadas": [1466, 1451, 82, 31],
	"tierras_conquistadas": [1393, 1540, 84, 31],
	"cimientos_coliseo": [1299, 1604, 94, 35],
	# Mandíbulas
	"mandibulas": [850, 1132, 95, 60],
	"mordida_rapida": [845, 1258, 96, 62],
	"mandibulas_acero": [972, 1375, 90, 58],
	"mordida_madera": [848, 1385, 87, 57],
	"pisada_auto": [723, 1383, 80, 52],
	"mordida_resistente": [907, 1511, 79, 50],
	"filo_aserrado": [794, 1511, 84, 53],
	"mordida_muros": [965, 1618, 68, 44],
	"titanio": [842, 1614, 71, 46],
	"acido_formico": [727, 1614, 73, 47],
	"mordida_incansable": [607, 1581, 80, 51],
	"legion": [1075, 1703, 70, 46],
	"diamante": [970, 1723, 75, 49],
	"golpe_cimientos": [856, 1728, 76, 50],
	"mate": [726, 1727, 65, 42],
	"colmillos": [627, 1700, 66, 43],
	# Recolección
	"buche": [686, 1064, 112, 48],
	"recoleccion_eficiente": [522, 1270, 89, 39],
	"huevos_dorados": [464, 1369, 87, 37],
	"banquete": [381, 1290, 82, 35],
	"bandeja": [416, 1466, 90, 39],
	"migas_finas": [318, 1391, 84, 37],
	"haute": [415, 1606, 87, 39],
	"despensa_sin_fondo": [325, 1534, 78, 35],
	"migas_abundancia": [227, 1457, 73, 32],
	"festin_eterno": [159, 1362, 77, 34],
	# Colonia
	"mas_obreras": [618, 908, 90, 67],
	"cria_acelerada": [494, 982, 84, 64],
	"patas_largas": [495, 866, 91, 70],
	"nodrizas": [365, 954, 82, 63],
	"patas_de_seda": [367, 850, 75, 58],
	"hermanas_mayores": [266, 1073, 79, 59],
	"camara_pupas": [254, 958, 77, 58],
	"restauradoras": [252, 843, 66, 50],
	"mirador": [150, 1082, 72, 54],
	"portenas": [121, 961, 70, 53],
	"marcha_nocturna": [123, 832, 74, 56],
	"colonia_inmensa": [148, 720, 64, 49],
	# Tiempo
	"reservas": [675, 754, 76, 74],
	"vuelta_a_casa": [582, 649, 75, 75],
	"segundo_aire": [448, 634, 69, 70],
	"frenesi_prolongado": [522, 536, 63, 64],
	"regreso_en_fila": [316, 611, 60, 59],
	"cuadrigas": [389, 523, 56, 55],
	"horas_extra": [462, 436, 59, 58],
	# Compartidas: piden una mejora de cada rama
	"senales_casta": [1201, 774, 89, 58],
	"pisada": [697, 1230, 98, 64],
	"olfato_explorador": [1306, 1106, 83, 54],
	"larvas_glotonas": [400, 1098, 91, 59],
	"relevos": [392, 727, 76, 50],
	"escuadrilla": [1427, 682, 72, 46],
	"picos": [1092, 1452, 73, 46],
	"pisada_equipo": [609, 1449, 79, 50],
	"mapa_tesoro": [1499, 1187, 79, 51],
	"demolicion": [1141, 1559, 67, 43],
	"banquete_familiar": [192, 1191, 69, 45],
	"acarreo_pesado": [521, 1665, 63, 41],
	"corazon": [850, 1842, 150, 60],
}

## [desde, hasta, ancho, puntos intermedios]. Primero los de la estructura.
const TUNELES := [
	["boca", "viajes", 20],
	["viajes", "castas", 22],
	["castas", "legado", 22, [[862, 620]]],
	["legado", "veloz", 18],
	["legado", "rastro_persistente", 18],
	["legado", "excavar", 18],
	["legado", "mandibulas", 18],
	["legado", "buche", 18],
	["legado", "mas_obreras", 18],
	["legado", "reservas", 18],
	["frenesi_prolongado", "castas", 12],
	["cargadora", "castas", 12],
	# Castas
	["veloz", "roja", 15],
	["veloz", "senales_casta", 11],
	["rastro_persistente", "senales_casta", 11],
	["roja", "cargadora", 13],
	["roja", "voladora", 13],
	["cargadora", "voladora", 10, [[1227, 565]]],
	["cargadora", "carpintera", 11],
	["voladora", "reina", 11],
	["voladora", "escuadrilla", 11],
	["carpintera", "demoledora", 11],
	["reina", "demoledora", 10],
	["reina", "escuela", 11],
	["carpintera", "escuela", 10],
	["reina", "cuarteles", 11],
	["cuarteles", "feromona_colmena", 10, [[1520, 599]]],
	# Feromonas
	["rastro_persistente", "antenas", 15],
	["senales_casta", "alarma", 13],
	["antenas", "pisoton", 13],
	["antenas", "olfato_explorador", 11],
	["entradas", "olfato_explorador", 11],
	["alarma", "escuadrilla", 11],
	["pisoton", "rastro_azucar", 11],
	["alarma", "rastro_azucar", 10],
	["olfato_explorador", "curadora", 11],
	["pisoton", "curadora", 10],
	["escuadrilla", "feromona_colmena", 11],
	["rastro_azucar", "feromona_colmena", 10],
	["rastro_azucar", "antenas_largas", 11],
	["rastro_azucar", "senderos_quimicos", 11],
	["curadora", "mapa_olores", 11],
	["rastro_azucar", "mapa_olores", 10],
	["curadora", "mapa_tesoro", 11],
	["galerias", "mapa_tesoro", 11],
	# Territorio
	["excavar", "entradas", 15],
	["entradas", "saqueo", 13],
	["saqueo", "galerias", 11],
	["saqueo", "socavones", 11],
	["saqueo", "picos", 11],
	["mandibulas_acero", "picos", 11],
	["galerias", "exploradoras", 11],
	["galerias", "derrumbe_cadena", 11],
	["socavones", "derrumbe_cadena", 10],
	["socavones", "botin_escondido", 11],
	["socavones", "demolicion", 11],
	["mordida_resistente", "demolicion", 11],
	["exploradoras", "guardianas", 11],
	["derrumbe_cadena", "guardianas", 10],
	["derrumbe_cadena", "calzadas", 11],
	["botin_escondido", "tierras_conquistadas", 11],
	["botin_escondido", "cimientos_coliseo", 11],
	["demolicion", "cimientos_coliseo", 10],
	["cimientos_coliseo", "legion", 10, [[1196, 1674]]],
	# Mandíbulas
	["mandibulas", "mordida_rapida", 15],
	["mandibulas", "pisada", 11],
	["buche", "pisada", 11],
	["mordida_rapida", "mandibulas_acero", 13],
	["mordida_rapida", "mordida_madera", 13],
	["pisada", "pisada_auto", 13],
	["pisada", "recoleccion_eficiente", 13],
	["mordida_madera", "mordida_resistente", 11],
	["mordida_madera", "filo_aserrado", 11],
	["pisada_auto", "pisada_equipo", 11],
	["recoleccion_eficiente", "pisada_equipo", 11],
	["mordida_resistente", "mordida_muros", 11],
	["filo_aserrado", "titanio", 11],
	["filo_aserrado", "acido_formico", 11],
	["pisada_equipo", "acido_formico", 10],
	["titanio", "acido_formico", 10, [[783, 1631]]],
	["pisada_equipo", "mordida_incansable", 11],
	["mordida_muros", "legion", 11],
	["mordida_muros", "diamante", 11],
	["titanio", "diamante", 10],
	["titanio", "golpe_cimientos", 11],
	["mordida_muros", "golpe_cimientos", 10],
	["acido_formico", "mate", 11],
	["titanio", "mate", 10],
	["mordida_incansable", "colmillos", 11],
	["acido_formico", "colmillos", 10],
	["mordida_incansable", "acarreo_pesado", 11],
	["bandeja", "acarreo_pesado", 11],
	["golpe_cimientos", "corazon", 11],
	["titanio", "corazon", 11],
	["mordida_muros", "corazon", 11],
	# Recolección
	["recoleccion_eficiente", "huevos_dorados", 11],
	["recoleccion_eficiente", "banquete", 11],
	["recoleccion_eficiente", "larvas_glotonas", 10],
	["huevos_dorados", "bandeja", 11],
	["mordida_incansable", "bandeja", 10, [[498, 1544]]],
	["banquete", "migas_finas", 11],
	["huevos_dorados", "migas_finas", 10],
	["bandeja", "migas_finas", 10, [[357, 1444]]],
	["banquete", "banquete_familiar", 11],
	["bandeja", "haute", 11],
	["bandeja", "despensa_sin_fondo", 11],
	["migas_finas", "migas_abundancia", 11],
	["bandeja", "migas_abundancia", 10],
	["migas_finas", "festin_eterno", 11],
	# Colonia
	["mas_obreras", "cria_acelerada", 15],
	["mas_obreras", "patas_largas", 15],
	["cria_acelerada", "larvas_glotonas", 11],
	["cria_acelerada", "nodrizas", 13],
	["patas_largas", "patas_de_seda", 13],
	["patas_de_seda", "nodrizas", 10, [[346, 902]]],
	["patas_largas", "relevos", 11],
	["vuelta_a_casa", "relevos", 11],
	["larvas_glotonas", "hermanas_mayores", 11],
	["nodrizas", "hermanas_mayores", 10],
	["nodrizas", "camara_pupas", 11],
	["patas_de_seda", "restauradoras", 11],
	["hermanas_mayores", "banquete_familiar", 11],
	["hermanas_mayores", "mirador", 11],
	["camara_pupas", "portenas", 11],
	["restauradoras", "portenas", 10],
	["restauradoras", "marcha_nocturna", 11],
	["camara_pupas", "marcha_nocturna", 10],
	["restauradoras", "colonia_inmensa", 11],
	["marcha_nocturna", "colonia_inmensa", 10, [[127, 774]]],
	# Tiempo
	["reservas", "vuelta_a_casa", 15],
	["vuelta_a_casa", "segundo_aire", 13],
	["vuelta_a_casa", "frenesi_prolongado", 13],
	["segundo_aire", "frenesi_prolongado", 10, [[468, 571]]],
	["segundo_aire", "regreso_en_fila", 11],
	["restauradoras", "regreso_en_fila", 10, [[257, 718]]],
	["segundo_aire", "cuadrigas", 11],
	["frenesi_prolongado", "horas_extra", 11],
]


## Rectángulo de una cámara en el corte.
static func rect(id: String) -> Rect2:
	var c: Array = CAMARAS[id]
	return Rect2(c[0] - c[2] * 0.5, c[1] - c[3] * 0.5, c[2], c[3])


static func centro(id: String) -> Vector2:
	if id == "boca":
		return BOCA
	var c: Array = CAMARAS[id]
	return Vector2(c[0], c[1])


## Curva de un túnel, igual que en el lienzo de diseño: una recta suave si
## no tiene puntos intermedios; si los tiene, una spline que pasa por ellos.
static func puntos_tunel(tunel: Array, pasos := 18) -> PackedVector2Array:
	var puntos: Array[Vector2] = [centro(tunel[0])]
	if tunel.size() > 3:
		for v in tunel[3]:
			puntos.append(Vector2(v[0], v[1]))
	puntos.append(centro(tunel[1]))
	var salida := PackedVector2Array()
	for i in puntos.size() - 1:
		var p0 := puntos[maxi(0, i - 1)]
		var p1 := puntos[i]
		var p2 := puntos[i + 1]
		var p3 := puntos[mini(puntos.size() - 1, i + 2)]
		var c1 := p1 + (p2 - p0) / 6.0
		var c2 := p2 - (p3 - p1) / 6.0
		if puntos.size() == 2:
			c1 = p1.lerp(p2, 1.0 / 3.0)
			c2 = p1.lerp(p2, 2.0 / 3.0)
		for j in pasos + 1:
			if i > 0 and j == 0:
				continue
			salida.append(p1.bezier_interpolate(c1, c2, p2, float(j) / pasos))
	return salida
