extends Node
## Prueba de humo: verifica que el juego arranca, que una run se juega de punta
## a punta sin errores y que la tienda se arma. No toca tu partida guardada.
##
## Correr desde la terminal:
##   godot --headless --path . res://tests/prueba_humo.tscn
## Termina con código 0 si todo anduvo, 1 si algo falló.

const ESCENA_RUN := preload("res://mundo/run.tscn")
const ESCENA_TIENDA := preload("res://ui/tienda.tscn")
const VELOCIDAD := 6.0

var _fallas: Array[String] = []
var _total := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")  # las verificaciones leen textos en español
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	await _probar_datos()
	await _probar_formato()
	var migas_base := await _probar_run("run inicial", false)
	await _probar_compras()
	var migas_mejorada := await _probar_run("run con mejoras", true)
	_verificar(migas_mejorada > migas_base, "una run con mejoras da más migas (%s > %s)" % [
		Juego.formatear(migas_mejorada), Juego.formatear(migas_base)])
	await _probar_tienda()
	_terminar()


func _probar_datos() -> void:
	_verificar(Juego.stats_base.size() > 0, "se leyeron las stats base")
	_verificar(Juego.mejoras.size() > 0, "se leyeron %d mejoras" % Juego.mejoras.size())
	_verificar(Juego.comidas.size() > 0, "se leyeron %d tipos de comida" % Juego.comidas.size())
	_verificar(Juego.stat("hormigas_iniciales") >= 1.0, "hay al menos una hormiga inicial")


func _probar_formato() -> void:
	var casos := {0.0: "0", 999.0: "999", 1234.0: "1.23K", 15600.0: "15.6K", 2500000.0: "2.50M"}
	for n in casos:
		_verificar(Juego.formatear(n) == casos[n], "formatear(%s) = %s (dio %s)" % [n, casos[n], Juego.formatear(n)])


func _probar_run(nombre: String, con_feromonas: bool) -> float:
	var run: Run = ESCENA_RUN.instantiate()
	add_child(run)
	Engine.time_scale = VELOCIDAD
	_verificar(run.comidas.lista.size() > 50, "%s: se generó el mapa (%d comidas)" % [nombre, run.comidas.lista.size()])
	var cuadros := 0
	var comida_lejana := _comida_mas_lejana_alcanzable(run)
	while not run.terminada and cuadros < 20000:
		if con_feromonas and is_instance_valid(comida_lejana):
			var t := clampf((run.duracion_total - run.tiempo_restante) / 14, 0, 1)
			run.feromonas.mantener_en(comida_lejana.position * t)
		await get_tree().process_frame
		cuadros += 1
	Engine.time_scale = 1.0
	_verificar(run.terminada, "%s: terminó" % nombre)
	_verificar(run.colonia.cantidad() >= int(Juego.stat("hormigas_iniciales")), "%s: nacieron %d hormigas" % [nombre, run.colonia.cantidad()])
	_verificar(Juego.migas_run > 0.0, "%s: juntó %s migas (%d comidas destruidas)" % [
		nombre, Juego.formatear(Juego.migas_run), Juego.comidas_destruidas_run])
	var migas := Juego.migas_run
	await get_tree().create_timer(1.0, true, false, true).timeout  # dejar que aparezca el panel de fin
	run.queue_free()
	await get_tree().process_frame
	return migas


func _comida_mas_lejana_alcanzable(run: Run) -> Comida:
	var mejor: Comida = null
	for c in run.comidas.lista:
		if Comidas.en_territorio(c, Juego.stat("radio_territorio")) and (mejor == null or c.radio > mejor.radio):
			mejor = c
	return mejor


func _probar_compras() -> void:
	Juego.migas = 10_000_000.0  # alcanza para las tres dietas (paredes cuesta 4M)
	var antes := Juego.stat("hormigas_iniciales")
	for _vuelta in 6:
		for m in Juego.mejoras:
			Juego.comprar(m.id)
	for c in Juego.castas:
		if c.comprable:
			Juego.comprar_casta(c.id)
	_verificar(Juego.total_especialistas() == 7, "se reclutó una unidad de cada casta para la run mejorada")
	_verificar(Juego.stat("hormigas_iniciales") > antes, "comprar mejoras cambia las stats")
	_verificar(not Juego.comprar("mandibulas_acero") or Juego.nivel_de("mandibulas") >= 10,
		"no se puede comprar una mejora bloqueada")
	print("    mejoras compradas: %s" % str(Juego.niveles))
	print("    stats: hormigas %d, daño %.1f, velocidad %.0f, territorio %.0f, duración %.0f s" % [
		Juego.stat("hormigas_iniciales"), Juego.stat("dano"), Juego.stat("velocidad"),
		Juego.stat("radio_territorio"), Juego.stat("duracion_run")])
	Juego.migas = 0.0


func _probar_tienda() -> void:
	var tienda := ESCENA_TIENDA.instantiate()
	add_child(tienda)
	await get_tree().process_frame
	await get_tree().process_frame
	_verificar(tienda._tarjetas.size() == Juego.mejoras.size(), "la tienda muestra %d tarjetas" % tienda._tarjetas.size())
	for rama in tienda.SALAS:
		tienda._seleccionar(rama)
		var visibles := 0
		var esperadas := 0
		for m in Juego.mejoras:
			# Las mejoras de destino aparecen recién con la pestaña Viajes.
			if m.rama == rama and (m.destino == "" or Juego.revelado("viajes")):
				esperadas += 1
			if tienda._tarjetas[m.id].boton.visible:
				visibles += 1
		_verificar(visibles == esperadas, "%s muestra sus %d mejoras" % [rama, esperadas])
	tienda.queue_free()
	await get_tree().process_frame


func _verificar(condicion: bool, descripcion: String) -> void:
	_total += 1
	if condicion:
		print("  OK   ", descripcion)
	else:
		print("  FALLA ", descripcion)
		_fallas.append(descripcion)


func _terminar() -> void:
	if _fallas.is_empty():
		print("\nTodo bien: pasaron las %d verificaciones." % _total)
		get_tree().quit(0)
	else:
		print("\n%d falla(s):" % _fallas.size())
		for f in _fallas:
			print("  - ", f)
		get_tree().quit(1)
