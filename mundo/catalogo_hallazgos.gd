class_name CatalogoHallazgos
extends RefCounted
## Tres encuentros pequeños: reparten un alimento real, no agregan dinero.
## Catálogo inmutable, independiente de la partida y del generador de comida.
const RUTA := "res://datos/hallazgos.csv"
const ENCABEZADO := "id,nombre,comida,forma,color,radio,vida_relativa,valor_relativo,distancia_min,distancia_max,distancia_respaldo"
const PREFIJO_ENVOLTORIO := "hallazgo_"
static var _cargado := false
static var _todos: Array[Dictionary] = []
static var _por_id: Dictionary = {}
static var _por_envoltorio: Dictionary = {}


static func todos() -> Array[Dictionary]:
	_cargar()
	return _todos.duplicate(true)


static func por_id(id: String) -> Dictionary:
	_cargar()
	return _por_id.get(id, {}).duplicate(true)


static func por_envoltorio(id: String) -> Dictionary:
	_cargar()
	return _por_envoltorio.get(id, {}).duplicate(true)


## El balance recibido ya contiene su factor de destino. No lo vuelve a aplicar
## ni redondea el reparto: HP/valor restantes pertenecen al mismo alimento.
## La comida reservada todavía no es un nodo ni paga bonus hasta aparecer.
static func dividir(id: String, original: Dictionary) -> Dictionary:
	var datos := por_id(id)
	if datos.is_empty() or str(original.get("id", "")) != datos.comida:
		return {}
	if typeof(original.get("vida")) not in [TYPE_INT, TYPE_FLOAT] or typeof(original.get("recompensa")) not in [TYPE_INT, TYPE_FLOAT]:
		return {}
	var vida := float(original.vida)
	var valor := float(original.recompensa)
	if not is_finite(vida) or not is_finite(valor) or vida <= 0.0 or valor <= 0.0:
		return {}
	var vida_papel: float = vida * datos.vida_relativa
	var valor_papel: float = valor * datos.valor_relativo
	# Comida.configurar impone HP>=1. Rechazar un reparto incompatible en vez
	# de inflarlo silenciosamente con max(1), quitárselo al contenido o truncar.
	if vida_papel < 1.0 or vida - vida_papel < 1.0 or valor_papel <= 0.0 or valor - valor_papel <= 0.0:
		return {}
	var envoltorio: Dictionary = original.duplicate(true)
	envoltorio.merge({"id": datos.id_envoltorio, "nombre": datos.nombre, "forma": datos.forma,
		"color": datos.color, "radio": datos.radio, "vida": vida_papel, "recompensa": valor_papel}, true)
	var contenido: Dictionary = original.duplicate(true)
	contenido.vida = vida - vida_papel
	contenido.recompensa = valor - valor_papel
	return {"envoltorio": envoltorio, "contenido": contenido}


static func _cargar() -> void:
	if _cargado:
		return
	_cargado = true
	var archivo := FileAccess.open(RUTA, FileAccess.READ)
	assert(archivo != null, "Falta el catálogo de hallazgos")
	if archivo == null:
		return
	var encabezado := archivo.get_csv_line()
	assert(",".join(encabezado) == ENCABEZADO, "Encabezado de hallazgos inválido")
	while not archivo.eof_reached():
		var fila := archivo.get_csv_line()
		if fila.size() == 1 and fila[0].strip_edges().is_empty():
			continue
		assert(fila.size() == 11, "Fila de hallazgo incompleta")
		if fila.size() != 11:
			continue
		var id := fila[0].strip_edges()
		var datos := {"id": id, "id_envoltorio": PREFIJO_ENVOLTORIO + id,
			"nombre": fila[1], "comida": fila[2], "forma": fila[3], "color": Color(fila[4]),
			"radio": float(fila[5]), "vida_relativa": float(fila[6]), "valor_relativo": float(fila[7]),
			"distancia_min": float(fila[8]), "distancia_max": float(fila[9]), "distancia_respaldo": float(fila[10])}
		assert(not id.is_empty() and id.is_valid_identifier() and not _por_id.has(id), "ID de hallazgo vacío o repetido")
		assert(datos.comida != "miga" and datos.radio > 0 and datos.radio <= 24, "El hallazgo no reemplaza migas ni crea un paquete gigante")
		assert(datos.vida_relativa > 0 and datos.vida_relativa < 1 and datos.valor_relativo > 0 and datos.valor_relativo < 1, "El envoltorio y su contenido deben conservar valor positivo")
		assert(datos.distancia_min >= 250 and datos.distancia_max >= datos.distancia_min and datos.distancia_max <= 900, "Los hallazgos no ocupan el primer ingreso ni recursos remotos")
		assert(datos.distancia_respaldo >= datos.distancia_max and datos.distancia_respaldo <= 900, "El respaldo no puede mandar los hallazgos al extremo del mapa")
		_todos.append(datos)
		_por_id[id] = datos
		_por_envoltorio[datos.id_envoltorio] = datos
