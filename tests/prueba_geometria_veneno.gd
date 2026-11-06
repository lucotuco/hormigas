extends Node
## Alcance geométrico exacto y veneno sin cambios; menos consultas lejanas.
var total := 0
var fallas := 0

class PiezaContada extends PiezaCasa:
	var consultas_distancia := 0
	var actualizaciones_mascara := 0
	var aplicaciones_visuales := 0

	func distancia_a(pos: Vector2) -> float:
		consultas_distancia += 1
		return super.distancia_a(pos)

	func _mostrar_veneno() -> void:
		aplicaciones_visuales += 1
		super._mostrar_veneno()

	func _actualizar_mascara() -> void:
		actualizaciones_mascara += 1
		super._actualizar_mascara()


func _init() -> void:
	Juego.guardado_habilitado = false


func _ready() -> void:
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	for destino in Mundos.ORDEN:
		Juego.reiniciar_estado()
		Juego.lugar_actual = destino
		var run := crear_run()
		var iguales := true
		var puntos := 0
		for parte in run.comidas.partes:
			var resultado := comparar_alcance(parte)
			iguales = iguales and resultado.igual
			puntos += resultado.puntos
		verificar(iguales, "%s: rejilla y bordes equivalentes al alcance exacto en %d puntos" % [destino, puntos])
		var muestra := PiezaContada.new()
		run.comidas.add_child(muestra)
		muestra.iniciar(run.comidas.partes[0].pieza.duplicate(true), run.cocina)
		muestra.consultas_distancia = 0
		var lejanas := true
		for i in 600:
			lejanas = lejanas and not muestra.alcanza_desde(muestra.rect_mundo.end + Vector2(1000 + i, 1000))
		verificar(lejanas and muestra.consultas_distancia == 0, "%s: 600 consultas lejanas no recorren la silueta" % destino)
		if not muestra.vivas.is_empty():
			var seccion: int = muestra.vivas[0]
			muestra.vidas[seccion] = 0
			muestra.vivas.erase(seccion)
			muestra._reconstruir_formas()
		verificar(comparar_alcance(muestra).igual, destino + ": una pieza recortada mantiene la equivalencia")
		run.queue_free()
		await get_tree().process_frame
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var run := crear_run()
	probar_bordes(run)
	probar_comida(run)
	probar_pieza(run)
	probar_origen_contagio(run)
	run.queue_free()
	await get_tree().process_frame
	await probar_mancha_fuerte_real()
	print("Geometría y veneno: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func crear_run() -> Run:
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	run.preparacion_sincrona = true # Referencia síncrona de máscara/HP, no rendimiento.
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	return run


func comparar_alcance(parte: PiezaCasa) -> Dictionary:
	var r := parte.rect_mundo
	var alcance := Cocina.MARGEN + 5.0
	# Mismas 81 muestras por pieza: borde inclusivo y vecinos a0,001u de ambos
	# lados. Llegar al puesto físico de apoyo se prueba aparte: este filtro
	# conserva el alcance geométrico de13u, no autoriza detenerse antes.
	var xs := [r.position.x - alcance - 0.001, r.position.x - alcance, r.position.x - alcance + 0.001,
		r.position.x, r.get_center().x, r.end.x,
		r.end.x + alcance - 0.001, r.end.x + alcance, r.end.x + alcance + 0.001]
	var ys := [r.position.y - alcance - 0.001, r.position.y - alcance, r.position.y - alcance + 0.001,
		r.position.y, r.get_center().y, r.end.y,
		r.end.y + alcance - 0.001, r.end.y + alcance, r.end.y + alcance + 0.001]
	var iguales := true
	for x in xs:
		for y in ys:
			var pos := Vector2(x, y)
			iguales = iguales and parte.alcanza_desde(pos) == (parte.distancia_a(pos) <= alcance)
	return {"igual": iguales, "puntos": xs.size() * ys.size()}


func probar_bordes(run: Run) -> void:
	var pieza := PiezaContada.new()
	run.comidas.add_child(pieza)
	pieza.iniciar({"clave": "borde_prueba", "tipo": "mesa", "rect": Rect2(150, 150, 300, 200), "color": Color.TAN, "pared": false, "dibujo": {"tipo": "mesa", "rect": Rect2(150, 150, 300, 200), "color": Color.TAN}}, run.cocina)
	var r := pieza.rect_mundo
	var alcance := Cocina.MARGEN + 5.0
	var bordes: Array[Vector2] = [Vector2(r.position.x - alcance, r.get_center().y),
		Vector2(r.end.x + alcance, r.get_center().y),
		Vector2(r.get_center().x, r.position.y - alcance),
		Vector2(r.get_center().x, r.end.y + alcance)]
	var normales: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	var inclusivos := true
	var exteriores := true
	for i in bordes.size():
		inclusivos = inclusivos and pieza.alcanza_desde(bordes[i])
		exteriores = exteriores and not pieza.alcanza_desde(bordes[i] + normales[i] * 0.001)
	var esquinas: Array[Vector2] = [r.position - Vector2.ONE * alcance, r.end + Vector2.ONE * alcance,
		Vector2(r.position.x - alcance, r.end.y + alcance),
		Vector2(r.end.x + alcance, r.position.y - alcance)]
	for pos: Vector2 in esquinas:
		exteriores = exteriores and not pieza.alcanza_desde(pos)
	verificar(inclusivos, "los cuatro bordes incluyen exactamente las %.2f unidades de alcance geométrico" % alcance)
	verificar(exteriores, "los cuatro bordes rechazan 0,001u por fuera y las esquinas diagonales no cuentan como alcance")
	pieza.queue_free()


func crear_comida(run: Run) -> Comida:
	var comida := Comida.new()
	run.comidas.add_child(comida)
	comida.configurar({"id": "miga", "nombre": "Miga", "forma": "miga", "color": Color.TAN, "vida": 1000.0, "recompensa": 1000.0, "radio": 5.0}, 1)
	return comida


func probar_comida(run: Run) -> void:
	var comida := crear_comida(run)
	comida._preparar_mordiscos()
	var inicio := Juego.migas_run
	var factor := Juego.stat("multiplicador_migas")
	comida.aplicar_veneno(10, 1.25, run)
	comida._process(0.25)
	drenar_erosion(run)
	verificar(comida.vida == 1000 and Juego.migas_run == inicio and comida.is_processing(), "el veneno espera su primer medio segundo sin adelantar pagos")
	comida._process(0.25)
	drenar_erosion(run)
	verificar(conserva_trabajo(comida, 1000, 5) and is_equal_approx(Juego.migas_run - inicio, (1000 - comida.vida) * factor), "el primer tick conserva su trabajo y sólo acredita píxeles físicamente retirados")
	comida.aplicar_veneno(2, comida.veneno_restante, run)
	comida._process(0.25)
	comida._process(0.25)
	drenar_erosion(run)
	verificar(conserva_trabajo(comida, 1000, 10) and comida._veneno_dps == 10, "renovar con veneno débil conserva el DPS y el crédito fraccionario, sin sumarlos")
	comida._process(0.25)
	drenar_erosion(run)
	comida._process(0.1) # Último destello/upload, sin segundos de veneno nuevos.
	verificar(conserva_trabajo(comida, 1000, 12.5) and is_equal_approx(Juego.migas_run - inicio, (1000 - comida.vida) * factor), "el último cuarto de segundo conserva su fracción sin pagar material todavía pendiente")
	verificar(comida.veneno_restante == 0 and comida._veneno_dps == 0 and comida._veneno_acumulado == 0 and not comida.is_processing(), "la comida deja de procesar al agotarse el veneno y su destello")
	var cobrado := Juego.migas_run
	comida._process(0.5)
	verificar(Juego.migas_run == cobrado, "procesar de nuevo un veneno terminado no duplica ingresos")
	# Esta miga tiene mucha resistencia para su área: los primeros 12,5 HP
	# quedan bajo un píxel. Un tick adicional paga un píxel entero y debe
	# conservar también el trabajo fraccionario del veneno anterior.
	var cuanto := comida.mordiscos._hp_pixel[0]
	comida.aplicar_veneno(cuanto * 2, 0.5, run)
	comida._process(0.5)
	drenar_erosion(run)
	verificar(comida.vida < 1000 and conserva_trabajo(comida, 1000, 12.5 + cuanto) and is_equal_approx(Juego.migas_run - inicio, (1000 - comida.vida) * factor), "un siguiente tick suficiente desprende material sin perder ni cobrar dos veces el crédito anterior")
	cobrado = Juego.migas_run
	comida.aplicar_veneno(10, 2, run)
	run.activa = false
	comida._process(0.5)
	verificar(comida.veneno_restante == 0 and Juego.migas_run == cobrado and not comida.is_processing(), "terminar la expedición cancela el veneno de comida sin pagos posteriores")
	run.activa = true
	comida.queue_free()


func probar_pieza(run: Run) -> void:
	var pieza := PiezaContada.new()
	run.comidas.add_child(pieza)
	var datos: Dictionary
	for parte in run.comidas.partes:
		if parte.pieza.tipo == "mesa" and not parte.pieza.get("meta", false):
			datos = parte.pieza.duplicate(true)
			break
	pieza.iniciar(datos, run.cocina)
	var vida := pieza.vida
	var ingreso := Juego.migas_run
	# Esta dosis prueba el reloj completo sin agotar la pequeña mancha fija.
	# La prueba fuerte de la mesa real cubre por separado su corte terminal.
	var dano := 1.0 * 1.25 * (1.0 + Juego.stat("corrosion_factor"))
	var restos_iniciales := valor_fragmentos(run)
	pieza._sacudida = 1.7
	pieza._destello = 0.075
	pieza.aplicar_veneno(1.0, 1.25, run)
	for i in 80:
		# Muchas renovaciones mantienen el vencimiento, no agregan daño ni
		# eluden el reloj de la máscara. 1/64 representa exactamente 1,25 s.
		pieza.aplicar_veneno(0.2, pieza.veneno_restante, run)
		pieza._process(1.0 / 64)
		drenar_erosion(run)
	var retirado := vida - pieza.vida
	var conservado := conserva_trabajo(pieza, vida, dano)
	if not conservado or not is_equal_approx(pieza.dano_recibido, retirado):
		var credito := 0.0
		for cantidad in pieza.mordiscos._credito:
			credito += cantidad
		for cantidad in pieza.mordiscos._credito_erosion:
			credito += cantidad
		print("DIAG VENENO aportado=", dano, " retirado=", retirado, " credito=", credito,
			" dps=", pieza._veneno_dps, " ancla=", pieza._ancla_veneno,
			" descartado=", pieza.mordiscos.trabajo_erosion_descartado,
			" cola_emitido=", run.cola_erosion.trabajo_emitido, " cola_admitido=", run.cola_erosion.trabajo_admitido,
			" cola_cancelado=", run.cola_erosion.trabajo_cancelado_zona)
		diagnosticar_zona(pieza, pieza._ancla_veneno)
	verificar(conservado and is_equal_approx(pieza.dano_recibido, retirado), "la pieza conserva DPS y corrosión como material retirado más crédito menor a un píxel")
	var valor_retirado := pieza.recompensa * retirado / pieza.vida_max * Juego.stat("multiplicador_migas")
	verificar(is_equal_approx(Juego.migas_run - ingreso, valor_retirado * 0.65) and is_equal_approx(valor_fragmentos(run) - restos_iniciales, valor_retirado * 0.35), "el veneno paga y deja fragmentos sólo de material retirado, sin anticipar el crédito")
	verificar(pieza.aplicaciones_visuales == 81 and pieza.actualizaciones_mascara <= 16, "81 aplicaciones conservan el máximo de 12,5 actualizaciones de máscara por segundo")
	verificar(pieza._sacudida == 1.7 and pieza._destello == 0.075, "la pieza no procesa la sacudida ni el destello visual de Comida")
	verificar(pieza.veneno_restante == 0 and pieza.corrosion > 0 and pieza.is_processing(), "terminar el DPS mantiene el procesamiento mientras se desvanece la corrosión")
	for i in 160:
		pieza._process(1.0 / 64)
	verificar(pieza.corrosion == 0 and not pieza._sucio and not pieza.is_processing() and pieza._mascara.get_shader_parameter("corrosion") == 0.0, "la última máscara elimina la corrosión y recién entonces apaga el procesamiento")
	var cobrado := Juego.migas_run
	var dibujos := pieza.actualizaciones_mascara
	for i in 30:
		pieza._process(1.0 / 64)
	verificar(Juego.migas_run == cobrado and pieza.actualizaciones_mascara == dibujos, "una pieza quieta no agrega pagos ni actualizaciones de máscara")
	pieza.queue_free()


func diagnosticar_zona(pieza: PiezaCasa, ancla: Vector2) -> void:
	var m := pieza.mordiscos
	var zona := m.zona_erosion(ancla)
	var tamano := m.tamano_mascara()
	var paso := pieza.rect_mundo.size / Vector2(tamano)
	print("DIAG ZONA rect=", pieza.rect_mundo, " tamano=", tamano, " paso=", paso,
		" zona=", zona, " ratios_ini=", (zona.position - pieza.rect_mundo.position) / paso,
		" ratios_fin=", (zona.end - pieza.rect_mundo.position) / paso,
		" aire=", m.aire_exterior(ancla), " material_zona=", m.intersecta_rect(zona, true),
		" credito=", m._credito_erosion, " hp=", m._hp_pixel)
	for celda in pieza.vivas:
		if not m.limites_celda(celda).intersects(zona, true):
			continue
		print("DIAG CELDA i=", celda, " limites=", m.limites_celda(celda),
			" semilla=", m._buscar_pixel(celda, ancla, zona, false, true),
			" frontera=", m.punto_frontera(celda, ancla, zona, true), " vida=", m.vida_celda(celda))

func conserva_trabajo(fuente: Comida, vida_inicial: float, aportado: float) -> bool:
	var m := fuente.mordiscos
	var pendiente := 0.0
	var vida_material := 0.0
	for i in m._credito.size():
		if m._credito[i] < 0 or m._credito[i] >= m._hp_pixel[i] + 0.000001 or m._credito_erosion[i] < 0 or m._credito_erosion[i] >= m._hp_pixel[i] + 0.000001:
			return false
		pendiente += m._credito[i] + m._credito_erosion[i]
		vida_material += m.vida_celda(i)
	var retirado := vida_inicial - fuente.vida
	return retirado >= 0 and is_equal_approx(retirado + pendiente, aportado) and is_equal_approx(vida_material, fuente.vida)


func probar_origen_contagio(run: Run) -> void:
	var mesa: PiezaCasa
	for parte: PiezaCasa in run.comidas.partes:
		if parte.pieza.tipo == "mesa_comedor":
			mesa = parte
			break
	verificar(is_instance_valid(mesa), "el contagio se revisa sobre la mesa grande real del comedor")
	if not is_instance_valid(mesa):
		return
	var radio_anterior := run.radio_actual
	run.radio_actual = 12000.0
	var origen := Vector2(mesa.rect_mundo.position.x - 11.0, mesa.rect_mundo.get_center().y)
	var alimento := crear_comida(run)
	alimento.position = origen - Vector2(10.0, 0.0)
	# Aislar sólo las candidatas, no sustituir la silueta ni el veneno del mueble.
	run.comidas._indice.clear()
	run.comidas._indexar(alimento)
	run.comidas._indexar(mesa)
	var vida_anterior := mesa.vida
	var ingreso_anterior := Juego.migas_run
	var infectadas := run.comidas.contagiar(origen, alimento, 10.0, run)
	verificar(infectadas == 1 and mesa.veneno_restante == 2.0 and mesa._origen_veneno == origen,
		"el contagio conserva el origen real a la izquierda, no inventa otro al extremo derecho de la mesa")
	verificar(mesa._origen_veneno.x < mesa.rect_mundo.position.x and mesa.vida == vida_anterior and Juego.migas_run == ingreso_anterior,
		"contagiar no extrae ni cobra material antes del tick físico localizado")
	var ancla := mesa._ancla_veneno
	verificar(ancla.is_finite() and ancla.x < mesa.rect_mundo.get_center().x and ancla.distance_to(origen) < 16.0,
		"la mancha se ancla al contacto izquierdo inicial, no al actor remoto ni al centro del mueble")
	mesa.aplicar_veneno(20.0, 2.0, run, origen)
	verificar(mesa._ancla_veneno == ancla and mesa._origen_veneno == origen,
		"renovar la misma contaminación conserva el contacto inicial congelado")
	# El detector físico se prueba en la suite de material. Acá se confirma
	# que su notificación terminal no vuelve a emitir miles de ticks quietos.
	mesa.cancelar_veneno_en(ancla)
	for i in 1000:
		mesa.aplicar_veneno(20.0, 2.0, run, origen)
	verificar(mesa.erosion_origen_agotado(ancla) and mesa.veneno_restante == 0.0 and mesa._veneno_dps == 0.0 and mesa._veneno_acumulado == 0.0,
		"una zona confirmada vacía no revive por mil aplicaciones desde el mismo lugar")
	var nuevo_origen := origen + Vector2(0.0, 24.0)
	mesa.aplicar_veneno(20.0, 2.0, run, nuevo_origen)
	verificar(mesa._origen_veneno == nuevo_origen and mesa._ancla_veneno != ancla and mesa.veneno_restante == 2.0,
		"moverse realmente a otro frente permite una contaminación nueva sin borrar el cierre anterior")
	var ancla_b := mesa._ancla_veneno
	mesa.cancelar_veneno_en(ancla_b)
	mesa.aplicar_veneno(1000.0, 2.0, run, origen)
	verificar(mesa._anclas_veneno[origen].ancla == ancla and mesa._anclas_veneno[nuevo_origen].ancla == ancla_b \
		and mesa._anclas_veneno[origen].agotada and mesa._anclas_veneno[nuevo_origen].agotada \
		and mesa.veneno_restante == 0.0 and mesa._veneno_dps == 0.0,
		"A/B/A: dos manchas agotadas recuerdan sus contactos y una roja quieta no vuelve a anclarse más adentro")
	for i in 81:
		mesa.aplicar_veneno(20.0, 2.0, run, origen + Vector2(0.0, 100.0 + i))
	verificar(mesa._anclas_veneno.size() == Comida.MAX_ANCLAS_VENENO and mesa._orden_anclas_veneno.size() == Comida.MAX_ANCLAS_VENENO \
		and mesa._anclas_veneno_agotadas.size() <= Comida.MAX_ANCLAS_VENENO and mesa._cursor_anclas_veneno > 0,
		"el historial FIFO de actores, anclas y agotadas queda acotado a 64 lugares por recurso")
	run.radio_actual = radio_anterior
	alimento.queue_free()


func probar_mancha_fuerte_real() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var run := crear_run()
	run.radio_actual = 12000.0
	var mesa: PiezaCasa
	for parte: PiezaCasa in run.comidas.partes:
		if parte.pieza.tipo == "mesa_comedor":
			mesa = parte
			break
	verificar(is_instance_valid(mesa) and mesa.preparar_material(), "el veneno fuerte usa otra mesa real limpia y preparada")
	if not is_instance_valid(mesa) or mesa.mordiscos == null:
		run.queue_free()
		await get_tree().process_frame
		return
	var origen_a := Vector2(mesa.rect_mundo.position.x - 11.0, mesa.rect_mundo.get_center().y)
	var origen_b := origen_a + Vector2(0.0, 96.0)
	var vida_original := mesa.vida
	var anclas: Array[Vector2] = []
	for origen: Vector2 in [origen_a, origen_b]:
		var pixeles_antes := mesa.mordiscos._pixeles.duplicate()
		mesa.aplicar_veneno(mesa.vida_max * 100.0, 4.0, run, origen)
		var ancla := mesa._ancla_veneno
		anclas.append(ancla)
		var zona := mesa.mordiscos.zona_erosion(ancla)
		mesa._procesar_veneno(0.5)
		var pasos := 0
		var porciones := 0
		var acotadas := true
		while run.cola_erosion.tiene_pendientes() and pasos < 1000:
			run.cola_erosion.procesar(100000000, 1)
			pasos += 1
			var porcion := mesa.mordiscos.ultima_porcion
			if porcion.has_area():
				porciones += 1
				acotadas = acotadas and zona.grow(0.001).encloses(porcion) and porcion.size.x <= 16.001 and porcion.size.y <= 16.001
				if run.cola_erosion._trabajos.has(mesa.get_instance_id()):
					var tarea: Dictionary = run.cola_erosion._trabajos[mesa.get_instance_id()]
					acotadas = acotadas and porcion.grow(0.001).has_point(tarea.pos)
		verificar(pasos > 0 and porciones > 0 and acotadas and not run.cola_erosion.tiene_pendientes(),
			"cada turno del veneno fuerte retira una porción de hasta 16 dentro de su mancha inicial y termina")
		var cambiado := 0
		var remoto := false
		var tamano := mesa.mordiscos.tamano_mascara()
		var paso := mesa.rect_mundo.size / Vector2(tamano)
		for pixel in pixeles_antes.size():
			if pixeles_antes[pixel] == mesa.mordiscos._pixeles[pixel]:
				continue
			cambiado += 1
			var pos := mesa.rect_mundo.position + Vector2(pixel % tamano.x, pixel / tamano.x as int) * paso
			remoto = remoto or not zona.grow(0.001).encloses(Rect2(pos, paso))
		verificar(cambiado > 0 and not remoto and not mesa.muerta and mesa.vida > 0.0,
			"la comparación completa de píxeles confirma que no desaparece ningún material fuera de la zona contaminada")
		verificar(mesa.erosion_origen_agotado(ancla) and mesa.veneno_restante == 0.0 and mesa._veneno_dps == 0.0 and mesa._veneno_acumulado == 0.0,
			"agotar la mancha física corta el DPS y no deja un tramo reactivable infinito")
	var emitido := run.cola_erosion.trabajo_emitido
	var vida_final := mesa.vida
	var saldo := Juego.migas_run
	for i in 1000:
		mesa.aplicar_veneno(mesa.vida_max * 100.0, 4.0, run, origen_a if i % 2 == 0 else origen_b)
		mesa._procesar_veneno(0.5)
	verificar(mesa._anclas_veneno[origen_a].ancla == anclas[0] and mesa._anclas_veneno[origen_b].ancla == anclas[1] \
		and run.cola_erosion.trabajo_emitido == emitido and not run.cola_erosion.tiene_pendientes() \
		and mesa.vida == vida_final and Juego.migas_run == saldo and vida_final < vida_original,
		"A/B/A físico: mil renovaciones alternadas no trasladan el veneno al centro ni crean extracción o ingresos")
	run.queue_free()
	await get_tree().process_frame

func valor_fragmentos(run: Run) -> float:
	var valor := 0.0
	for f in run.comidas.fragmentos:
		if is_instance_valid(f) and not f.muerta:
			valor += f.recompensa
	return valor


func drenar_erosion(run: Run) -> void:
	for paso in 10000:
		if not run.cola_erosion.tiene_pendientes():
			return
		run.cola_erosion.procesar(100000000, 32)
	verificar(false, "la cola de erosión termina sin espera infinita")


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)
