extends Node
## Cierre por vaciado, registros comparables y entregas sin daño ni cobro mágico.
var total := 0
var fallas := 0
const RUN := preload("res://mundo/run.tscn")

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	await probar_recursos_pendientes()
	await probar_reloj_relevante()
	await probar_botin_recuperable()
	await probar_cierre_con_entrega()
	await probar_expansion_y_cadena()
	await probar_timeout_y_cancelacion()
	Juego.reiniciar_estado()
	print("Limpieza: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)

func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("OK " if ok else "FALLA ", detalle)

func crear() -> Run:
	Juego.reiniciar_estado()
	var r: Run = RUN.instantiate()
	add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	r.colonia._activa = false
	r.colonia._por_salir = 0
	# Escenario aislado: no se devora el mapa de preparación ni se cobran sus
	# recompensas. Se mantienen las colisiones para que las rutas sean reales.
	for grupo in [r.comidas.lista, r.comidas.partes, r.comidas.fragmentos]:
		for c: Comida in grupo:
			c.free()
		grupo.clear()
	r.comidas._indice.clear()
	r.comidas._pilas.clear()
	r.objetivo_mapa = null
	r.objetivo_practica = null
	r.colonia._nacer("obrera", Vector2.ZERO)
	return r

func alimento(r: Run, pos := Vector2(-100, -100)) -> Comida:
	var datos: Dictionary = Juego.comidas[0].duplicate()
	datos.vida = 100
	r.comidas._crear(datos, pos, 123)
	return r.comidas.lista.back()

func bloqueada(r: Run) -> PiezaCasa:
	var dibujo := {"tipo": "heladera", "rect": Rect2(300, 200, 100, 100), "color": Color.WHITE}
	var datos := {"tipo": "heladera", "rect": dibujo.rect, "color": Color.WHITE,
		"clave": "prueba:limpieza", "pared": false, "dibujo": dibujo}
	var parte := PiezaCasa.new()
	r.comidas.add_child(parte)
	parte.iniciar(datos, r.cocina)
	r.comidas.partes.append(parte)
	return parte

func probar_recursos_pendientes() -> void:
	var r := crear()
	var c := alimento(r)
	var h := r.colonia.hormigas[0]
	h._comidas_sin_ruta[c.get_instance_id()] = 100
	h._ruta_fallida = true
	c.trabajadoras = 64
	verificar(not r._comprobar_limpieza() and r.activa, "un recurso vivo impide declarar limpieza aunque sus puestos estén ocupados o falte una ruta")
	r.tiempo_jugado = 3.25
	c.morder(c.vida)
	r.comidas.soltar_fragmento(Vector2(-100, 0), 11, 0)
	verificar(not r._comprobar_limpieza(), "los fragmentos transportables también deben recogerse antes de limpiar")
	var resto: FragmentoCasa = r.comidas.fragmentos.back()
	resto.morder(1)
	var parte := bloqueada(r)
	parte.derrumbando = true
	verificar(not r._comprobar_limpieza(), "un derrumbe pendiente puede soltar fragmentos o tesoros y no se corta a mitad")
	parte.derrumbando = false
	alimento(r, Vector2(2000, 0))
	verificar(not r.comidas.estado_limpieza(r.radio_actual).pendientes and not r.comidas.estado_limpieza(r.radio_actual).completa, "se ignoran dieta bloqueada y comida fuera de alcance, distinguiendo limpieza parcial de mapa entero")
	verificar(r._comprobar_limpieza() and r.limpieza_lograda and not r.limpieza_completa, "terminar lo habilitado inicia retirada aunque el resto del mapa siga cerrado")
	r.queue_free()
	await get_tree().process_frame

func probar_cierre_con_entrega() -> void:
	var r := crear()
	var c := alimento(r)
	var h := r.colonia.hormigas[0]
	h.position = Vector2(25, 0)
	h._velocidad = 1000
	h.carga = 17
	h._carga_origen = [17.0, 0.0, 0.0]
	r.tiempo_jugado = 8.125
	c.morder(c.vida)
	var cobradas := Juego.migas_run
	r._process(0.5)
	verificar(r.retirando and not r.activa and r.limpieza_completa and is_equal_approx(r.tiempo_limpieza, 8.125), "la limpieza conserva el instante exacto del último recurso aunque se detecte medio segundo después")
	verificar(Juego.archivo_expediciones.is_empty(), "el registro espera las últimas entregas, no se guarda al empezar la retirada")
	for i in 20:
		h._process(0.05)
		r._process(0.05)
		if r.terminada:
			break
	verificar(r.terminada and h.carga == 0 and is_equal_approx(Juego.migas, cobradas + 17), "la retirada cobra la carga una sola vez antes del cierre automático")
	verificar(r.limpieza_registrada and r.nuevo_record_limpieza and Juego.archivo_expediciones.size() == 1, "la primera marca queda en el archivo y en el récord de su categoría")
	if not Juego.archivo_expediciones.is_empty():
		var registro: Dictionary = Juego.archivo_expediciones[0]
		verificar(is_equal_approx(registro.tiempo_limpieza, 8.125) and registro.tiempo_total > registro.tiempo_limpieza and registro.completa, "archivo separa tiempo de limpieza del total con entregas y distingue mapa completo")
	r._cerrar()
	verificar(Juego.archivo_expediciones.size() == 1 and Juego.runs_jugadas == 1, "repetir el cierre no duplica ni el archivo ni los ingresos")
	r._mostrar_fin()
	verificar(r.hud._lbl_fin_titulo.text == "¡Mapa despejado!" and "Limpieza:" in r.hud._lbl_fin_detalle.text, "el resultado de una limpieza muestra final propio y duración")
	r.hud._abrir_archivo()
	verificar(r.hud._ventana is PanelArchivo and r.hud._ventana.is_visible_in_tree(), "el resultado abre el archivo de expediciones como ventana consultable")
	r.hud._ventana.cerrar()
	verificar(not is_instance_valid(r.hud._ventana), "cerrar el archivo vuelve al resultado sin reanudar la extracción")
	r.queue_free()
	await get_tree().process_frame

func probar_reloj_relevante() -> void:
	var r := crear()
	var cercana := alimento(r)
	var lejana := alimento(r, Vector2(2000, 0))
	r.tiempo_jugado = 8.125
	cercana.morder(cercana.vida)
	r.tiempo_jugado = 8.3
	lejana.morder(lejana.vida)
	verificar(is_equal_approx(r.comidas.ultimo_cambio, 8.125), "destruir comida fuera del alcance después del último recurso no retrasa su marca")
	r.tiempo_jugado = 8.4
	alimento(r, Vector2(2200, 0))
	var cerrada := bloqueada(r)
	r.comidas._indexar(cerrada)
	verificar(is_equal_approx(r.comidas.ultimo_cambio, 8.125), "crear comida lejana o material de dieta bloqueada tampoco modifica el tiempo de limpieza")
	r.tiempo_jugado = 8.5
	verificar(r._comprobar_limpieza() and is_equal_approx(r.tiempo_limpieza, 8.125), "la comprobación posterior conserva el tiempo de la categoría y no el último cambio global")
	r.queue_free()
	await get_tree().process_frame
	r = crear()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1}
	Juego._cache_stats.clear()
	var pieza := bloqueada(r)
	pieza.destruida.connect(r.comidas._on_destruida)
	r.comidas._indexar(pieza)
	pieza.recompensa = 0 # Aislar el reloj de la pieza, sin restos que lo tapen.
	r.tiempo_jugado = 7.25
	pieza.morder_en(pieza.vida, pieza.position)
	verificar(is_equal_approx(r.comidas.ultimo_cambio, 7.25) and pieza.muerta, "la última pieza conserva su alcance inicial al quedar vacía y fecha correctamente su destrucción")
	r.queue_free()
	await get_tree().process_frame

func probar_botin_recuperable() -> void:
	var r := crear()
	var c := alimento(r)
	r.tiempo_jugado = 3.125
	c.morder(c.vida)
	var evento: Evento = r.eventos.aparecer("aspiradora")[0]
	evento.botin = 20
	verificar(not r._comprobar_limpieza() and r.activa, "el botín que todavía guarda una amenaza no desaparece por un cierre prematuro")
	r.tiempo_jugado = 3.375
	evento._vencer()
	r.tiempo_jugado = 3.5
	verificar(r._comprobar_limpieza() and is_equal_approx(r.tiempo_limpieza, 3.375), "resolver el botín fecha la limpieza exactamente sin redondear al chequeo de medio segundo")
	r.queue_free()
	await get_tree().process_frame
	r = crear()
	c = alimento(r)
	r.tiempo_jugado = 4.125
	c.morder(c.vida)
	evento = r.eventos.aparecer("rata")[0]
	evento.botin = 20
	var antes := Juego.migas_run
	r.tiempo_jugado = 4.25
	evento._terminar() # Huyó entre dos chequeos, sin pagar su botín.
	r.tiempo_jugado = 4.5
	verificar(r._comprobar_limpieza() and is_equal_approx(r.tiempo_limpieza, 4.25) and Juego.migas_run == antes, "una amenaza que escapa libera el cierre sin cobrar el botín ni perder su instante real")
	r.queue_free()
	await get_tree().process_frame

func probar_expansion_y_cadena() -> void:
	var r := crear()
	var c := alimento(r)
	r.tiempo_jugado = 2
	c.morder(c.vida)
	r.radio_actual = Juego.stat("radio_territorio") - 100
	verificar(not r._comprobar_limpieza(), "no cierra durante la expansión inicial del territorio")
	r.radio_actual = Juego.stat("radio_territorio")
	r.colonia._por_salir = 2
	verificar(not r._comprobar_limpieza(), "no cierra antes de que termine de salir la colonia inicial")
	r.colonia._por_salir = 0
	r.reglas._pendientes.append({})
	verificar(not r._comprobar_limpieza(), "las cadenas pendientes pueden generar nuevos restos y deben terminar")
	r.reglas._pendientes.clear()
	# Si el último recurso termina con veneno tras perder la última hormiga,
	# la colonia ya estuvo operativa: no debe esperar inútilmente al reloj.
	r.colonia.perder(r.colonia.hormigas[0])
	verificar(r._comprobar_limpieza(), "la comprobación termina al quedar estable aunque la última hormiga ya no esté")
	r.queue_free()
	await get_tree().process_frame

func probar_timeout_y_cancelacion() -> void:
	var r := crear()
	alimento(r)
	r.tiempo_restante = 0.1
	r._process(0.2)
	r._process(0.2)
	verificar(r.terminada and not r.limpieza_lograda and Juego.archivo_expediciones.is_empty(), "el tiempo agotado con recursos restantes no fabrica una marca de limpieza")
	r._mostrar_fin()
	verificar(r.hud._lbl_fin_titulo.text == "¡Se acabó el tiempo!", "el fin por tiempo conserva su título diferente")
	r.queue_free()
	await get_tree().process_frame
	r = crear()
	var c := alimento(r)
	r.tiempo_jugado = 4
	c.morder(c.vida)
	var h := r.colonia.hormigas[0]
	h.carga = 99
	h._velocidad = 0
	r._comprobar_limpieza()
	r._process(Juego.stat("retirada") + 0.1)
	verificar(r.terminada and r.cargas_pendientes == 99 and Juego.archivo_expediciones.size() == 1, "una carga que no llega respeta el límite de retirada y no bloquea el registro")
	verificar(Juego.archivo_expediciones[0].pendiente == 99 and Juego.migas < 99, "el archivo informa lo pendiente sin acreditarlo mágicamente")
	r.queue_free()
	await get_tree().process_frame
	r = crear()
	c = alimento(r)
	r.tiempo_jugado = 5
	c.morder(c.vida)
	r._comprobar_limpieza()
	r._cerrar() # Salir al menú antes de resolver la retirada.
	verificar(Juego.archivo_expediciones.is_empty(), "abandonar a mitad de la retirada no guarda una limpieza terminada")
	r.queue_free()
	await get_tree().process_frame
	r = crear()
	c = alimento(r)
	r.tiempo_jugado = 44.99
	r.tiempo_restante = 0.01
	c.morder(c.vida)
	r._process(0.02)
	verificar(r.limpieza_lograda and r.retirando and is_equal_approx(r.tiempo_limpieza, 44.99), "completar en el último intervalo del reloj cuenta como limpieza y no como tiempo agotado")
	r.queue_free()
	await get_tree().process_frame
