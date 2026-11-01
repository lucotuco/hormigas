class_name ComponentesProyecto
extends RefCounted
## Autoría de partes reconocibles sobre la grilla del MISMO mueble.
## No reconstruye porcentajes, no paga recursos y no consulta la partida.
const RUTA := "res://datos/componentes_proyecto.csv"
const ENCABEZADO := "objetivo,tipo,perfil,grilla_x,grilla_y,alias,nombre,celdas,tesoro"
const CASA := {"casa/carton_inicial": "silla", "casa/alacena_cocina": "alacena"}
static var _cargado := false
static var _objetivos: Dictionary = {}
static var _componentes: Dictionary = {}


static func todos() -> Array[Dictionary]:
	_cargar()
	var resultado: Array[Dictionary] = []
	for datos: Dictionary in _objetivos.values():
		resultado.append(datos.duplicate(true))
	return resultado


static func objetivo(id: String) -> Dictionary:
	_cargar()
	return _objetivos.get(id, {}).duplicate(true)


static func componente(id: String) -> Dictionary:
	_cargar()
	return _componentes.get(id, {}).duplicate(true)


static func objetivo_valido(id: String) -> bool:
	_cargar()
	return _objetivos.has(id)


static func componente_valido(id: String) -> bool:
	_cargar()
	return _componentes.has(id)


static func objetivo_del_componente(id: String) -> String:
	_cargar()
	return str(_componentes.get(id, {}).get("objetivo", ""))


static func ids_objetivo(id: String) -> Array[String]:
	_cargar()
	var resultado: Array[String] = []
	for datos: Dictionary in _objetivos.get(id, {}).get("componentes", []):
		resultado.append(datos.id)
	return resultado


static func ids_del_objetivo(id: String) -> Array[String]:
	return ids_objetivo(id)


static func objetivo_tiene_tesoro(id: String) -> bool:
	_cargar()
	return _objetivos.get(id, {}).get("tesoro", false) == true


static func objetivo_terminado(id: String, estado: Dictionary) -> bool:
	var ids := ids_objetivo(id)
	if ids.is_empty():
		return false
	for componente_id in ids:
		if estado.get(componente_id, false) != true:
			return false
	return true


static func normalizar_completos(estado: Dictionary, objetivos_completos: Dictionary) -> Dictionary:
	_cargar()
	var resultado: Dictionary = {}
	for id in estado:
		if id is String and estado[id] is bool and estado[id] and _componentes.has(id):
			resultado[id] = true
	for id in objetivos_completos:
		if id is String and objetivos_completos[id] == true:
			for componente_id in ids_objetivo(id):
				resultado[componente_id] = true
	return resultado


## Casa usa una marca propia: nunca se convierte en un proyecto obligatorio
## ni hereda la resistencia de una meta turística.
static func id_para_pieza(datos: Dictionary, destino: String) -> String:
	if datos.has("objetivo_proyecto"):
		var id: String = datos.objetivo_proyecto
		return id if objetivo_valido(id) else ""
	if destino != "casa":
		return ""
	if datos.get("practica", false):
		return "casa/carton_inicial"
	if datos.tipo == "alacena" and datos.rect.position == Vector2(-850, 800):
		return "casa/alacena_cocina"
	return ""


static func celdas_devoradas(id: String, estado: Dictionary) -> Array[int]:
	_cargar()
	var resultado: Array[int] = []
	for datos: Dictionary in _objetivos.get(id, {}).get("componentes", []):
		if estado.get(datos.id, false) == true:
			resultado.append_array(datos.celdas)
	return resultado


## Se usa una vez al generar navegación. La silueta original permanece
## inmutable y los huecos respetan el material/arte dentro de cada celda.
static func formas_restantes(datos: Dictionary, formas: Array[Rect2], estado: Dictionary) -> Array[Rect2]:
	var id: String = datos.get("componentes_id", "")
	var borradas := celdas_devoradas(id, estado)
	if borradas.is_empty():
		return formas.duplicate()
	var perfil := objetivo(id)
	var grilla: Vector2i = perfil.grilla
	var rect: Rect2 = datos.rect
	var tam := rect.size / Vector2(grilla)
	var resultado: Array[Rect2] = []
	for celda in grilla.x * grilla.y:
		if borradas.has(celda):
			continue
		var zona := Rect2(rect.position + Vector2(celda % grilla.x, celda / grilla.x as int) * tam, tam)
		for forma in formas:
			var parte := forma.intersection(zona)
			if parte.has_area():
				resultado.append(parte)
	return resultado


static func _cargar() -> void:
	if _cargado:
		return
	_cargado = true
	var archivo := FileAccess.open(RUTA, FileAccess.READ)
	assert(archivo != null, "Falta el catálogo de componentes")
	if archivo == null:
		return
	var encabezado := archivo.get_csv_line()
	assert(",".join(encabezado) == ENCABEZADO, "Encabezado de componentes inválido")
	while not archivo.eof_reached():
		var fila := archivo.get_csv_line()
		if fila.size() == 1 and fila[0].strip_edges().is_empty():
			continue
		assert(fila.size() == 9, "Fila de componente incompleta")
		if fila.size() != 9:
			continue
		var id := fila[0].strip_edges()
		var original := ProyectosCampana.objetivo(id)
		var tipo: String = CASA.get(id, original.get("tipo", ""))
		var grilla := Vector2i(int(fila[3]), int(fila[4]))
		assert(not tipo.is_empty() and tipo == fila[1], "Objetivo o tipo de componente inválido: " + id)
		assert(grilla.x > 0 and grilla.y > 0 and grilla.x * grilla.y <= 16, "Los componentes conservan hasta dieciséis celdas")
		if not _objetivos.has(id):
			_objetivos[id] = {"id": id, "destino": "casa" if CASA.has(id) else original.destino,
				"tipo": tipo, "perfil": fila[2], "grilla": grilla, "componentes": [], "tesoro": false}
		var perfil: Dictionary = _objetivos[id]
		assert(perfil.grilla == grilla and perfil.perfil == fila[2], "Un objetivo no mezcla perfiles")
		var alias := fila[5].strip_edges()
		var global_id := id + "#" + alias
		assert(not alias.is_empty() and alias.is_valid_identifier() and not _componentes.has(global_id), "Alias de componente inválido o repetido")
		var celdas: Array[int] = []
		for valor in fila[7].split("|", false):
			var celda := int(valor)
			assert(valor.is_valid_int() and celda >= 0 and celda < grilla.x * grilla.y and not celdas.has(celda), "Celda de componente inválida")
			celdas.append(celda)
		assert(not celdas.is_empty() and fila[8] in ["0", "1"], "Componente vacío o escondite inválido")
		var datos := {"id": global_id, "objetivo": id, "alias": alias, "nombre": fila[6],
			"celdas": celdas, "tesoro": fila[8] == "1"}
		_componentes[global_id] = datos
		perfil.componentes.append(datos)
		perfil.tesoro = perfil.tesoro or datos.tesoro
	for id: String in _objetivos:
		var perfil: Dictionary = _objetivos[id]
		var usadas: Dictionary = {}
		var escondites := 0
		for datos: Dictionary in perfil.componentes:
			escondites += int(datos.tesoro)
			for celda: int in datos.celdas:
				assert(not usadas.has(celda), "Dos componentes no comparten material: " + id)
				usadas[celda] = true
		assert(usadas.size() == perfil.grilla.x * perfil.grilla.y, "Todo el mueble debe pertenecer a un componente")
		assert(perfil.componentes.size() >= 2 and perfil.componentes.size() <= 4, "Cada mueble conserva entre dos y cuatro partes reconocibles")
		assert(escondites <= 1, "Un mueble conserva un único escondite nativo")
