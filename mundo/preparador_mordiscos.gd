class_name PreparadorMordiscos
extends Node
## Un presupuesto compartido por expedición, no uno por recurso/hormiga.
## La máscara queda privada hasta completar raster, árbol y aire exterior.
signal cola_vacia

const PRESUPUESTO_USEC := 1000
const UNIDADES_POR_CUADRO := 128
const PRESUPUESTO_CIERRE_USEC := 4000
const UNIDADES_CIERRE := 512
var _run: WeakRef
var _trabajos: Dictionary = {}
var _cola: Array[int] = []
var _cursor := 0
var _cancelado := false
var _cerrando := false
var unidades_ultimo_cuadro := 0
var max_unidades_cuadro := 0
var max_unidad_usec := 0
var max_servicio_usec := 0
var max_publicacion_usec := 0
var terminadas := 0


func iniciar(run: Node) -> void:
	_run = weakref(run)
	set_process(false)


func solicitar(propietario: Node, rect: Rect2, grilla: Vector2i, formas: Array, vidas: PackedFloat64Array) -> bool:
	if _cancelado or not is_instance_valid(propietario) or not propietario.has_method("_recibir_mordiscos"):
		return false
	if not rect.has_area() or not rect.position.is_finite() or not rect.size.is_finite() or grilla.x <= 0 or grilla.y <= 0 or grilla.x * grilla.y > MordiscosMaterial.MAX_CELDAS:
		return false
	var id := propietario.get_instance_id()
	if _trabajos.has(id):
		return false
	var mascara := MordiscosMaterial.new()
	mascara.iniciar_configuracion(rect, grilla, formas, vidas)
	_trabajos[id] = {"propietario": weakref(propietario), "mascara": mascara}
	_cola.append(id)
	set_process(true)
	return true


func pendiente(propietario: Node) -> bool:
	return is_instance_valid(propietario) and _trabajos.has(propietario.get_instance_id())


func tiene_pendientes() -> bool:
	return not _trabajos.is_empty()


func cantidad_pendientes() -> int:
	return _trabajos.size()


func iniciar_cierre() -> void:
	_cerrando = true
	if tiene_pendientes():
		set_process(true)


## Filtro único al cerrar: no esperar precalentados sin trabajo ya emitido.
func conservar_propietarios(ids: Array) -> void:
	var conservar: Dictionary = {}
	for id in ids:
		conservar[id] = true
	for id in _trabajos.keys():
		if conservar.has(id):
			continue
		var trabajo: Dictionary = _trabajos[id]
		trabajo.mascara.cancelar_configuracion()
		var propietario = trabajo.propietario.get_ref()
		if is_instance_valid(propietario) and propietario.has_method("_cancelar_preparacion"):
			propietario.call("_cancelar_preparacion")
		_trabajos.erase(id)
	_cola.assign(_trabajos.keys())
	_cursor = 0
	set_process(tiene_pendientes())


func cancelar() -> void:
	_cancelado = true
	for trabajo: Dictionary in _trabajos.values():
		trabajo.mascara.cancelar_configuracion()
	_trabajos.clear()
	_cola.clear()
	_cursor = 0
	set_process(false)


func _process(_delta: float) -> void:
	procesar()


func procesar(presupuesto_usec := -1, max_unidades := -1) -> void:
	unidades_ultimo_cuadro = 0
	if _cancelado:
		return
	var run = _run.get_ref() if _run != null else null
	if not is_instance_valid(run) or run.get("terminada") == true:
		cancelar()
		return
	if is_inside_tree() and get_tree().paused:
		return
	var presupuesto := presupuesto_usec if presupuesto_usec >= 0 else (PRESUPUESTO_CIERRE_USEC if _cerrando else PRESUPUESTO_USEC)
	var limite := max_unidades if max_unidades >= 0 else (UNIDADES_CIERRE if _cerrando else UNIDADES_POR_CUADRO)
	var inicio := Time.get_ticks_usec()
	var habia_trabajo := tiene_pendientes()
	while _cursor < _cola.size() and unidades_ultimo_cuadro < limite:
		if unidades_ultimo_cuadro > 0 and Time.get_ticks_usec() - inicio >= presupuesto:
			break
		var id := _cola[_cursor]
		_cursor += 1
		unidades_ultimo_cuadro += 1
		if not _trabajos.has(id):
			continue
		var trabajo: Dictionary = _trabajos[id]
		var propietario = trabajo.propietario.get_ref()
		var mascara: MordiscosMaterial = trabajo.mascara
		if not is_instance_valid(propietario) or propietario.is_queued_for_deletion():
			mascara.cancelar_configuracion()
			_trabajos.erase(id)
			continue
		var antes := Time.get_ticks_usec()
		var lista := mascara.avanzar_configuracion()
		max_unidad_usec = maxi(max_unidad_usec, Time.get_ticks_usec() - antes)
		if lista:
			# Publicar de forma atómica dentro del mismo presupuesto medido.
			# La subida nativa de textura es acotada, pero no promete un hard1ms.
			_trabajos.erase(id)
			antes = Time.get_ticks_usec()
			propietario.call("_recibir_mordiscos", mascara)
			max_publicacion_usec = maxi(max_publicacion_usec, Time.get_ticks_usec() - antes)
			terminadas += 1
		else:
			_cola.append(id)
	max_unidades_cuadro = maxi(max_unidades_cuadro, unidades_ultimo_cuadro)
	max_servicio_usec = maxi(max_servicio_usec, Time.get_ticks_usec() - inicio)
	if _cursor >= _cola.size():
		_cola.clear()
		_cursor = 0
	elif _cursor > 256 and _cursor * 2 > _cola.size():
		_cola = _cola.slice(_cursor)
		_cursor = 0
	if not tiene_pendientes():
		set_process(false)
		if habia_trabajo:
			cola_vacia.emit()


func _exit_tree() -> void:
	cancelar()
