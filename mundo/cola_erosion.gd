class_name ColaErosion
extends Node
## Trabajo ambiental compartido: una porción física por turno, nunca un pago
## por crédito. Sólo recorre recursos activos; no añade trabajo por hormiga.
signal drenada

const PRESUPUESTO_USEC := 1000
const PASOS_POR_CUADRO := 32
const PRESUPUESTO_CIERRE_USEC := 4000
const PASOS_CIERRE := 128
var run: Run
var _fuentes: Dictionary = {}
var _trabajos: Dictionary = {}
var _latentes: Dictionary = {}
var _cola: Array[int] = []
var _cursor := 0
var _admite := true
var _cerrando := false
var _aviso_pendiente := false
var _reloj := 0.0
var operaciones_ultimo_cuadro := 0
var max_operaciones_cuadro := 0
var max_operacion_usec := 0
var trabajo_emitido := 0.0
var trabajo_admitido := 0.0
var ingresos_reales := 0.0


func iniciar(r: Run) -> void:
	run = r
	set_process(false)


func registrar_fuente(objetivo: Comida) -> void:
	if _admite and is_instance_valid(objetivo):
		_fuentes[objetivo.get_instance_id()] = weakref(objetivo)


func olvidar_fuente(objetivo: Comida) -> void:
	if is_instance_valid(objetivo):
		_fuentes.erase(objetivo.get_instance_id())


func encolar(objetivo: Comida, dano: float, origen: Vector2) -> bool:
	if not _admite or not is_instance_valid(run) or run.terminada or not is_instance_valid(objetivo) or objetivo.muerta or dano <= 0 or not is_finite(dano) or not origen.is_finite():
		return false
	var trabajo := minf(dano * objetivo.factor_erosion(), objetivo.vida)
	if trabajo <= 0 or not is_finite(trabajo):
		return false
	var id := objetivo.get_instance_id()
	despertar(objetivo)
	if not _trabajos.has(id):
		_trabajos[id] = {"objetivo": weakref(objetivo), "tramos": [], "bloqueados": [], "cursor": 0, "visual": 0.0, "ultimo_visual": _reloj, "pos": objetivo.global_position}
		_cola.append(id)
	var tarea: Dictionary = _trabajos[id]
	var tramos: Array = tarea.tramos
	if tramos.size() > int(tarea.cursor) and tramos.back().origen == origen:
		tramos.back().dano += trabajo
	else:
		tramos.append({"dano": trabajo, "origen": origen})
	trabajo_emitido += trabajo
	set_process(true)
	return true


## Sólo una mutación real de geometría o un tick nuevo despiertan un frente
## antes inaccesible. Nunca insistir cada cuadro sobre crédito subpíxel/aire.
func despertar(objetivo: Comida) -> void:
	if not is_instance_valid(objetivo):
		return
	var id := objetivo.get_instance_id()
	if _latentes.has(id) and not _trabajos.has(id):
		_trabajos[id] = _latentes[id]
		_latentes.erase(id)
		_cola.append(id)
		set_process(true)
	elif _trabajos.has(id):
		var tarea: Dictionary = _trabajos[id]
		# Otro frente recién abierto puede habilitar un origen aparcado. No se
		# reintenta por cuadro: sólo ante una mutación real o una emisión nueva.
		if not tarea.bloqueados.is_empty():
			tarea.tramos.append_array(tarea.bloqueados)
			tarea.bloqueados.clear()


func tiene_pendientes() -> bool:
	return not _trabajos.is_empty()


func cantidad_pendientes() -> int:
	return _trabajos.size()


func propietarios_pendientes() -> Array:
	return _trabajos.keys()


func cerrar_emision() -> void:
	if not _admite:
		return
	# La admisión sigue abierta sólo para la fracción de segundo ya ganada.
	for referencia: WeakRef in _fuentes.values():
		var objetivo = referencia.get_ref()
		if is_instance_valid(objetivo) and not objetivo.muerta:
			objetivo.cerrar_emision_veneno()
	_fuentes.clear()
	_admite = false


func iniciar_cierre() -> void:
	_cerrando = true
	set_process(true)


func cancelar() -> void:
	# Destruir una run nunca convierte crédito pendiente en recursos.
	_admite = false
	_fuentes.clear()
	_trabajos.clear()
	_latentes.clear()
	_cola.clear()
	_cursor = 0
	set_process(false)


func _process(delta: float) -> void:
	_reloj += delta
	procesar()


func procesar(presupuesto_usec := -1, max_pasos := -1) -> void:
	operaciones_ultimo_cuadro = 0
	if not is_instance_valid(run) or run.terminada or (not run.activa and not run.cerrando_erosion):
		cancelar()
		return
	var presupuesto := presupuesto_usec if presupuesto_usec >= 0 else (PRESUPUESTO_CIERRE_USEC if _cerrando else PRESUPUESTO_USEC)
	var limite := max_pasos if max_pasos >= 0 else (PASOS_CIERRE if _cerrando else PASOS_POR_CUADRO)
	var inicio := Time.get_ticks_usec()
	while _cursor < _cola.size() and operaciones_ultimo_cuadro < limite:
		if operaciones_ultimo_cuadro > 0 and Time.get_ticks_usec() - inicio >= presupuesto:
			break
		var id := _cola[_cursor]
		_cursor += 1
		operaciones_ultimo_cuadro += 1
		if not _trabajos.has(id):
			continue
		var tarea: Dictionary = _trabajos[id]
		var objetivo = tarea.objetivo.get_ref()
		if not is_instance_valid(objetivo) or objetivo.muerta:
			_finalizar_tarea(id, tarea)
			_fuentes.erase(id)
			continue
		var tramos: Array = tarea.tramos
		var tramo: Dictionary = tramos[int(tarea.cursor)]
		var antes := Time.get_ticks_usec()
		var migas: float = objetivo.erosion_paso(tramo.dano, tramo.origen)
		max_operacion_usec = maxi(max_operacion_usec, Time.get_ticks_usec() - antes)
		if objetivo.material_preparandose():
			# La preparación no es un frente inaccesible ni admite daño/crédito.
			# Conservar el tramo; la publicación atómica lo vuelve ejecutable.
			_cola.append(id)
			continue
		var admitido := clampf(objetivo.trabajo_erosion_admitido, 0, tramo.dano)
		tramo.dano = maxf(0, tramo.dano - admitido)
		trabajo_admitido += admitido
		tarea.visual += migas
		ingresos_reales += migas
		if migas > 0:
			var categoria := 2 if objetivo is PiezaCasa and objetivo.nivel_requerido >= 3 else (1 if objetivo is PiezaCasa else 0)
			run.registrar_ingreso(migas, categoria)
		if objetivo.muerta:
			_finalizar_tarea(id, tarea)
			_fuentes.erase(id)
			continue
		if tramo.dano <= 0 and not objetivo.erosion_continua:
			objetivo.terminar_tramo_erosion()
			tarea.cursor += 1
		elif admitido == 0 and migas == 0 and not objetivo.erosion_continua:
			# Aparcar este origen, no el recurso entero: otro origen del mismo
			# veneno puede tener contacto aunque éste siga tapado por un piso.
			objetivo.terminar_tramo_erosion()
			tarea.bloqueados.append(tramo)
			tarea.cursor += 1
		if int(tarea.cursor) >= tramos.size():
			if tarea.bloqueados.is_empty():
				_finalizar_tarea(id, tarea)
			else:
				# Conservar el trabajo no accesible sin insistir ni bloquear la UI.
				tarea.tramos = tarea.bloqueados
				tarea.bloqueados = []
				tarea.cursor = 0
				_latentes[id] = tarea
				_trabajos.erase(id)
				_mostrar_ingreso(tarea)
		else:
			if int(tarea.cursor) >= 32 and int(tarea.cursor) * 2 >= tramos.size():
				tarea.tramos = tramos.slice(int(tarea.cursor))
				tarea.cursor = 0
			if _reloj - float(tarea.ultimo_visual) >= 0.2:
				_mostrar_ingreso(tarea)
			_cola.append(id)
	max_operaciones_cuadro = maxi(max_operaciones_cuadro, operaciones_ultimo_cuadro)
	if _cursor >= _cola.size():
		_cola.clear()
		_cursor = 0
	elif _cursor > 256 and _cursor * 2 > _cola.size():
		_cola = _cola.slice(_cursor)
		_cursor = 0
	if _trabajos.is_empty():
		set_process(false)
		if _cerrando and not _aviso_pendiente:
			_aviso_pendiente = true
			_avisar_drenada.call_deferred()


func _finalizar_tarea(id: int, tarea: Dictionary) -> void:
	_mostrar_ingreso(tarea)
	_trabajos.erase(id)
	_latentes.erase(id)


func _mostrar_ingreso(tarea: Dictionary) -> void:
	if float(tarea.visual) > 0 and is_instance_valid(run) and not run.terminada:
		run.efectos.numero(tarea.pos, tarea.visual, Color("b7d68b"), 0.7)
	tarea.visual = 0.0
	tarea.ultimo_visual = _reloj


func _avisar_drenada() -> void:
	_aviso_pendiente = false
	if _cerrando and _trabajos.is_empty() and is_instance_valid(run) and not run.terminada:
		drenada.emit()
