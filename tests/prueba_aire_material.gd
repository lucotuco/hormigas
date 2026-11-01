extends Node
## Las podas por bloque deben conservar el flood independiente píxel a píxel.
## No mide FPS ni altera una partida real.
const REFERENCIA := preload("res://tests/prueba_material_visible.gd")


## Borrado anterior retenido como referencia; selección, DDA y flood comunes.
class PixelAPixel extends MordiscosMaterial:
	func _borrar_rectangulo(celda: int, rect: Rect2i, semilla := Vector2i(-1, -1)) -> void:
		var frentes: Array[int] = []
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if _pixeles[y * _ancho + x] != 0:
					if semilla.x < 0 and _frontera_exterior(x, y):
						frentes.append(y * _ancho + x)
					_borrar_pixel(celda, x, y)
		_aplicar_bloques()
		_actualizar_limites(celda)
		if semilla.x >= 0:
			_marcar_aire(semilla.x, semilla.y)
		else:
			for indice in frentes:
				_marcar_aire(indice % _ancho, indice / _ancho as int)
		_propagar_aire()


var total := 0
var fallas := 0
var _referencia := REFERENCIA.new()


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	var casos := [
		{"nombre": "sólido", "rect": Rect2(0, 0, 128, 128), "formas": [Rect2(0, 0, 128, 128)]},
		{"nombre": "vacío", "rect": Rect2(0, 0, 128, 128), "formas": []},
		{"nombre": "isla entre bloques vacíos", "rect": Rect2(0, 0, 256, 256), "formas": [Rect2(112, 112, 32, 32)]},
		{"nombre": "cavidad cerrada", "rect": Rect2(0, 0, 128, 128), "formas": [Rect2(16, 16, 96, 16), Rect2(16, 96, 96, 16), Rect2(16, 32, 16, 64), Rect2(96, 32, 16, 64)]},
		{"nombre": "cavidad abierta", "rect": Rect2(0, 0, 128, 128), "formas": [Rect2(16, 16, 96, 16), Rect2(16, 96, 96, 16), Rect2(16, 32, 16, 64)]},
		{"nombre": "bordes de bloque incompleto", "rect": Rect2(-13, 7, 107, 95), "formas": [Rect2(-13, 7, 107, 11), Rect2(-13, 78, 107, 24), Rect2(70, 18, 24, 60)]},
		{"nombre": "celdas y bloques desalineados", "rect": Rect2(-21, -17, 150, 126), "grilla": Vector2i(3, 4), "formas": [Rect2(-21, -17, 150, 126)]},
	]
	for caso: Dictionary in casos:
		probar(caso)
	probar_bit_alto()
	_referencia.free()
	print("Aire exterior por bloques: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func probar(caso: Dictionary) -> void:
	var m := MordiscosMaterial.new()
	var anterior := PixelAPixel.new()
	configurar(m, caso)
	configurar(anterior, caso)
	verificar(coincide(m), caso.nombre + ": aire y frontera iniciales equivalen al flood por píxel")
	var conservado := true
	var equivalente := estados_iguales(m, anterior)
	var tamano: Vector2 = caso.rect.size
	var origen: Vector2 = caso.rect.position
	var lados: Array[Vector2] = [origen + Vector2(-2, tamano.y * 0.5), origen + Vector2(tamano.x + 2, tamano.y * 0.5), origen + Vector2(tamano.x * 0.5, -2), origen + Vector2(tamano.x * 0.5, tamano.y + 2)]
	for i in 24:
		var celda := i % m._cantidad_celdas
		var antes := m.area_total()
		var hp := m.vida_celda(celda)
		var real := m.recortar_local(celda, 1.0e6, lados[i % lados.size()], 6.0)
		var previo := anterior.recortar_local(celda, 1.0e6, lados[i % lados.size()], 6.0)
		conservado = conservado and coincide(m) and is_equal_approx(antes - m.area_total(), m.ultima_porcion.get_area()) and is_equal_approx(hp - m.vida_celda(celda), real)
		equivalente = equivalente and real == previo and estados_iguales(m, anterior)
	verificar(conservado, caso.nombre + ": 24 intentos mantienen conectividad, frontera y masa exactas")
	# La corrosión selecciona rectángulos de hasta16unidades: sí activa el
	# batch32+píxeles y conserva el mismo orden de todos sus recortes locales.
	for i in 24:
		var celda := i % m._cantidad_celdas
		var desde := m.origen_exterior(celda, lados[i % lados.size()])
		var real := m.recortar_frente(celda, 43.5, desde)
		var previo := anterior.recortar_frente(celda, 43.5, desde)
		equivalente = equivalente and real == previo and estados_iguales(m, anterior) and coincide(m)
	verificar(equivalente, caso.nombre + ": batch y borrado anterior conservan buffer, árboles, filas, columnas, límites, crédito y frontera")
	# El bulk administrativo también debe propagar el aire de todos los
	# bloques recién vaciados, sin convertir una cavidad cerrada antes de hora.
	for celda in m._cantidad_celdas:
		m.recortar_bulk(celda, 1.0e6, lados[0])
		anterior.recortar_bulk(celda, 1.0e6, lados[0])
	verificar(coincide(m) and estados_iguales(m, anterior) and m.area_total() == 0, caso.nombre + ": el vaciado completo conserva aire, frontera y agotamiento")


func configurar(m: MordiscosMaterial, caso: Dictionary) -> void:
	var grilla: Vector2i = caso.get("grilla", Vector2i.ONE)
	var formas: Array = []
	var vidas := PackedFloat64Array()
	for y in grilla.y:
		for x in grilla.x:
			var celda := Rect2(caso.rect.position + caso.rect.size * Vector2(x, y) / Vector2(grilla), caso.rect.size / Vector2(grilla))
			var recortes: Array[Rect2] = []
			for forma: Rect2 in caso.formas:
				var parte := forma.intersection(celda)
				if parte.has_area():
					recortes.append(parte)
			formas.append(recortes)
			vidas.append(1000)
	m.configurar(caso.rect, grilla, formas, vidas)


func probar_bit_alto() -> void:
	var caso := {"rect": Rect2(0, 0, 20, 20), "formas": [Rect2(0, 0, 16, 16)]}
	var m := MordiscosMaterial.new()
	var anterior := PixelAPixel.new()
	configurar(m, caso)
	configurar(anterior, caso)
	verificar((m._frontera_bits[0] & (1 << 63)) != 0, "el fixture sólido8×8 incluye el bit63 firmado en su frontera")
	var real := m.recortar_frente(0, 1.0e6, Vector2(18, 18), 16)
	var previo := anterior.recortar_frente(0, 1.0e6, Vector2(18, 18), 16)
	verificar(real == previo and real == 1000 and m.area_total() == 0 and estados_iguales(m, anterior) and coincide(m), "el batch borra64píxeles incluyendo el bit63 sin overflow ni pérdida de conteos")


func estados_iguales(a: MordiscosMaterial, b: MordiscosMaterial) -> bool:
	return a._pixeles == b._pixeles and a._vivos == b._vivos and a._cantidad_vivos == b._cantidad_vivos \
		and a._filas_vivas == b._filas_vivas and a._columnas_vivas == b._columnas_vivas and a._limites_pixels == b._limites_pixels \
		and a._arbol == b._arbol and a._frontera_arbol == b._frontera_arbol and a._frontera_celdas == b._frontera_celdas \
		and a._aire_bits == b._aire_bits and a._aire_bloques == b._aire_bloques and a._frontera_bits == b._frontera_bits \
		and a._credito == b._credito and a.ultima_porcion == b.ultima_porcion


func coincide(m: MordiscosMaterial) -> bool:
	var aire: PackedByteArray = _referencia.aire_exterior(m._pixeles, m.tamano_mascara())
	var ancho := m.tamano_mascara().x
	var alto := m.tamano_mascara().y
	var frontera := 0
	for y in alto:
		for x in ancho:
			var indice := y * ancho + x
			if m._aire_conocido(x, y) != (aire[indice] != 0):
				return false
			var esperada: bool = m._pixeles[indice] != 0 and (x == 0 or y == 0 or x == ancho - 1 or y == alto - 1 or aire[indice - 1] != 0 or aire[indice + 1] != 0 or aire[indice - ancho] != 0 or aire[indice + ancho] != 0)
			var bloque := (y / 8 as int) * m._columnas_bloques + (x / 8 as int)
			var registrada: bool = (m._frontera_bits[bloque] & (1 << ((y % 8) * 8 + x % 8))) != 0
			if registrada != esperada:
				return false
			frontera += int(esperada)
	var frontera_por_celdas := 0
	for cantidad in m._frontera_celdas:
		frontera_por_celdas += cantidad
	return frontera == frontera_por_celdas and frontera == m._frontera_arbol[0]


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", detalle)
