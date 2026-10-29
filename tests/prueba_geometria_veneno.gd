extends Node
## Mismo alcance exacto y mismo veneno; menos consultas lejanas y redibujos.
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
	run.queue_free()
	await get_tree().process_frame
	print("Geometría y veneno: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func crear_run() -> Run:
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	return run


func comparar_alcance(parte: PiezaCasa) -> Dictionary:
	var r := parte.rect_mundo
	var xs := [r.position.x - 14, r.position.x - 13, r.position.x - 12, r.position.x, r.get_center().x, r.end.x, r.end.x + 12, r.end.x + 13, r.end.x + 14]
	var ys := [r.position.y - 14, r.position.y - 13, r.position.y - 12, r.position.y, r.get_center().y, r.end.y, r.end.y + 12, r.end.y + 13, r.end.y + 14]
	var iguales := true
	for x in xs:
		for y in ys:
			var pos := Vector2(x, y)
			iguales = iguales and parte.alcanza_desde(pos) == (parte.distancia_a(pos) <= Cocina.MARGEN + 5)
	return {"igual": iguales, "puntos": xs.size() * ys.size()}


func probar_bordes(run: Run) -> void:
	var pieza := PiezaContada.new()
	run.comidas.add_child(pieza)
	pieza.iniciar({"clave": "borde_prueba", "tipo": "mesa", "rect": Rect2(150, 150, 300, 200), "color": Color.TAN, "pared": false, "dibujo": {"tipo": "mesa", "rect": Rect2(150, 150, 300, 200), "color": Color.TAN}}, run.cocina)
	var r := pieza.rect_mundo
	var bordes := [Vector2(r.position.x - 13, r.get_center().y), Vector2(r.end.x + 13, r.get_center().y), Vector2(r.get_center().x, r.position.y - 13), Vector2(r.get_center().x, r.end.y + 13)]
	var inclusivos := true
	for pos in bordes:
		inclusivos = inclusivos and pieza.alcanza_desde(pos)
	verificar(inclusivos, "los cuatro bordes incluyen exactamente las 13 unidades de alcance")
	verificar(not pieza.alcanza_desde(Vector2(r.end.x + 13.01, r.get_center().y)) and not pieza.alcanza_desde(r.end + Vector2(13, 13)), "el filtro conservador no convierte esquinas ni puntos lejanos en mordidas")
	pieza.queue_free()


func crear_comida(run: Run) -> Comida:
	var comida := Comida.new()
	run.comidas.add_child(comida)
	comida.configurar({"id": "miga", "nombre": "Miga", "forma": "miga", "color": Color.TAN, "vida": 1000.0, "recompensa": 1000.0, "radio": 5.0}, 1)
	return comida


func probar_comida(run: Run) -> void:
	var comida := crear_comida(run)
	var inicio := Juego.migas_run
	var factor := Juego.stat("multiplicador_migas")
	comida.aplicar_veneno(10, 1.25, run)
	comida._process(0.25)
	verificar(comida.vida == 1000 and Juego.migas_run == inicio and comida.is_processing(), "el veneno espera su primer medio segundo sin adelantar pagos")
	comida._process(0.25)
	verificar(is_equal_approx(comida.vida, 995) and is_equal_approx(Juego.migas_run - inicio, 5 * factor), "el primer medio segundo aplica y acredita exactamente un tick")
	comida.aplicar_veneno(2, comida.veneno_restante, run)
	comida._process(0.25)
	comida._process(0.25)
	verificar(is_equal_approx(comida.vida, 990), "renovar con veneno débil no suma ni reduce el DPS existente")
	comida._process(0.25)
	verificar(is_equal_approx(comida.vida, 987.5) and is_equal_approx(Juego.migas_run - inicio, 12.5 * factor), "el último cuarto de segundo se cobra una sola vez y sin perder fracción")
	verificar(comida.veneno_restante == 0 and comida._veneno_dps == 0 and comida._veneno_acumulado == 0 and not comida.is_processing(), "la comida deja de procesar al agotarse el veneno y su destello")
	var cobrado := Juego.migas_run
	comida._process(0.5)
	verificar(Juego.migas_run == cobrado, "procesar de nuevo un veneno terminado no duplica ingresos")
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
	var dano := 10 * 1.25 * (1.0 + Juego.stat("corrosion_factor"))
	var pago := pieza.recompensa * dano / pieza.vida_max * Juego.stat("multiplicador_migas") * 0.65
	pieza._sacudida = 1.7
	pieza._destello = 0.075
	pieza.aplicar_veneno(10, 1.25, run)
	for i in 80:
		# Muchas renovaciones mantienen el vencimiento, no agregan daño ni
		# eluden el reloj de la máscara. 1/64 representa exactamente 1,25 s.
		pieza.aplicar_veneno(2, pieza.veneno_restante, run)
		pieza._process(1.0 / 64)
	verificar(is_equal_approx(vida - pieza.vida, dano) and is_equal_approx(pieza.dano_recibido, dano), "la pieza conserva DPS, corrosión y último tick fraccionario")
	verificar(is_equal_approx(Juego.migas_run - ingreso, pago), "el veneno acredita sólo su proporción transportable y no duplica los fragmentos")
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


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print(("OK: " if ok else "FALLA: ") + detalle)
