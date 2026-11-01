class_name ProyectosCampana
extends RefCounted
## Catálogo inmutable de proyectos físicos. Se lee una vez y no consulta la
## partida: los planos conservan sus marcas aunque cambie el progreso.
const RUTA := "res://datos/proyectos.csv"
const ENCABEZADO := "id,destino,nombre,detalle,premio,objetos,vida_relativa,entrada,alijo"
static var _cargado := false
static var _todos: Array[Dictionary] = []
static var _por_id: Dictionary = {}
static var _por_destino: Dictionary = {}
static var _objetivos: Dictionary = {}


static func todos() -> Array[Dictionary]:
	_cargar()
	return _todos.duplicate(true)


static func del_destino(destino: String) -> Array[Dictionary]:
	_cargar()
	var resultado: Array[Dictionary] = []
	resultado.assign(_por_destino.get(destino, []))
	return resultado.duplicate(true)


static func por_id(id: String) -> Dictionary:
	_cargar()
	return _por_id.get(id, {}).duplicate(true)


static func objetivo(id_global: String) -> Dictionary:
	_cargar()
	return _objetivos.get(id_global, {}).duplicate(true)


static func objetivos_destino(destino: String) -> Array[Dictionary]:
	_cargar()
	var resultado: Array[Dictionary] = []
	for proyecto: Dictionary in _por_destino.get(destino, []):
		resultado.append_array(proyecto.objetivos)
	return resultado.duplicate(true)


static func marcar_plano(plano: Dictionary, destino: String) -> void:
	_cargar()
	for proyecto: Dictionary in _por_destino.get(destino, []):
		var proporcion: float = float(proyecto.vida_relativa) / float(proyecto.objetivos.size())
		for objetivo_datos: Dictionary in proyecto.objetivos:
			var encontrados := 0
			for i in plano.muebles.size():
				var mueble: Dictionary = plano.muebles[i]
				# Los arcos elípticos usan trigonometría. Un milésimo en el CSV
				# no cambia el alias persistente ni exige redondear el plano.
				if mueble.tipo != objetivo_datos.tipo or mueble.rect.position.distance_squared_to(objetivo_datos.pos) > 0.01:
					continue
				assert("mueble:%d" % i != plano.meta, "Un proyecto no reemplaza la meta canónica: " + objetivo_datos.id)
				assert(not mueble.has("objetivo_proyecto"), "Un mueble pertenece a dos proyectos: " + objetivo_datos.id)
				mueble.proyecto_id = proyecto.id
				mueble.objetivo_proyecto = objetivo_datos.id
				mueble.proyecto_vida = proporcion
				encontrados += 1
			assert(encontrados == 1, "El objetivo debe corresponder a un único mueble existente: " + objetivo_datos.id)


static func _cargar() -> void:
	if _cargado:
		return
	_cargado = true
	var archivo := FileAccess.open(RUTA, FileAccess.READ)
	assert(archivo != null, "Falta el catálogo de proyectos")
	if archivo == null:
		return
	var encabezado := archivo.get_csv_line()
	assert(",".join(encabezado) == ENCABEZADO, "Encabezado de proyectos inválido")
	while not archivo.eof_reached():
		var fila := archivo.get_csv_line()
		if fila.size() == 1 and fila[0].strip_edges().is_empty():
			continue
		assert(fila.size() == 9, "Fila de proyecto incompleta")
		if fila.size() != 9:
			continue
		var id := fila[0].strip_edges()
		var destino := fila[1].strip_edges()
		assert(not id.is_empty() and not _por_id.has(id), "ID de proyecto vacío o repetido")
		var objetivos: Array[Dictionary] = []
		for especificacion in fila[5].split("|", false):
			var partes := especificacion.split("@", false)
			assert(partes.size() == 2, "Un objetivo necesita alias@tipo:x:y")
			if partes.size() != 2:
				continue
			var campos := partes[1].split(":", false)
			assert(campos.size() == 3, "Un objetivo necesita tipo:x:y")
			if campos.size() != 3:
				continue
			var id_objetivo := id + "/" + partes[0]
			assert(not _objetivos.has(id_objetivo), "Alias de objetivo repetido: " + id_objetivo)
			var datos := {"id": id_objetivo, "proyecto": id, "destino": destino,
				"tipo": campos[0], "pos": Vector2(float(campos[1]), float(campos[2]))}
			objetivos.append(datos)
			_objetivos[id_objetivo] = datos
		assert(not objetivos.is_empty() and objetivos.size() <= 3, "Cada proyecto necesita entre uno y tres objetos")
		var proyecto := {"id": id, "destino": destino, "nombre": fila[2], "detalle": fila[3], "premio": fila[4],
			"objetivos": objetivos, "vida_relativa": float(fila[6]), "entrada": int(fila[7]), "alijo": fila[8]}
		assert(proyecto.vida_relativa > 0 and proyecto.entrada in [0, 1], "Premio o resistencia de proyecto inválido")
		_todos.append(proyecto)
		_por_id[id] = proyecto
		if not _por_destino.has(destino):
			var destino_proyectos: Array[Dictionary] = []
			_por_destino[destino] = destino_proyectos
		_por_destino[destino].append(proyecto)
