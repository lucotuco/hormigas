class_name Hormiga
extends Node2D
## Una hormiga obrera.
##
## Máquina de estados simple:
##   EXPLORANDO     recorre sectores del territorio buscando comida
##   SIGUIENDO      se acerca al llamado que el jugador mantiene bajo el cursor
##   YENDO_A_COMIDA vio comida y va hacia ella
##   MORDIENDO      muerde hasta llenar el buche (stat "capacidad")
##   VOLVIENDO      lleva la carga al hormiguero; después vuelve a la misma comida
##   QUIETA         la run terminó
##
## Las decisiones caras (buscar comida, oler feromonas) se toman cada
## INTERVALO_PENSAR segundos, no en cada cuadro, para que entren cientos.

enum Estado { EXPLORANDO, SIGUIENDO, YENDO_A_COMIDA, MORDIENDO, VOLVIENDO, QUIETA }

const INTERVALO_PENSAR := 0.15
const VELOCIDAD_GIRO := 9.0          # radianes por segundo
const COLOR_CUERPO := Color(0.16, 0.1, 0.07)

var estado := Estado.EXPLORANDO
var run: Run
var objetivo := Vector2.ZERO
var comida: Comida = null:
	set(nueva):
		if comida == nueva:
			return
		if is_instance_valid(comida):
			comida.trabajadoras = maxi(0, comida.trabajadoras - 1)
		comida = nueva
		_version_objetivo = -1
		_version_mirada = -1
		_vida_mirada = -1.0
		_distancia_apoyo = INF
		_reubicando_frente = false
		_masticando_visual = false
		_contacto_visual = Vector2.INF
		if is_instance_valid(comida):
			comida.trabajadoras += 1
			if is_instance_valid(run) and is_instance_valid(run.colonia):
				run.colonia.exploracion.liberar(get_instance_id())
var carga := 0.0          # migas que lleva encima
var bocados := 0
var casta := "obrera"
var escala_casta := 1.0
var _color := COLOR_CUERPO
var _reloj_reina := 0.0
var _minis_creadas := 0
const INTERVALO_REINA := 6.0
const MINIS_POR_TANDA := 2
const LIMITE_MINIS_REINA := 24

var _recuerdo: Comida = null    # la comida a la que vuelve después de descargar
var _color_carga := Color.WHITE
var _reloj_pensar := 0.0
var _reloj_mordida := 0.0
var _reubicando_frente := false
var _reloj_vagar := 0.0
var _ruta := PackedVector2Array()
var _origen_ruta := Vector2.INF
var _indice_ruta := 0
var _espera_ruta := 0.0
var _ruta_fallida := false
var _esperando_ruta := false
var _meta_ruta := Vector2.INF
var _pedido_ruta := Vector2.INF
var _version_ruta := -1
var _cuerpo: Sprite2D
var _carga_sprite: Sprite2D
var _reloj_visual := 0.0
var en_pantalla := true
var _evolucion := 0
var _material_carga := -1
var _siguiendo_llamado := false
var _proxima_busqueda_llamado := 0.0
var _comidas_sin_ruta: Dictionary = {}
var _reloj_vida := 0.0
var _fase := 0.0
var _reloj_progreso := 0.0
var _ultima_pos := Vector2.ZERO
var _puesto := 0
var _reloj_habilidad := 0.0
var _corte := false
var _contagio := false
var _barrido := false
var _camada := false
var _sondeo := false
var _cantera := false
var _proxima_memoria := 0.0
var _animacion: Array[Rect2] = []
var _tipo_animacion := ""
var _evolucion_animacion := -1
var _version_objetivo := -1
var _version_mirada := -1
var _vida_mirada := -1.0
var _distancia_apoyo := INF
var _posicion_mirada := Vector2.INF
var _angulo_mordida := 0.0
var _masticando_visual := false
var _contacto_visual := Vector2.INF
var _desfase_masticar := 0.0
var _masticando_animacion := false
var _animacion_masticar: Array[Rect2] = []
var _desplazamiento_masticar := Vector2.ZERO
var _entradas_fallidas: Dictionary = {}
var _carga_origen: Array[float] = [0.0, 0.0, 0.0]
## Hasta tres muestras del material realmente retirado, en el atlas común.
## No conservan la comida ni crean texturas, nodos o tweens por mordisco.
var _retazos: Array[Rect2] = []
var _angulos_retazos: Array[float] = []
var _tamanos_retazos: Array[Vector2] = []
var _origenes_retazos: Array[Vector2] = []
var _tiempos_retazos: Array[float] = []
var _levantando_retazos := false
var _origen_retazo := Vector2.ZERO
var _tiempo_bocado := -10.0
var _tiempo_descarga := -10.0
var _detalle_bocado := false

# Stats copiadas al nacer (no cambian durante la run).
var _velocidad := 60.0
var _olfato := 45.0
var _dano := 1.0
var _intervalo_mordida := 0.6
var _capacidad := 1
var _porciones_ciclo := 1


func iniciar(r: Run, tipo := "obrera") -> void:
	run = r
	casta = tipo
	var datos: Dictionary = Juego.castas_por_id[tipo]
	var stats := Juego.stats_casta(tipo)
	_color = datos.color
	escala_casta = datos.escala
	_velocidad = stats.velocidad * randf_range(0.9, 1.1)
	_olfato = stats.olfato
	_dano = stats.dano
	_intervalo_mordida = stats.intervalo_mordida
	_capacidad = stats.capacidad
	# Aprender materiales habilita tandas pequeñas, no un trozo más grande.
	# El tope técnico coincide con las tres muestras ya retenidas por hormiga.
	var max_porciones := clampi(int(Juego.stat("porciones_por_ciclo_max")), 1, 3)
	_porciones_ciclo = clampi(1 + int(Juego.stat("materiales")), 1, max_porciones)
	_puesto = get_instance_id() % 12
	_corte = tipo == "carpintera" and Juego.evolucion_activa("corte")
	_contagio = tipo == "roja" and Juego.evolucion_activa("contagio")
	_barrido = tipo == "cargadora" and Juego.evolucion_activa("barrido")
	_camada = tipo == "reina" and Juego.evolucion_activa("camada")
	_sondeo = tipo == "voladora" and Juego.evolucion_activa("sondeo")
	_cantera = tipo == "demoledora" and Juego.evolucion_activa("cantera")
	_evolucion = Juego.nivel_visual()
	if _corte or _contagio or _barrido or _camada or _sondeo or _cantera or (tipo == "voladora" and Juego.evolucion_activa("puente")):
		_evolucion = maxi(1, _evolucion)
	if casta == "reina" and Juego.hitos.has("primer_monumento"):
		_evolucion = 2
	if casta == "voladora":
		z_index = 2
	_reloj_pensar = randf() * INTERVALO_PENSAR
	_proxima_memoria = randf() * 0.6
	_fase = randf() * TAU
	_desfase_masticar = _fase # Reutiliza el azar de nacimiento, no consume RNG nuevo.
	_elegir_destino_al_azar()
	if Graficos.listo:
		_crear_sprite()
	else:
		Graficos.preparado.connect(_crear_sprite, CONNECT_ONE_SHOT)


func detener() -> void:
	estado = Estado.QUIETA
	_masticando_visual = false
	_esperando_ruta = false
	comida = null
	run.colonia.exploracion.liberar(get_instance_id())
	_actualizar_sprite()
	queue_redraw()

func _exit_tree() -> void:
	comida = null
	if is_instance_valid(run) and is_instance_valid(run.colonia):
		run.colonia.exploracion.liberar(get_instance_id())


func _process(delta: float) -> void:
	if estado == Estado.QUIETA:
		return
	_reloj_vida += delta
	_espera_ruta = maxf(0, _espera_ruta - delta)
	_reloj_habilidad = maxf(0, _reloj_habilidad - delta)
	if casta == "reina" and run.activa:
		_reloj_reina += delta
		while _reloj_reina >= INTERVALO_REINA and _minis_creadas < LIMITE_MINIS_REINA:
			_reloj_reina -= INTERVALO_REINA
			_minis_creadas += run.colonia.desplegar_minis(global_position, mini(3 if _camada else MINIS_POR_TANDA, LIMITE_MINIS_REINA - _minis_creadas))
	_fase += delta * (4.0 if estado == Estado.MORDIENDO else _velocidad * 0.24)
	_reloj_visual -= delta
	if _reloj_visual <= 0 and en_pantalla:
		_reloj_visual = 1.0 / 12.0
		_actualizar_sprite()
	_reloj_pensar -= delta
	if _reloj_pensar <= 0.0:
		_reloj_pensar += INTERVALO_PENSAR
		_pensar()
	if estado == Estado.MORDIENDO:
		_morder(delta)
	else:
		_caminar(delta)
	# Recuperación ante objetivos inaccesibles o un cambio de territorio.
	_reloj_progreso += delta
	if _reloj_progreso >= 1.2:
		var esperando_en_destino := estado == Estado.SIGUIENDO and global_position.distance_squared_to(objetivo) < 400
		if estado != Estado.MORDIENDO and not esperando_en_destino and not _esperando_ruta and global_position.distance_to(_ultima_pos) < 3.0:
			_meta_ruta = Vector2.INF
			if estado == Estado.SIGUIENDO:
				_espera_ruta = 0.3
			elif estado != Estado.VOLVIENDO:
				if _comida_valida(comida):
					_comidas_sin_ruta[comida.get_instance_id()] = _reloj_vida + 3
				comida = null
				estado = Estado.EXPLORANDO
				_elegir_destino_al_azar()
		_ultima_pos = global_position
		_reloj_progreso = 0.0


func _pensar() -> void:
	if run.retirando:
		if carga <= 0:
			detener()
		elif estado != Estado.VOLVIENDO:
			_volver()
		return
	if not _comidas_sin_ruta.is_empty():
		for id in _comidas_sin_ruta.keys():
			if _comidas_sin_ruta[id] <= _reloj_vida:
				_comidas_sin_ruta.erase(id)
	if estado == Estado.VOLVIENDO:
		return
	if carga > 0:
		if estado == Estado.MORDIENDO:
			return
		# Un retazo ya arrancado se entrega antes de buscar otra orilla. Esto
		# también recupera portadoras que estaban reubicándose entre frentes.
		_volver()
		return
	if run.feromonas.llama_a(self):
		run.colonia.exploracion.liberar(get_instance_id())
		_siguiendo_llamado = true
		var elegida: Comida
		if comida != null and not _comida_valida(comida):
			# Otra obrera pudo agotarla entre dos muestreos. No esperar el
			# enfriamiento de una búsqueda sin trabajo para tomar su reemplazo.
			_proxima_busqueda_llamado = 0.0
		# Apuntar expresamente a otro objeto reemplaza el trabajo automático
		# retenido, sin esperar un enfriamiento de búsqueda ni ignorar sus cupos.
		if run.feromonas._trabajo_elegible(run.feromonas.objetivo_comida, self):
			elegida = run.feromonas.objetivo_comida
		elif run.feromonas._trabajo_elegible(comida, self):
			elegida = comida
		# La consulta usa candidatas compartidas y sólo corre al necesitar
		# otro recurso. No obliga a llegar a 24 unidades del cursor ni recorre
		# todo el mapa en cada decisión de las 64 hormigas seleccionadas.
		if elegida == null and _reloj_vida >= _proxima_busqueda_llamado:
			_proxima_busqueda_llamado = _reloj_vida + 0.6
			elegida = run.feromonas.trabajo_para(self)
			if elegida != null:
				run.colonia.avistar(elegida)
		if _comida_valida(elegida) and _alcanza_trabajo(elegida):
			comida = elegida
			if estado != Estado.MORDIENDO:
				_reloj_mordida = _intervalo_mordida * 0.4
			estado = Estado.MORDIENDO
			return
		comida = elegida if _comida_valida(elegida) else null
		if comida != null:
			_actualizar_puesto()
			estado = Estado.YENDO_A_COMIDA
		else:
			objetivo = run.feromonas.destino_para(casta == "voladora")
			estado = Estado.SIGUIENDO
		return
	if _siguiendo_llamado:
		_siguiendo_llamado = false
		if estado == Estado.SIGUIENDO:
			estado = Estado.EXPLORANDO
			_elegir_destino_al_azar()
	if estado == Estado.MORDIENDO:
		return
	if not _comida_valida(comida):
		comida = null
		if carga > 0.0:
			_volver()
			return
		comida = run.comidas.buscar_cercana(global_position, _olfato, run.radio_actual, _comidas_sin_ruta, casta)
		if comida == null and _reloj_vida >= _proxima_memoria:
			_proxima_memoria = _reloj_vida + 0.6
			comida = run.colonia.trabajo_conocido(global_position, casta, _comidas_sin_ruta)
		elif comida != null:
			run.colonia.avistar(comida)
	if comida != null:
		# Al cambiar a una miga o un montón que ya está a la boca no hace
		# falta volver a entrar en la cola global ni caminar hasta su centro.
		# Esto importa cuando otra hormiga termina el trabajo a nuestros pies.
		if _alcanza_trabajo(comida):
			estado = Estado.MORDIENDO
			_esperando_ruta = false
			_reloj_mordida = _intervalo_mordida * 0.4
			return
		# El puesto se conserva durante el viaje. Sólo cambia al abrir material
		# o tomar otro recurso: no perseguir una proyección móvil cada 150 ms.
		_actualizar_puesto()
		estado = Estado.YENDO_A_COMIDA
		return
	if estado != Estado.EXPLORANDO:
		estado = Estado.EXPLORANDO
		_elegir_destino_al_azar()


func _actualizar_puesto() -> void:
	# Romper un mueble lejano sólo abre caminos: no cambia este frente de
	# trabajo ni obliga a cientos de hormigas a volver a elegir su acercamiento.
	var version: int = comida.version_forma if comida is PiezaCasa else 0
	if estado not in [Estado.YENDO_A_COMIDA, Estado.SIGUIENDO] or _version_objetivo != version:
		objetivo = comida.punto_trabajo(global_position, run.radio_actual, casta == "voladora", _puesto)
		_version_objetivo = version


func _alcanza_trabajo(fuente: Comida) -> bool:
	if fuente is PiezaCasa:
		if estado == Estado.MORDIENDO and fuente == comida:
			return true # El apoyo vivo se revalida antes del reloj de mordida.
		# El alcance máximo no es una orden de detenerse antes de llegar.
		# Mantener el puesto elegido también permite apoyar en curvas/diagonales
		# que necesitan más de 9u para respetar el margen de navegación.
		if fuente != comida or not objetivo.is_finite() or global_position.distance_squared_to(objetivo) > 0.0625:
			return false
	return fuente.alcanza_desde(global_position)


func _caminar(delta: float) -> void:
	if estado == Estado.EXPLORANDO:
		if not _esperando_ruta:
			_reloj_vagar -= delta
		if (_reloj_vagar <= 0.0 and not _esperando_ruta) or global_position.distance_squared_to(objetivo) < 64.0:
			if global_position.distance_squared_to(objetivo) < 64.0:
				run.colonia.exploracion.visitar(global_position)
			_elegir_destino_al_azar()

	# El desplazamiento sigue una ruta; la orientación visual gira suavemente.
	# Así una hormiga rápida no orbita una miga ni sobrepasa el hormiguero.
	if objetivo == Vector2.INF:
		_esperando_ruta = false
		if estado == Estado.SIGUIENDO or estado == Estado.EXPLORANDO:
			# Sin una salida válida, la exploración reintenta al vencer su reloj,
			# no doce pruebas geométricas por hormiga en cada cuadro.
			return
		if _comida_valida(comida):
			_comidas_sin_ruta[comida.get_instance_id()] = _reloj_vida + 3
		comida = null
		estado = Estado.EXPLORANDO
		_elegir_destino_al_azar()
		return
	# Al ir a comer, el destino de la ruta debe tener la misma precisión que
	# la llegada al apoyo. Ignorar ajustes de 2u la dejaba en un puesto viejo.
	var umbral := 144.0 if estado == Estado.SIGUIENDO else (0.0625 if estado == Estado.YENDO_A_COMIDA else 16.0)
	var necesita_ruta := _meta_ruta == Vector2.INF or _pedido_ruta.distance_squared_to(objetivo) > umbral
	if not necesita_ruta:
		_esperando_ruta = false
	if _ruta_fallida and _version_ruta != run.cocina.version:
		_espera_ruta = 0
	if necesita_ruta and _espera_ruta <= 0 and run.cocina.admitir_ruta(self):
		var meta := run.cocina.ajustar_destino(objetivo, run.radio_actual, casta == "voladora")
		if meta == Vector2.INF:
			_espera_ruta = 0.6
			return
		_ruta = run.cocina.ruta(global_position, meta, run.radio_actual, casta == "voladora")
		_origen_ruta = global_position
		_indice_ruta = 0
		_meta_ruta = meta
		_pedido_ruta = objetivo
		_version_ruta = run.cocina.version
		_ruta_fallida = _ruta.is_empty()
		_espera_ruta = randf_range(0.5, 0.8) if _ruta_fallida else (0.18 if estado == Estado.SIGUIENDO else 0.0)
		if _ruta_fallida and estado == Estado.VOLVIENDO:
			_entradas_fallidas[objetivo] = true
			objetivo = run.entradas.elegir(global_position, _entradas_fallidas)
			_meta_ruta = Vector2.INF
			return
	# Seguir avanzando por el recorrido seguro anterior mientras espera turno.
	if _indice_ruta >= _ruta.size():
		if necesita_ruta and (_espera_ruta > 0 or _meta_ruta == Vector2.INF or _esperando_ruta):
			return
		if estado == Estado.SIGUIENDO and global_position.distance_squared_to(_meta_ruta) < 9:
			return
		_meta_ruta = Vector2.INF
		if estado == Estado.SIGUIENDO:
			return
		if estado != Estado.VOLVIENDO:
			if _comida_valida(comida):
				_comidas_sin_ruta[comida.get_instance_id()] = _reloj_vida + 3
			comida = null
			estado = Estado.EXPLORANDO
			_elegir_destino_al_azar()
		return
	var presupuesto := _velocidad * run.factor_ritmo() * delta
	while presupuesto > 0.0 and _indice_ruta < _ruta.size():
		var destino := _ruta[_indice_ruta]
		var distancia := global_position.distance_to(destino)
		if distancia > 0.01:
			rotation = rotate_toward(rotation, (destino - global_position).angle(), VELOCIDAD_GIRO * delta)
		if distancia <= presupuesto:
			global_position = destino
			presupuesto -= distancia
			_indice_ruta += 1
		else:
			global_position = global_position.move_toward(destino, presupuesto)
			presupuesto = 0.0
	match estado:
		Estado.YENDO_A_COMIDA:
			if not _comida_valida(comida):
				comida = null
				estado = Estado.EXPLORANDO
				_elegir_destino_al_azar()
			elif _alcanza_trabajo(comida):
				estado = Estado.MORDIENDO
				_reloj_mordida = _intervalo_mordida * randf_range(0.3, 1.0)
		Estado.VOLVIENDO:
			if global_position.distance_squared_to(objetivo) <= Hormiguero.RADIO_ENTRADA * Hormiguero.RADIO_ENTRADA:
				_descargar()


func _morder(delta: float) -> void:
	if run.retirando:
		if carga > 0:
			_volver()
		else:
			detener()
		return
	_esperando_ruta = false
	if not _comida_valida(comida):
		comida = null
		if carga > 0.0:
			_volver()
		else:
			estado = Estado.EXPLORANDO
			_elegir_destino_al_azar()
		return
	# Preparación geométrica presupuestada: seguir trabajando en el mismo
	# frente sin interpretar la espera como falta de contacto. No se consume
	# ni se acumula reloj de daño, carga o varios mordiscos durante la espera.
	if not comida.preparar_material():
		_masticando_visual = false
		return
	var hacia := (comida.global_position - global_position).angle()
	if comida is PiezaCasa:
		# Mirar la piedra o la pata que se muerde, no el aire en el centro de
		# un arco. Alcance y orientación comparten la invalidación: una obrera
		# quieta no vuelve a recorrer las secciones del mueble en cada cuadro.
		# Cambiar de pieza, moverse o perder una sección obliga a comprobarlos.
		if _version_mirada != comida.version_forma or _vida_mirada != comida.vida or _posicion_mirada != global_position:
			# La máscara cambia antes de publicar la navegación cada 0,12s.
			# Si una mordida lejana no retiró ESTE apoyo, cuatro lecturas R8
			# evitan repetir nearest para toda la colonia por cada astilla.
			var conserva_apoyo: bool = _version_mirada == comida.version_forma and _posicion_mirada == global_position and comida.mordiscos != null and comida.mordiscos.contacto_vigente(_contacto_visual)
			if not conserva_apoyo:
				_contacto_visual = comida.material_cercano(global_position)
			var distancia := global_position.distance_to(_contacto_visual)
			var mismo_puesto := _posicion_mirada == global_position and is_finite(_distancia_apoyo)
			var apoyo_maximo := _distancia_apoyo if mismo_puesto else minf(Cocina.MARGEN + 5, maxf(PiezaCasa.DISTANCIA_TRABAJO, distancia + 0.25))
			if not _contacto_visual.is_finite() or distancia > apoyo_maximo:
				_reubicar_frente()
				return
			_distancia_apoyo = apoyo_maximo
			var direccion: Vector2 = _contacto_visual - global_position
			_angulo_mordida = direccion.angle() if direccion.length_squared() > 0.001 else hacia
			_version_mirada = comida.version_forma
			_vida_mirada = comida.vida
			_posicion_mirada = global_position
		hacia = _angulo_mordida
		_masticando_visual = _contacto_visual.is_finite()
	elif not comida is FragmentoCasa:
		# Confirmar el apoyo ANTES del primer bocado: con capacidad uno ya
		# estaría volviendo al llenarse. Una consulta por llegada/posición;
		# las siguientes mordidas renuevan el contacto como siempre.
		if _version_mirada == -1 or _vida_mirada != comida.vida or _posicion_mirada != global_position:
			var conserva_apoyo: bool = _posicion_mirada == global_position and comida.mordiscos != null and comida.mordiscos.contacto_vigente(comida.to_local(_contacto_visual))
			if not conserva_apoyo:
				_contacto_visual = comida.punto_contacto(global_position)
			if not _contacto_visual.is_finite() or global_position.distance_squared_to(_contacto_visual) > 9.0:
				_reubicar_frente()
				return
			_version_mirada = 0
			_vida_mirada = comida.vida
			_posicion_mirada = global_position
			_masticando_visual = _contacto_visual.is_finite() and global_position.distance_squared_to(_contacto_visual) <= 9.0
			if _masticando_visual:
				_angulo_mordida = (_contacto_visual - global_position).angle()
		hacia = _angulo_mordida
	rotation = rotate_toward(rotation, hacia, VELOCIDAD_GIRO * delta)
	_reloj_mordida -= delta * run.factor_ritmo() * run.multiplicador_ritmo_activo()
	if _reloj_mordida > 0.0:
		return
	if not comida is FragmentoCasa:
		# El frente visual puede retroceder sin agotar la celda física. Esta
		# comprobación corre por intento de mordida, no por hormiga y cuadro.
		var contacto: Vector2 = comida.punto_contacto(global_position)
		var alcance := Cocina.MARGEN + 5 if comida is PiezaCasa else 3.0
		if contacto == Vector2.INF or global_position.distance_squared_to(contacto) > alcance * alcance:
			_reubicar_frente()
			return
		_reubicando_frente = false
		_contacto_visual = contacto
		_masticando_visual = true
		_angulo_mordida = (contacto - global_position).angle()
		rotation = rotate_toward(rotation, _angulo_mordida, VELOCIDAD_GIRO * delta)
	_reloj_mordida += _intervalo_mordida
	var actual := comida
	# Ráfaga modifica sólo el trabajo emitido ahora. El daño base de la casta
	# no se reescribe y los ticks de veneno no reciben el multiplicador otra vez.
	var dano_activo := _dano * run.multiplicador_dano_activo()
	var lado_bocado := Juego.stat("tamano_bocado")
	if actual is PiezaCasa:
		lado_bocado = actual.lado_para_dano(dano_activo * RolesHormiga.dano(casta, actual.nivel_requerido) * run.reglas.factor_dano(actual), lado_bocado)
	for porcion in _porciones_ciclo:
		if not is_instance_valid(actual) or actual.muerta or estado != Estado.MORDIENDO:
			break
		if porcion > 0:
			if actual is FragmentoCasa:
				break
			# Cada retirada puede alejar la frontera o terminar la pieza. No
			# morder a distancia ni cambiar de objetivo para completar la tanda.
			var contacto := actual.punto_contacto(global_position)
			var alcance := Cocina.MARGEN + 5 if actual is PiezaCasa else 3.0
			if contacto == Vector2.INF or global_position.distance_squared_to(contacto) > alcance * alcance:
				break
		if not _desprender_porcion(actual, dano_activo, lado_bocado, porcion > 0):
			break


## Cada llamada devuelve una sola porción real, captura su región ANTES de
## que la siguiente la reemplace y consume un lugar del buche. Las otras dos
## operaciones de la tanda sólo pueden gastar crédito previo del mismo frente.
func _desprender_porcion(actual: Comida, dano_activo: float, lado_bocado: float, continuar: bool) -> bool:
	var carga_previa := carga
	var corte_continuo: bool = actual is PiezaCasa and ((_corte and actual.nivel_requerido == 1) or (_cantera and actual.nivel_requerido in [2, 3]))
	if actual is PiezaCasa:
		var dano := dano_activo * RolesHormiga.dano(casta, actual.nivel_requerido) * run.reglas.factor_dano(actual)
		carga += actual.continuar_bocado(global_position, lado_bocado) if continuar else actual.morder_local(dano, global_position, lado_bocado)
		_material_carga = actual.nivel_requerido
	elif actual is FragmentoCasa:
		for i in 3:
			_carga_origen[i] += actual.origen[i]
		carga += actual.morder(dano_activo)
		_material_carga = actual.material_id
		if _barrido:
			var barrido := run.comidas.recoger_vecinos(global_position, RolesHormiga.peso_maximo(casta))
			carga += barrido.valor
			for i in 3:
				_carga_origen[i] += barrido.origen[i]
			if barrido.valor > 0:
				run.efectos.habilidad(global_position - Vector2(48, 0), global_position + Vector2(48, 0), Color("dfcd91"))
			_material_carga = maxi(_material_carga, barrido.material)
	else:
		carga += actual.continuar_bocado(global_position, lado_bocado) if continuar else actual.morder_local(dano_activo, global_position, lado_bocado)
		_material_carga = -1
	var extraido := carga - carga_previa
	if corte_continuo:
		# Corte/Cantera producen en el frente; la colonia transporta.
		# El corte local no genera un 35% adicional: cae exactamente su valor.
		run.comidas.soltar_fragmento(global_position, extraido, actual.nivel_requerido)
		carga = carga_previa
	elif not actual is FragmentoCasa:
		_carga_origen[0 if _material_carga <= 0 else (2 if _material_carga >= 3 else 1)] += carga - carga_previa
	if not corte_continuo and carga > carga_previa:
		if carga_previa <= 0:
			_retazos.clear()
			_angulos_retazos.clear()
			_tamanos_retazos.clear()
			_origenes_retazos.clear()
			_tiempos_retazos.clear()
			_levantando_retazos = false
		_guardar_retazo(actual)
	if not continuar and casta == "roja" and not actual.muerta:
		actual.aplicar_veneno(dano_activo * 0.8, 3.0, run, global_position)
		if _contagio and _reloj_habilidad <= 0:
			_reloj_habilidad = 1.5
			run.comidas.contagiar(global_position, actual, dano_activo * 0.4, run)
			run.efectos.habilidad(global_position, global_position + Vector2.from_angle(rotation) * 55, Color("acd870"))
	if extraido <= 0:
		# Trabajar una superficie dura no es haber desprendido un trozo. El
		# trabajo queda en el recurso; no se inventa carga ni se llena el buche.
		return false
	if _sondeo and actual is PiezaCasa:
		actual.abrir_escondite()
	bocados += 1
	_color_carga = actual.color
	_tiempo_bocado = _reloj_vida
	_reloj_visual = 0
	run.efectos.mordida(global_position + Vector2.from_angle(rotation) * 4.0, actual.color, _material_carga, Vector2.from_angle(rotation))
	# El timbre sólo confirma material retirado. Su puerta global es compartida
	# con el levantado; no suena por crédito pendiente ni fuera de cámara.
	if not Sonido.silenciado and en_pantalla and visible and Sonido.detalle_material(run.camara.zoom.x, run.colonia.hormigas.size()):
		Sonido.tocar(_sonido_bocado(actual), 1.0, 0.08)
	if corte_continuo:
		bocados = 0
		if actual.muerta:
			comida = null
			estado = Estado.EXPLORANDO
			_elegir_destino_al_azar()
		return true
	if bocados >= _capacidad or actual.muerta:
		_volver()
	return true


func _reubicar_frente() -> void:
	_masticando_visual = false
	_reloj_visual = 0.0
	if carga > 0:
		# La capacidad permite juntar porciones contiguas. Si este borde se
		# alejó, no perseguir el resto del mueble con material en la boca:
		# transportar lo recogido y volver después por un frente nuevo.
		_volver()
		return
	_distancia_apoyo = INF
	var destino := comida.punto_trabajo(global_position, run.radio_actual, casta == "voladora", _puesto)
	if destino == Vector2.INF:
		# Un frente todavía pendiente de sincronización no debe generar una
		# rueda infinita de intentos. La memoria compartida podrá retomarlo.
		_comidas_sin_ruta[comida.get_instance_id()] = _reloj_vida + 0.6
		comida = null
		estado = Estado.EXPLORANDO
		_elegir_destino_al_azar()
		return
	_reubicando_frente = true
	_version_objetivo = comida.version_forma if comida is PiezaCasa else 0
	_version_mirada = -1
	estado = Estado.YENDO_A_COMIDA
	objetivo = destino
	_meta_ruta = Vector2.INF
	_ruta = PackedVector2Array()
	_indice_ruta = 0
	_espera_ruta = 0
	_esperando_ruta = false


func _volver() -> void:
	var regreso_inicial := _invertir_tramo_recorrido()
	run.colonia.exploracion.liberar(get_instance_id())
	_siguiendo_llamado = false
	_esperando_ruta = false
	_recuerdo = comida
	comida = null
	estado = Estado.VOLVIENDO
	_entradas_fallidas.clear()
	objetivo = run.entradas.elegir(global_position)
	_meta_ruta = Vector2.INF
	# Mientras espera el turno global puede desandar su ida comprobada.
	# El material sólo desaparece durante la run: esos segmentos no se
	# vuelven sólidos. No se inventa una recta hacia el nido ni otro A*.
	_ruta = regreso_inicial
	_indice_ruta = 0
	_espera_ruta = 0
	_reloj_visual = 0.0
	queue_redraw()


func _invertir_tramo_recorrido() -> PackedVector2Array:
	var vuelta := PackedVector2Array()
	if _ruta.is_empty() or not _origen_ruta.is_finite() or _ruta_fallida:
		return vuelta
	var indice := clampi(_indice_ruta, 0, _ruta.size())
	var anterior := _origen_ruta if indice == 0 else _ruta[indice - 1]
	var siguiente := _ruta[mini(indice, _ruta.size() - 1)]
	# No reutilizar una ruta después de reposicionar una hormiga: debe seguir
	# sobre el segmento que realmente caminó. Es una comprobación O(1).
	if Geometry2D.get_closest_point_to_segment(global_position, anterior, siguiente).distance_squared_to(global_position) > 0.0001:
		return vuelta
	var ultimo := global_position
	for i in range(indice - 1, -1, -1):
		if ultimo.distance_squared_to(_ruta[i]) > 0.0001:
			vuelta.append(_ruta[i])
			ultimo = _ruta[i]
	if ultimo.distance_squared_to(_origen_ruta) > 0.0001:
		vuelta.append(_origen_ruta)
	return vuelta


## Quitar el agujero no bloquea el piso ni hace fallar la ruta anterior.
## Cambia únicamente los retornos hacia ese acceso, conservando su carga,
## recuerdo y muestras. La ruta nueva se pide en el turno normal de caminar.
func reasignar_entrada_quitada(punto: Vector2) -> void:
	if estado != Estado.VOLVIENDO or objetivo != punto:
		return
	_entradas_fallidas.erase(punto)
	objetivo = run.entradas.elegir(global_position, _entradas_fallidas)
	_meta_ruta = Vector2.INF
	_pedido_ruta = Vector2.INF
	_ruta = PackedVector2Array()
	_indice_ruta = 0
	_ruta_fallida = false
	_espera_ruta = 0
	_esperando_ruta = false


func _descargar() -> void:
	if carga > 0:
		_tiempo_descarga = _reloj_vida
	run.depositar(carga, objetivo, 0 if _material_carga <= 0 else (2 if _material_carga >= 3 else 1), _carga_origen)
	_vaciar_carga()
	if run.retirando:
		detener()
		return
	# Vuelve a la misma comida si sigue ahí: así se forman las filas de hormigas.
	if _comida_valida(_recuerdo) and _recuerdo.trabajadoras < _recuerdo.cupos_trabajo() and Comidas.en_territorio(_recuerdo, run.radio_actual):
		comida = _recuerdo
		estado = Estado.YENDO_A_COMIDA
		objetivo = comida.punto_mordida(global_position, run.radio_actual, casta == "voladora")
	else:
		estado = Estado.EXPLORANDO
		_elegir_destino_al_azar()
	_recuerdo = null


## La avispa retira sólo material que ya viajaba. No acredita ingreso ni
## vuelve a extraerlo del mapa: queda en su botín hasta vencerla o perderla.
func soltar_carga_para_robo() -> Dictionary:
	if not is_instance_valid(run) or not run.activa or run.terminada or carga <= 0.0:
		return {}
	var retirada := {"valor": carga, "material": _material_carga}
	_vaciar_carga()
	if estado == Estado.VOLVIENDO:
		estado = Estado.EXPLORANDO
		_ruta_fallida = false
		_elegir_destino_al_azar()
	return retirada


func _vaciar_carga() -> void:
	_carga_origen.fill(0.0)
	carga = 0.0
	_material_carga = -1
	bocados = 0
	_retazos.clear()
	_angulos_retazos.clear()
	_tamanos_retazos.clear()
	_origenes_retazos.clear()
	_tiempos_retazos.clear()
	_levantando_retazos = false
	if is_instance_valid(_carga_sprite):
		_carga_sprite.hide()
	_reloj_visual = 0
	queue_redraw()


func _elegir_destino_al_azar() -> void:
	_esperando_ruta = false
	objetivo = run.colonia.exploracion.elegir(get_instance_id(), global_position, run.radio_actual, run.cocina, casta == "voladora")
	_meta_ruta = Vector2.INF
	_ruta = PackedVector2Array()
	_indice_ruta = 0
	_espera_ruta = 0
	# La exploración dura lo necesario para llegar, no cambia de idea cada
	# dos segundos. Esperar turno de navegación no consume este plazo.
	_reloj_vagar = 2.0 + global_position.distance_to(objetivo) / maxf(_velocidad, 1) * 2.0 if objetivo != Vector2.INF else 1.0


## Sin tipo a propósito: la comida pudo haber sido destruida (liberada) y un
## parámetro tipado tiraría error al recibir un objeto liberado.
func _comida_valida(c) -> bool:
	return is_instance_valid(c) and c.disponible() and (not c is FragmentoCasa or RolesHormiga.puede_cargar(casta, c))


func _draw() -> void:
	if not is_instance_valid(_cuerpo):
		AspectoHormiga.dibujar(self, casta, _color, _fase, carga > 0.0, _color_carga)
	elif carga > 0 and Graficos.listo:
		# Los retazos adicionales comparten el CanvasItem de la hormiga.
		# Su levantado usa el tick visual compartido de 12 Hz sólo 0,28 s;
		# después quedan retenidos hasta otra carga o descarga, no por cuadro.
		for i in range(1, _retazos.size()):
			var region := _retazos[i]
			var tamano := region.size * _escala_retazo(region, i)
			var centro := _posicion_retazo(i)
			draw_set_transform(centro, _angulos_retazos[i])
			draw_texture_rect_region(Graficos.textura, Rect2(-tamano * 0.5, tamano), region)
		draw_set_transform(Vector2.ZERO)


func _guardar_retazo(fuente: Comida) -> void:
	var region := fuente.region_bocado()
	var tamano := fuente.tamano_bocado()
	if not region.has_area() or tamano.x <= 0 or tamano.y <= 0:
		return
	if _retazos.size() < 3:
		_retazos.append(region)
		_angulos_retazos.append(fuente.global_rotation - global_rotation)
		_tamanos_retazos.append(tamano)
		_origenes_retazos.append(fuente.origen_bocado())
		_tiempos_retazos.append(_reloj_vida)
	else:
		# Tres muestras del material transportado, no un límite al buche.
		# Retener las más recientes permite ver cada nuevo levantado incluso
		# con capacidad alta. El valor y su origen siguen en carga/_carga_origen;
		# no se agrandan retazos ni se crean otros sprites para representarlos.
		for i in 2:
			_retazos[i] = _retazos[i + 1]
			_angulos_retazos[i] = _angulos_retazos[i + 1]
			_tamanos_retazos[i] = _tamanos_retazos[i + 1]
			_origenes_retazos[i] = _origenes_retazos[i + 1]
			_tiempos_retazos[i] = _tiempos_retazos[i + 1]
		_retazos[2] = region
		_angulos_retazos[2] = fuente.global_rotation - global_rotation
		_tamanos_retazos[2] = tamano
		_origenes_retazos[2] = fuente.origen_bocado()
		_tiempos_retazos[2] = _reloj_vida
	_levantando_retazos = true
	_origen_retazo = _origenes_retazos[0]
	queue_redraw()


func _sonido_bocado(fuente: Comida) -> String:
	if fuente is FragmentoCasa:
		return "levantar"
	if DibujoHallazgo.tiene_forma(fuente.forma):
		return "mordida_carton"
	if fuente is PiezaCasa and (fuente.pieza.get("practica", false) or fuente.pieza.get("dibujo", {}).get("acabado", "") == "carton"):
		return "mordida_carton"
	# La gran mesa exige dieta 3 por progresión, pero sigue siendo madera.
	# El timbre describe el objeto; no cambia la categoría económica cargada.
	var material := MaterialesCasa.nivel_tipo(fuente.pieza.tipo) if fuente is PiezaCasa else _material_carga
	return ["mordida", "mordida_madera", "mordida_metal", "mordida_piedra"][clampi(material, 0, 3)]


## Sólo cambia el dibujo. La carga real y la posición física ya fueron
## resueltas por la mordida/ruta; nunca se interpolan ni se vuelven a cobrar.
func _posicion_retazo(indice: int) -> Vector2:
	var pinza := Vector2(5.8 - indice * 0.3, (1 if indice % 2 else -1) * 1.6 if indice > 0 else 0.0) + _desplazamiento_masticar
	if not _detalle_bocado or indice >= _origenes_retazos.size() or indice >= _tiempos_retazos.size():
		return pinza
	var edad := _reloj_vida - _tiempos_retazos[indice]
	return AspectoHormiga.levantar_retazo(to_local(_origenes_retazos[indice]), pinza, edad)


func _escala_retazo(region: Rect2, indice := 0) -> Vector2:
	if indice >= _tamanos_retazos.size():
		return Vector2.ONE
	# El atlas y la hormiga tienen escalas propias. Se compensan ambas para
	# que el retazo mida en el mundo exactamente lo que mide el hueco, también
	# al cambiar el zoom o el tamaño visual de la casta.
	var escala_mundo := Vector2(maxf(0.001, absf(global_scale.x)), maxf(0.001, absf(global_scale.y)))
	return _tamanos_retazos[indice] / escala_mundo / region.size

func _crear_sprite() -> void:
	_cuerpo = Sprite2D.new()
	_cuerpo.texture = Graficos.textura
	_cuerpo.region_enabled = true
	_cuerpo.region_filter_clip_enabled = true
	_cuerpo.scale = Vector2.ONE / 3.0
	add_child(_cuerpo)
	_carga_sprite = Sprite2D.new()
	_carga_sprite.texture = Graficos.textura
	_carga_sprite.region_enabled = true
	_carga_sprite.region_filter_clip_enabled = true
	_carga_sprite.region_rect = Graficos.regiones.carga
	_carga_sprite.position = Vector2(5, 0)
	_carga_sprite.scale = Vector2.ONE * 0.16
	add_child(_carga_sprite)
	_actualizar_sprite()
	queue_redraw()

func _actualizar_sprite() -> void:
	if not is_instance_valid(_cuerpo):
		if DisplayServer.get_name() != "headless":
			queue_redraw()
		return
	var cuadro := floori(fposmod(_fase, TAU) / TAU * Graficos.CUADROS)
	if _tipo_animacion != casta or _evolucion_animacion != _evolucion:
		_tipo_animacion = casta
		_evolucion_animacion = _evolucion
		_animacion = Graficos.animacion(casta, _evolucion)
		_animacion_masticar = Graficos.animacion(casta, _evolucion, true)
	_detalle_bocado = en_pantalla and run.camara.zoom.x >= 0.28
	var masticaba := _masticando_animacion
	_masticando_animacion = _esta_masticando() and not _animacion_masticar.is_empty()
	var fase_masticar := _reloj_vida * TAU * AspectoHormiga.CICLOS_MASTICAR + _desfase_masticar
	if _masticando_animacion:
		var cuadro_masticar := floori(fposmod(fase_masticar, TAU) / TAU * _animacion_masticar.size())
		_cuerpo.region_rect = _animacion_masticar[cuadro_masticar]
	else:
		_cuerpo.region_rect = _animacion[cuadro]
	_desplazamiento_masticar = Vector2.ZERO
	if _masticando_animacion:
		# La boca se apoya en el contacto YA calculado por la IA; no consulta
		# otra vez la geometría. Compensa también el cuerpo chico de las minis.
		var apoyo := clampf(to_local(_contacto_visual).length() - 6.7, 0.0, 14.0)
		_desplazamiento_masticar.x = apoyo * (0.9 + AspectoHormiga.cierre_masticar(fase_masticar) * 0.1)
	var progreso := clampf(1.0 - _reloj_mordida / maxf(_intervalo_mordida, 0.001), 0, 1) if estado == Estado.MORDIENDO else 0.0
	var preparacion := AspectoHormiga.preparar_bocado(progreso) if _detalle_bocado else 0.0
	var tiron := AspectoHormiga.pulso_bocado(_reloj_vida - _tiempo_bocado, 0.19) if _detalle_bocado and estado != Estado.QUIETA else 0.0
	var entrega := AspectoHormiga.pulso_bocado(_reloj_vida - _tiempo_descarga, 0.22) if _detalle_bocado and estado != Estado.QUIETA else 0.0
	var postura := AspectoHormiga.postura_bocado(preparacion, tiron, entrega, carga > 0 and _detalle_bocado and estado != Estado.QUIETA, _fase, _material_carga)
	postura.origin += _desplazamiento_masticar
	_cuerpo.transform = postura
	_cuerpo.modulate = Color(1.025, 1.025, 1.0) if estado == Estado.MORDIENDO else Color.WHITE
	_carga_sprite.visible = carga > 0
	if not _retazos.is_empty():
		var region := _retazos[0]
		_carga_sprite.region_rect = region
		_carga_sprite.rotation = _angulos_retazos[0]
		_carga_sprite.scale = _escala_retazo(region)
		_carga_sprite.modulate = Color.WHITE
		_carga_sprite.position = _posicion_retazo(0)
	else:
		_carga_sprite.rotation = 0
		_carga_sprite.region_rect = Graficos.regiones.get("resto:%d" % _material_carga, Rect2()) if _material_carga >= 0 else Graficos.regiones.get("carga", Rect2())
		_carga_sprite.scale = Vector2.ONE * (0.12 if _material_carga >= 0 else 0.16) * (1.55 if casta == "cargadora" else 1.0)
		_carga_sprite.modulate = Color.WHITE if _material_carga >= 0 else _color_carga
		_carga_sprite.position = Vector2(5, 0)
	if _retazos.size() > 1 and (masticaba or _masticando_animacion):
		# Los dos retazos retenidos también acompañan el apoyo de la cabeza.
		# Mismo tick visible de 12 Hz; no agrega un proceso ni otro sprite.
		queue_redraw()
	if _levantando_retazos:
		# Sólo los dos retazos secundarios necesitan redibujarse. Se reutiliza
		# el tick visual de 12 Hz, durante como máximo 0,28 s por muestra.
		if _retazos.size() > 1:
			queue_redraw()
		_levantando_retazos = _detalle_bocado and not _tiempos_retazos.is_empty() and _reloj_vida - _tiempos_retazos.back() < AspectoHormiga.DURACION_LEVANTADO


## Sólo visual y sólo con contacto confirmado por el trabajo real. Preparar
## una máscara, seguir feromonas o esperar una ruta no simulan estar comiendo.
func _esta_masticando() -> bool:
	return _detalle_bocado and estado == Estado.MORDIENDO and _masticando_visual and _contacto_visual.is_finite() and _comida_valida(comida) and not run.retirando and run.activa and absf(angle_difference(rotation, _angulo_mordida)) < 0.5
