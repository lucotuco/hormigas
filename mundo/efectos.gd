class_name Efectos
extends Node2D
## Golpes, estelas, ondas y números desde un solo lienzo. Las formas comparten
## pools y techos: más variedad no significa más emisores por hormiga.

const MAX_PARTICULAS := 600
const MAX_TEXTOS := 40
const MAX_TEXTOS_VISIBLES := 12
const MAX_ONDAS := 24
const COLOR_SOMBRA_TEXTO := Color(0.12, 0.07, 0.03)
const TAMANO_FUENTE := 28
const VENTANA_AGRUPACION := 0.28
const COLORES_INGRESO := [Color("ffe497"), Color("ffc29b"), Color("b7e6f2")]
enum Forma { RETAZO, POLVO, ESTELA, BRILLO }
enum Pulso { EXPANSION, ENTREGA, GOLPE, DESTRUCCION, EPICO, AVISO, IMPACTO, REPELIDO, RAFAGA, RACHA, RECIBO, CORTE }
const MAX_ENTRADAS_HALO := 8


class Particula:
	var pos: Vector2
	var vel: Vector2
	var vida: float
	var vida_max: float
	var color: Color
	var tamano: float
	var material_id := -1
	var inicio := Vector2.ZERO
	var destino := Vector2.ZERO
	var convergente := false
	var forma := Forma.RETAZO
	var estela := 0.0
	var giro := 0.0
	var angulo := 0.0
	var eje := Vector2.RIGHT


class Onda:
	var pos: Vector2
	var radio_max: float
	var vida: float
	var vida_max: float
	var color: Color
	var estilo := Pulso.EXPANSION
	var direccion := 0.0
	var acentos := 3


class TextoFlotante:
	var pos: Vector2
	var texto: String
	var color: Color
	var escala: float
	var vida: float
	var vida_max: float
	var ancho := 0.0
	var cantidad := 0.0
	var origen := Vector2.INF
	var clase := "texto"
	var categoria := -1
	var pantalla_minima := 18.0
	var carril := 0.0
	var sucio := false


var _particulas: Array[Particula] = []
var _libres: Array[Particula] = []
var _ondas: Array[Onda] = []
var _ondas_libres: Array[Onda] = []
var _textos: Array[TextoFlotante] = []
var _textos_libres: Array[TextoFlotante] = []
var _rect_textos: Array[Rect2] = []
var _marcas: Array[Dictionary] = []
var _marcas_libres: Array[Dictionary] = []
const MAX_MARCAS := 16
var _pausa_marca := 0.0
var _pausa_entrega := 0.0
var _pausa_epico := 0.0
var _pausa_mordida := 0.0
var _pausa_destruccion := 0.0
var _pausa_rafaga := 0.0
var _pausa_racha := 0.0
var _pausas_amenaza: Array[float] = [0.0, 0.0, 0.0]
var _cerrado := false
var _azar := RandomNumberGenerator.new()
var _secuencia_textos := 0
## Snapshot al preparar la expedición: las mordidas no consultan la tienda.
var _migas_brillantes := false
var _mandibulas_destello := false
var _pulso_colonia := false
var _frenesi_restante := 0.0
var _fase_halo := 0.0
var _entradas_halo := PackedVector2Array()
## QA observa dibujo efectivo, no confunde un objeto del pool con algo visible.
var depositos_dibujados := 0
var fracciones_dibujadas := 0
var halos_dibujados := 0


func _ready() -> void:
	_azar.seed = 41731 # El feedback no consume el azar de enemigos/IA.
	set_process(false)


## Se configura una vez por expedición, después de comprar. No depende del
## diccionario mutable de la partida ni crea objetos por cada hormiga.
func configurar_mejoras(niveles: Dictionary) -> void:
	if _cerrado:
		return
	_migas_brillantes = int(niveles.get("migas_brillantes", 0)) > 0
	_mandibulas_destello = int(niveles.get("mandibulas_destello", 0)) > 0
	_pulso_colonia = int(niveles.get("pulso_colonia", 0)) > 0
	if not _pulso_colonia:
		_frenesi_restante = 0.0
		_entradas_halo.clear()
		queue_redraw()


## Sólo recibe el estado verdadero del frenesí y las entradas ya conocidas.
## El refresco puede ser espaciado: la duración también vence localmente.
func actualizar_frenesi(restante: float, entradas: PackedVector2Array) -> void:
	if _cerrado:
		return
	var activa := _pulso_colonia and is_finite(restante) and restante > 0.0 and not entradas.is_empty()
	if not activa:
		if _frenesi_restante > 0.0 or not _entradas_halo.is_empty():
			_frenesi_restante = 0.0
			_entradas_halo.clear()
			queue_redraw()
		return
	if _frenesi_restante <= 0.0:
		_fase_halo = 0.0
	_frenesi_restante = restante
	_entradas_halo.resize(mini(MAX_ENTRADAS_HALO, entradas.size()))
	for i in _entradas_halo.size():
		_entradas_halo[i] = entradas[i]
	_despertar()


## Una entrega ya cobrada: pequeño pulso hacia la entrada, no otra moneda.
## El gate global evita una ráfaga por cada una de las quinientas hormigas.
func entrega(pos: Vector2, cantidad: float, combo := 0, material_id := -1) -> void:
	if _cerrado or cantidad <= 0.0 or _pausa_entrega > 0.0 or not _en_vista(pos):
		return
	_pausa_entrega = 0.10
	var tinta: Color = COLORES_INGRESO[clampi(material_id, 0, 2)]
	var alcance := _radio_pantalla(36.0, 30.0, 46.0)
	var cantidad_particulas := 4 + mini(4, maxi(0, combo) / 8)
	for i in mini(cantidad_particulas, MAX_PARTICULAS - _particulas.size()):
		var direccion := Vector2.from_angle(TAU * i / cantidad_particulas + _azar.randf_range(-0.1, 0.1))
		_agregar_particula(pos + direccion * alcance * _azar.randf_range(0.8, 1.05), -direccion * alcance * 2.0,
			0.48, tinta, _azar.randf_range(2.8, 3.8))
		var p: Particula = _particulas.back()
		p.forma = Forma.ESTELA
		p.estela = 12.0
		p.convergente = true
		p.destino = pos + direccion * 2.0
	_agregar_onda(pos, alcance, 0.48, tinta, Pulso.ENTREGA, 0.0, 3 + mini(3, maxi(0, combo) / 8))
	if _migas_brillantes:
		# Cruces breves y arcos de recibo: el dinero ya fue acreditado. No son
		# monedas adicionales ni astillas que aparenten extraer otro bocado.
		var oro := Color("ffe6a0")
		for i in mini(4, MAX_PARTICULAS - _particulas.size()):
			var eje := Vector2.from_angle(i * TAU / 4.0 + 0.35)
			_agregar_particula(pos + eje * alcance * 0.65, eje * alcance * 0.45, 0.42, oro, 4.2)
			_particulas.back().forma = Forma.BRILLO
			_particulas.back().giro = 1.8
		_agregar_onda(pos, alcance * 1.55, 0.54, oro, Pulso.RECIBO)
	_despertar()


## Confirmación de un depósito YA acreditado: número exacto y gesto visual.
## El gate de partículas nunca descarta importes; la ventana del número es fija.
func deposito(pos: Vector2, cantidad: float, combo := 0, categoria := 0) -> void:
	if _cerrado or cantidad <= 0.0 or not is_finite(cantidad) or not _en_vista(pos):
		return
	var grupo := clampi(categoria, 0, 2)
	entrega(pos, cantidad, combo, grupo)
	_numero_real(pos, cantidad, COLORES_INGRESO[grupo], 1.0, "deposito", grupo, 24.0 + minf(maxi(combo, 0), 25) * 0.08)


## Contacto confirmado con material real: golpe corto y hasta tres astillas.
## Un gate compartido da presencia a una obrera sin escalar con 500 bocas.
func mordida(pos: Vector2, color: Color, material_id := -1, direccion := Vector2.ZERO) -> void:
	if _cerrado or _pausa_mordida > 0.0 or not _en_vista(pos):
		return
	_pausa_mordida = 0.035
	var normal := direccion.normalized() if not direccion.is_zero_approx() else Vector2.from_angle(_azar.randf() * TAU)
	var cantidad := 1 if _zoom() < 0.3 else 3
	for i in mini(cantidad, MAX_PARTICULAS - _particulas.size()):
		var salida := normal.rotated(_azar.randf_range(-0.85, 0.85))
		_agregar_particula(pos, salida * _azar.randf_range(22.0, 48.0),
			_azar.randf_range(0.18, 0.28), color, _azar.randf_range(1.5, 2.1))
		var p: Particula = _particulas.back()
		p.material_id = material_id
		p.estela = 2.3 if material_id == 2 else 0.0
		p.giro = _azar.randf_range(-4.0, 4.0)
	if cantidad > 1:
		_agregar_onda(pos, _radio_pantalla(8.0, 7.0, 12.0), 0.18, color.lerp(Color("fff0cd"), 0.5), Pulso.GOLPE, normal.angle())
	if _mandibulas_destello:
		var destello := color.lerp(Color("fff3ca"), 0.78)
		_agregar_onda(pos, _radio_pantalla(16.0, 13.0, 21.0), 0.23, destello, Pulso.CORTE, normal.angle())
		for i in mini(2, MAX_PARTICULAS - _particulas.size()):
			var salida := normal.rotated(-0.75 if i == 0 else 0.75)
			_agregar_particula(pos, salida * _radio_pantalla(38.0, 32.0, 48.0), 0.22, destello, 2.5)
			_particulas.back().forma = Forma.BRILLO
			_particulas.back().estela = 3.5
	_despertar()


## Un hito de combo real, no otra entrega ni una moneda inventada.
func racha(pos: Vector2, nivel: int) -> void:
	if _cerrado or nivel <= 0 or _pausa_racha > 0.0 or not _en_vista(pos):
		return
	_pausa_racha = 0.45
	var acentos := clampi(nivel + 2, 3, 6)
	_agregar_onda(pos, _radio_pantalla(34.0 + acentos * 2.0, 42.0, 70.0), 0.65, Color("ffda87"), Pulso.RACHA, -PI * 0.5, acentos)
	_despertar()


## Activa sólo cuando la Ráfaga existe. El anillo se abre en tres sectores,
## no ilumina la pantalla ni persiste durante ocho segundos por hormiga.
func rafaga(pos: Vector2, radio := 70.0) -> void:
	if _cerrado or _pausa_rafaga > 0.0 or not _en_vista(pos, radio + 40.0):
		return
	_pausa_rafaga = 0.6
	var alcance := _radio_pantalla(clampf(radio, 24.0, 120.0), 55.0, 110.0)
	_agregar_onda(pos, alcance, 0.8, Color("f8d98e"), Pulso.RAFAGA)
	for i in mini(12, MAX_PARTICULAS - _particulas.size()):
		var dir := Vector2.from_angle(TAU * i / 12.0)
		_agregar_particula(pos + dir * alcance * 0.2, dir * 140.0 / _zoom(), 0.55, Color("ffe3a1"), 2.6)
		_particulas.back().forma = Forma.ESTELA
		_particulas.back().estela = 14.0
	_despertar()


## Aviso, contacto o rechazo de una amenaza: una llamada por transición real.
## El radio describe su área; no modifica hitboxes, botín ni estado enemigo.
func amenaza(pos: Vector2, fase: String, radio := 30.0, direccion := Vector2.ZERO, duracion := 0.0) -> void:
	var indice := ["aviso", "impacto", "repelido"].find(fase)
	if _cerrado or indice < 0 or _pausas_amenaza[indice] > 0.0 or not _en_vista(pos, radio + 40.0):
		return
	_pausas_amenaza[indice] = 0.12
	var alcance := clampf(radio, 10.0, 140.0)
	var color: Color = [Color("e9b469"), Color("e18a70"), Color("d6dfac")][indice]
	var vida: float = [1.1, 0.32, 0.45][indice] if duracion <= 0.0 else clampf(duracion, 0.15, 2.4)
	var estilo: int = [Pulso.AVISO, Pulso.IMPACTO, Pulso.REPELIDO][indice]
	_agregar_onda(pos, alcance, vida, color, estilo, direccion.angle())
	if indice > 0:
		for i in mini(5, MAX_PARTICULAS - _particulas.size()):
			var dir := Vector2.from_angle(TAU * i / 5.0 + direccion.angle())
			_agregar_particula(pos + dir * 4.0, dir * 55.0, 0.28, color, 1.4)
			_particulas.back().forma = Forma.BRILLO
	_despertar()


## Sólo se llama por una victoria/hito REAL. Una ráfaga, máximo dos ondas,
## sin emisores ni nodos por fragmento ni cadenas de timers/tweens.
func epico(pos: Vector2, color: Color, radio := 70.0) -> void:
	if _cerrado or _pausa_epico > 0.0 or not _en_vista(pos, radio + 100.0):
		return
	_pausa_epico = 0.75
	var alcance := _radio_pantalla(clampf(radio, 24.0, 160.0), 70.0, 150.0)
	for i in mini(36, MAX_PARTICULAS - _particulas.size()):
		var direccion := Vector2.from_angle(i * TAU / 36.0 + _azar.randf_range(-0.04, 0.04))
		_agregar_particula(pos + direccion * alcance * 0.12,
			direccion * _azar.randf_range(90.0, 220.0) / _zoom(), _azar.randf_range(0.55, 0.9),
			color.lerp(Color("ffe49d"), 0.35 + _azar.randf() * 0.4), _azar.randf_range(2.4, 4.0))
		_particulas.back().estela = 9.0
		_particulas.back().forma = Forma.BRILLO
	_agregar_onda(pos, alcance, 0.65, color.lerp(Color("ffe49d"), 0.5), Pulso.EPICO)
	_agregar_onda(pos, alcance * 0.68, 0.85, color.lightened(0.3), Pulso.EPICO, PI / 6.0)
	_despertar()


func _despertar() -> void:
	set_process(true)
	queue_redraw()


## Terminal por instancia: callbacks tardíos no reviven la run abandonada.
func limpiar() -> void:
	_cerrado = true
	for p in _particulas:
		_libres.append(p)
	_particulas.clear()
	for o in _ondas:
		_ondas_libres.append(o)
	_ondas.clear()
	_textos_libres.append_array(_textos)
	_textos.clear()
	_marcas_libres.append_array(_marcas)
	_marcas.clear()
	_rect_textos.clear()
	depositos_dibujados = 0
	fracciones_dibujadas = 0
	halos_dibujados = 0
	_frenesi_restante = 0.0
	_entradas_halo.clear()
	_pausa_marca = 0.0
	_pausa_entrega = 0.0
	_pausa_epico = 0.0
	_pausa_mordida = 0.0
	_pausa_destruccion = 0.0
	_pausa_rafaga = 0.0
	_pausa_racha = 0.0
	_pausas_amenaza.fill(0.0)
	set_process(false)
	queue_redraw()

## Una señal breve por habilidad, con límite global; no un emisor por hormiga.
func habilidad(desde: Vector2, hasta: Vector2, color: Color) -> void:
	if _cerrado or _pausa_marca > 0 or _marcas.size() >= MAX_MARCAS or not _en_vista(desde):
		return
	_pausa_marca = 0.08
	var marca: Dictionary = _marcas_libres.pop_back() if not _marcas_libres.is_empty() else {}
	marca.a = desde
	marca.b = hasta
	marca.color = color
	marca.vida = 0.35
	_marcas.append(marca)
	_despertar()


## Chispitas rápidas de las mordidas. No generar efectos fuera de cámara.
func chispas(pos: Vector2, color: Color, cantidad: int, material_id := -1) -> void:
	if _cerrado or not _en_vista(pos):
		return
	for i in mini(cantidad, MAX_PARTICULAS - _particulas.size()):
		_agregar_particula(pos, Vector2.from_angle(_azar.randf() * TAU) * _azar.randf_range(30.0, 90.0),
			_azar.randf_range(0.2, 0.4), color.lightened(_azar.randf_range(0.0, 0.3)), _azar.randf_range(1.0, 1.8))
		_particulas.back().material_id = material_id
	_despertar()


## Explosión al destruir una comida: pedazos + onda expansiva.
func explosion(pos: Vector2, color: Color, radio: float) -> void:
	if _cerrado or _pausa_destruccion > 0.0 or not _en_vista(pos, radio * 2.5 + 100):
		return
	_pausa_destruccion = 0.055
	var cantidad := int(clampf(radio * 0.9, 8.0, 48.0))
	var fuerza := clampf(radio * 3.0, 45.0, 170.0)
	for i in mini(cantidad, MAX_PARTICULAS - _particulas.size()):
		var dir := Vector2.from_angle(_azar.randf() * TAU)
		_agregar_particula(pos + dir * _azar.randf() * radio * 0.6, dir * _azar.randf_range(0.3, 1.0) * fuerza,
			_azar.randf_range(0.35, 0.65), color.lerp(Color("e4d8bf"), _azar.randf_range(0.0, 0.3)),
			_azar.randf_range(1.2, 2.0) + minf(radio * 0.025, 1.8))
		_particulas.back().forma = Forma.POLVO if i % 3 == 0 else Forma.RETAZO
		_particulas.back().giro = _azar.randf_range(-3.0, 3.0)
	_agregar_onda(pos, _radio_pantalla(clampf(radio * 1.6 + 10.0, 16.0, 180.0), 35.0, 90.0), 0.5, color.lightened(0.3), Pulso.DESTRUCCION)
	_despertar()


func _agregar_onda(pos: Vector2, radio: float, vida: float, color: Color, estilo := Pulso.EXPANSION, direccion := 0.0, acentos := 3) -> void:
	if _ondas.size() >= MAX_ONDAS:
		return
	var onda: Onda = _ondas_libres.pop_back() if not _ondas_libres.is_empty() else Onda.new()
	onda.pos = pos
	onda.radio_max = radio
	onda.vida_max = vida
	onda.vida = vida
	onda.color = color
	onda.estilo = estilo
	onda.direccion = direccion
	onda.acentos = acentos
	_ondas.append(onda)


## Conservador: nunca transforma 0.96 en una miga ni esconde 0.004 como cero.
## El valor completo sigue en TextoFlotante.cantidad; sólo se acorta su rótulo.
static func formatear_importe(valor: float) -> String:
	if not is_finite(valor) or valor <= 0.0:
		return "0"
	if valor >= 1000.0:
		return Juego.formatear(valor)
	var decimales := 2 if valor >= 1.0 else maxi(2, 2 - floori(log(valor) / log(10.0)))
	if decimales > 10:
		var exponente := floori(log(valor) / log(10.0))
		var mantisa := floorf(valor / pow(10.0, exponente) * 100.0) / 100.0
		return String.num(mantisa, 2).trim_suffix("0").trim_suffix(".") + "e" + str(exponente)
	var factor := pow(10.0, decimales)
	var truncado := floorf(valor * factor) / factor
	var contenido := String.num(truncado, decimales)
	while contenido.contains(".") and contenido.ends_with("0"):
		contenido = contenido.left(-1)
	return contenido.trim_suffix(".")


## Un único tamaño rasterizado, con escala de pantalla independiente del zoom.
static func tamano_numero_pantalla(t: TextoFlotante) -> float:
	var edad := maxf(0.0, t.vida_max - t.vida)
	var golpe := maxf(0.0, 1.0 - edad / 0.14)
	return t.pantalla_minima * (1.0 + 0.4 * golpe * golpe)


## "+12" y fracciones reales. Bonus importantes conservan un mínimo de 32px.
func numero(pos: Vector2, cantidad: float, color: Color, escala := 1.0) -> void:
	var clase := "bonus" if escala >= 1.5 else "numero"
	var minimo := 32.0 if clase == "bonus" else clampf(18.0 * escala, 18.0, 26.0)
	_numero_real(pos, cantidad, color, escala, clase, -1, minimo)


func _numero_real(pos: Vector2, cantidad: float, color: Color, escala: float, clase: String, categoria: int, minimo: float) -> void:
	if _cerrado or cantidad <= 0.0 or not is_finite(cantidad) or not _en_vista(pos):
		return
	# La entrada tiene su propia cuenta. Un bonus vecino no la contamina y
	# sumar no prolonga la ventana ni hace inmortal el mismo cartel.
	var radio_agrupacion := 1.0 if clase == "deposito" else maxf(96, 65.0 / _zoom())
	for t in _textos:
		if t.cantidad > 0 and t.clase == clase and t.categoria == categoria and t.vida_max - t.vida < VENTANA_AGRUPACION \
			and t.origen.distance_squared_to(pos) < radio_agrupacion * radio_agrupacion and t.color == color:
			t.cantidad += cantidad
			t.sucio = true
			t.pantalla_minima = maxf(t.pantalla_minima, minimo)
			return
	texto(pos, "+" + formatear_importe(cantidad), color, escala)
	var nuevo: TextoFlotante = _textos.back()
	nuevo.cantidad = cantidad
	nuevo.origen = pos
	nuevo.clase = clase
	nuevo.categoria = categoria
	nuevo.pantalla_minima = minimo


func texto(pos: Vector2, contenido: String, color: Color, escala := 1.0) -> void:
	if _cerrado or not _en_vista(pos):
		return
	if _textos.size() >= MAX_TEXTOS:
		_textos_libres.append(_textos.pop_front())
	var t: TextoFlotante = _textos_libres.pop_back() if not _textos_libres.is_empty() else TextoFlotante.new()
	t.pos = pos
	t.texto = contenido
	t.ancho = ThemeDB.fallback_font.get_string_size(contenido, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_FUENTE).x
	t.color = color
	t.escala = escala
	t.vida_max = 0.9
	t.vida = t.vida_max
	t.cantidad = 0.0
	t.origen = Vector2.INF
	t.clase = "texto"
	t.categoria = -1
	t.pantalla_minima = clampf(18.0 * escala, 18.0, 26.0)
	t.sucio = false
	t.carril = [0.0, -30.0, 30.0][_secuencia_textos % 3]
	_secuencia_textos += 1
	_textos.append(t)
	_despertar()


## Una tanda puede contener cientos de entregas. Sumar es O(1); formatear y
## medir el resultado sucede una sola vez al dibujarlo, no por hormiga.
func _actualizar_texto(t: TextoFlotante) -> void:
	if not t.sucio:
		return
	t.texto = "+" + formatear_importe(t.cantidad)
	t.ancho = ThemeDB.fallback_font.get_string_size(t.texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_FUENTE).x
	t.sucio = false


func _agregar_particula(pos: Vector2, vel: Vector2, vida: float, color: Color, tamano: float) -> void:
	if _particulas.size() >= MAX_PARTICULAS:
		return
	var p: Particula = _libres.pop_back() if not _libres.is_empty() else Particula.new()
	p.pos = pos
	p.vel = vel
	p.vida = vida
	p.vida_max = vida
	p.color = color
	p.tamano = tamano
	p.material_id = -1
	p.inicio = pos
	p.destino = pos
	p.convergente = false
	p.forma = Forma.RETAZO
	p.estela = 0.0
	p.giro = 0.0
	p.angulo = vel.angle()
	p.eje = Vector2.from_angle(p.angulo)
	_particulas.append(p)


func _process(delta: float) -> void:
	if _frenesi_restante > 0.0:
		_frenesi_restante = maxf(0.0, _frenesi_restante - delta)
		_fase_halo += delta
		if _frenesi_restante <= 0.0:
			_entradas_halo.clear()
	_pausa_marca = maxf(0, _pausa_marca - delta)
	_pausa_entrega = maxf(0, _pausa_entrega - delta)
	_pausa_epico = maxf(0, _pausa_epico - delta)
	_pausa_mordida = maxf(0, _pausa_mordida - delta)
	_pausa_destruccion = maxf(0, _pausa_destruccion - delta)
	_pausa_rafaga = maxf(0, _pausa_rafaga - delta)
	_pausa_racha = maxf(0, _pausa_racha - delta)
	for i in _pausas_amenaza.size():
		_pausas_amenaza[i] = maxf(0.0, _pausas_amenaza[i] - delta)
	if _particulas.is_empty() and _ondas.is_empty() and _textos.is_empty() and _marcas.is_empty():
		if maxf(maxf(_pausa_marca, _pausa_entrega), maxf(_pausa_epico, _pausa_mordida)) <= 0.0 \
			and maxf(maxf(_pausa_destruccion, _pausa_rafaga), _pausa_racha) <= 0.0 and _pausas_amenaza.max() <= 0.0 and _frenesi_restante <= 0.0:
			set_process(false)
		queue_redraw()
		return
	for i in range(_marcas.size() - 1, -1, -1):
		_marcas[i].vida -= delta
		if _marcas[i].vida <= 0:
			_marcas_libres.append(_marcas[i])
			_marcas[i] = _marcas.back()
			_marcas.pop_back()
	var zoom := _zoom()
	var friccion := pow(0.03, delta)
	for i in range(_particulas.size() - 1, -1, -1):
		var p := _particulas[i]
		p.vida -= delta
		if p.vida <= 0.0:
			# El orden no afecta a estos cuadrados; no desplazar hasta 600 referencias.
			_particulas[i] = _particulas.back()
			_particulas.pop_back()
			_libres.append(p)
			continue
		if p.convergente:
			var progreso := 1.0 - p.vida / p.vida_max
			p.pos = p.inicio.lerp(p.destino, 1.0 - pow(1.0 - progreso, 3.0))
		else:
			p.pos += p.vel * delta
			p.vel *= friccion
		if p.giro != 0.0:
			p.angulo += p.giro * delta
			p.eje = Vector2.from_angle(p.angulo)
	for i in range(_ondas.size() - 1, -1, -1):
		_ondas[i].vida -= delta
		if _ondas[i].vida <= 0.0:
			_ondas_libres.append(_ondas[i])
			_ondas[i] = _ondas.back()
			_ondas.pop_back()
	for i in range(_textos.size() - 1, -1, -1):
		var t := _textos[i]
		t.vida -= delta
		if t.vida <= 0.0:
			_textos_libres.append(t)
			_textos.remove_at(i)
			continue
		t.pos.y -= 18.0 / zoom * delta
	queue_redraw()


func _draw() -> void:
	depositos_dibujados = 0
	fracciones_dibujadas = 0
	halos_dibujados = 0
	var zoom := _zoom()
	var escala_minima := maxf(1.0, 0.8 / zoom)
	var rect_visible := get_canvas_transform().affine_inverse() * get_viewport_rect().grow(80.0)
	if _frenesi_restante > 0.0:
		_dibujar_halos(zoom, rect_visible)
	for p in _particulas:
		if not rect_visible.has_point(p.pos):
			continue
		var alfa := clampf(p.vida / p.vida_max * 1.5, 0.0, 1.0)
		var lado := p.tamano * escala_minima
		var tinta := Color(p.color, alfa)
		var eje := p.eje
		if p.estela > 0.0:
			var largo := p.estela * escala_minima * minf(1.0, p.vida / (p.vida_max * 0.3))
			draw_line(p.pos - eje * largo, p.pos, Color(COLOR_SOMBRA_TEXTO, alfa * 0.5), lado + 1.5 / zoom, true)
			draw_line(p.pos - eje * largo, p.pos, Color(p.color, alfa * 0.85), lado * 0.75, true)
		if p.material_id == 1:
			draw_line(p.pos - eje * lado * 1.5, p.pos + eje * lado * 1.5, tinta, lado * 0.8, true)
		elif p.forma == Forma.POLVO:
			draw_circle(p.pos, lado, Color(p.color, alfa * 0.25), false, lado * 0.6, true)
		elif p.forma == Forma.BRILLO:
			draw_line(p.pos - eje * lado * 1.5, p.pos + eje * lado * 1.5, Color(COLOR_SOMBRA_TEXTO, alfa * 0.5), lado * 0.65 + 1.5 / zoom, true)
			draw_line(p.pos - eje * lado * 1.5, p.pos + eje * lado * 1.5, tinta, lado * 0.65, true)
			draw_line(p.pos - eje.orthogonal() * lado, p.pos + eje.orthogonal() * lado, Color(p.color, alfa * 0.65), lado * 0.5, true)
		elif p.material_id == 2:
			draw_line(p.pos - eje * lado, p.pos + eje * lado, tinta, lado, true)
		else:
			draw_rect(Rect2(p.pos - Vector2.ONE * lado * 0.5, Vector2.ONE * lado), tinta)
	for marca in _marcas:
		if rect_visible.intersects(Rect2(marca.a, Vector2.ZERO).expand(marca.b).grow(4.0)):
			draw_line(marca.a, marca.b, Color(marca.color, marca.vida / 0.35), 2 / zoom, true)
	for o in _ondas:
		if rect_visible.grow(o.radio_max).has_point(o.pos):
			_dibujar_onda(o, zoom)
	var fuente := ThemeDB.fallback_font
	_rect_textos.clear()
	var transformacion := get_canvas_transform()
	var inversa := transformacion.affine_inverse()
	var presupuesto := 8 if zoom < 0.25 else MAX_TEXTOS_VISIBLES
	var zona_segura := get_viewport_rect().grow(-12.0)
	# Priorizar los últimos ingresos y no tapar el mapa con nombres repetidos.
	for i in range(_textos.size() - 1, -1, -1):
		if _rect_textos.size() >= presupuesto:
			break
		var t := _textos[i]
		_actualizar_texto(t)
		if zoom < 0.25 and t.cantidad <= 0:
			continue
		var alfa := clampf(t.vida / (t.vida_max * 0.3), 0.0, 1.0)
		if alfa < 0.05:
			continue
		# Un solo tamaño de fuente cacheado. El mínimo en pantalla no baja con
		# el zoom: antes una fracción quedaba oculta o medía apenas trece píxeles.
		var tamano := tamano_numero_pantalla(t)
		var escala_pantalla := tamano / TAMANO_FUENTE
		var posicion_pantalla := transformacion * t.pos + Vector2(t.carril, -22.0)
		var rect := Rect2(posicion_pantalla - Vector2(t.ancho * escala_pantalla * 0.5 + 16.0, tamano + 6.0),
			Vector2((t.ancho + 8.0) * escala_pantalla + 24.0, tamano * 1.25 + 8.0))
		if not get_viewport_rect().intersects(rect):
			continue
		var original := rect.position
		var colocado := false
		# Repartir una tanda alrededor/encima de la entrada en vez de esconder
		# todos los números salvo el último. Seis intentos acotados, sin ordenar.
		for intento in 6:
			rect.position.x = clampf(rect.position.x, zona_segura.position.x, maxf(zona_segura.position.x, zona_segura.end.x - rect.size.x))
			rect.position.y = clampf(original.y - intento * (rect.size.y + 4.0), zona_segura.position.y, maxf(zona_segura.position.y, zona_segura.end.y - rect.size.y))
			var solapado := false
			for ocupado in _rect_textos:
				if rect.intersects(ocupado):
					solapado = true
					break
			if not solapado:
				colocado = true
				break
		if not colocado:
			continue
		posicion_pantalla += rect.position - original
		_rect_textos.append(rect)
		var escala := escala_pantalla / zoom
		draw_set_transform(inversa * posicion_pantalla, 0, Vector2.ONE * escala)
		var origen := -Vector2(t.ancho * 0.5, 0.0)
		draw_string_outline(fuente, origen + Vector2(0, 2), t.texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_FUENTE,
			7, Color(COLOR_SOMBRA_TEXTO, alfa * 0.45))
		draw_string_outline(fuente, origen, t.texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_FUENTE,
			4, Color(COLOR_SOMBRA_TEXTO, alfa))
		draw_string(fuente, origen, t.texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_FUENTE, Color(t.color, alfa))
		if t.clase == "deposito":
			draw_line(origen + Vector2(-13, -10), origen + Vector2(-9, -6), Color(t.color, alfa), 2.5, true)
			draw_line(origen + Vector2(-9, -6), origen + Vector2(-3, -14), Color(t.color, alfa), 2.5, true)
			depositos_dibujados += 1
			if t.cantidad > 0.0 and t.cantidad < 1.0:
				fracciones_dibujadas += 1
	draw_set_transform(Vector2.ZERO)


## Cada gesto cambia de dirección, ritmo y silueta sin agregar partículas.
## Los segmentos son fijos y cortos: nunca hay polígonos por píxel de material.
func _dibujar_onda(o: Onda, zoom: float) -> void:
	var t := 1.0 - o.vida / o.vida_max
	var alfa := (1.0 - t) * 0.75
	var ancho := 1.6 / zoom
	var radio := maxf(0.5, o.radio_max * ease(t, 0.4))
	var tinta := Color(o.color, alfa)
	match o.estilo:
		Pulso.ENTREGA:
			ancho = 3.2 / zoom
			radio = o.radio_max * lerpf(1.0, 0.12, t)
			for i in o.acentos:
				var angulo := i * TAU / o.acentos + t * 0.35
				draw_arc(o.pos, radio, angulo, angulo + 0.85, 10, Color(COLOR_SOMBRA_TEXTO, alfa * 0.6), ancho + 2.0 / zoom, true)
				draw_arc(o.pos, radio, angulo, angulo + 0.85, 10, Color(o.color, (1.0 - t) * 0.95), ancho, true)
			if t > 0.45:
				var brazo := 7.0 / zoom * (1.0 - t)
				draw_line(o.pos - Vector2(brazo, 0), o.pos + Vector2(brazo, 0), tinta, 2.3 / zoom, true)
				draw_line(o.pos - Vector2(0, brazo), o.pos + Vector2(0, brazo), tinta, 2.3 / zoom, true)
		Pulso.GOLPE:
			for lado in [-1.0, 1.0]:
				var eje := Vector2.from_angle(o.direccion + lado * 0.65)
				draw_line(o.pos + eje * radio * 0.45, o.pos + eje * radio, Color(COLOR_SOMBRA_TEXTO, alfa * 0.65), 3.5 / zoom, true)
				draw_line(o.pos + eje * radio * 0.45, o.pos + eje * radio, tinta, 2.0 / zoom, true)
		Pulso.DESTRUCCION:
			for i in 4:
				var angulo := i * TAU / 4.0 + 0.25
				draw_arc(o.pos, radio, angulo, angulo + 0.8, 10, Color(COLOR_SOMBRA_TEXTO, alfa * 0.4), 4.0 / zoom, true)
				draw_arc(o.pos, radio, angulo, angulo + 0.8, 10, Color(o.color, alfa * 0.8), 2.2 / zoom, true)
		Pulso.EPICO:
			for i in 6:
				var angulo := i * TAU / 6.0 + o.direccion + t * 0.16
				draw_arc(o.pos, radio, angulo, angulo + 0.8, 11, Color(COLOR_SOMBRA_TEXTO, alfa * 0.5), 5.5 / zoom, true)
				draw_arc(o.pos, radio, angulo, angulo + 0.8, 11, tinta, 3.5 / zoom, true)
		Pulso.AVISO:
			radio = o.radio_max * lerpf(1.12, 1.0, t)
			var pulso := 0.5 + 0.3 * sin(t * TAU * 2.0)
			for i in 3:
				var angulo := i * TAU / 3.0 + o.direccion
				draw_arc(o.pos, radio, angulo + 0.2, angulo + 1.25, 12, Color(o.color, pulso * minf(1.0, o.vida * 5.0)), ancho, true)
		Pulso.IMPACTO:
			for i in 6:
				var eje := Vector2.from_angle(i * TAU / 6.0 + o.direccion)
				draw_line(o.pos + eje * radio * 0.6, o.pos + eje * radio, tinta, ancho, true)
		Pulso.REPELIDO:
			for i in 3:
				var eje := Vector2.from_angle(o.direccion + (i - 1) * 0.7)
				var centro := o.pos + eje * radio
				draw_line(centro - eje.rotated(-0.55) * 6.0, centro, tinta, ancho, true)
				draw_line(centro - eje.rotated(0.55) * 6.0, centro, tinta, ancho, true)
		Pulso.RAFAGA:
			for i in 3:
				var angulo := i * TAU / 3.0 + t * 0.55
				draw_arc(o.pos, radio, angulo, angulo + 1.25, 16, Color(COLOR_SOMBRA_TEXTO, alfa * 0.6), 6.0 / zoom, true)
				draw_arc(o.pos, radio, angulo, angulo + 1.25, 16, tinta, 4.0 / zoom, true)
		Pulso.RACHA:
			for i in o.acentos:
				var eje := Vector2.from_angle(o.direccion + (i - (o.acentos - 1) * 0.5) * 0.4)
				draw_line(o.pos + eje * radio * 0.6, o.pos + eje * radio, Color(COLOR_SOMBRA_TEXTO, alfa * 0.65), 7.0 / zoom, true)
				draw_line(o.pos + eje * radio * 0.6, o.pos + eje * radio, tinta, 4.5 / zoom, true)
		Pulso.RECIBO:
			# El aro abre hacia afuera mientras la entrega base entra: dos
			# movimientos legibles, sin una nube que tape a la obrera.
			radio = o.radio_max * lerpf(0.7, 1.0, t)
			for i in 3:
				var angulo := i * TAU / 3.0 + t * 0.45
				draw_arc(o.pos, radio, angulo, angulo + 0.7, 9, Color(COLOR_SOMBRA_TEXTO, alfa * 0.45), 4.0 / zoom, true)
				draw_arc(o.pos, radio, angulo, angulo + 0.7, 9, tinta, 3.0 / zoom, true)
		Pulso.CORTE:
			var centro := o.pos + Vector2.from_angle(o.direccion) * radio * 0.1
			var eje := Vector2.from_angle(o.direccion + 0.65)
			var largo := radio * (0.7 + t * 0.3)
			draw_line(centro - eje * largo, centro + eje * largo, Color(COLOR_SOMBRA_TEXTO, alfa * 0.65), 5.2 / zoom, true)
			draw_line(centro - eje * largo, centro + eje * largo, tinta, 3.2 / zoom, true)
			var brazo := eje.orthogonal() * largo * 0.42
			draw_line(centro - brazo, centro + brazo, Color(o.color, alfa * 0.85), 1.8 / zoom, true)
		_:
			draw_arc(o.pos, radio, 0, TAU, 32, tinta, ancho, true)


## Como máximo ocho entradas, no las quinientas hormigas. El halo acompaña
## un frenesí real y se apaga aunque deje de llegar el refresco de la run.
func _dibujar_halos(zoom: float, rect_visible: Rect2) -> void:
	var respiracion := 0.5 + 0.5 * sin(_fase_halo * 4.5)
	var fin := minf(1.0, _frenesi_restante * 3.0)
	var radio := _radio_pantalla(44.0, 28.0, 55.0) * lerpf(0.94, 1.06, respiracion)
	var tinta := Color("b9efd0", (0.5 + respiracion * 0.25) * fin)
	for entrada in _entradas_halo:
		if not rect_visible.grow(radio).has_point(entrada):
			continue
		halos_dibujados += 1
		draw_arc(entrada, radio, 0.0, TAU, 40, Color("8cd8b0", 0.22 * fin), 5.0 / zoom, true)
		for i in 3:
			var angulo := i * TAU / 3.0 + _fase_halo * 0.6
			draw_arc(entrada, radio, angulo, angulo + 1.1, 12, tinta, 2.4 / zoom, true)
			var punto := entrada + Vector2.from_angle(angulo + 1.1) * radio
			var lado := 2.8 / zoom
			draw_line(punto - Vector2(lado, 0.0), punto + Vector2(lado, 0.0), Color("f6e2a6", 0.6 * fin), 1.4 / zoom, true)
			draw_line(punto - Vector2(0.0, lado), punto + Vector2(0.0, lado), Color("f6e2a6", 0.6 * fin), 1.4 / zoom, true)


func _zoom() -> float:
	return maxf(get_viewport().get_canvas_transform().get_scale().x, 0.01)


func _radio_pantalla(radio_mundo: float, minimo: float, maximo: float) -> float:
	var zoom := _zoom()
	return clampf(radio_mundo * zoom, minimo, maximo) / zoom


func _en_vista(pos: Vector2, margen_mundo := 100.0) -> bool:
	var transformacion := get_canvas_transform()
	return get_viewport_rect().grow(80 + margen_mundo * transformacion.get_scale().x).has_point(transformacion * pos)
