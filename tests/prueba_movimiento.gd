extends Node
## Regresiones deterministas de llegada, llamado y muebles.
var fallas := 0


## Referencia anterior al descarte por AABB. Comparar los mismos obstáculos,
## sin caché auxiliar y con idéntico orden de sectores y bandas.
class CocinaAnterior extends Cocina:
	func libre(pos: Vector2, margen := 0.0, volando := false) -> bool:
		if not PlanoCasa.limites().grow(-50 - margen).has_point(pos):
			return false
		var a := Vector2i(((pos - Vector2.ONE * margen) / SECTOR).floor())
		var b := Vector2i(((pos + Vector2.ONE * margen) / SECTOR).floor())
		for x in range(a.x, b.x + 1):
			for y in range(a.y, b.y + 1):
				for clave in _sectores.get(Vector2i(x, y), []):
					if not _obstaculos.has(clave):
						continue
					var pieza: Dictionary = _obstaculos[clave]
					if volando and not pieza.pared:
						continue
					if pieza.has("recortes"):
						for rect in pieza.recortes:
							if rect.grow(margen).has_point(pos):
								return false
					elif pieza.rect.grow(margen).has_point(pos):
						return false
		return true

	func _cercanos(rect: Rect2, volando: bool) -> Array[Rect2]:
		var resultado: Array[Rect2] = []
		var vistos: Dictionary = {}
		var a := Vector2i((rect.position / SECTOR).floor())
		var b := Vector2i((rect.end / SECTOR).floor())
		for x in range(a.x, b.x + 1):
			for y in range(a.y, b.y + 1):
				for clave in _sectores.get(Vector2i(x, y), []):
					if vistos.has(clave) or not _obstaculos.has(clave):
						continue
					vistos[clave] = true
					var pieza: Dictionary = _obstaculos[clave]
					if not volando or pieza.pared:
						if pieza.has("recortes"):
							for recorte in pieza.recortes:
								if recorte.intersects(rect, true):
									resultado.append(recorte)
						else:
							if pieza.rect.intersects(rect, true):
								resultado.append(pieza.rect)
		return resultado


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")  # las verificaciones leen textos en español
	Sonido.silenciado = true
	Juego.reiniciar_estado()
	seed(731)
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.cocina.limite_rutas_por_cuadro = 0
	# La línea recta atraviesa la primera pata de silla.
	var inicio := Vector2(460, 0)
	var puntos := run.cocina.ruta(inicio, Vector2.ZERO, run.radio_actual)
	verificar(puntos.size() > 1, "la ruta rodea la pata de silla")
	var anterior := inicio
	var segura := true
	for p in puntos:
		segura = segura and run.cocina.segmento_libre(anterior, p) and p.length() < run.radio_actual
		anterior = p
	verificar(segura, "todos los segmentos son transitables y quedan dentro del territorio")
	var comida_libre := true
	for c in run.comidas.lista:
		comida_libre = comida_libre and run.cocina.libre(c.position, c.radio + 8)
	verificar(comida_libre, "la comida no aparece dentro de muebles")
	# Llegada exacta, incluso cuando un paso supera el radio del hormiguero.
	run.colonia._nacer()
	var h: Hormiga = run.colonia.hormigas.back()
	h.global_position = Vector2(20, 0)
	h.carga = 1
	h._velocidad = 1600
	h._volver()
	h._process(1.0 / 30.0)
	verificar(h.carga == 0 and Juego.migas_run == 1, "una hormiga rápida descarga sin orbitar el hormiguero")
	run.feromonas.mantener_en(Vector2(40, 0))
	h._pensar()
	verificar(h.estado == Hormiga.Estado.SIGUIENDO, "el llamado atrae a la hormiga cercana")
	run.feromonas.soltar()
	h._pensar()
	verificar(h.estado != Hormiga.Estado.SIGUIENDO, "soltar el llamado deja de atraer")
	# La comida puede asomar del límite: se llega a su borde sin salir del mapa.
	var borde: Comida = preload("res://mundo/comida.tscn").instantiate()
	run.add_child(borde)
	borde.position = Vector2(0, -run.radio_actual - 5)
	borde.configurar(Juego.comidas[0], 1)
	borde.radio = 20
	h.global_position = Vector2(0, -run.radio_actual + 20)
	h.comida = borde
	h.estado = Hormiga.Estado.YENDO_A_COMIDA
	h.objetivo = borde.position
	h._meta_ruta = Vector2.INF
	h._caminar(1.0 / 30.0)
	verificar(h.estado == Hormiga.Estado.MORDIENDO and h.global_position.length() < run.radio_actual, "alcanza comida del borde sin quedar empujando el límite")
	h.detener()
	h.comida = null
	borde.queue_free()
	# 500 regresos en paralelo, a distintas velocidades, detrás del mueble.
	var inicio_test := Time.get_ticks_msec()
	for i in 500:
		run.colonia._nacer()
		h = run.colonia.hormigas.back()
		h.global_position = inicio + Vector2(0, (i % 7) - 3)
		h._velocidad = 60 + i * 0.7
		h.carga = 1
		h._volver()
	var atravesaron := false
	for cuadro in 360:
		for ant in run.colonia.hormigas:
			if ant.carga > 0:
				ant._process(1.0 / 30.0)
				if not run.cocina.libre(ant.global_position, 7.5):
					atravesaron = true
	var pendientes := 0
	for ant in run.colonia.hormigas:
		if ant.carga > 0:
			pendientes += 1
	verificar(pendientes == 0, "500 hormigas vuelven y descargan sin quedar atrapadas (%d pendientes)" % pendientes)
	verificar(not atravesaron, "ninguna hormiga atraviesa los muebles")
	print("Simulación de 500 regresos: %d ms (prueba lógica, no benchmark gráfico)." % (Time.get_ticks_msec() - inicio_test))
	# La vista previa no altera la economía.
	var antes := Juego.stat("hormigas_iniciales")
	verificar(Juego.stat_tras_comprar("mas_obreras") == antes + 1 and Juego.stat("hormigas_iniciales") == antes, "la vista previa muestra una obrera adicional sin comprar")
	probar_descarte_por_limites(run.cocina)
	print("Pruebas de movimiento: %d fallas." % fallas)
	run.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if fallas == 0 else 1)


func probar_descarte_por_limites(cocina: Cocina) -> void:
	var referencia := CocinaAnterior.new()
	referencia._obstaculos = cocina._obstaculos
	referencia._sectores = cocina._sectores
	var puntos: Array[Vector2] = [Vector2.ZERO, Vector2(-2100, -1850), Vector2(8100, 5450)]
	var elegida: Dictionary = {}
	for pieza: Dictionary in cocina.piezas:
		var rect: Rect2 = pieza.rect
		puntos.append_array([rect.position, rect.end, rect.get_center(),
			rect.position - Vector2.ONE * 0.001, rect.end + Vector2.ONE * 0.001])
		if elegida.is_empty() and pieza.tipo == "silla":
			elegida = pieza
	comparar_consultas(cocina, referencia, puntos, "mapa completo")
	verificar(not elegida.is_empty(), "hay una silla real para comprobar recorte y eliminación")
	if not elegida.is_empty():
		var rect: Rect2 = elegida.rect
		var recortes: Array[Rect2] = [Rect2(rect.position, rect.size * Vector2(0.28, 0.75)),
			Rect2(rect.position + rect.size * Vector2(0.70, 0.40), rect.size * Vector2(0.30, 0.60))]
		for recorte: Rect2 in recortes:
			puntos.append_array([recorte.position, recorte.end, recorte.get_center()])
		cocina.recortar_pieza(elegida.clave, recortes)
		comparar_consultas(cocina, referencia, puntos, "recorte con hueco")
		var vacios: Array[Rect2] = []
		cocina.recortar_pieza(elegida.clave, vacios)
		comparar_consultas(cocina, referencia, puntos, "recortes vacíos con margen")
		# Un descriptor reemplazado directamente no hereda el AABB anterior.
		cocina._obstaculos[elegida.clave] = {"rect": rect, "pared": false, "recortes": recortes}
		comparar_consultas(cocina, referencia, puntos, "descriptor sin caché")
		cocina.quitar_pieza(elegida.clave)
		comparar_consultas(cocina, referencia, puntos, "pieza eliminada")
	referencia.free()


func comparar_consultas(cocina: Cocina, referencia: CocinaAnterior, puntos: Array[Vector2], etapa: String) -> void:
	var libres_iguales := true
	var segmentos_iguales := true
	var candidatos_iguales := true
	for punto: Vector2 in puntos:
		for margen: float in [0.0, 1.0, 8.0, 30.72, 64.0]:
			for volando: bool in [false, true]:
				var actual := cocina.libre(punto, margen, volando)
				var anterior := referencia.libre(punto, margen, volando)
				libres_iguales = libres_iguales and actual == anterior
		var fin := punto + Vector2(193, -137)
		var zona := Rect2(punto.min(fin), (fin - punto).abs()).grow(Cocina.MARGEN)
		for volando: bool in [false, true]:
			var actual := cocina.segmento_libre(punto, fin, volando)
			var anterior := referencia.segmento_libre(punto, fin, volando)
			segmentos_iguales = segmentos_iguales and actual == anterior
			candidatos_iguales = candidatos_iguales and cocina._cercanos(zona, volando) == referencia._cercanos(zona, volando)
	verificar(libres_iguales and segmentos_iguales and candidatos_iguales,
		"%s: AABB conserva puntos, cinco márgenes, segmentos y bandas exactas en suelo y vuelo" % etapa)


func verificar(condicion: bool, texto: String) -> void:
	print("  OK   " if condicion else "  FALLA ", texto)
	if not condicion:
		fallas += 1
