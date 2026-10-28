extends Node
var total := 0
var fallas := 0

func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")  # las verificaciones leen textos en español
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	seed(445)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.cocina.limite_rutas_por_cuadro = 0 # Esta prueba avanza muchos pasos en un solo cuadro real.
	var silla: PiezaCasa
	var heladera: PiezaCasa
	var muro: PiezaCasa
	for parte in run.comidas.partes:
		if parte.pieza.clave == "mueble:6":
			silla = parte
		if parte.pieza.tipo == "heladera":
			heladera = parte
		if parte.pieza.pared and parte.rect_mundo.has_point(Vector2(1700, -300)):
			muro = parte
	verificar(silla != null and heladera != null and muro != null and run.comidas.partes.size() > 100, "los muebles y muros por tramos son objetivos reales del mapa")
	verificar(Juego.stat("materiales") == 0 and not silla.disponible() and not heladera.disponible() and not muro.disponible(), "la colonia inicial sólo puede comer alimentos")
	var vida := silla.vida
	verificar(silla.morder(10000) == 0 and silla.vida == vida, "el daño no permite saltarse un material bloqueado")
	run.pisar(silla.position)
	verificar(silla.vida == vida, "no existe el daño por clic sobre muebles")
	Juego.migas = 1e8
	verificar(not Juego.comprar("mordida_madera"), "madera requiere primero mejorar las mandíbulas")
	Juego.comprar_lote("mandibulas", 4)
	verificar(Juego.comprar_lote("mordida_madera", 10) == 1 and Juego.stat("materiales") == 1, "la compra por lote desbloquea la etapa de madera una sola vez")
	verificar(silla.disponible() and not heladera.disponible() and not muro.disponible(), "madera y telas no desbloquean metal ni paredes")
	var punto := silla.punto_mordida(Vector2.ZERO, run.radio_actual)
	verificar(punto != Vector2.INF and silla.alcanza_desde(punto) and run.cocina.libre(punto, Cocina.MARGEN), "se ataca el borde del mueble sin entrar en su colisión")
	var previa := run.cocina.ruta(Vector2.ZERO, Vector2(460, 0), run.radio_actual)
	verificar(previa.size() > 1, "la silla intacta bloquea el recorrido directo")
	verificar(run.cocina._celdas_preparadas.size() < 2000, "la navegación inicial no prepara celdas de toda la casa")
	var h := run.colonia._nacer()
	h._dano = 100
	h._capacidad = 100
	h.position = punto
	h.comida = silla
	h._reloj_mordida = 1000
	h._morder(1.0)
	verificar(absf(angle_difference(h.rotation, (silla.material_cercano(punto) - punto).angle())) < 0.001, "la hormiga mira el material que muerde, no el centro transparente del dibujo")
	h._reloj_mordida = 0
	run.feromonas.mantener_en(silla.position)
	for paso in 800:
		run.feromonas._process(0.1)
		h._process(0.1)
		if not silla.muerta:
			silla._process(0.1)
		run.cocina.procesar_cambios()
		if silla.muerta:
			break
	verificar(silla.muerta, "mantener sobre una silla reúne hormigas que la devoran desde el borde")
	verificar(run.cocina.libre(silla.position, Cocina.MARGEN) and run.cocina.ruta(Vector2.ZERO, Vector2(460, 0), run.radio_actual).size() == 1, "la silla devorada libera colisión y permite un nuevo atajo")
	var celda_silla := Vector2i((silla.position / Cocina.CELDA).floor())
	verificar(not run.cocina._suelo.is_point_solid(celda_silla), "la grilla A* también libera las celdas que ocupaba el mueble")
	verificar(Juego.partes_destruidas_run == 1 and Juego.comidas_destruidas_run == 0, "el resultado cuenta por separado las partes de la casa")
	var version := run.cocina.version
	verificar(silla.morder(100) == 0 and run.cocina.version == version, "una pieza destruida no vuelve a pagar ni a modificar la navegación")
	run.feromonas.soltar()
	for paso in 800:
		if h.carga == 0:
			break
		h._process(0.1)
	verificar(h.carga == 0 and Juego.migas_run > 0, "las migas del mueble se transportan y depositan normalmente")
	verificar(Juego.comprar("mordida_resistente") and heladera.disponible() and not muro.disponible(), "la segunda etapa habilita electrodomésticos pero no muros")
	verificar(Juego.comprar("mordida_muros") and muro.disponible(), "la tercera etapa habilita paredes")
	var partida := Juego.datos_partida()
	Juego.reiniciar_estado()
	Juego.restaurar_partida(partida)
	verificar(Juego.stat("materiales") == 3, "los desbloqueos de materiales se conservan al guardar y cargar")
	run.radio_actual = 9500
	var a := Vector2(1645, -300)
	var b := Vector2(1850, -300)
	verificar(not run.cocina.segmento_libre(a, b), "un tramo de muro intacto separa dos ambientes")
	var grafo := run.cocina._suelo.get_instance_id()
	muro.morder(muro.vida + 1)
	verificar(run.cocina.segmento_libre(a, b) and run.cocina._suelo.get_instance_id() == grafo, "comer un tramo abre paso sin reconstruir los mapas de navegación")
	var correctas := true
	for i in 80:
		var pos := Vector2(randf_range(-500, 6500), randf_range(-700, 4300))
		var candidata := run.comidas.buscar_cercana(pos, 140, 9500)
		var distancia := INF
		for c in run.comidas.lista + run.comidas.partes + run.comidas.fragmentos:
			if not c.muerta and c.disponible() and c.en_territorio(9500):
				distancia = minf(distancia, c.distancia_a(pos))
		if distancia < 140:
			correctas = correctas and candidata != null and is_equal_approx(candidata.distancia_a(pos), distancia)
		else:
			correctas = correctas and candidata == null
	verificar(correctas, "la búsqueda espacial devuelve los mismos objetivos que revisar toda la casa")
	run.queue_free()
	await get_tree().process_frame
	var otra: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(otra)
	otra.process_mode = Node.PROCESS_MODE_DISABLED
	var reconstruida := false
	for parte in otra.comidas.partes:
		if parte.pieza.clave == "mueble:6":
			reconstruida = parte.vida == parte.vida_max and parte.disponible()
	verificar(reconstruida, "cada expedición reconstruye la casa y conserva la dieta desbloqueada")
	otra.queue_free()
	await get_tree().process_frame
	await probar_siluetas()
	print("Materiales y destrucción: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(0 if fallas == 0 else 1)

func probar_siluetas() -> void:
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	for destino in ["obelisco", "coliseo", "eiffel"]:
		Juego.lugar_actual = destino
		var run: Run = preload("res://mundo/run.tscn").instantiate()
		add_child(run)
		run.process_mode = Node.PROCESS_MODE_DISABLED
		run.radio_actual = 12000
		var meta := run.objetivo_mapa
		var vacio := meta.rect_mundo.position + meta.rect_mundo.size * Vector2(0.02, 0.02)
		verificar(run.cocina.libre(vacio, Cocina.MARGEN) and not meta.dentro_silueta(vacio), destino + ": la esquina transparente no bloquea ni selecciona el objeto")
		var suma := 0.0
		var sin_aire := true
		for i in meta.vidas.size():
			suma += meta.vidas[i]
			sin_aire = sin_aire and (meta.vidas[i] > 0) == meta.vivas.has(i)
		verificar(is_equal_approx(suma, meta.vida_max) and sin_aire and meta.celdas.size() <= 16, destino + ": se conserva la resistencia total sin celdas de aire comestibles")
		var alcanzables := true
		for i in 12:
			var desde := meta.position + Vector2.from_angle(i * TAU / 12) * meta.rect_mundo.size.length()
			var punto := meta.punto_mordida(desde, 12000)
			alcanzables = alcanzables and punto != Vector2.INF and run.cocina.libre(punto, Cocina.MARGEN) and meta.alcanza_desde(punto)
		verificar(alcanzables, destino + ": los puntos de trabajo quedan junto al material y fuera de la colisión")
		if destino != "obelisco":
			var uv := Vector2(0.35, 0.80) if destino == "coliseo" else Vector2(0.50, 0.90)
			var hueco := meta.rect_mundo.position + meta.rect_mundo.size * uv
			verificar(not meta.contiene_punto(hueco) and run.cocina.libre(hueco, Cocina.MARGEN), destino + ": el vano visible permite pasar")
		var punto := meta.punto_mordida(Vector2.ZERO, 12000)
		meta.morder_en(meta.vida_max * 0.18, punto)
		verificar(meta.vivas.size() < meta._celdas_ocupadas and not meta.muerta and run.cocina.libre(vacio, Cocina.MARGEN), destino + ": una rotura quita material sin reponer colisión en la transparencia")
		for paso in 100:
			if meta.muerta:
				break
			if meta.derrumbando:
				meta._process(0.1)
			else:
				meta.morder(meta.vida_max * 0.1)
		verificar(meta.muerta, destino + ": no quedan celdas transparentes imposibles de terminar")
		run.queue_free()
		await get_tree().process_frame

func verificar(ok: bool, mensaje: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", mensaje)
