class_name Run
extends Node2D
## Una run: la colonia tiene un tiempo limitado para comer todo lo que pueda.
##
## Este nodo coordina las piezas de la escena (comida, hormigas, feromonas,
## efectos, cámara y HUD) y decide cuándo empieza y termina la run.
## Convención: el hormiguero está en (0, 0) y todas las piezas cuelgan de
## nodos ubicados en el origen, así que posición local = posición global.

const ESCENA_TIENDA := "res://ui/tienda.tscn"
const ESCENA_MENU := "res://ui/menu.tscn"
const DURACION_EXPANSION := 1.8   # segundos que tarda en crecer el territorio al empezar
const VENTANA_COMBO := 1.2        # segundos entre depósitos para que el combo siga
const PROPORCION_PISOTON := 0.5   # el pisotón da la mitad de migas que una mordida de hormiga
const ALCANCE_PISADA_AUTO := 400.0  # el pisotón automático busca comida a esta distancia del cursor
const MAX_PISADAS_POR_CUADRO := 4
const INTERVALO_LIMPIEZA := 0.5

@onready var comidas: Comidas = $Comidas
@onready var cocina: Cocina = $Cocina
@onready var feromonas: Feromonas = $Feromonas
@onready var hormiguero: Hormiguero = $Hormiguero
@onready var colonia: Colonia = $Hormigas
@onready var niebla: Niebla = $Niebla
@onready var efectos: Efectos = $Efectos
@onready var camara: Camara = $Camara
@onready var hud: HUD = $HUD
## Amenazas de cada destino y migas doradas (se crea por código).
var eventos: Eventos

## Radio del territorio en este momento (se anima al empezar si creció).
var radio_actual: float = 0.0
var tiempo_restante: float = 0.0
var duracion_total: float = 0.0
var activa := false
var terminada := false
var combo := 0
var objetivo_mapa: PiezaCasa
var objetivo_practica: PiezaCasa
var recorrido: RecorridoDestino
var cola_erosion: ColaErosion
var preparador_mordiscos: PreparadorMordiscos
## Sólo los fixtures que comparan operaciones directas usan la referencia.
var preparacion_sincrona := false
## Compatibilidad de fixtures/perfiles anteriores al corte estricto. No hay
## fase de liquidación: se mantienen false/0 y nunca habilitan extracción.
var cerrando_erosion := false
var tiempo_espera_erosion := 0.0
var _extraccion_cerrada := false
var poderes: PoderesColonia
var reglas: ReglasDestino
var entradas: EntradasHormiguero
var retirando := false
var retiro_restante := 0.0
var ingresos: Array[float] = [0.0, 0.0, 0.0]
var tiempo_jugado := 0.0
var mejora_produccion := 0.0
var progreso_objetivo := 0.0
var cargas_pendientes := 0.0
var _reloj_retiro := 0.0
var tiempo_retirada := 0.0
var produccion_run := 0.0
var tenia_record := false
var objetivo_completado := false
var resistencia_total := 1.0
var resistencia_extraida := 0.0
var frenesi := 0.0
var frenesi_restante := 0.0
var _descanso_frenesi := 0.0
var _sillas_devoradas := 0
var _ultimo_efecto_deposito := -1000

var _reloj := 0.0
var _carga_pisadas := 0.0
var _ultimo_deposito := -100.0
var _ultimo_tic := -1
var limpieza_lograda := false
## Una amenaza se comió a todas las hormigas y no queda ninguna por salir.
var colonia_perdida := false
var limpieza_completa := false
var tiempo_limpieza := 0.0
var nuevo_record_limpieza := false
var limpieza_registrada := false
var _hubo_objetivos := false
var _reloj_limpieza := INTERVALO_LIMPIEZA
var _retiro_completado := false
var _colonia_operativa := false
var _tiempo_fin_botin := 0.0


func _ready() -> void:
	Engine.time_scale = 1.0
	Juego.iniciar_run()
	preparador_mordiscos = PreparadorMordiscos.new()
	add_child(preparador_mordiscos)
	preparador_mordiscos.iniciar(self)
	cola_erosion = ColaErosion.new()
	add_child(cola_erosion)
	cola_erosion.iniciar(self)
	duracion_total = Juego.stat("duracion_run")
	tiempo_restante = duracion_total
	camara.vista_cambiada.connect(feromonas.queue_redraw)
	camara.vista_cambiada.connect(niebla.queue_redraw)

	var radio_objetivo := Juego.stat("radio_territorio")
	var radio_inicio := radio_objetivo
	if Juego.radio_visto > 0.0:
		radio_inicio = minf(Juego.radio_visto, radio_objetivo)
	radio_actual = radio_inicio

	comidas.generar()
	_hubo_objetivos = comidas.estado_limpieza(radio_actual).pendientes
	reglas = ReglasDestino.new()
	add_child(reglas)
	reglas.run = self
	for parte in comidas.partes:
		resistencia_total += parte.vida
		if parte.pieza.get("meta", false):
			objetivo_mapa = parte
		if parte.pieza.get("practica", false):
			objetivo_practica = parte
	for c in comidas.lista:
		resistencia_total += c.vida_max
	resistencia_total += comidas.resistencia_reservada()
	recorrido = RecorridoDestino.new()
	add_child(recorrido)
	recorrido.iniciar(self)
	comidas.comida_destruida.connect(_on_comida_destruida)
	niebla.radio = radio_actual
	camara.ajustar_a_radio(radio_actual, true)

	if radio_objetivo > radio_inicio + 1.0:
		var tween := create_tween()
		tween.tween_interval(0.4)
		tween.tween_property(self, "radio_actual", radio_objetivo, DURACION_EXPANSION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(recorrido.queue_redraw)
		hud.mostrar_aviso(tr("¡El territorio creció!"))
		Sonido.tocar("crecer", 1.0, 0.0)

	colonia.iniciar(self)
	entradas = EntradasHormiguero.new()
	add_child(entradas)
	entradas.iniciar(self)
	eventos = Eventos.new()
	add_child(eventos)
	eventos.iniciar(self)
	eventos.botin_terminado.connect(_registrar_fin_botin)
	poderes = PoderesColonia.new()
	add_child(poderes)
	poderes.iniciar(self)
	activa = true
	recorrido.queue_redraw()
	# Un checkpoint entre el último objeto y su celebración puede contener
	# todo el trabajo hecho sin la corona. Resolverlo no repone ni paga material.
	if recorrido.conquista_pendiente():
		_conquistar_destino()
	hud._actualizar_meta()


func _exit_tree() -> void:
	if is_instance_valid(poderes):
		poderes.cerrar()
	if is_instance_valid(preparador_mordiscos):
		preparador_mordiscos.cancelar()
	if is_instance_valid(cola_erosion):
		cola_erosion.cancelar()
	Sonido.detener_mundo()
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	_reloj += delta
	niebla.radio = radio_actual
	camara.ajustar_a_radio(radio_actual)
	if retirando:
		tiempo_retirada += delta
		retiro_restante = maxf(0, retiro_restante - delta)
		_reloj_retiro -= delta
		if _reloj_retiro <= 0:
			_reloj_retiro = 0.2
			cargas_pendientes = 0
			for h in colonia.hormigas:
				cargas_pendientes += h.carga
			if cargas_pendientes <= 0 or retiro_restante <= 0:
				_retiro_completado = true
				_terminar()
		return
	if not activa:
		return
	# El padre corre antes que sus hijos: vencer el reloj cancela las fuentes
	# antes de que hormigas, veneno o colas reciban otro cuadro de trabajo.
	var paso := minf(maxf(0, delta), maxf(0, tiempo_restante))
	tiempo_jugado += paso
	tiempo_restante = maxf(0, tiempo_restante - maxf(0, delta))
	if tiempo_restante <= 0:
		_comprobar_limpieza()
		_iniciar_retirada()
		return
	poderes.procesar(paso)
	frenesi_restante = maxf(0, frenesi_restante - delta)
	_descanso_frenesi = maxf(0, _descanso_frenesi - delta)
	_pisotones_automaticos(delta)
	_reloj_limpieza -= delta
	if _reloj_limpieza <= 0 or tiempo_restante <= 0:
		_reloj_limpieza = INTERVALO_LIMPIEZA
		if _comprobar_limpieza():
			return
	var segundos := int(ceil(tiempo_restante))
	if segundos <= 5 and segundos != _ultimo_tic and segundos > 0:
		_ultimo_tic = segundos
		Sonido.tocar("tic", 1.0 + (5 - segundos) * 0.08, 0.0)
	if _colonia_sin_hormigas():
		colonia_perdida = true
		_iniciar_retirada()
		hud.mostrar_aviso(tr("¡Se comieron a toda la colonia! Termina la expedición"))
		return


## Sin hormigas en el mapa, ninguna por salir y sin una cría que llegue antes
## del final, la expedición ya no puede hacer nada: termina.
func _colonia_sin_hormigas() -> bool:
	_colonia_operativa = _colonia_operativa or colonia.cantidad() > 0
	if not _colonia_operativa or colonia.cantidad() > 0 or colonia._por_salir > 0:
		return false
	return not colonia.nacera_antes_de(tiempo_restante)


func _comprobar_limpieza() -> bool:
	if not activa or retirando or terminada:
		return false
	if not _clasificar_limpieza():
		return false
	_iniciar_retirada()
	return true


## Sólo material ya retirado puede contar como limpieza. La erosión pendiente
## al vencer el reloj no se liquida ni completa objetos durante la retirada.
func _clasificar_limpieza() -> bool:
	# No confundir la salida inicial o la expansión animada con un escenario
	# sin trabajo. Tampoco retirar mientras una cadena puede producir restos.
	_colonia_operativa = _colonia_operativa or colonia.cantidad() > 0
	if colonia._por_salir > 0 or not _colonia_operativa or radio_actual < Juego.stat("radio_territorio") - 1:
		return false
	if is_instance_valid(reglas) and not reglas._pendientes.is_empty():
		return false
	for evento in eventos.activos:
		if is_instance_valid(evento) and not evento.resuelto and evento.botin > 0:
			return false # Todavía puede recuperarse el recurso que se llevó.
	var estado := comidas.estado_limpieza(radio_actual)
	if estado.pendientes:
		_hubo_objetivos = true
		return false
	if not _hubo_objetivos:
		return false
	limpieza_lograda = true
	limpieza_completa = estado.completa
	tiempo_limpieza = maxf(0.001, minf(tiempo_jugado, maxf(comidas.ultimo_cambio, _tiempo_fin_botin)))
	return true


func _registrar_fin_botin() -> void:
	if activa:
		_tiempo_fin_botin = tiempo_jugado


func _unhandled_input(event: InputEvent) -> void:
	if not activa:
		return
	var tecla := event as InputEventKey
	if tecla and tecla.pressed and not tecla.echo and tecla.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		hud.pausar()


# =====================================================================
# Eventos del juego
# =====================================================================

## Lo llaman las hormigas al llegar al hormiguero con comida.
func depositar(cantidad: float, origen := Vector2.ZERO, categoria := 0, desglose: Array[float] = []) -> void:
	if cantidad <= 0.0 or terminada:
		return
	if activa and is_instance_valid(poderes):
		poderes.registrar_entrega()
	if desglose.size() == 3 and desglose[0] + desglose[1] + desglose[2] > 0:
		for i in 3:
			ingresos[i] += desglose[i]
		Juego.sumar_migas_run(cantidad)
	else:
		registrar_ingreso(cantidad, categoria)
	# El frenesí aparece desde la segunda run (ver Juego.REVELABLES).
	if activa and frenesi_restante <= 0 and _descanso_frenesi <= 0 and Juego.revelado("frenesi"):
		frenesi = minf(100, frenesi + reglas.carga_frenesi())
		if frenesi >= 100:
			frenesi = 0
			frenesi_restante = Juego.stat("frenesi_duracion")
			_descanso_frenesi = 18
			hud.mostrar_aviso(tr("¡FRENESÍ! La colonia trabaja más rápido"))
	if _reloj - _ultimo_deposito <= VENTANA_COMBO:
		combo += 1
	else:
		combo = 1
	_ultimo_deposito = _reloj
	Juego.mejor_combo_run = maxi(Juego.mejor_combo_run, combo)
	efectos.entrega(origen, cantidad, combo)
	Sonido.entrega(combo)
	var ahora := Time.get_ticks_msec()
	if ahora - _ultimo_efecto_deposito < 45:
		return
	_ultimo_efecto_deposito = ahora

	hormiguero.latir()
	hud.migas_voladoras(a_pantalla(origen), 1)
	hud.mostrar_combo(combo)


## Objetivo sugerido del recorrido; no cambia la libertad de las hormigas.
func objetivo_actual() -> PiezaCasa:
	return recorrido.objetivo_actual() if is_instance_valid(recorrido) else objetivo_mapa


func _on_comida_destruida(comida: Comida) -> void:
	if not activa or comida is FragmentoCasa or comida.retiro_amenaza:
		return
	if comida is PiezaCasa:
		reglas.parte_devorada(comida)
		Juego.partes_destruidas_run += 1
		hud.mostrar_aviso(tr("¡La colonia devoró: %s!") % comida.nombre)
		if comida.pieza.tipo == "silla" and not comida.pieza.get("practica", false):
			_sillas_devoradas += 1
			Juego.obtener_hito("primera_silla")
			if _sillas_devoradas >= 4:
				Juego.obtener_hito("cuatro_sillas")
		if recorrido.registrar_destruccion(comida) and not objetivo_completado:
			_conquistar_destino()
		if Juego.lugar_actual == "casa" and PlanoCasa.ambiente_en(comida.position) == "cocina":
			var queda := false
			for parte in comidas.partes:
				if not parte.pieza.pared and PlanoCasa.ambiente_en(parte.position) == "cocina":
					queda = true
					break
			if not queda:
				Juego.obtener_hito("cocina_vacia")
	else:
		Juego.comidas_destruidas_run += 1
	var bonus := comida.recompensa * Juego.stat("bonus_destruir") * Juego.stat("multiplicador_migas")
	registrar_ingreso(bonus, 2 if comida is PiezaCasa and comida.nivel_requerido >= 3 else (1 if comida is PiezaCasa else 0))

	var pos := comida.global_position
	if comida is PiezaCasa:
		efectos.epico(pos, comida.color, comida.radio)
	efectos.explosion(pos, comida.color, comida.radio)
	efectos.numero(pos, bonus, Color(1.0, 0.82, 0.3), clampf(0.9 + comida.radio / 30.0, 1.0, 2.4))
	if comida.radio >= 12.0:
		efectos.texto(pos + Vector2(0, -comida.radio - 10.0), tr("¡%s!") % comida.nombre, Color.WHITE, 1.1)
	hud.migas_voladoras(a_pantalla(pos), int(clampf(comida.radio / 2.5, 2, 16)))
	camara.sacudir(clampf(comida.radio * 0.35, 2.0, 18.0))
	Sonido.tocar("romper", clampf(1.7 - comida.radio / 45.0, 0.5, 1.7))


func _conquistar_destino() -> void:
	if objetivo_completado:
		return
	objetivo_completado = true
	var entregadas := Juego.completar_destino()
	if Juego.lugar_actual in ["obelisco", "coliseo", "eiffel"]:
		Juego.obtener_hito("primer_monumento")
	Conquista.celebrar_destino(self, entregadas)

## El clic manual sólo interactúa con eventos; no rompe alimentos ni muebles.
## Se conserva la mejora automática incorporada en main, limitada por cuadro.
## Devuelve las migas obtenidas.
func pisar(pos: Vector2, automatico := false) -> float:
	if not activa:
		return 0.0
	# Las amenazas y la miga dorada se pisan antes que la comida de abajo.
	if not automatico:
		eventos.pisar(pos)
		return 0.0
	var comida := comidas.comida_en(pos, radio_actual)
	if comida == null or comida is PiezaCasa or comida is FragmentoCasa:
		return 0.0
	var color := comida.color
	var lugar := comida.global_position
	var migas := comida.morder(Juego.stat("dano_clic")) * PROPORCION_PISOTON
	Juego.sumar_estadistica("pisotones")
	if migas > 0.0:
		registrar_ingreso(migas)
		efectos.numero(lugar + Vector2(0, -comida.radio), migas, Color(1.0, 0.97, 0.8), 0.9)
		hud.migas_voladoras(a_pantalla(lugar), 1)
	efectos.chispas(lugar, color, 6)
	if not automatico:
		camara.sacudir(1.5)
	Sonido.tocar("clic", randf_range(0.7, 0.85) if automatico else randf_range(0.9, 1.15), 0.0)
	return migas


## Pisada automática (mejora) y Guardia de la reina (jalea): pisotones solos
## sobre la comida más cercana al cursor, o al hormiguero si el cursor está
## lejos de la comida. La stat "pisotones_auto" son pisotones por segundo.
func _pisotones_automaticos(delta: float) -> void:
	var ritmo := Juego.stat("pisotones_auto")
	if ritmo <= 0.0:
		return
	_carga_pisadas = minf(_carga_pisadas + ritmo * delta, MAX_PISADAS_POR_CUADRO)
	while _carga_pisadas >= 1.0:
		_carga_pisadas -= 1.0
		var objetivo: Comida = null
		for centro in [get_global_mouse_position(), Vector2.ZERO]:
			objetivo = _comida_para_pisada(centro)
			if objetivo != null:
				break
		if objetivo == null:
			_carga_pisadas = 0.0
			return
		pisar(objetivo.global_position, true)


func _comida_para_pisada(centro: Vector2) -> Comida:
	var mejor: Comida = null
	var mejor_distancia := INF
	for c in comidas._candidatas(centro, ALCANCE_PISADA_AUTO):
		if c is PiezaCasa or c is FragmentoCasa or not c.en_territorio(radio_actual):
			continue
		var d := c.global_position.distance_squared_to(centro)
		if d < ALCANCE_PISADA_AUTO * ALCANCE_PISADA_AUTO and d < mejor_distancia:
			mejor = c
			mejor_distancia = d
	return mejor


func registrar_extraccion(cantidad: float) -> void:
	resistencia_extraida += maxf(0, cantidad)

func registrar_derrumbe() -> void:
	Juego.sumar_estadistica("derrumbes")
	Juego.obtener_hito("primer_derrumbe")

func factor_ritmo() -> float:
	return Juego.stat("frenesi_ritmo") if frenesi_restante > 0 else 1.0


func multiplicador_dano_activo() -> float:
	return poderes.multiplicador_dano() if is_instance_valid(poderes) else 1.0


func multiplicador_ritmo_activo() -> float:
	return poderes.multiplicador_ritmo() if is_instance_valid(poderes) else 1.0


func activar_rafaga() -> bool:
	if not is_instance_valid(poderes) or not poderes.activar():
		return false
	efectos.epico(camara.position, Color("e0bd75"), 90)
	Sonido.tocar("epico", 1.08)
	return true


func entradas_disponibles() -> int:
	return entradas.disponibles() if is_instance_valid(entradas) else 0


func iniciar_colocacion_entrada() -> bool:
	return is_instance_valid(poderes) and poderes.iniciar_colocacion()


func cancelar_colocacion_entrada() -> void:
	if is_instance_valid(poderes):
		poderes.cancelar_colocacion()


func colocar_entrada(pos: Vector2) -> bool:
	return is_instance_valid(poderes) and poderes.colocar(pos)

func registrar_ingreso(cantidad: float, categoria := 0) -> void:
	if terminada or cantidad <= 0:
		return
	ingresos[clampi(categoria, 0, 2)] += cantidad
	Juego.sumar_migas_run(cantidad)

func _iniciar_retirada() -> void:
	if retirando or terminada:
		return
	_detener_extraccion()
	retirando = true
	recorrido.queue_redraw()
	feromonas.soltar()
	colonia._activa = false
	retiro_restante = Juego.stat("retirada")
	for h in colonia.hormigas:
		if h.carga > 0:
			# Las que ya vuelven conservan el recorrido y su turno de navegación.
			# No disparar hasta 500 rutas nuevas justo al cerrar la expedición.
			if h.estado != Hormiga.Estado.VOLVIENDO:
				h._volver()
		else:
			h.detener()
	hud.mostrar_aviso(tr("¡A casa! Últimas entregas · no se extrae más material"))


func _terminar() -> void:
	if terminada:
		return
	_cerrar()
	Sonido.tocar("fin", 1.0, 0.0)
	# Cámara lenta un instante antes de mostrar el resultado.
	Engine.time_scale = 0.3
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_interval(0.8)
	tween.tween_callback(_mostrar_fin)


## Cierra la run y suma lo juntado (también al salir al menú desde la pausa).
func _cerrar() -> void:
	if terminada:
		return
	_detener_extraccion()
	retirando = false
	feromonas.soltar()
	terminada = true
	cola_erosion.cancelar()
	preparador_mordiscos.cancelar()
	Sonido.detener_mundo()
	efectos.limpiar()
	recorrido.queue_redraw()
	colonia.detener()
	progreso_objetivo = 1.0 if objetivo_completado else recorrido.progreso()
	produccion_run = Juego.migas_run / maxf(1, tiempo_jugado + tiempo_retirada)
	var previa := float(Juego.records_destino.get(Juego.lugar_actual, {}).get("produccion", 0.0))
	tenia_record = previa > 0
	mejora_produccion = (produccion_run / previa - 1) * 100 if previa > 0 else 0.0
	Juego.registrar_record(produccion_run, progreso_objetivo)
	Juego.registrar_maximo("mayor_colonia", colonia.cantidad())
	Juego.terminar_run()
	if limpieza_lograda and _retiro_completado:
		nuevo_record_limpieza = Juego.registrar_limpieza({
			"destino": Juego.lugar_actual, "dieta": int(Juego.stat("materiales")),
			"territorio": Juego.stat("radio_territorio"), "version_mapa": Mundos.VERSION_CONTENIDO,
			"recorrido": recorrido.contexto_inicial,
			"completa": limpieza_completa, "tiempo_limpieza": tiempo_limpieza,
			"tiempo_total": tiempo_jugado + tiempo_retirada, "retirando": tiempo_retirada,
			"migas": Juego.migas_run, "produccion": produccion_run, "pendiente": cargas_pendientes,
		})
		limpieza_registrada = true


func salir_al_menu() -> void:
	get_tree().paused = false
	if not terminada:
		_cerrar()
	get_tree().change_scene_to_file(ESCENA_MENU)


func _mostrar_fin() -> void:
	Engine.time_scale = 1.0
	hud.mostrar_fin()


func ir_a_tienda() -> void:
	get_tree().change_scene_to_file(ESCENA_TIENDA)


## El silbato es un corte real, no una fase de daño posterior. Crédito,
## preparaciones, veneno y dominó que todavía no retiraron material se pierden.
## Sólo la carga que una hormiga ya llevaba puede producir una última entrega.
func _detener_extraccion() -> void:
	if _extraccion_cerrada:
		return
	_extraccion_cerrada = true
	activa = false
	cerrando_erosion = false
	feromonas.soltar()
	cola_erosion.cancelar()
	preparador_mordiscos.conservar_propietarios([])
	preparador_mordiscos.cancelar()
	reglas._pendientes.clear()
	reglas.festin = 0
	reglas.set_process(false)
	if is_instance_valid(eventos):
		eventos.cerrar()
	for hijo in get_children():
		if hijo is Conquista:
			hijo.cancelar()
	poderes.cerrar()
	Sonido.detener_mundo()


## Convierte una posición del mundo a coordenadas de pantalla (para el HUD).
func a_pantalla(pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * pos
