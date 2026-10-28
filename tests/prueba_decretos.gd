extends Node
## Pisada automática (mejora temprana y Guardia de la reina) y decretos de la
## reina: al fundar se elige uno que rige toda la colonia nueva.
##   godot --headless --fixed-fps 60 --path . res://tests/prueba_decretos.tscn
var fallas := 0
var total := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")  # las verificaciones leen textos en español
	Sonido.silenciado = true
	probar_pisada_automatica_datos()
	await probar_pisada_automatica_en_run()
	probar_decretos()
	probar_partidas()
	await probar_ventana()
	Juego.reiniciar_estado()
	print("Pisada automática y decretos: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func probar_pisada_automatica_datos() -> void:
	Juego.reiniciar_estado()
	verificar(Juego.stat("pisotones_auto") == 0.0, "al empezar no hay pisotones automáticos")
	var m: Dictionary = Juego.mejoras_por_id.get("pisada_auto", {})
	verificar(not m.is_empty() and m.rama == "Mandíbulas" and m.requiere_id == "pisada", "la Pisada automática está en el taller y pide Pisotón")
	verificar(Juego.costo("pisada_auto") <= 60.0, "la primera Pisada automática es barata: se compra en los primeros minutos")
	Juego.niveles = {"pisada": 2, "pisada_auto": 2}
	Juego._cache_stats.clear()
	verificar(is_equal_approx(Juego.stat("pisotones_auto"), 1.0), "dos niveles: un pisotón automático por segundo")
	Juego.niveles_jalea = {"guardia": 1}
	Juego._cache_stats.clear()
	verificar(is_equal_approx(Juego.stat("pisotones_auto"), 2.0), "la Guardia de la reina suma uno más por segundo")
	Juego.coronas = 1
	Juego.fundar_colonia()
	verificar(is_equal_approx(Juego.stat("pisotones_auto"), 1.0), "al fundar se pierde la mejora pero la Guardia sigue")


func probar_pisada_automatica_en_run() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"pisada": 2, "pisada_auto": 6}
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.colonia.set_process(false)
	await get_tree().process_frame
	var antes := Juego.estadistica("pisotones")
	var migas := Juego.migas_run
	for i in 20:
		run._pisotones_automaticos(0.1)
	verificar(Juego.estadistica("pisotones") - antes == 6, "a 3 por segundo, en 2 segundos pisa 6 veces (%d)" % (Juego.estadistica("pisotones") - antes))
	verificar(Juego.migas_run > migas, "los pisotones automáticos dan migas")
	antes = Juego.estadistica("pisotones")
	run._pisotones_automaticos(10.0)
	verificar(Juego.estadistica("pisotones") - antes <= Run.MAX_PISADAS_POR_CUADRO, "un cuadro largo no dispara una ráfaga de pisotones")
	run.queue_free()
	await get_tree().process_frame


func probar_decretos() -> void:
	verificar(Juego.decretos.size() >= 4, "hay al menos cuatro decretos (%d)" % Juego.decretos.size())
	var con_costo := 0
	for d in Juego.decretos:
		var sube := false
		var baja := false
		for e in d.efectos:
			var mejora: bool = (e.tipo == "multiplica" and e.valor > 1.0) or (e.tipo == "suma" and e.valor > 0.0)
			if e.stat == "intervalo_mordida":
				mejora = not mejora  # más intervalo es peor
			if mejora:
				sube = true
			else:
				baja = true
		if sube and baja:
			con_costo += 1
	verificar(con_costo == Juego.decretos.size(), "cada decreto tiene una ventaja y un costo")
	var base := {}
	Juego.reiniciar_estado()
	for s in ["hormigas_iniciales", "dano", "dano_clic", "multiplicador_migas", "duracion_run", "radio_territorio", "cria"]:
		base[s] = Juego.stat(s)
	Juego.coronas = 1
	Juego.fundar_colonia("guerrera")
	verificar(Juego.decreto == "guerrera", "fundar con un decreto lo deja vigente")
	verificar(is_equal_approx(Juego.stat("dano_clic"), base.dano_clic * 3.0) and Juego.stat("hormigas_iniciales") < base.hormigas_iniciales, "la colonia guerrera pisa ×3 y tiene menos obreras")
	Juego.coronas = 1
	Juego.fundar_colonia("recolectora")
	verificar(Juego.stat("multiplicador_migas") > base.multiplicador_migas * 1.9 and Juego.stat("duracion_run") < base.duracion_run, "la colonia recolectora junta el doble y dura menos")
	verificar(Juego.stat("duracion_run") >= Juego.DURACION_MINIMA, "ninguna expedición baja de %d s" % Juego.DURACION_MINIMA)
	Juego.coronas = 1
	Juego.fundar_colonia("numerosa")
	verificar(Juego.stat("hormigas_iniciales") > base.hormigas_iniciales and Juego.stat("cria") > base.cria, "la colonia numerosa nace con más obreras y cría")
	Juego.coronas = 1
	Juego.fundar_colonia("inventado")
	verificar(Juego.decreto == "", "un decreto que no existe no se aplica")


func probar_partidas() -> void:
	Juego.reiniciar_estado()
	Juego.coronas = 1
	Juego.fundar_colonia("exploradora")
	var datos := Juego.datos_partida()
	verificar(datos.get("decreto") == "exploradora", "el decreto se guarda con la partida")
	Juego.reiniciar_estado()
	Juego.restaurar_partida(datos)
	verificar(Juego.decreto == "exploradora", "y se recupera al cargar")
	Juego.restaurar_partida({"decreto": "borrado"})
	verificar(Juego.decreto == "", "un decreto guardado que ya no existe se descarta")
	Juego.restaurar_partida({"version": 4, "niveles_jalea": {"guardia": 2}})
	verificar(Juego.nivel_jalea("guardia") == 2 and is_equal_approx(Juego.stat("pisotones_auto"), 2.0), "la Guardia comprada en partidas viejas da pisotones automáticos")


func probar_ventana() -> void:
	Juego.reiniciar_estado()
	Juego.coronas = 2
	Juego.migas_colonia = 1e7
	Juego.descubiertos = {"legado": true}
	var tienda: Control = preload("res://ui/tienda.tscn").instantiate()
	add_child(tienda)
	await get_tree().process_frame
	tienda._cambiar_pestana("legado")
	tienda._panel_legado._pedir_fundacion()
	await get_tree().process_frame
	var ventana: VentanaFundar = tienda._panel_legado._confirmar
	verificar(is_instance_valid(ventana) and ventana.get_parent() == tienda, "Fundar abre una ventana sobre toda la pantalla")
	verificar(ventana._tarjetas.size() == Juego.decretos.size(), "la ventana muestra todos los decretos")
	verificar(ventana.elegido == Juego.decretos[0].id, "en la primera fundación arranca elegido el primero")
	ventana._tarjetas.guerrera.pressed.emit()
	verificar(ventana.elegido == "guerrera", "tocar un decreto lo elige")
	var jalea := Juego.jalea_por_fundar()
	ventana.fundar()
	await get_tree().process_frame
	verificar(Juego.fundaciones == 1 and Juego.decreto == "guerrera" and Juego.jalea == jalea, "fundar desde la ventana aplica el decreto elegido")
	tienda._refrescar()
	verificar("Colonia guerrera" in tienda._lbl_proxima.text, "el hormiguero muestra el decreto vigente")
	Juego.coronas = 1
	tienda._panel_legado._pedir_fundacion()
	await get_tree().process_frame
	verificar(tienda._panel_legado._confirmar.elegido == "guerrera", "la próxima vez propone el decreto vigente")
	tienda.queue_free()
	await get_tree().process_frame


func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)
