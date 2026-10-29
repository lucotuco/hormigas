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
var _reloj_vagar := 0.0
var _ruta := PackedVector2Array()
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
var _proxima_memoria := 0.0
var _animacion: Array[Rect2] = []
var _tipo_animacion := ""
var _evolucion_animacion := -1
var _version_objetivo := -1
var _version_mirada := -1
var _posicion_mirada := Vector2.INF
var _angulo_mordida := 0.0
var _entradas_fallidas: Dictionary = {}
var _carga_origen: Array[float] = [0.0, 0.0, 0.0]

# Stats copiadas al nacer (no cambian durante la run).
var _velocidad := 60.0
var _olfato := 45.0
var _dano := 1.0
var _intervalo_mordida := 0.6
var _capacidad := 1


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
	_puesto = get_instance_id() % 12
	_corte = tipo == "carpintera" and Juego.evolucion_activa("corte")
	_contagio = tipo == "roja" and Juego.evolucion_activa("contagio")
	_barrido = tipo == "cargadora" and Juego.evolucion_activa("barrido")
	_camada = tipo == "reina" and Juego.evolucion_activa("camada")
	_evolucion = Juego.nivel_visual()
	if _corte or _contagio or _barrido or _camada:
		_evolucion = maxi(1, _evolucion)
	if casta == "reina" and Juego.hitos.has("primer_monumento"):
		_evolucion = 2
	if casta == "voladora":
		z_index = 2
	_reloj_pensar = randf() * INTERVALO_PENSAR
	_proxima_memoria = randf() * 0.6
	_fase = randf() * TAU
	_elegir_destino_al_azar()
	if Graficos.listo:
		_crear_sprite()
	else:
		Graficos.preparado.connect(_crear_sprite, CONNECT_ONE_SHOT)


func detener() -> void:
	estado = Estado.QUIETA
	_esperando_ruta = false
	comida = null
	run.colonia.exploracion.liberar(get_instance_id())

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
	_fase += delta * _velocidad * 0.24
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
		_volver()
		return
	if run.feromonas.llama_a(self):
		run.colonia.exploracion.liberar(get_instance_id())
		_siguiendo_llamado = true
		# Puede haberse liberado desde el último muestreo compartido del cursor.
		var elegida = run.feromonas.objetivo_comida
		if not _comida_valida(elegida):
			elegida = null
		if elegida is FragmentoCasa and elegida.peso > RolesHormiga.peso_maximo(casta):
			elegida = null
		# Una orden sobre suelo o sobre comida ya agotada sigue reuniendo a la
		# colonia, pero al llegar no la deja inmóvil entre migas libres. La
		# búsqueda es local, respeta cupos y se espacia: no suma trabajo por cuadro.
		if elegida == null:
			if _comida_valida(comida) and comida.distancia_a(run.feromonas.posicion) < _olfato:
				elegida = comida
			elif global_position.distance_squared_to(run.feromonas.posicion) < 24 * 24 and _reloj_vida >= _proxima_busqueda_llamado:
				_proxima_busqueda_llamado = _reloj_vida + 0.6
				elegida = run.comidas.buscar_cercana(global_position, _olfato, run.radio_actual, _comidas_sin_ruta, casta)
				if elegida != null:
					run.colonia.avistar(elegida)
		if _comida_valida(elegida) and elegida.alcanza_desde(global_position):
			comida = elegida
			if estado != Estado.MORDIENDO:
				_reloj_mordida = _intervalo_mordida * 0.4
			estado = Estado.MORDIENDO
			return
		comida = elegida if _comida_valida(elegida) else null
		if comida != null:
			_actualizar_puesto()
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
		if comida.alcanza_desde(global_position):
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
	var umbral := 144.0 if estado == Estado.SIGUIENDO else 16.0
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
		if necesita_ruta and (_espera_ruta > 0 or _meta_ruta == Vector2.INF):
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
			elif comida.alcanza_desde(global_position):
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
	var hacia := (comida.global_position - global_position).angle()
	if comida is PiezaCasa:
		# Mirar la piedra o la pata que se muerde, no el aire en el centro de
		# un arco. Alcance y orientación comparten la invalidación: una obrera
		# quieta no vuelve a recorrer las secciones del mueble en cada cuadro.
		# Cambiar de pieza, moverse o perder una sección obliga a comprobarlos.
		if _version_mirada != comida.version_forma or _posicion_mirada != global_position:
			if not comida.alcanza_desde(global_position):
				if carga > 0:
					_volver()
				else:
					estado = Estado.YENDO_A_COMIDA
					objetivo = comida.punto_mordida(global_position, run.radio_actual, casta == "voladora")
				return
			var direccion: Vector2 = comida.material_cercano(global_position) - global_position
			_angulo_mordida = direccion.angle() if direccion.length_squared() > 0.001 else hacia
			_version_mirada = comida.version_forma
			_posicion_mirada = global_position
		hacia = _angulo_mordida
	rotation = rotate_toward(rotation, hacia, VELOCIDAD_GIRO * delta)
	_reloj_mordida -= delta * run.factor_ritmo()
	if _reloj_mordida > 0.0:
		return
	_reloj_mordida += _intervalo_mordida
	var actual := comida
	var carga_previa := carga
	var corte_continuo: bool = _corte and actual is PiezaCasa and actual.nivel_requerido == 1
	if actual is PiezaCasa:
		var dano := _dano * RolesHormiga.dano(casta, actual.nivel_requerido) * run.reglas.factor_dano(actual)
		if _corte and actual.nivel_requerido == 1:
			var segundo: Vector2 = actual.siguiente_seccion(global_position)
			carga += actual.morder_en(dano * 0.75, global_position)
			carga += actual.morder_en(dano * 0.25, segundo)
			run.efectos.habilidad(global_position, segundo, Color("f1ce8c"))
		else:
			carga += actual.morder_en(dano, global_position)
		_material_carga = actual.nivel_requerido
	elif actual is FragmentoCasa:
		for i in 3:
			_carga_origen[i] += actual.origen[i]
		carga += actual.morder(_dano)
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
		carga += actual.morder(_dano)
		_material_carga = -1
	if corte_continuo:
		# La carpintera evolucionada produce en el frente; la colonia transporta.
		# El 35% ya cayó al morder: se agrega el 65% restante sin multiplicarlo.
		run.comidas.soltar_fragmento(global_position, carga - carga_previa, 1)
		carga = carga_previa
	elif not actual is FragmentoCasa:
		_carga_origen[0 if _material_carga <= 0 else (2 if _material_carga >= 3 else 1)] += carga - carga_previa
	if casta == "roja" and not actual.muerta:
		actual.aplicar_veneno(_dano * 0.8, 3.0, run)
		if _contagio and _reloj_habilidad <= 0:
			_reloj_habilidad = 1.5
			run.comidas.contagiar(global_position, actual, _dano * 0.4, run)
			run.efectos.habilidad(global_position, global_position + Vector2.from_angle(rotation) * 55, Color("acd870"))
	bocados += 1
	_color_carga = actual.color
	run.efectos.chispas(global_position + Vector2.from_angle(rotation) * 4.0, actual.color, 2, _material_carga)
	Sonido.tocar(["mordida", "mordida_madera", "mordida_metal", "mordida_piedra"][maxi(0, _material_carga)], randf_range(0.9, 1.1), 0.0)
	if corte_continuo:
		bocados = 0
		if actual.muerta:
			comida = null
			estado = Estado.EXPLORANDO
			_elegir_destino_al_azar()
		return
	if bocados >= _capacidad or actual.muerta:
		_volver()


func _volver() -> void:
	run.colonia.exploracion.liberar(get_instance_id())
	_siguiendo_llamado = false
	_esperando_ruta = false
	_recuerdo = comida
	comida = null
	estado = Estado.VOLVIENDO
	_entradas_fallidas.clear()
	objetivo = run.entradas.elegir(global_position)
	_meta_ruta = Vector2.INF
	_ruta = PackedVector2Array()
	_indice_ruta = 0
	_espera_ruta = 0
	queue_redraw()


func _descargar() -> void:
	run.depositar(carga, objetivo, 0 if _material_carga <= 0 else (2 if _material_carga >= 3 else 1), _carga_origen)
	_carga_origen.fill(0.0)
	carga = 0.0
	_material_carga = -1
	bocados = 0
	queue_redraw()
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
	return is_instance_valid(c) and c.disponible()


func _draw() -> void:
	if not is_instance_valid(_cuerpo):
		AspectoHormiga.dibujar(self, casta, _color, _fase, carga > 0.0, _color_carga)

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
	_cuerpo.region_rect = _animacion[cuadro]
	_cuerpo.modulate = Color(1.18, 1.18, 1.05) if estado == Estado.MORDIENDO else Color.WHITE
	_carga_sprite.visible = carga > 0
	_carga_sprite.region_rect = Graficos.regiones["resto:%d" % _material_carga] if _material_carga >= 0 else Graficos.regiones.carga
	_carga_sprite.scale = Vector2.ONE * (0.12 if _material_carga >= 0 else 0.16) * (1.55 if casta == "cargadora" else 1.0)
	_carga_sprite.modulate = Color.WHITE if _material_carga >= 0 else _color_carga
