extends Node
## Primeras expediciones reales: una obrera sin compras ni ingresos
## prefijados. Se mide sola y guiada a migas pequeñas existentes en el mapa.
const RUN := preload("res://mundo/run.tscn")
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Engine.max_fps = 0
	Engine.time_scale = 1.0
	var autonoma := await probar_segunda_obrera(false)
	var guiada := await probar_segunda_obrera(true)
	print("ARRANQUE AUTÓNOMO: %s" % JSON.stringify(autonoma))
	print("ARRANQUE GUIADO: %s" % JSON.stringify(guiada))
	Juego.reiniciar_estado()
	Engine.time_scale = 1.0
	print("Arranque solitario: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func probar_segunda_obrera(guiada: bool) -> Dictionary:
	Juego.reiniciar_estado()
	verificar(Juego.migas == 0 and Juego.stat("hormigas_iniciales") == 1 and Juego.stat("cria") == 0, "el ensayo empieza sin dinero y con una sola obrera, sin nacimientos regalados")
	var limite := 3 if guiada else 5
	var tiempo_limite := 180.0 if guiada else 240.0
	var resumen := {"guiada": guiada, "expediciones": [], "compra_en": 0, "tiempo_activo": 0.0, "migas_guiadas": 0, "limite_expediciones": limite}
	for expedicion in limite:
		seed(417)
		Engine.time_scale = 1.0
		var run: Run = RUN.instantiate()
		add_child(run)
		run.set_process_unhandled_input(false)
		run.feromonas.set_process_unhandled_input(false)
		var maximo_hormigas := 0
		var primer_ingreso := -1.0
		var objetivo: Comida
		var guias_reales := true
		var reloj := 0.0
		while not run.terminada:
			await get_tree().process_frame
			maximo_hormigas = maxi(maximo_hormigas, run.colonia.cantidad())
			if primer_ingreso < 0 and Juego.migas_run > 0:
				primer_ingreso = run.tiempo_jugado
			reloj -= get_process_delta_time()
			if guiada and reloj <= 0 and run.activa and not run.retirando:
				reloj = 0.5
				if not is_instance_valid(objetivo) or not objetivo.disponible():
					objetivo = miga_cercana(run)
					if objetivo != null:
						resumen.migas_guiadas += 1
				if is_instance_valid(objetivo):
					guias_reales = guias_reales and objetivo.id == "miga" and objetivo in run.comidas.lista and objetivo.en_territorio(run.radio_actual)
					# Sólo señalar un alimento generado normalmente: no crearlo,
					# acercarlo, morderlo por script ni adelantar su recompensa.
					run.feromonas.mantener_en(objetivo.position)
				else:
					run.feromonas.soltar()
		var tiempo := run.tiempo_jugado + run.tiempo_retirada
		resumen.tiempo_activo += tiempo
		resumen.expediciones.append({"numero": expedicion + 1, "ingreso": Juego.migas_run, "saldo": Juego.migas, "primera_entrega": primer_ingreso, "tiempo": tiempo})
		verificar(maximo_hormigas == 1, "la expedición %d usa exactamente una hormiga real (%s)" % [expedicion + 1, "guiada" if guiada else "autónoma"])
		verificar(primer_ingreso >= 0 and primer_ingreso < 10 and Juego.migas_run > 0, "una obrera sola encuentra, extrae y entrega recursos antes de diez segundos en la expedición %d" % (expedicion + 1))
		if guiada:
			verificar(guias_reales and resumen.migas_guiadas > 0, "la guía apunta sólo a migas pequeñas reales dentro del territorio y cambia al agotarse")
		run.queue_free()
		await get_tree().process_frame
		Engine.time_scale = 1.0
		if Juego.puede_comprar("mas_obreras"):
			var saldo := Juego.migas
			var precio := Juego.costo("mas_obreras")
			verificar(Juego.comprar("mas_obreras") and is_equal_approx(Juego.migas, saldo - precio), "la segunda obrera se paga con ingresos reales, sin adelantos ni regalos")
			resumen.compra_en = expedicion + 1
			break
	verificar(resumen.compra_en > 0 and resumen.compra_en <= limite and resumen.tiempo_activo <= tiempo_limite, "la primera compra llega en hasta %d expediciones reales y %.0f segundos activos (%s)" % [limite, tiempo_limite, "guiada" if guiada else "autónoma"])
	verificar(Juego.stat("hormigas_iniciales") == 2 and Juego.nivel_de("mas_obreras") == 1, "la primera compra transforma una obrera en dos y no salta etapas")
	return resumen


func miga_cercana(run: Run) -> Comida:
	var elegida: Comida
	var distancia := INF
	for comida in run.comidas.lista:
		if comida.id != "miga" or not comida.disponible() or not comida.en_territorio(run.radio_actual):
			continue
		var candidata := comida.position.length_squared()
		if candidata < distancia:
			distancia = candidata
			elegida = comida
	return elegida


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)
