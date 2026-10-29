class_name ArbolHormiguero
extends Control
## El hormiguero de mejoras: un corte de tierra de 1700 × 1900 (PlanoHormiguero)
## con la reina en el centro y siete ramas alrededor. Se recorre arrastrando y
## con la rueda. Avisa qué cámara está bajo el mouse y cuál se cliqueó; qué
## significa cada una lo decide la tienda.
##
## Capas, de abajo hacia arriba, todas dentro de `mundo` (que es lo único que
## se mueve al arrastrar o hacer zoom, sin redibujar):
##   fondo     tierra, túneles cavados y rastros (se redibuja al comprar)
##   transito  hormigas que caminan por los túneles cavados (30 Hz)
##   camaras   cámaras y lo que guardan (se redibuja al comprar)
##   resalte   cámaras comprables, la del mouse y el estallido al comprar

signal camara_pulsada(id: String)
signal camara_pulsada_derecha(id: String)
signal camara_sobrevolada(id: String)
signal vista_cambiada

const ZOOM_MAXIMO := 1.6
const ARRASTRE_MINIMO := 7.0

var mundo: Control
var fondo: CapaFondo
var transito: TransitoNido
var capa_camaras: CapaCamaras
var resalte: CapaResalte
## Botones con el nombre de cada sección (viajes, castas, legado), en pantalla.
var etiquetas: Dictionary = {}

## id -> {kit, mezcla, color, nivel, maximo, lleno, abierta, puede, lejana, misterio, extra}
var estados: Dictionary = {}
## Un valor por túnel de PlanoHormiguero.TUNELES: cuánto está cavado (0 a 1)
## y el rastro que deja ("" si ninguno).
var cavado: Array[float] = []
var rastros: Array[String] = []
var rutas: Array[Curve2D] = []
var caminos: Array[Dictionary] = []
var sobrevolada := ""
var seleccion := ""
var zoom := 0.7
## Si el jugador ya movió la vista, la tienda no la vuelve a encuadrar.
var movida_por_jugador := false

var _poligonos: Dictionary = {}
var _presionado := -1
var _desde := Vector2.ZERO
var _arrastrando := false
var _tween: Tween


## Las capas existen desde que se crea el nodo: la tienda las conecta antes
## de agregarlo al árbol.
func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	mundo = Control.new()
	mundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mundo.size = PlanoHormiguero.TAMANO
	add_child(mundo)
	fondo = CapaFondo.new()
	transito = TransitoNido.new()
	capa_camaras = CapaCamaras.new()
	resalte = CapaResalte.new()
	for capa in [fondo, transito, capa_camaras, resalte]:
		capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		capa.size = PlanoHormiguero.TAMANO
		capa.set("arbol", self)
		mundo.add_child(capa)
	for id in PlanoHormiguero.SECCIONES:
		var boton := Button.new()
		boton.add_theme_font_size_override("font_size", 17)
		boton.focus_mode = Control.FOCUS_NONE
		boton.pressed.connect(func() -> void: camara_pulsada.emit(id))
		boton.mouse_entered.connect(func() -> void: _sobrevolar(id))
		add_child(boton)
		etiquetas[id] = boton
	_armar_caminos()
	for id in PlanoHormiguero.CAMARAS:
		_poligonos[id] = ArteCamara.forma(_kit_plano(id), PlanoHormiguero.rect(id).size + Vector2.ONE * 6.0)
	resized.connect(_al_redimensionar)


## Curvas de todos los túneles, una vez: el plano no cambia.
func _armar_caminos() -> void:
	caminos.clear()
	rutas.clear()
	for tunel in PlanoHormiguero.TUNELES:
		var puntos := PlanoHormiguero.puntos_tunel(tunel)
		var ruta := Curve2D.new()
		ruta.bake_interval = 8
		for p in puntos:
			ruta.add_point(p)
		rutas.append(ruta)
		caminos.append({"desde": tunel[0], "id": tunel[1], "ancho": float(tunel[2]), "puntos": puntos})
	cavado.resize(caminos.size())
	cavado.fill(1.0)
	rastros.resize(caminos.size())
	rastros.fill("")


func _kit_plano(id: String) -> String:
	match id:
		"viajes": return "viajes"
		"legado": return "reina"
		"castas": return "comun"
	return estados.get(id, {}).get("kit", "comun")


## Nuevos estados de cámaras y túneles. Sólo se redibuja la capa que cambió.
func actualizar(nuevos: Dictionary, nuevo_cavado: Array[float], nuevos_rastros: Array[String]) -> void:
	var formas_cambiaron := false
	for id in nuevos:
		if estados.get(id, {}).get("kit", "") != nuevos[id].get("kit", ""):
			formas_cambiaron = true
	var camaras_cambiaron := _sin_comprables(estados) != _sin_comprables(nuevos)
	var comprables_cambiaron := estados != nuevos
	estados = nuevos
	if formas_cambiaron:
		for id in PlanoHormiguero.CAMARAS:
			_poligonos[id] = ArteCamara.forma(_kit_plano(id), PlanoHormiguero.rect(id).size + Vector2.ONE * 6.0)
	if cavado != nuevo_cavado or rastros != nuevos_rastros:
		cavado = nuevo_cavado.duplicate()
		rastros = nuevos_rastros.duplicate()
		fondo.queue_redraw()
		transito.indices_rutas.clear()
		for i in caminos.size():
			if cavado[i] >= 1.0:
				transito.indices_rutas.append(i)
	if camaras_cambiaron:
		capa_camaras.queue_redraw()
	if comprables_cambiaron:
		resalte.hay_comprables = false
		for id in estados:
			resalte.hay_comprables = resalte.hay_comprables or estados[id].get("puede", false)
		resalte.queue_redraw()


func _sin_comprables(datos: Dictionary) -> Dictionary:
	var copia := {}
	for id in datos:
		var d: Dictionary = datos[id].duplicate()
		d.erase("puede")
		copia[id] = d
	return copia


# =====================================================================
# Vista: arrastrar, zoom y encuadre
# =====================================================================

func zoom_minimo() -> float:
	if size.x < 1 or size.y < 1:
		return 0.3
	return minf(ZOOM_MAXIMO, minf(size.x / PlanoHormiguero.TAMANO.x, size.y / PlanoHormiguero.TAMANO.y) * 0.98)


## Del punto en pantalla (local a este control) al punto del plano.
func a_plano(punto: Vector2) -> Vector2:
	return (punto - mundo.position) / zoom


func a_pantalla(punto: Vector2) -> Vector2:
	return mundo.position + punto * zoom


## Rectángulo de una cámara en este control (para ubicar la ficha).
func rect_en_pantalla(id: String) -> Rect2:
	var r := PlanoHormiguero.rect(id)
	return Rect2(a_pantalla(r.position), r.size * zoom)


func _aplicar_vista(posicion: Vector2, nuevo_zoom: float) -> void:
	zoom = clampf(nuevo_zoom, zoom_minimo(), ZOOM_MAXIMO)
	mundo.scale = Vector2.ONE * zoom
	mundo.position = _limitar(posicion)
	_ubicar_etiquetas()
	vista_cambiada.emit()


## El plano nunca deja un borde vacío; si entra entero, queda centrado.
func _limitar(posicion: Vector2) -> Vector2:
	var tamano := PlanoHormiguero.TAMANO * zoom
	var p := posicion
	for eje in 2:
		if tamano[eje] <= size[eje]:
			p[eje] = (size[eje] - tamano[eje]) * 0.5
		else:
			p[eje] = clampf(p[eje], size[eje] - tamano[eje], 0.0)
	return p


## Encuadra un rectángulo del plano, con zoom entre `zoom_piso` y `zoom_tope`.
## Si no entra con el piso, queda centrado y el resto se recorre arrastrando.
func encuadrar(zona: Rect2, animado := true, zoom_tope := 1.0, zoom_piso := 0.0) -> void:
	if size.x < 1 or size.y < 1:
		return
	var piso := clampf(zoom_piso, zoom_minimo(), ZOOM_MAXIMO)
	var nuevo := clampf(minf(size.x / zona.size.x, size.y / zona.size.y), piso, maxf(piso, zoom_tope))
	var posicion := size * 0.5 - zona.get_center() * nuevo
	_mover_vista(posicion, nuevo, animado)


## Centra una cámara sin alejar la vista si ya estaba cerca.
func enfocar(id: String, animado := true) -> void:
	var nuevo := maxf(zoom, 0.85)
	_mover_vista(size * 0.5 - PlanoHormiguero.centro(id) * nuevo, nuevo, animado)


func _mover_vista(posicion: Vector2, nuevo_zoom: float, animado: bool) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	if not animado or not is_inside_tree():
		_aplicar_vista(posicion, nuevo_zoom)
		return
	var desde_pos := mundo.position
	var desde_zoom := zoom
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(t: float) -> void:
		_aplicar_vista(desde_pos.lerp(posicion, t), lerpf(desde_zoom, nuevo_zoom, t)), 0.0, 1.0, 0.35)


func _al_redimensionar() -> void:
	_aplicar_vista(mundo.position, zoom)


func _ubicar_etiquetas() -> void:
	for id in etiquetas:
		var boton: Button = etiquetas[id]
		var r := rect_en_pantalla(id)
		boton.size = boton.get_combined_minimum_size()
		boton.position = Vector2(r.get_center().x - boton.size.x * 0.5, r.end.y + 4.0)


# =====================================================================
# Mouse
# =====================================================================

## La cámara bajo un punto de este control ("" si ninguna).
func camara_en(punto: Vector2) -> String:
	var p := a_plano(punto)
	for id in _poligonos:
		var r := PlanoHormiguero.rect(id).grow(4.0)
		if r.has_point(p) and Geometry2D.is_point_in_polygon(p - r.get_center(), _poligonos[id]):
			return id
	return ""


func _gui_input(evento: InputEvent) -> void:
	var boton := evento as InputEventMouseButton
	if boton:
		if boton.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and boton.pressed:
			var factor := 1.15 if boton.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
			var antes := a_plano(boton.position)
			var nuevo := clampf(zoom * factor, zoom_minimo(), ZOOM_MAXIMO)
			if _tween and _tween.is_running():
				_tween.kill()
			movida_por_jugador = true
			_aplicar_vista(boton.position - antes * nuevo, nuevo)
			_sobrevolar(camara_en(boton.position))
			accept_event()
			return
		if boton.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if boton.pressed:
				_presionado = boton.button_index
				_desde = boton.position
				_arrastrando = false
			elif boton.button_index == _presionado:
				var id := camara_en(boton.position)
				if not _arrastrando and id != "":
					if boton.button_index == MOUSE_BUTTON_LEFT:
						camara_pulsada.emit(id)
					elif boton.button_index == MOUSE_BUTTON_RIGHT:
						camara_pulsada_derecha.emit(id)
				elif not _arrastrando and id == "" and boton.button_index == MOUSE_BUTTON_LEFT:
					camara_pulsada.emit("")
				_presionado = -1
				_arrastrando = false
			accept_event()
		return
	var movimiento := evento as InputEventMouseMotion
	if movimiento:
		if _presionado != -1:
			if not _arrastrando and movimiento.position.distance_to(_desde) >= ARRASTRE_MINIMO:
				_arrastrando = true
				movida_por_jugador = true
				_sobrevolar("")
			if _arrastrando:
				if _tween and _tween.is_running():
					_tween.kill()
				_aplicar_vista(mundo.position + movimiento.relative, zoom)
				accept_event()
				return
		_sobrevolar(camara_en(movimiento.position))


func _notification(que: int) -> void:
	if que == NOTIFICATION_MOUSE_EXIT:
		_presionado = -1
		_arrastrando = false
		_sobrevolar("")


func _sobrevolar(id: String) -> void:
	if id == sobrevolada:
		return
	sobrevolada = id
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if id != "" else Control.CURSOR_ARROW
	resalte.queue_redraw()
	camara_sobrevolada.emit(id)


## Estallido del color de la rama sobre una cámara recién comprada.
func celebrar(id: String) -> void:
	resalte.estallar(id, estados.get(id, {}).get("color", Estilo.ACENTO))


# =====================================================================
# Capas
# =====================================================================

class CapaFondo extends Control:
	var arbol: ArbolHormiguero

	## La tierra sigue más allá del plano: al alejar la vista no quedan bordes vacíos.
	const MARGEN := 4000.0

	func _draw() -> void:
		var t := PlanoHormiguero.TAMANO
		var izquierda := -MARGEN
		var derecha := t.x + MARGEN
		var inclinacion := -10.0 / t.x
		draw_rect(Rect2(izquierda, 37, derecha - izquierda, t.y + MARGEN), Color("35261a"))
		var colores := [Color("62452d"), Color("5b402a"), Color("553c27"), Color("4e3724"), Color("473221"), Color("412d1e"), Color("3d2a1c")]
		for i in colores.size():
			var y := 2.0 + i * 238.0 if i > 0 else 37.0
			var fin := 240.0 + i * 238.0
			draw_colored_polygon(PackedVector2Array([Vector2(izquierda, y + izquierda * inclinacion), Vector2(derecha, y + derecha * inclinacion),
				Vector2(derecha, fin + derecha * inclinacion), Vector2(izquierda, fin + izquierda * inclinacion)]), colores[i])
		draw_rect(Rect2(izquierda, -MARGEN, derecha - izquierda, MARGEN + 37), Color("252c22"))
		var boca := PlanoHormiguero.BOCA
		draw_colored_polygon(PackedVector2Array([Vector2(boca.x - 100, 37), Vector2(boca.x - 68, 21), Vector2(boca.x + 68, 21), Vector2(boca.x + 100, 37)]), Color("62452d"))
		var superficie := PackedVector2Array([Vector2(izquierda, 37), Vector2(boca.x - 100, 37), Vector2(boca.x - 68, 21), Vector2(boca.x + 68, 21), Vector2(boca.x + 100, 37), Vector2(derecha, 37)])
		draw_polyline(superficie, Color("967448"), 3, true)
		for raiz in [[Vector2(60, 37), Vector2(66, 90), Vector2(46, 140), Vector2(58, 210)], [Vector2(1640, 37), Vector2(1634, 100), Vector2(1656, 150), Vector2(1642, 230)], [Vector2(480, 37), Vector2(476, 60), Vector2(490, 84), Vector2(482, 110)], [Vector2(1020, 37), Vector2(1026, 64), Vector2(1012, 90), Vector2(1020, 118)]]:
			var linea := PackedVector2Array()
			for i in 13:
				linea.append(raiz[0].bezier_interpolate(raiz[1], raiz[2], raiz[3], i / 12.0))
			draw_polyline(linea, Color(0.588, 0.455, 0.282, 0.5), 1.6, true)
		var semilla := 9
		for i in 140:
			semilla = (semilla * 9301 + 49297) % 233280
			var x := roundf(semilla / 233280.0 * 1695)
			semilla = (semilla * 9301 + 49297) % 233280
			var y := roundf(44 + semilla / 233280.0 * 1850)
			semilla = (semilla * 9301 + 49297) % 233280
			draw_circle(Vector2(x, y), 1.5 if semilla / 233280.0 < 0.3 else 1.0, Color(0.11, 0.075, 0.047, 0.4))
		if arbol == null:
			return
		for camino in arbol.caminos:
			draw_polyline(camino.puntos, Color(0.141, 0.102, 0.078, 0.34), 13, true)
		# Borde y fondo en dos pasadas: las bifurcaciones quedan abiertas.
		for pasada in 2:
			for i in arbol.caminos.size():
				var parte := _tramo(arbol.caminos[i].puntos, arbol.cavado[i])
				if parte.size() >= 2:
					var ancho: float = arbol.caminos[i].ancho
					draw_polyline(parte, Color("7a5a3a") if pasada == 0 else ArteCamara.RELLENO, ancho + 3.0 if pasada == 0 else ancho, true)
		for i in arbol.caminos.size():
			if arbol.rastros[i] != "":
				ArteCamara.rastro(self, arbol.rastros[i], arbol.caminos[i].puntos)

	## El principio de un túnel, hasta la fracción cavada.
	func _tramo(puntos: PackedVector2Array, fraccion: float) -> PackedVector2Array:
		if fraccion >= 1.0:
			return puntos
		if fraccion <= 0.0:
			return PackedVector2Array()
		var total := 0.0
		for i in puntos.size() - 1:
			total += puntos[i].distance_to(puntos[i + 1])
		var falta := total * fraccion
		var salida := PackedVector2Array([puntos[0]])
		for i in puntos.size() - 1:
			var tramo := puntos[i].distance_to(puntos[i + 1])
			if tramo >= falta:
				salida.append(puntos[i].lerp(puntos[i + 1], falta / maxf(tramo, 0.001)))
				break
			salida.append(puntos[i + 1])
			falta -= tramo
		return salida


class CapaCamaras extends Control:
	var arbol: ArbolHormiguero

	func _draw() -> void:
		if arbol == null:
			return
		var orden := 0
		for id in PlanoHormiguero.CAMARAS:
			orden += 1
			var e: Dictionary = arbol.estados.get(id, {})
			if e.is_empty():
				continue
			var r := PlanoHormiguero.rect(id)
			var centro := r.get_center()
			var kit: String = e.kit
			var color: Color = e.color
			var especial: bool = kit in ["reina", "viajes"]
			var aro := ArteCamara.CERRADO.lerp(color, 0.22)
			if e.misterio:
				aro = ArteCamara.CERRADO.lerp(color, 0.12)
			elif especial or (e.maximo > 0 and e.nivel >= e.maximo):
				aro = color
			elif e.nivel > 0:
				aro = ArteCamara.BORDE.lerp(color, 0.55)
			elif e.abierta:
				aro = ArteCamara.BORDE.lerp(color, 0.3)
			if kit == "comun" and (e.abierta or e.nivel > 0) and not especial:
				aro = ArteCamara.BORDE.lerp(ArteCamara.COLORES.comun, 0.55 if e.nivel < e.maximo else 1.0)
			var grosor := 7.0 if especial else (6.0 if r.size.x > 90 else 5.0)
			var opacidad := 0.55 if e.lejana else (0.85 if not e.abierta and e.nivel == 0 else 1.0)
			if especial or e.get("seccion", false):
				opacidad = 1.0 if e.abierta else 0.75
			if kit == "reina":
				for i in 4:
					var halo := ArteCamara.forma("reina", r.size + Vector2.ONE * (18.0 + i * 12.0))
					draw_colored_polygon(_mover(halo, centro), Color(0.92, 0.776, 0.49, 0.06))
			ArteCamara.caparazon(self, kit, centro, r.size, aro, grosor, e.lleno if not especial else (1.0 if kit == "reina" else 0.0), opacidad)
			if kit == "feromonas" and e.maximo > 0 and e.nivel >= e.maximo:
				var brillo := ArteCamara.forma("feromonas", r.size - Vector2.ONE * (grosor * 2.0 + 4.0))
				var linea := _mover(brillo, centro)
				linea.append(linea[0])
				draw_polyline(linea, Color(0.553, 0.765, 0.737, 0.3), 5.0, true)
			if kit == "comun" and not especial:
				ArteCamara.punteado(self, "comun", centro, r.size, Color(0.92, 0.776, 0.49, 0.75 if not e.lejana else 0.35))
			if not e.misterio:
				ArteCamara.contenido(self, kit, centro, r.size, e.lleno, orden, e.mezcla, e.extra)

	func _mover(puntos: PackedVector2Array, d: Vector2) -> PackedVector2Array:
		var salida := PackedVector2Array()
		for p in puntos:
			salida.append(p + d)
		return salida


class CapaResalte extends Control:
	var arbol: ArbolHormiguero
	var hay_comprables := false
	var reloj := 0.0
	var _proximo := 0.0
	var _estallidos: Array[Dictionary] = []

	func _ready() -> void:
		set_process(true)

	func estallar(id: String, color: Color) -> void:
		_estallidos.append({"id": id, "color": color, "t": 0.0})
		queue_redraw()

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		reloj += delta
		for e in _estallidos:
			e.t += delta
		var habia := _estallidos.size()
		_estallidos = _estallidos.filter(func(e: Dictionary) -> bool: return e.t < 0.6)
		if habia > 0 and _estallidos.is_empty():
			queue_redraw()
		# Pulso suave de lo comprable a 12 Hz; los estallidos van a 30 Hz.
		# Sin nada que latir ni estallar no se redibuja.
		if reloj >= _proximo and (hay_comprables or not _estallidos.is_empty()):
			_proximo = reloj + (1.0 / 30.0 if not _estallidos.is_empty() else 1.0 / 12.0)
			queue_redraw()

	func _draw() -> void:
		if arbol == null:
			return
		var pulso := 0.5 + 0.5 * sin(reloj * 3.2)
		for id in arbol.estados:
			var e: Dictionary = arbol.estados[id]
			if not e.get("puede", false):
				continue
			var r := PlanoHormiguero.rect(id)
			var punto := r.get_center() + Vector2(r.size.x * 0.42, -r.size.y * 0.42)
			draw_circle(punto, 9.0 + pulso * 3.0, Color(0.72, 0.85, 0.56, 0.12 + 0.1 * pulso))
			draw_circle(punto, 5.5, Color("b7da8f"))
			draw_arc(punto, 5.5, 0, TAU, 16, Color("2a3522"), 1.2, true)
		for id in [arbol.sobrevolada, arbol.seleccion]:
			if id == "" or not PlanoHormiguero.CAMARAS.has(id):
				continue
			var e: Dictionary = arbol.estados.get(id, {})
			var r := PlanoHormiguero.rect(id)
			var contorno := ArteCamara.forma(e.get("kit", "comun"), r.size + Vector2.ONE * (12.0 if id == arbol.seleccion else 9.0), 12)
			var linea := PackedVector2Array()
			for p in contorno:
				linea.append(p + r.get_center())
			linea.append(linea[0])
			draw_polyline(linea, Color(e.get("color", Estilo.ACENTO), 0.9 if id == arbol.seleccion else 0.65), 2.5, true)
		for estallido in _estallidos:
			var r := PlanoHormiguero.rect(estallido.id)
			var t: float = estallido.t / 0.6
			var color: Color = estallido.color
			var radio := r.size * (0.55 + t * 0.6)
			draw_set_transform(r.get_center(), 0, Vector2(radio.x / radio.y, 1.0))
			draw_arc(Vector2.ZERO, radio.y, 0, TAU, 40, Color(color, 0.8 * (1.0 - t)), 4.0 * (1.0 - t) + 1.0, true)
			draw_set_transform(Vector2.ZERO)
			for i in 10:
				var angulo: float = TAU * i / 10.0 + String(estallido.id).hash() % 7
				var p := r.get_center() + Vector2.from_angle(angulo) * (r.size.x * 0.35 + t * 46.0)
				draw_circle(p, 2.6 * (1.0 - t) + 0.6, Color(color.lightened(0.2), 1.0 - t))


## 22 siluetas como máximo en un solo CanvasItem, sin nodos ni IA por hormiga.
## Sólo esta capa se redibuja a 30 Hz; el suelo y las cámaras quedan retenidos.
class TransitoNido extends Control:
	var arbol: ArbolHormiguero
	var indices_rutas: Array[int] = []
	var reloj := 0.0
	var acumulado := 0.0
	var actualizaciones := 0
	var rutas: Array[Curve2D]:
		get:
			return arbol.rutas if arbol != null else ([] as Array[Curve2D])

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		reloj += delta
		acumulado += delta
		if acumulado >= 1.0 / 30.0:
			acumulado = fmod(acumulado, 1.0 / 30.0)
			actualizaciones += 1
			queue_redraw()

	func posicion(ruta: Curve2D, indice: int, tiempo: float) -> Vector2:
		var largo := ruta.get_baked_length()
		var recorrido := fposmod(tiempo * (22 + indice % 3 * 5) + indice * 83, largo * 2)
		return ruta.sample_baked(largo - absf(largo - recorrido))

	func _draw() -> void:
		if indices_rutas.is_empty() or arbol == null:
			return
		for indice in mini(22, indices_rutas.size() * 2):
			var ruta := arbol.rutas[indices_rutas[(indice * 7) % indices_rutas.size()]]
			if ruta.get_baked_length() < 1:
				continue
			var p := posicion(ruta, indice, reloj)
			var rumbo := (posicion(ruta, indice, reloj + 0.08) - p).angle()
			draw_set_transform(p, rumbo, Vector2.ONE * 1.25)
			var tinta := Color("c3a176") if indice % 2 == 0 else Color("a38b6c")
			for pata in 3:
				var paso := sin(reloj * 11 + pata * 2 + indice) * 1.5
				for lado in [-1, 1]:
					draw_line(Vector2(-2 + pata * 2, lado), Vector2(-4 + pata * 3 + paso * lado, lado * 4), tinta, 1, true)
			draw_circle(Vector2(-4, 0), 3.0, tinta.darkened(.18))
			draw_circle(Vector2.ZERO, 2, tinta)
			draw_circle(Vector2(4, 0), 2.3, tinta)
			draw_line(Vector2(5, -1), Vector2(8, -3), tinta, 1, true)
			draw_line(Vector2(5, 1), Vector2(8, 3), tinta, 1, true)
			if indice % 4 == 0:
				draw_circle(Vector2(8, 0), 2.8, Color("dfc273"))
		draw_set_transform(Vector2.ZERO)
