class_name Evento
extends Node2D
## Algo que aparece durante la expedición y se resuelve con clics: una amenaza
## propia de cada destino (araña, mozo, aspiradora, paloma, gato, rata) o una
## miga dorada. Las amenazas tienen contra: pisarlas a tiempo da un botín;
## ignorarlas cuesta hormigas o comida. Ver Eventos para cuándo aparecen.

signal terminado(evento: Evento)

## Por tipo: golpes para vencerlo, radio nativo en unidades del mundo,
## segundos antes de irse solo y velocidad. El zoom no agranda su hitbox.
const DATOS := {
	"arana": {"golpes": 6, "radio": 15.0, "vida": 25.0, "velocidad": 70.0},
	"mozo": {"golpes": 3, "radio": 60.0, "vida": 40.0, "velocidad": 0.0},
	"aspiradora": {"golpes": 6, "radio": 22.0, "vida": 30.0, "velocidad": 55.0},
	"paloma": {"golpes": 1, "radio": 13.0, "vida": 20.0, "velocidad": 230.0},
	"gato": {"golpes": 4, "radio": 22.0, "vida": 40.0, "velocidad": 260.0},
	"rata": {"golpes": 5, "radio": 13.0, "vida": 30.0, "velocidad": 120.0},
	"cucaracha": {"golpes": 3, "radio": 11.0, "vida": 20.0, "velocidad": 95.0},
	"escarabajo": {"golpes": 2, "radio": 12.0, "vida": 22.0, "velocidad": 68.0},
	"dorada": {"golpes": 1, "radio": 11.0, "vida": 9.0, "velocidad": 0.0},
}
const PISADAS_MOZO := 3
const AVISO_MOZO := 2.4
const MAX_ATRAPADAS := 8
const AVISO_ENTRADA := 1.5
const AVISO_ROBO := 1.8
static var _datos_activos: Dictionary = {}


static func datos_tipo(id: String) -> Dictionary:
	if DATOS.has(id):
		return DATOS[id]
	if _datos_activos.is_empty():
		var archivo := FileAccess.open("res://datos/amenazas_activas.csv", FileAccess.READ)
		if archivo == null:
			push_error("No se pudo leer datos/amenazas_activas.csv")
			return {}
		archivo.get_csv_line()
		while not archivo.eof_reached():
			var fila := archivo.get_csv_line()
			if fila.size() < 8 or fila[0].is_empty():
				continue
			_datos_activos[fila[0]] = {"golpes": maxi(1, fila[1].to_int()), "radio": maxf(1, fila[2].to_float()),
				"vida": maxf(1, fila[3].to_float()), "velocidad": maxf(1, fila[4].to_float()),
				"aviso": maxf(0.8, fila[5].to_float()), "escape": maxf(1, fila[6].to_float()),
				"velocidad_acecho": maxf(1, fila[7].to_float())}
	return _datos_activos.get(id, {})

var tipo := ""
var run: Run
var golpes := 1
var golpes_max := 1
var vida_restante := 10.0
var estado := "entrando"
## Migas que lleva encima (lo que robó o aspiró): se recupera al vencerlo.
var botin := 0.0
var atrapadas := 0
var resuelto := false
var premio_cobrado := false
var grupo := 0

var _objetivo := Vector2.ZERO
var _comida: Comida = null
var _reloj := 0.0
var _reloj_accion := 0.0
var _destello := 0.0
var _pisadas := 0
var _molestia := 0.0
var _hogar := Vector2.ZERO
var _fase := 0.0
var _aviso_restante := 0.0
var _reloj_dibujo := 0.0
var _puesto_robo := Vector2.INF
var _datos: Dictionary = {}
var _presa: Hormiga
var _pausa_golpe := 0.0
var _reloj_busqueda := 0.0
var _reloj_sensores := 0.0
var _cercanas_gato := 0
var consultas_objetivos := 0
var _escape_restante := -1.0


func iniciar(r: Run, tipo_evento: String, posicion_inicial: Vector2) -> void:
	run = r
	tipo = tipo_evento
	var datos := datos_tipo(tipo)
	_datos = datos
	golpes = int(datos.golpes)
	golpes_max = golpes
	vida_restante = float(datos.vida)
	position = posicion_inicial
	z_index = 6
	_aviso_restante = AVISO_ENTRADA if tipo not in ["dorada", "mozo", "gato"] else 0.0
	match tipo:
		"mozo":
			estado = "eligiendo"
			_reloj_accion = 0.6
		"gato":
			_comida = _comida_mas_valiosa()
			_hogar = _comida.position if _comida else position
			position = _hogar
			estado = "dormido"
		"dorada":
			estado = "quieta"
		"paloma":
			_comida = _comida_valiosa_al_azar()
			estado = "entrando"
		"rata":
			_comida = _comida_mas_valiosa()
			estado = "entrando"
		"cucaracha", "escarabajo", "rival":
			_comida = _buscar_para_robar()
			estado = "entrando"
		"avispa":
			estado = "acechando"
		_:
			estado = "entrando"


func escala() -> float:
	return 1.0 # Tamaño nativo; alejar la cámara no agranda enemigos ni hitboxes.


func radio() -> float:
	# También se dibujan muestras nativas sin Run en las revisiones visuales.
	var datos := _datos if not _datos.is_empty() else datos_tipo(tipo)
	return float(datos.radio) * (escala() if tipo != "mozo" else sqrt(escala()))


func es_amenaza() -> bool:
	return tipo != "dorada"


## ¿Un clic en `pos` le pega? El mozo sólo se puede frenar mientras avisa.
func contiene(pos: Vector2) -> bool:
	if resuelto or not is_instance_valid(run) or not run.activa:
		return false
	if tipo == "mozo":
		return estado == "avisando" and pos.distance_to(_objetivo) <= radio()
	return pos.distance_to(position) <= radio() * 1.35


## Un clic encima. Devuelve true si lo venció.
func golpear() -> bool:
	if resuelto or not is_instance_valid(run) or not run.activa:
		return false
	golpes -= 1
	_destello = 0.12
	_pausa_golpe = Eventos.parametro("pausa_golpe")
	queue_redraw()
	run.efectos.amenaza(_centro(), "repelido", radio() * 1.8, Vector2.from_angle(rotation))
	if golpes > 0:
		Sonido.tocar("impacto", 1.0 + (golpes_max - golpes) * 0.03, 0.025)
	if golpes <= 0:
		_vencer()
		return true
	return false


func _centro() -> Vector2:
	return _objetivo if tipo == "mozo" else position


# =====================================================================
# Comportamiento
# =====================================================================

func _process(delta: float) -> void:
	if resuelto or not is_instance_valid(run):
		if not resuelto:
			_terminar()
		return
	_fase += delta
	_destello = maxf(0.0, _destello - delta)
	if not run.activa:
		_terminar()
		return
	vida_restante -= delta
	if _pausa_golpe > 0:
		_pausa_golpe = maxf(0, _pausa_golpe - delta)
		_refrescar_dibujo(delta)
		return
	if _aviso_restante > 0.0:
		_aviso_restante = maxf(0.0, _aviso_restante - delta)
		_refrescar_dibujo(delta)
		return
	_reloj += delta
	match tipo:
		"arana": _arana(delta)
		"mozo": _mozo(delta)
		"aspiradora": _aspiradora(delta)
		"paloma": _paloma(delta)
		"gato": _gato(delta)
		"rata": _rata(delta)
		"cucaracha", "escarabajo", "rival": _recolector(delta)
		"avispa": _avispa(delta)
		"dorada":
			if vida_restante <= 0.0:
				_terminar()
	_refrescar_dibujo(delta)


func _refrescar_dibujo(delta: float) -> void:
	_reloj_dibujo += delta
	if _reloj_dibujo >= 1.0 / 24.0:
		_reloj_dibujo = 0.0
		queue_redraw()


func _arana(delta: float) -> void:
	if estado == "huyendo" or vida_restante <= 0.0 or atrapadas >= MAX_ATRAPADAS:
		_huir(delta)
		return
	_reloj_accion -= delta
	if _reloj_accion <= 0.0:
		_reloj_accion = 0.5
		var presa := _hormiga_cercana(position, 900.0)
		_objetivo = presa.position if presa else Vector2.ZERO
	_mover_hacia(_objetivo, float(DATOS.arana.velocidad), delta)
	_reloj_sensores = maxf(0, _reloj_sensores - delta)
	if _reloj >= 1.4 and _reloj_sensores <= 0:
		_reloj_sensores = Eventos.parametro("consulta_contacto")
		var cerca := run.colonia.hormigas_cerca(position, radio() * 0.9, 1)
		if not cerca.is_empty():
			_reloj = 0.0
			_atrapar(cerca)


func _mozo(delta: float) -> void:
	_reloj_accion -= delta
	match estado:
		"eligiendo":
			if _reloj_accion <= 0.0:
				if _pisadas >= PISADAS_MOZO or vida_restante <= 0.0:
					_terminar()
					return
				var presa := _hormiga_al_azar(140.0)
				_objetivo = presa.position if presa else (position + Vector2.from_angle(randf() * TAU) * 160.0).limit_length(run.radio_actual * 0.85)
				position = _objetivo
				estado = "avisando"
				golpes = golpes_max
				_reloj_accion = AVISO_MOZO
				run.efectos.amenaza(_objetivo, "aviso", radio(), Vector2.ZERO, AVISO_MOZO)
				Sonido.tocar("tic", 0.6, 0.0)
		"avisando":
			if _reloj_accion <= 0.0:
				_pisadas += 1
				estado = "pisando"
				_reloj_accion = 0.4
				var aplastadas := run.colonia.hormigas_cerca(_objetivo, radio(), 6)
				_atrapar(aplastadas)
				run.camara.sacudir(9.0)
				Sonido.tocar("romper", 0.6, 0.0)
				# Al pisar, se le cae una porción de la bandeja.
				run.comidas.soltar_comida(_comida_del_destino(), _objetivo)
		"pisando":
			if _reloj_accion <= 0.0:
				estado = "eligiendo"
				_reloj_accion = 3.5


func _aspiradora(delta: float) -> void:
	if vida_restante <= 0.0 or estado == "huyendo":
		_huir(delta)
		return
	if position.distance_to(_objetivo) < 12.0 or _reloj_accion <= 0.0:
		var presa := _hormiga_al_azar(80.0)
		_objetivo = presa.position if presa else (position + Vector2.from_angle(randf() * TAU) * 200.0).limit_length(run.radio_actual * 0.85)
		_reloj_accion = 4.0
	_reloj_accion -= delta
	_mover_hacia(_objetivo, float(DATOS.aspiradora.velocidad), delta)
	if _reloj >= 0.25:
		_reloj = 0.0
		for c in run.comidas._candidatas(position, radio()):
			if c is PiezaCasa or c is FragmentoCasa or c.radio > 20.0 or c.muerta:
				continue
			if c.position.distance_to(position) <= radio() + c.radio:
				botin += c.retirar_por_amenaza()
		var tragadas := run.colonia.hormigas_cerca(position, radio() * 0.8, 1)
		_atrapar(tragadas)


func _paloma(delta: float) -> void:
	if estado == "huyendo" or vida_restante <= 0.0:
		_huir(delta)
		return
	if not is_instance_valid(_comida) or _comida.muerta:
		_comida = _comida_valiosa_al_azar()
		if _comida == null:
			estado = "huyendo"
			return
		estado = "entrando"
	if estado == "entrando":
		_comida.preparar_material()
		if _mover_hacia(_comida.position + Vector2(-_comida.radio, 0), float(DATOS.paloma.velocidad), delta):
			estado = "comiendo"
	elif estado == "comiendo":
		if not _comida.preparar_material():
			return
		_reloj_accion -= delta
		if _reloj_accion <= 0.0:
			_reloj_accion = 0.6
			var origen := _comida.global_position + Vector2.from_angle(_comida.rotation) * _comida.radio
			botin += _comida.morder_por_amenaza(_comida.vida_max * 0.05, origen, 0.0)


func _gato(delta: float) -> void:
	if vida_restante <= 0.0 or estado == "huyendo":
		_huir(delta)
		return
	match estado:
		"dormido":
			_reloj_sensores -= delta
			if _reloj_sensores <= 0:
				_reloj_sensores = Eventos.parametro("consulta_objetivo")
				_cercanas_gato = run.colonia.hormigas_cerca(position, radio() * 3.2, 4).size()
			_molestia = maxf(0.0, _molestia + (delta if _cercanas_gato >= 4 else -delta * 0.5))
			if _molestia >= 2.5:
				_molestia = 0.0
				var presa := _hormiga_cercana(position, radio() * 10.0)
				if presa:
					_objetivo = presa.position
					estado = "agazapado"
					_reloj_accion = 1.0
					run.efectos.amenaza(_objetivo, "aviso", radio() * 1.6, Vector2.ZERO, 1.0)
					Sonido.tocar("aviso", 0.8, 0.0)
		"agazapado":
			_reloj_accion -= delta
			if _reloj_accion <= 0.0:
				estado = "saltando"
		"saltando":
			if _mover_hacia(_objetivo, float(DATOS.gato.velocidad), delta):
				_atrapar(run.colonia.hormigas_cerca(position, radio() * 1.6, 6))
				run.camara.sacudir(5.0)
				estado = "volviendo"
		"volviendo":
			if _mover_hacia(_hogar, 90.0, delta):
				estado = "dormido"


func _rata(delta: float) -> void:
	if vida_restante <= 0.0 or estado == "huyendo":
		_huir(delta, 95.0)
		return
	if estado == "entrando":
		if not is_instance_valid(_comida) or _comida.muerta:
			_comida = _comida_mas_valiosa()
			if _comida == null:
				estado = "huyendo"
				return
		if _mover_hacia(_comida.position, float(DATOS.rata.velocidad), delta):
			# Se la lleva entera: lo que valía queda en el botín.
			botin += _comida.retirar_por_amenaza()
			_comida = null
			estado = "huyendo"


## Dos gestos distintos del depredador: la cucaracha arranca una porción
## pequeña; el escarabajo carga un montón ya extraído. Ambos se detienen y
## muestran el aro antes de robar, y jamás se llevan hormigas.
func _recolector(delta: float) -> void:
	if estado == "huyendo" or vida_restante <= 0.0:
		_huir(delta, 100.0)
		return
	if not is_instance_valid(_comida) or _comida.muerta:
		_comida = _buscar_para_robar()
		_puesto_robo = Vector2.INF
		if _comida == null:
			estado = "huyendo"
			return
		estado = "entrando"
	if estado == "entrando":
		if _comida is FragmentoCasa:
			_puesto_robo = _comida.position + Vector2(-_comida.radio - 2.0, 0.0)
		elif not _comida.preparar_material():
			return # No convertir una máscara pendiente en robo o falta de comida.
		elif _puesto_robo == Vector2.INF:
			# Un cuadrado girado no tiene su borde en position-radio. Reusar
			# el mismo puesto de aire exterior que usa la extracción real.
			_puesto_robo = _comida.punto_mordida(position, run.radio_actual, false)
		if _puesto_robo == Vector2.INF:
			estado = "huyendo"
			return
		if _mover_hacia(_puesto_robo, float(_datos.velocidad), delta):
			estado = "cargando"
			_reloj_accion = float(_datos.get("aviso", AVISO_ROBO))
			run.efectos.amenaza(position, "aviso", radio() * 1.7, Vector2.ZERO, _reloj_accion)
			Sonido.tocar("aviso", 0.9, 0.0)
	elif estado == "cargando":
		_reloj_accion -= delta
		if _reloj_accion > 0.0:
			return
		var tomado := 0.0
		if _comida is FragmentoCasa:
			tomado = _comida.morder(1.0)
		elif _comida.preparar_material():
			# Otra hormiga pudo retirar el frente durante el aviso de carga.
			# Reubicar físicamente, no morder desde adentro ni cobrar a distancia.
			var puesto := _comida.punto_mordida(position, run.radio_actual, false)
			if puesto == Vector2.INF:
				estado = "huyendo"
				return
			if position.distance_squared_to(puesto) > 0.25 or not _comida.mordiscos.aire_exterior(_comida.to_local(position)):
				_puesto_robo = puesto
				estado = "entrando"
				return
			tomado = _comida.morder_por_amenaza(_comida.vida_max, position)
		if tomado > 0.0:
			botin += tomado
			run.efectos.amenaza(position, "impacto", radio() * 1.5, Vector2.from_angle(rotation))
			_comida = null
			_puesto_robo = Vector2.INF
			estado = "huyendo"


func _buscar_para_robar() -> Comida:
	consultas_objetivos += 1
	if tipo in ["escarabajo", "rival"]:
		var cercano: Comida
		var distancia := INF
		for resto in run.comidas.fragmentos:
			if not is_instance_valid(resto) or resto.muerta or not resto.en_territorio(run.radio_actual):
				continue
			var d := position.distance_squared_to(resto.position)
			if d < distancia:
				distancia = d
				cercano = resto
		if cercano != null:
			return cercano
		if tipo == "rival":
			return null # La rival disputa restos físicos, no inventa una carga.
	return _comida_valiosa_al_azar()


## Acecha una carga y fija el lugar al empezar el aviso. La presa puede salir
## naturalmente del círculo; el robo jamás elimina hormigas.
func _avispa(delta: float) -> void:
	if estado == "huyendo" or vida_restante <= 0:
		_huir(delta, float(_datos.escape))
		return
	match estado:
		"acechando":
			_reloj_busqueda -= delta
			if _reloj_busqueda > 0:
				return
			_reloj_busqueda = Eventos.parametro("consulta_objetivo")
			_presa = _buscar_portadora()
			if _presa == null:
				return
			_objetivo = _punto_acecho(_presa)
			estado = "marcando"
			_reloj_accion = float(_datos.aviso)
			run.efectos.amenaza(_objetivo, "aviso", radio() * 2.1, Vector2.ZERO, _reloj_accion)
		"marcando":
			if not is_instance_valid(_presa) or _presa.carga <= 0:
				estado = "acechando"
				return
			_mover_hacia(_objetivo + Vector2(-65, -25), float(_datos.velocidad_acecho), delta)
			_reloj_accion -= delta
			if _reloj_accion <= 0:
				estado = "picando" # El lugar sigue siendo el mismo que anunció el aro.
		"picando":
			if _mover_hacia(_objetivo, float(_datos.velocidad), delta):
				if is_instance_valid(_presa) and _presa.global_position.distance_squared_to(_objetivo) <= pow(radio() * 2.1, 2):
					var carga := _presa.soltar_carga_para_robo()
					botin += float(carga.get("valor", 0.0))
				run.efectos.amenaza(_objetivo, "impacto", radio() * 1.8, Vector2.from_angle(rotation))
				_presa = null
				estado = "huyendo"


func _buscar_portadora() -> Hormiga:
	consultas_objetivos += 1
	var mejor: Hormiga
	var puntaje_mejor := INF
	for h in run.colonia.hormigas:
		if h.carga <= 0 or h.estado == Hormiga.Estado.QUIETA or h.global_position.length_squared() > run.radio_actual * run.radio_actual:
			continue
		if position.distance_squared_to(h.global_position) > 900.0 * 900.0:
			continue
		var puntaje := position.distance_squared_to(h.global_position) / (3.0 if h.casta == "cargadora" else 1.0)
		if puntaje < puntaje_mejor:
			mejor = h
			puntaje_mejor = puntaje
	return mejor


## Una única predicción al empezar el aviso, usando el recorrido que la
## hormiga ya tenía. No consulta navegación ni sigue corrigiendo el ataque.
func _punto_acecho(presa: Hormiga) -> Vector2:
	var punto := presa.global_position
	if presa.estado in [Hormiga.Estado.MORDIENDO, Hormiga.Estado.QUIETA] or presa._esperando_ruta:
		return punto
	if presa._indice_ruta >= presa._ruta.size():
		return punto
	var indice := presa._indice_ruta
	if punto.distance_squared_to(presa._ruta[indice]) < 0.01 and indice + 1 < presa._ruta.size():
		indice += 1
	var siguiente := presa._ruta[indice]
	var anticipo := maxf(0, presa._velocidad * run.factor_ritmo() * float(_datos.aviso))
	return punto.move_toward(siguiente, anticipo).limit_length(run.radio_actual)


func _huir(delta: float, velocidad := 160.0) -> void:
	estado = "huyendo"
	if _escape_restante < 0:
		_escape_restante = Eventos.parametro("escape_duracion")
	_escape_restante = maxf(0, _escape_restante - delta)
	modulate.a = clampf(_escape_restante / 0.4, 0, 1)
	var salida := position.normalized() * (run.radio_actual + 200.0) if position.length() > 1.0 else Vector2(run.radio_actual + 200.0, 0)
	if _escape_restante <= 0 or _mover_hacia(salida, velocidad, delta) or position.length() > run.radio_actual + 120.0:
		_terminar()


## Mueve hacia `destino`; devuelve true al llegar.
func _mover_hacia(destino: Vector2, velocidad: float, delta: float) -> bool:
	var paso := velocidad * delta
	var falta := destino - position
	if falta.length() <= paso:
		position = destino
		return true
	rotation = lerp_angle(rotation, falta.angle(), minf(1.0, delta * 8.0))
	position += falta.normalized() * paso
	return false


func _atrapar(hormigas: Array[Hormiga]) -> void:
	if not is_instance_valid(run) or not run.activa or _aviso_restante > 0.0:
		return
	for h in hormigas:
		if atrapadas >= MAX_ATRAPADAS or run.colonia.cantidad() <= 1:
			break # Una amenaza no borra sin remedio a la última trabajadora.
		if not is_instance_valid(h):
			continue
		var pos := h.position
		if run.colonia.perder(h):
			atrapadas += 1
			run.efectos.chispas(pos, Color("c94f3d"), 4)


# =====================================================================
# Final
# =====================================================================

func _vencer() -> void:
	if resuelto or not is_instance_valid(run) or not run.activa:
		return
	resuelto = true
	var eventos: Eventos = get_parent()
	var premio := eventos.premiar(self)
	run.efectos.epico(_centro(), Color("f0d277"), radio() * 2.4)
	Sonido.tocar("espantar", 0.9, 0.03)
	if premio > 0.0:
		run.efectos.numero(_centro() + Vector2(0, -radio()), premio, Color("ffe08a"), 1.6)
		run.hud.migas_voladoras(run.a_pantalla(_centro()), 12)
	terminado.emit(self)
	queue_free()


func _terminar() -> void:
	if resuelto:
		return
	resuelto = true
	_comida = null
	_presa = null
	set_process(false)
	terminado.emit(self)
	queue_free()


# =====================================================================
# Búsquedas (pocas veces por segundo, nunca por hormiga y cuadro)
# =====================================================================

func _hormiga_cercana(desde: Vector2, alcance: float) -> Hormiga:
	var mejor: Hormiga = null
	var mejor_distancia := alcance * alcance
	for h in run.colonia.hormigas:
		var d := h.position.distance_squared_to(desde)
		if d < mejor_distancia:
			mejor = h
			mejor_distancia = d
	return mejor


func _hormiga_al_azar(distancia_minima: float) -> Hormiga:
	var elegida: Hormiga
	var vistas := 0
	for h in run.colonia.hormigas:
		if h.position.length() >= distancia_minima and h.position.distance_squared_to(position) <= 800.0 * 800.0:
			vistas += 1
			if randi_range(1, vistas) == 1:
				elegida = h
	return elegida


func _comida_mas_valiosa(sin_piezas := true) -> Comida:
	var mejor: Comida = null
	var mejor_local := false
	for c in run.comidas.lista:
		if c.muerta or (sin_piezas and (c is PiezaCasa or c is FragmentoCasa)) or not c.en_territorio(run.radio_actual):
			continue
		if c.position.length() < 120.0:
			continue
		var local := c.position.distance_squared_to(position) <= 800.0 * 800.0
		if mejor == null or (local and not mejor_local) or (local == mejor_local and c.recompensa > mejor.recompensa):
			mejor = c
			mejor_local = local
	return mejor


## Una de las comidas más valiosas, al azar: las palomas no se amontonan.
func _comida_valiosa_al_azar() -> Comida:
	var candidatas: Array[Comida] = []
	for c in run.comidas.lista:
		if not c.muerta and not c is PiezaCasa and not c is FragmentoCasa and c.en_territorio(run.radio_actual) and c.position.length() >= 120.0:
			var indice := 0
			while indice < candidatas.size() and candidatas[indice].recompensa > c.recompensa:
				indice += 1
			if indice < 6:
				candidatas.insert(indice, c)
				if candidatas.size() > 6:
					candidatas.pop_back()
	return candidatas.pick_random() if not candidatas.is_empty() else null


func _comida_del_destino() -> String:
	return {"restaurante": "pizza", "museo": "sandwich", "obelisco": "choripan", "coliseo": "pan_romano", "eiffel": "croissant"}.get(Juego.lugar_actual, "galletita")


# =====================================================================
# Dibujo
# =====================================================================

func _draw() -> void:
	var r := radio()
	var luz := 0.5 if _destello > 0.0 else 0.0
	match tipo:
		"arana":
			for lado in [-1, 1]:
				for i in 4:
					var a: float = lado * (0.5 + i * 0.42)
					var paso := sin(_fase * 14.0 + i * 1.7) * 0.15
					var rodilla := Vector2.from_angle(a + paso) * r * 1.1
					var pie := Vector2.from_angle(a * 1.08 + paso) * r * 1.9
					draw_polyline(PackedVector2Array([Vector2.ZERO, rodilla + Vector2(0, -lado * r * 0.25).rotated(a), pie]), Color("2a2220"), maxf(1.2, r * 0.1), true)
			draw_circle(Vector2(-r * 0.55, 0), r * 0.75, Color("3a2d29").lightened(luz))
			draw_circle(Vector2(-r * 0.6, 0), r * 0.32, Color("a3402f"))
			draw_circle(Vector2(r * 0.35, 0), r * 0.48, Color("2e2421").lightened(luz))
			for lado in [-1, 1]:
				draw_circle(Vector2(r * 0.65, lado * r * 0.15), r * 0.08, Color("f0e3c0"))
		"mozo":
			if estado == "avisando":
				var avance := 1.0 - _reloj_accion / AVISO_MOZO
				draw_set_transform(_objetivo - position, 0.4)
				_elipse(Vector2.ZERO, Vector2(r, r * 0.55) * (0.4 + avance * 0.6), Color(0.1, 0.07, 0.05, 0.18 + avance * 0.32))
				draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(1, 0.86, 0.6, 0.35 + luz), maxf(1.5, r * 0.04), true)
				draw_set_transform(Vector2.ZERO)
			elif estado == "pisando":
				draw_set_transform(_objetivo - position, 0.4)
				_elipse(Vector2.ZERO, Vector2(r, r * 0.55), Color("2b2622"))
				_elipse(Vector2(r * 0.15, 0), Vector2(r * 0.7, r * 0.38), Color("4a4039"))
				for i in 5:
					draw_line(Vector2(-r * 0.6 + i * r * 0.28, -r * 0.3), Vector2(-r * 0.6 + i * r * 0.28, r * 0.3), Color("3a322c"), maxf(1.0, r * 0.05))
				draw_set_transform(Vector2.ZERO)
		"aspiradora":
			draw_circle(Vector2(2, 3), r, Color(0.1, 0.08, 0.06, 0.25))
			draw_circle(Vector2.ZERO, r, Color("3d4446").lightened(luz))
			draw_circle(Vector2.ZERO, r * 0.82, Color("5a6466").lightened(luz))
			draw_arc(Vector2.ZERO, r * 0.95, -1.1, 1.1, 20, Color("22282a"), maxf(1.5, r * 0.12), true)
			draw_circle(Vector2(r * 0.45, 0), r * 0.1, Color("7fe08a") if fmod(_fase, 1.0) < 0.5 else Color("2f6b3a"))
			for i in 3:
				var a := _fase * 9.0 + i * TAU / 3
				draw_line(Vector2(r * 0.6, r * 0.7), Vector2(r * 0.6, r * 0.7) + Vector2.from_angle(a) * r * 0.35, Color("c9c2b0"), 1.0, true)
		"paloma":
			_elipse(Vector2(-r * 0.2, 0), Vector2(r, r * 0.6), Color("8c8f98").lightened(luz))
			for lado in [-1, 1]:
				var aleteo := sin(_fase * 30.0) * 0.4 if estado != "comiendo" else 0.0
				_elipse(Vector2(-r * 0.3, lado * r * 0.45), Vector2(r * 0.75, r * 0.3 + absf(aleteo) * r), Color("6f727c"))
			draw_circle(Vector2(r * 0.55, 0), r * 0.38, Color("5d7a6f"))
			draw_circle(Vector2(r * 0.8, 0), r * 0.28, Color("7d808a"))
			draw_colored_polygon(PackedVector2Array([Vector2(r * 1.0, -r * 0.08), Vector2(r * 1.3, 0), Vector2(r * 1.0, r * 0.08)]), Color("d6b07a"))
			draw_circle(Vector2(r * 0.85, -r * 0.12), r * 0.06, Color("e27a3c"))
		"gato":
			var tinta := Color("d98a3d").lightened(luz)
			if estado == "dormido":
				# Hecho un ovillo: lomo rayado, cola alrededor y la cabeza asomando.
				draw_circle(Vector2(2, 3), r * 1.02, Color(0.1, 0.08, 0.06, 0.2))
				draw_circle(Vector2.ZERO, r, tinta.darkened(0.22))
				draw_circle(Vector2(0, -r * 0.04), r * 0.92, tinta)
				for i in 4:
					draw_arc(Vector2(-r * 0.1, r * 0.05), r * (0.28 + i * 0.16), 1.9, 4.3, 12, tinta.darkened(0.28), maxf(1.0, r * 0.08), true)
				draw_arc(Vector2.ZERO, r * 0.98, 0.15, 2.1, 20, tinta.darkened(0.12), maxf(2.0, r * 0.24), true)
				var cabeza := Vector2(r * 0.62, -r * 0.56)
				var afuera := cabeza.normalized()
				for lado in [-1, 1]:
					var base_oreja: Vector2 = cabeza + afuera.rotated(lado * 0.75) * r * 0.32
					draw_colored_polygon(PackedVector2Array([base_oreja + afuera.orthogonal() * r * 0.13, base_oreja + afuera.rotated(lado * 0.55) * r * 0.3, base_oreja - afuera.orthogonal() * r * 0.13]), tinta.darkened(0.15))
				draw_circle(cabeza, r * 0.44, tinta.darkened(0.15))
				draw_circle(cabeza, r * 0.4, tinta.lightened(0.05))
				for lado in [-1, 1]:
					var ojo: Vector2 = cabeza + afuera.orthogonal() * lado * r * 0.15 + afuera * r * 0.08
					draw_arc(ojo, r * 0.07, 0.3, 2.8, 6, Color("4a2f1c"), maxf(1.0, r * 0.04), true)
				draw_circle(cabeza + afuera * r * 0.25, r * 0.05, Color("c46a6a"))
				draw_string(ThemeDB.fallback_font, Vector2(r * 0.7, -r * 1.1), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(10.0, r * 0.7)), Color(1, 1, 1, 0.5 + sin(_fase * 3.0) * 0.3))
			else:
				var estirado := 1.4 if estado == "saltando" else (0.85 if estado == "agazapado" else 1.1)
				_elipse(Vector2.ZERO, Vector2(r * estirado, r * 0.55), tinta)
				for i in 3:
					draw_line(Vector2(-r * 0.4 + i * r * 0.3, -r * 0.5), Vector2(-r * 0.4 + i * r * 0.3, r * 0.5), tinta.darkened(0.3), maxf(1.0, r * 0.08))
				draw_circle(Vector2(r * estirado, 0), r * 0.42, tinta)
				draw_line(Vector2(-r * estirado, 0), Vector2(-r * estirado * 1.6, r * 0.4 * sin(_fase * 8.0)), tinta.darkened(0.2), maxf(1.5, r * 0.16), true)
		"rata":
			draw_line(Vector2(-r * 0.9, 0), Vector2(-r * 2.2, sin(_fase * 10.0) * r * 0.5), Color("d9a3a0"), maxf(1.0, r * 0.12), true)
			_elipse(Vector2.ZERO, Vector2(r, r * 0.55), Color("7c7470").lightened(luz))
			_elipse(Vector2(r * 0.85, 0), Vector2(r * 0.45, r * 0.32), Color("8a827e"))
			for lado in [-1, 1]:
				draw_circle(Vector2(r * 0.6, lado * r * 0.35), r * 0.2, Color("d9a3a0"))
			draw_circle(Vector2(r * 1.28, 0), r * 0.08, Color("3a2a28"))
			if botin > 0.0:
				draw_circle(Vector2(r * 1.3, r * 0.3), r * 0.4, Color("e3c08d"))
		"cucaracha", "escarabajo":
			var tinta := Color("76503a") if tipo == "cucaracha" else Color("47614c")
			var ancho := 0.53 if tipo == "cucaracha" else 0.72
			for lado in [-1, 1]:
				for i in 3:
					var x := (i - 1) * r * 0.55
					var vaiven := sin(_fase * 16.0 + i * 1.6) * r * 0.12 if estado == "entrando" else 0.0
					draw_line(Vector2(x, lado * r * ancho * 0.7), Vector2(x - r * 0.25 + vaiven, lado * r * 1.02), tinta.darkened(0.45), 1.3, true)
			_elipse(Vector2(-r * 0.08, 0), Vector2(r, r * ancho), tinta.darkened(0.3).lightened(luz))
			_elipse(Vector2(-r * 0.08, -r * 0.06), Vector2(r * 0.88, r * ancho * 0.85), tinta.lightened(luz))
			draw_line(Vector2(-r * 0.85, 0), Vector2(r * 0.55, 0), tinta.darkened(0.5), 1.2)
			draw_circle(Vector2(r * 0.8, 0), r * 0.32, tinta.darkened(0.35))
			for lado in [-1, 1]:
				draw_line(Vector2(r, lado * r * 0.12), Vector2(r * 1.65, lado * r * 0.48), tinta.darkened(0.45), 1.0, true)
			if botin > 0.0:
				draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.4, 0), Vector2(0, -r * 0.34), Vector2(r * 0.3, 0), Vector2(0, r * 0.3)]), Color("e3c08d"))
		"avispa":
			_dibujar_avispa(r, luz)
		"rival":
			_dibujar_rival(r, luz)
		"dorada":
			var pulso := 0.5 + 0.5 * sin(_fase * 6.0)
			draw_circle(Vector2.ZERO, r * (2.0 + pulso * 0.6), Color(1.0, 0.85, 0.3, 0.12 + pulso * 0.1))
			draw_circle(Vector2.ZERO, r * 1.3, Color(1.0, 0.9, 0.45, 0.35))
			var puntas := PackedVector2Array()
			for i in 7:
				puntas.append(Vector2.from_angle(TAU * i / 7 + 0.3) * r * (0.8 + 0.25 * (i % 2)))
			draw_colored_polygon(puntas, Color("f2c84b"))
			draw_circle(Vector2(-r * 0.2, -r * 0.25), r * 0.22, Color("fff3c0"))
			for i in 3:
				var a := _fase * 2.0 + i * TAU / 3
				var p := Vector2.from_angle(a) * r * 2.0
				draw_line(p - Vector2(r * 0.25, 0), p + Vector2(r * 0.25, 0), Color(1, 0.95, 0.7, 0.8), 1.5)
				draw_line(p - Vector2(0, r * 0.25), p + Vector2(0, r * 0.25), Color(1, 0.95, 0.7, 0.8), 1.5)
	# Aviso visible antes de moverse/robar. La pausa de carga permite decidir
	# y reaccionar; no hace falta perseguir un píxel que roba instantáneamente.
	if _aviso_restante > 0.0:
		draw_arc(Vector2.ZERO, r * 1.8, -PI * 0.5, TAU - PI * 0.5,
			24, Color(0.95, 0.79, 0.48, 0.45 + 0.25 * sin(_fase * 6.0)), 1.5, true)
	elif estado == "cargando":
		var avance := clampf(1.0 - _reloj_accion / float(_datos.get("aviso", AVISO_ROBO)), 0.0, 1.0)
		draw_arc(Vector2.ZERO, r * 1.7, -PI * 0.5, -PI * 0.5 + TAU * avance,
			24, Color("efd092"), 2.0, true)
	elif tipo == "avispa" and estado in ["marcando", "picando"]:
		# El aviso y la pasada comparten exactamente el mismo punto fijo.
		var punto := to_local(_objetivo)
		draw_arc(punto, r * 2.1, 0, TAU, 28, Color(0.94, 0.59, 0.27, 0.85), 2.0, true)
		draw_line(Vector2.ZERO, punto, Color(0.94, 0.59, 0.27, 0.35), 1.0, true)
	elif tipo == "gato" and estado == "agazapado":
		draw_arc(to_local(_objetivo), r * 1.6, 0, TAU, 24, Color(0.95, 0.68, 0.36, 0.65), 1.5, true)
	# Golpes que faltan: puntos sobre la amenaza.
	if es_amenaza() and golpes_max > 1 and (tipo != "mozo" or estado == "avisando"):
		var centro := (_objetivo - position) if tipo == "mozo" else Vector2.ZERO
		draw_set_transform(centro, -rotation if tipo != "mozo" else 0.0)
		for i in golpes_max:
			var p := Vector2((i - (golpes_max - 1) * 0.5) * r * 0.42, -r * 1.55)
			draw_circle(p, maxf(2.5, r * 0.13), Color("f0d277") if i < golpes else Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO)


func _dibujar_avispa(r: float, luz: float) -> void:
	draw_set_transform(Vector2(-_destello * 45.0, 0), 0, Vector2(1 + _destello, 1 - _destello))
	var tinta := Color("d5a840").lightened(luz)
	for lado in [-1, 1]:
		var aleteo := 0.3 + absf(sin(_fase * 35.0)) * 0.35
		_elipse(Vector2(-r * 0.1, lado * r * 0.6), Vector2(r * 0.8, r * aleteo), Color(0.8, 0.9, 0.9, 0.6))
		for i in 3:
			draw_line(Vector2((i - 1) * r * 0.3, lado * r * 0.2), Vector2((i - 1) * r * 0.5 - r * 0.2, lado * r * 0.9), Color("392f28"), 1.5, true)
	_elipse(Vector2(-r * 0.65, 0), Vector2(r * 0.8, r * 0.47), tinta)
	for i in 3:
		draw_line(Vector2(-r * 1.1 + i * r * 0.35, -r * 0.34), Vector2(-r * 1.1 + i * r * 0.35, r * 0.34), Color("40352b"), r * 0.15)
	draw_circle(Vector2(r * 0.3, 0), r * 0.4, Color("4a3c2d").lightened(luz))
	draw_circle(Vector2(r * 0.9, 0), r * 0.38, tinta)
	for lado in [-1, 1]:
		draw_circle(Vector2(r * 1.06, lado * r * 0.19), r * 0.1, Color("282521"))
		draw_line(Vector2(r * 1.05, lado * r * 0.19), Vector2(r * 1.55, lado * r * 0.5), Color("40352b"), 1.2, true)
	if botin > 0:
		draw_colored_polygon(PackedVector2Array([Vector2(r * 0.65, r * 0.3), Vector2(r * 1.3, r * 0.24), Vector2(r * 1.5, r * 0.65), Vector2(r * 0.8, r * 0.8)]), Color("dfc18b"))
	draw_set_transform(Vector2.ZERO)


func _dibujar_rival(r: float, luz: float) -> void:
	draw_set_transform(Vector2(-_destello * 45.0, 0), 0, Vector2(1 + _destello, 1 - _destello))
	var tinta := Color("a2573d").lightened(luz)
	for lado in [-1, 1]:
		for i in 3:
			var paso := sin(_fase * 14.0 + i * 1.8) * r * 0.15 if estado != "cargando" else 0.0
			draw_polyline(PackedVector2Array([Vector2((i - 1) * r * 0.33, lado * r * 0.2), Vector2((i - 1) * r * 0.6 - r * 0.2, lado * r * 0.7), Vector2((i - 1) * r * 0.7 + paso, lado * r * 1.1)]), Color("50342a"), 1.6, true)
	_elipse(Vector2(-r * 0.7, 0), Vector2(r * 0.65, r * 0.5), tinta.darkened(0.2))
	draw_line(Vector2(-r * 0.92, -r * 0.4), Vector2(-r * 0.92, r * 0.4), Color("d8bb86"), r * 0.16)
	draw_circle(Vector2.ZERO, r * 0.37, tinta)
	draw_circle(Vector2(r * 0.7, 0), r * 0.46, tinta.lightened(0.15))
	for lado in [-1, 1]:
		draw_line(Vector2(r * 0.9, lado * r * 0.2), Vector2(r * 1.55, lado * r * 0.48), Color("50342a"), 1.3, true)
		draw_circle(Vector2(r * 0.93, lado * r * 0.23), r * 0.075, Color("241f1b"))
	if botin > 0:
		draw_colored_polygon(PackedVector2Array([Vector2(r * 0.8, -r * 0.3), Vector2(r * 1.5, -r * 0.4), Vector2(r * 1.8, r * 0.15), Vector2(r * 1.1, r * 0.5)]), Color("c8ae7e"))
	draw_set_transform(Vector2.ZERO)


func _elipse(centro: Vector2, radios: Vector2, tinta: Color) -> void:
	var puntos := PackedVector2Array()
	for i in 20:
		var a := i * TAU / 20
		puntos.append(centro + Vector2(cos(a) * radios.x, sin(a) * radios.y))
	draw_colored_polygon(puntos, tinta)
