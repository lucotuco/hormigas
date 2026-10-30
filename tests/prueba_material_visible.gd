extends Node
## El material transportable coincide con el cuerpo, nunca con su sombra.
## El flood fill de QA es independiente de la frontera retenida del juego.
const RECT := Rect2(0, 0, 64, 64)
const LADO := 6.0
const EPS := 0.00001
# Vector2/Rect2 usan float32: en y=280 un ULP ya supera 0,00001.
# Esta tolerancia sólo cubre coordenadas; área, HP y tamaño siguen con EPS.
const EPS_POSICION := 0.0001
const DATOS := "res://datos/siluetas_muebles.json"
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	Juego.reiniciar_estado()
	probar_fronteras()
	probar_cavidad()
	probar_veneno_exterior()
	await probar_voladora_y_veneno()
	if FileAccess.file_exists(DATOS):
		await probar_catalogo()
	else:
		verificar(false, "el catálogo incluye metadatos de material independientes del renderer")
	Juego.reiniciar_estado()
	print("Material visible: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func nuevo(formas: Array = [RECT]) -> MordiscosMaterial:
	var m := MordiscosMaterial.new()
	m.configurar(RECT, Vector2i.ONE, [formas], PackedFloat64Array([1000]))
	return m


func probar_fronteras() -> void:
	var m := nuevo()
	var lados: Array[Vector2] = [Vector2(-2, 32), Vector2(66, 32), Vector2(32, -2), Vector2(32, 66)]
	var conectadas := true
	var conservadas := true
	var retirados := PackedByteArray()
	retirados.resize(m._pixeles.size())
	retirados.fill(0)
	for i in 64:
		var antes := m._pixeles.duplicate()
		var aire := aire_exterior(antes, m.tamano_mascara())
		var area := m.area_total()
		var hp := m.vida_celda(0)
		var real := m.recortar_local(0, 1.0e6, lados[i % lados.size()], LADO)
		var porcion := m.ultima_porcion
		conectadas = conectadas and real > 0 and porcion_exterior(m, antes, aire, porcion)
		conservadas = conservadas and absf(area - m.area_total() - porcion.get_area()) < EPS and absf(hp - m.vida_celda(0) - real) < EPS
		for p in antes.size():
			if retirados[p] != 0:
				conservadas = conservadas and m._pixeles[p] == 0
			if antes[p] != 0 and m._pixeles[p] == 0:
				retirados[p] = 1
	verificar(conectadas, "64 bocados alternados desde cuatro lados abren el borde existente, sin agujeros aislados")
	verificar(conservadas, "los bocados conservan área y HP y nunca reponen material anterior")
	m = nuevo()
	var area := m.area_total()
	var hp := m.vida_celda(0)
	var real := m.recortar_local(0, 1.0e6, Vector2(32, 32), LADO)
	verificar(real == 0 and m.area_total() == area and m.vida_celda(0) == hp and not m.ultima_porcion.has_area(), "una boca accidentalmente dentro del cuerpo no abre un pozo ni recibe carga")


func probar_cavidad() -> void:
	var formas: Array = [Rect2(0, 0, 64, 12), Rect2(0, 52, 64, 12), Rect2(0, 12, 12, 40), Rect2(52, 12, 12, 40)]
	var m := nuevo(formas)
	var area := m.area_total()
	var real := m.recortar_local(0, 1.0e6, Vector2(32, 32), LADO)
	verificar(real == 0 and m.area_total() == area and not m.ultima_porcion.has_area(), "el aire de una cavidad cerrada no se confunde con el exterior del mueble")
	var antes := m._pixeles.duplicate()
	var aire := aire_exterior(antes, m.tamano_mascara())
	real = m.recortar_local(0, 1.0e6, Vector2(-2, 32), LADO)
	verificar(real > 0 and porcion_exterior(m, antes, aire, m.ultima_porcion), "el mismo mueble hueco sí se come desde su contorno exterior")


func probar_veneno_exterior() -> void:
	var m := nuevo()
	var hp := m.vida_celda(0)
	var real := m.recortar(0, 190, Vector2(-2, 32))
	var aire := aire_exterior(m._pixeles, m.tamano_mascara())
	var conectado := real > 0
	for i in m._pixeles.size():
		if m._pixeles[i] == 0:
			conectado = conectado and aire[i] != 0
	verificar(conectado and is_equal_approx(hp - m.vida_celda(0), real), "el daño ambiental desde un lado también desgasta el exterior y conserva su HP")


func probar_catalogo() -> void:
	var metadatos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATOS))
	var catalogo := catalogo_unico()
	verificar(not metadatos.is_empty() and catalogo.size() <= metadatos.size(), "cada acabado y orientación del catálogo tiene material prehorneado")
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.colonia._activa = false
	var hay_detalle_fino := false
	for clave: String in catalogo:
		var datos: Dictionary = catalogo[clave].duplicate(true)
		datos.rect = rect_fixture(datos.rect)
		var fina: Array[Rect2] = SiluetaMueble.material(datos)
		var perfil := SiluetaMueble.rectangulos(datos)
		hay_detalle_fino = hay_detalle_fino or fina.size() > perfil.size()
		var bandas := {}
		for banda in perfil:
			bandas[Vector2i(roundi((banda.position.y - datos.rect.position.y) / datos.rect.size.y * 1.0e6), roundi((banda.end.y - datos.rect.position.y) / datos.rect.size.y * 1.0e6))] = true
		var geometria := metadatos.has(clave) and not fina.is_empty() and not perfil.is_empty() and bandas.size() <= 16 and perfil.size() <= 128
		var fuera := 0
		var descubiertas := 0
		var ejemplo := Rect2()
		for forma in fina:
			var dentro: bool = forma.has_area() and datos.rect.grow(EPS_POSICION).encloses(forma)
			var cubierta := perfil.any(func(banda: Rect2) -> bool: return banda.grow(EPS_POSICION).has_point(forma.get_center()))
			fuera += int(not dentro)
			descubiertas += int(not cubierta)
			if not dentro or not cubierta:
				ejemplo = forma
			geometria = geometria and dentro and cubierta
		if not geometria:
			print("  DIAG %s: fina=%d; perfil=%d; bandas=%d; fuera=%d; sin_perfil=%d; ejemplo=%s; rect=%s" % [clave, fina.size(), perfil.size(), bandas.size(), fuera, descubiertas, ejemplo, datos.rect])
		verificar(geometria, "%s conserva detalle fino y hasta 16 bandas físicas con sus huecos, sin sobrehang" % clave)
		var pieza := PiezaCasa.new()
		run.comidas.add_child(pieza)
		pieza.iniciar({"clave": "visible:" + clave, "tipo": datos.tipo, "rect": datos.rect, "color": datos.color, "pared": false, "dibujo": datos, "recortes": perfil}, run.cocina)
		pieza._preparar_mordiscos()
		var hp := 0.0
		for i in pieza.celdas.size():
			hp += pieza.mordiscos.vida_celda(i)
		verificar(is_equal_approx(hp, pieza.vida_max) and pieza.celdas.size() <= 16 and pieza.mordiscos.area_total() > 0, "%s asigna toda su resistencia al material, no a bandas de sombra" % clave)
		pieza.queue_free()
		await get_tree().process_frame
	verificar(hay_detalle_fino, "la silueta visual no se reduce a las 16 bandas de navegación")
	run.queue_free()
	await get_tree().process_frame


func catalogo_unico() -> Dictionary:
	var catalogo := {}
	for datos: Dictionary in Graficos.catalogo_muebles():
		var clave := Graficos.clave_mueble(datos)
		if not catalogo.has(clave):
			catalogo[clave] = datos
	return catalogo


func rect_fixture(original: Rect2) -> Rect2:
	# La orientación de biblioteca forma parte de su clave de arte.
	var escala := minf(110.0 / original.size.x, 130.0 / original.size.y)
	return Rect2(Vector2(150, 150), original.size * escala)


func probar_voladora_y_veneno() -> void:
	Juego.reiniciar_estado()
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	Juego._cache_stats.clear()
	var run: Run = preload("res://mundo/run.tscn").instantiate()
	add_child(run)
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run.colonia._activa = false
	var carton := run.objetivo_practica
	carton._preparar_mordiscos()
	var inicio := carton.rect_mundo.get_center()
	var h := run.colonia._nacer("voladora", inicio)
	h.comida = carton
	h.estado = Hormiga.Estado.MORDIENDO
	h._dano = 1.0e6
	h._reloj_mordida = 0
	var hp := carton.vida
	h._morder(1.0 / 30.0)
	var estado_inicial := h.estado
	var objetivo_inicial := h.objetivo
	verificar(carton.vida == hp and h.carga == 0 and h.bocados == 0 and h.estado in [Hormiga.Estado.YENDO_A_COMIDA, Hormiga.Estado.EXPLORANDO], "una voladora sobre el interior del cartón se reubica sin extraerlo desde arriba")
	var movida := false
	for i in 600:
		h._process(1.0 / 30.0)
		movida = movida or h.global_position.distance_to(inicio) > 2
		if h.carga > 0:
			break
		await get_tree().process_frame
	if not movida or h.carga <= 0 or carton.vida >= hp or h.bocados <= 0:
		print("  DIAG voladora: inicio=%s; primer_estado=%d; primer_objetivo=%s; final=%s; estado=%d; objetivo=%s; carga=%.12f; vida=%.12f/%.12f; fuente=%s; reubicando=%s" % [inicio, estado_inicial, objetivo_inicial, h.global_position, h.estado, h.objetivo, h.carga, carton.vida, hp, h.comida, h._reubicando_frente])
		print("  DIAG ruta: espera=%s; meta=%s; contacto=%s; radio=%.4f; velocidad=%.4f; ruta=%s; índice=%d" % [h._esperando_ruta, h._meta_ruta, carton.punto_contacto(h.global_position), run.radio_actual, h._velocidad, h._ruta, h._indice_ruta])
	# Headless no crea atlas ni retazos de Sprite2D: la revisión GPU verifica
	# esas muestras. Aquí se comprueban movimiento, bocado, HP y carga reales.
	verificar(movida and h.carga > 0 and carton.vida < hp and h.bocados > 0, "la misma voladora avanza hasta un borde real y entonces sí transporta material")
	h.detener()
	var datos: Dictionary = carton.pieza.duplicate(true)
	datos.clave = "visible:veneno_lateral"
	datos.rect = rect_fixture(carton.rect_mundo)
	datos.dibujo.rect = datos.rect
	datos.recortes = SiluetaMueble.rectangulos(datos)
	var pieza := PiezaCasa.new()
	run.comidas.add_child(pieza)
	pieza.iniciar(datos, run.cocina)
	pieza._preparar_mordiscos()
	var origen := pieza.punto_contacto(pieza.rect_mundo.get_center() + Vector2(300, 0)) + Vector2(10.5, 0)
	var vida := pieza.vida
	var ingreso := Juego.migas_run
	var restos := valor_fragmentos(run)
	pieza.aplicar_veneno(pieza.vida_max * 0.01 / 3.0, 3.0, run, origen)
	var conectados := true
	var desde_su_lado := true
	var retirados := 0
	for i in 6:
		var antes := pieza.mordiscos._pixeles.duplicate()
		pieza._process(0.5)
		var m := pieza.mordiscos
		var tam := m.tamano_mascara()
		var aire := aire_exterior(m._pixeles, tam)
		for p in antes.size():
			if antes[p] != 0 and m._pixeles[p] == 0:
				retirados += 1
				conectados = conectados and aire[p] != 0
				var x := m._rect_mundo.position.x + (p % tam.x + 0.5) * m._rect_mundo.size.x / tam.x
				desde_su_lado = desde_su_lado and x > pieza.rect_mundo.get_center().x
	verificar(retirados > 0 and conectados and desde_su_lado, "el veneno real desgasta el lado aplicado y conecta cada hueco nuevo al exterior, sin saltar al centro")
	var valor := pieza.recompensa * (vida - pieza.vida) / pieza.vida_max * Juego.stat("multiplicador_migas")
	verificar(is_equal_approx(Juego.migas_run - ingreso, valor * 0.65) and is_equal_approx(valor_fragmentos(run) - restos, valor * 0.35), "el veneno lateral paga y deja restos sólo del material que físicamente retiró")
	run.queue_free()
	await get_tree().process_frame


func valor_fragmentos(run: Run) -> float:
	var valor := 0.0
	for f in run.comidas.fragmentos:
		if is_instance_valid(f) and not f.muerta:
			valor += f.recompensa
	return valor


func aire_exterior(pixeles: PackedByteArray, tam: Vector2i) -> PackedByteArray:
	var aire := PackedByteArray()
	aire.resize(pixeles.size())
	aire.fill(0)
	var cola := PackedInt32Array()
	for y in tam.y:
		for x in tam.x:
			if x != 0 and y != 0 and x != tam.x - 1 and y != tam.y - 1:
				continue
			var i := y * tam.x + x
			if pixeles[i] == 0 and aire[i] == 0:
				aire[i] = 1
				cola.append(i)
	var siguiente := 0
	while siguiente < cola.size():
		var i := cola[siguiente]
		siguiente += 1
		var x := i % tam.x
		var y := i / tam.x as int
		for vecino in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
			if vecino.x < 0 or vecino.y < 0 or vecino.x >= tam.x or vecino.y >= tam.y:
				continue
			var j: int = vecino.y * tam.x + vecino.x
			if pixeles[j] == 0 and aire[j] == 0:
				aire[j] = 1
				cola.append(j)
	return aire


func porcion_exterior(m: MordiscosMaterial, antes: PackedByteArray, aire: PackedByteArray, porcion: Rect2) -> bool:
	if not porcion.has_area() or porcion.size.x > LADO + EPS or porcion.size.y > LADO + EPS:
		return false
	var tam := m.tamano_mascara()
	var paso := m._rect_mundo.size / Vector2(tam)
	var inicio := Vector2i(((porcion.position - m._rect_mundo.position) / paso).round())
	var fin := Vector2i(((porcion.end - m._rect_mundo.position) / paso).round())
	var toca := false
	for y in range(inicio.y, fin.y):
		for x in range(inicio.x, fin.x):
			if x < 0 or y < 0 or x >= tam.x or y >= tam.y or antes[y * tam.x + x] == 0 or m._pixeles[y * tam.x + x] != 0:
				return false
			for vecino in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
				if vecino.x < 0 or vecino.y < 0 or vecino.x >= tam.x or vecino.y >= tam.y:
					toca = true
				elif aire[vecino.y * tam.x + vecino.x] != 0:
					toca = true
	return toca


func verificar(ok: bool, detalle: String) -> void:
	total += 1
	if not ok:
		fallas += 1
	print("  OK   " if ok else "  FALLA ", detalle)
