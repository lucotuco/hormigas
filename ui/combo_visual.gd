class_name ComboVisual
extends Control
## Un único lienzo y una etiqueta: impacto central, viaje y regreso al HUD.
## Los depósitos se agrupan en HUD; no hay tweens ni nodos por hormiga.
## Sin placa ni oscurecimiento: el contraste pertenece a la letra, no al mapa.
signal impacto(intensidad: float)

const UMBRALES := [3, 10, 25, 50, 100, 250]
const COLORES := [Color("ecd39a"), Color("ffd36e"), Color("ffac72"), Color("ff827d"), Color("d8a0ff"), Color("a3edff")]
const TAMANOS := [24, 27, 30, 32, 34, 36]
const MAX_CHISPAS := 32
const DURACION_VISIBLE := 1.2
const DURACION_DESVANECER := 1.0 / 3.0
const DURACION_HITO := 1.22
const DURACION_IMPACTO := 0.44
const DURACION_CINEMATICA := 1.04
const TAMANO_FUENTE := 96 # Una fuente nítida, escalada sin regenerarla por cuadro.
const POSICION_TEXTO := Vector2(18, 15)
const CENTRO := Vector2(150, 36)

class Chispa extends RefCounted:
	var posicion := Vector2.ZERO
	var velocidad := Vector2.ZERO
	var vida := 0.0
	var vida_max := 0.0
	var ancho := 1.0
	var rayo := false

var etiqueta: Label
var _chispas: Array[Chispa] = []
var _combo := 0
var _etapa := 0
var _edad := 0.0
var _pulso := 0.0
var _hito := 0.0
var _fase := 0.0
var _escala_base := 1.0
var _ancho_acento := 176.0
var _digitos_medidos := 0
var _etapa_medida := 0
var _cerrado := false
var _cinematica := false
var _tiempo_cinematica := 0.0
var _centro_animado := CENTRO
var _escala_hud := 1.0
var _escala_actual := 1.0
var _pantalla := Vector2.ONE
## Contadores QA: son de presentación, no tocan estadísticas ni la partida.
var presentaciones := 0
var celebraciones := 0


static func etapa_de(combo: int) -> int:
	var etapa := 0
	for umbral: int in UMBRALES:
		if combo < umbral:
			break
		etapa += 1
	return etapa


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300, 72)
	size = custom_minimum_size
	clip_contents = false # El mismo texto debe poder salir de su casillero.
	z_index = 80
	set_process(false) # HUD comparte un solo reloj; no otro callback por cuadro.
	for i in MAX_CHISPAS:
		_chispas.append(Chispa.new())
	etiqueta = Estilo.etiqueta("", TAMANO_FUENTE, COLORES[0], 6)
	etiqueta.position = POSICION_TEXTO
	etiqueta.size = Vector2(264, 44)
	etiqueta.pivot_offset = etiqueta.size * 0.5
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.hide()
	add_child(etiqueta)
	hide()
	get_viewport().size_changed.connect(_actualizar_pantalla)
	_actualizar_pantalla()


func _actualizar_pantalla() -> void:
	_pantalla = get_viewport_rect().size.max(Vector2.ONE)
	if visible:
		_aplicar_pose()
		queue_redraw()


func fase_cinematica() -> String:
	if not _cinematica:
		return "inactiva"
	return "impacto" if _tiempo_cinematica < DURACION_IMPACTO else "regreso"


func progreso_cinematica() -> float:
	return clampf(_tiempo_cinematica / DURACION_CINEMATICA, 0.0, 1.0)


func limites_etiqueta() -> Rect2:
	return etiqueta.get_global_transform() * Rect2(Vector2.ZERO, etiqueta.size)


## Se llama una sola vez por cuadro aunque haya cientos de entregas reales.
func actualizar(combo: int) -> void:
	if _cerrado:
		return
	presentaciones += 1
	if combo < UMBRALES[0]:
		_reiniciar_racha()
		return
	var anterior := _etapa if combo >= _combo else 0
	_combo = combo
	_etapa = etapa_de(combo)
	_edad = 0.0
	_fase += 1.0
	_pulso = 0.15
	var color: Color = COLORES[_etapa - 1]
	etiqueta.text = tr("COMBO x%d") % combo
	# El acabado se modifica sólo al cambiar de escalón, no durante el pulso.
	if anterior != _etapa:
		etiqueta.label_settings.font_color = color
		etiqueta.label_settings.outline_color = Color("14211de6")
		etiqueta.label_settings.shadow_color = Color("06110ed9").lerp(Color(color, 0.7), 0.18)
		etiqueta.label_settings.shadow_size = 9
		etiqueta.label_settings.shadow_offset = Vector2(1, 5)
	var digitos := str(combo).length()
	if _digitos_medidos != digitos or _etapa_medida != _etapa:
		# Medir sólo al cambiar escalón o cantidad de dígitos, no por cuadro.
		var muestra := tr("COMBO x%d").replace("%d", "8".repeat(digitos))
		var ancho := ThemeDB.fallback_font.get_string_size(muestra, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANOS[_etapa - 1]).x
		_escala_base = minf(1.0, 245.0 / maxf(1.0, ancho))
		_ancho_acento = clampf(ancho * _escala_base + 44.0, 176.0, 280.0)
		_escala_hud = float(TAMANOS[_etapa - 1]) / TAMANO_FUENTE * _escala_base
		# Misma fuente para centro y HUD. La caja usa el ancho máximo de estos
		# dígitos: ni crece el atlas ni se recalcula la tipografía al sacudir.
		etiqueta.size = Vector2(ancho * TAMANO_FUENTE / TAMANOS[_etapa - 1] + 12.0, 144)
		etiqueta.pivot_offset = etiqueta.size * 0.5
		_digitos_medidos = digitos
		_etapa_medida = _etapa
	etiqueta.show()
	show()
	modulate.a = 1.0
	if _etapa > anterior:
		_celebrar()
	_aplicar_pose()
	queue_redraw()


func avanzar(delta: float) -> void:
	if _cerrado or not visible:
		return
	var animando := _pulso > 0.0 or _hito > 0.0 or _cinematica
	_edad += delta
	_pulso = maxf(0.0, _pulso - delta)
	_hito = maxf(0.0, _hito - delta)
	if _cinematica:
		_tiempo_cinematica = minf(DURACION_CINEMATICA, _tiempo_cinematica + delta)
		if _tiempo_cinematica >= DURACION_CINEMATICA or Ajustes.temblor <= 0.0:
			_cinematica = false
	for chispa: Chispa in _chispas:
		if chispa.vida <= 0.0:
			continue
		if Ajustes.temblor <= 0.0:
			chispa.vida = 0.0
			continue
		chispa.vida = maxf(0.0, chispa.vida - delta)
		chispa.posicion += chispa.velocidad * delta
		chispa.velocidad *= exp(-3.0 * delta)
	# La misma ventana real de 1,2 s: el brillo nunca mantiene vivo el combo.
	modulate.a = clampf(1.0 - (_edad - DURACION_VISIBLE) / DURACION_DESVANECER, 0.0, 1.0)
	if modulate.a <= 0.0:
		_reiniciar_racha()
		return
	_aplicar_pose()
	# Redibujar también el cuadro que apaga el último destello.
	if animando or _edad > DURACION_VISIBLE:
		queue_redraw()


func _aplicar_pose() -> void:
	var movimiento := clampf(Ajustes.temblor, 0.0, 1.0)
	var golpe := sin(PI * _pulso / 0.15)
	var latido := 1.0 + golpe * (0.055 + _etapa * 0.006) * movimiento
	_centro_animado = CENTRO
	_escala_actual = _escala_hud * latido
	etiqueta.rotation = 0.0
	if _cinematica and movimiento > 0.0:
		var centro := _centro_pantalla()
		var grande := minf(_pantalla.x * (0.58 + _etapa * 0.025) / etiqueta.size.x,
			_pantalla.y * 0.23 / etiqueta.size.y)
		if _tiempo_cinematica < DURACION_IMPACTO:
			# Entrada de golpe, sostén y sacudida amortiguada. No se frena la IA.
			var entrada := 1.0 - clampf(_tiempo_cinematica / 0.12, 0.0, 1.0)
			var fuerza := (1.0 - _tiempo_cinematica / DURACION_IMPACTO) * movimiento
			_centro_animado = centro + Vector2(sin(_tiempo_cinematica * 93.0), cos(_tiempo_cinematica * 79.0)) * (9.0 + _etapa * 2.0) * fuerza
			_escala_actual = grande * (1.0 + 0.28 * entrada * entrada * entrada)
			etiqueta.rotation = sin(_tiempo_cinematica * 67.0) * 0.035 * fuerza
		else:
			var viaje := (_tiempo_cinematica - DURACION_IMPACTO) / (DURACION_CINEMATICA - DURACION_IMPACTO)
			var suave := viaje * viaje * (3.0 - 2.0 * viaje)
			_centro_animado = centro.lerp(CENTRO, suave) + Vector2(90, -110) * sin(PI * viaje)
			_escala_actual = lerpf(grande, _escala_hud, suave)
			etiqueta.rotation = -sin(PI * viaje) * 0.07 * movimiento
	etiqueta.scale = Vector2.ONE * _escala_actual
	etiqueta.position = _centro_animado - etiqueta.size * 0.5


func _centro_pantalla() -> Vector2:
	return get_global_transform().affine_inverse() * (_pantalla * 0.5)


func _celebrar() -> void:
	# Un escalón mayor durante el impacto adopta su color y valor SIN volver
	# al centro ni reiniciar el viaje. Tampoco se encola una película por pago.
	if _cinematica:
		return
	celebraciones += 1
	_hito = DURACION_HITO
	_cinematica = Ajustes.temblor > 0.0
	_tiempo_cinematica = 0.0
	if _cinematica:
		impacto.emit(9.0 + _etapa * 1.5)
	# No usa randf(): un destello nunca cambia el azar de la IA o los enemigos.
	var cantidad := mini(MAX_CHISPAS, 8 + _etapa * 4)
	for i in MAX_CHISPAS:
		var chispa := _chispas[i]
		chispa.vida = 0.0
		if i >= cantidad or Ajustes.temblor <= 0.0:
			continue
		var angulo := TAU * float(i) / cantidad + _fase * 0.43
		var direccion := Vector2.from_angle(angulo)
		chispa.posicion = CENTRO + direccion * Vector2(_ancho_acento * 0.4, 18.0)
		chispa.velocidad = direccion * Vector2(38.0, 22.0)
		chispa.vida_max = 0.38 + float(i % 4) * 0.09
		chispa.vida = chispa.vida_max
		chispa.ancho = 1.1 + _etapa * 0.12
		chispa.rayo = _etapa >= 3 and i % 3 == 0


func _draw() -> void:
	if _etapa <= 0 or _cerrado:
		return
	var color: Color = COLORES[_etapa - 1]
	var rect := Rect2(CENTRO - Vector2(_ancho_acento * 0.5, 25), Vector2(_ancho_acento, 50))
	var viaje := clampf((_tiempo_cinematica - DURACION_IMPACTO) / (DURACION_CINEMATICA - DURACION_IMPACTO), 0.0, 1.0)
	var presencia := 1.0 - viaje if _cinematica else 0.0
	if _cinematica:
		_dibujar_impacto(color, presencia)
	# Los escalones se leen también sin animación: una muesca por etapa.
	var factor := clampf(_escala_actual / maxf(_escala_hud, 0.01), 1.0, 5.0)
	var inicio := _centro_animado + Vector2(-(_etapa - 1) * 5.0, 22.0) * factor
	for i in _etapa:
		var p := inicio + Vector2(i * 10 * factor, 0)
		draw_line(p - Vector2(2 * factor, 0), p + Vector2(2 * factor, 0), Color(color, 0.9), 2.0 * factor, true)
	if _hito > 0.0 and not _cinematica:
		var fuerza := _hito / DURACION_HITO
		# El nuevo color queda en el casillero al aterrizar.
		draw_arc(CENTRO, _ancho_acento * 0.5 + 3.0, -0.15, 0.15, 12, Color(color, fuerza * 0.65), 2.0, true)
		draw_arc(CENTRO, _ancho_acento * 0.5 + 3.0, PI - 0.15, PI + 0.15, 12, Color(color, fuerza * 0.65), 2.0, true)
		if _etapa >= 4:
			draw_line(rect.position + Vector2(14, 1), rect.position + Vector2(rect.size.x - 14, 1), Color(color, fuerza * 0.7), 2.0, true)
	for chispa: Chispa in _chispas:
		if chispa.vida <= 0.0:
			continue
		var alfa := chispa.vida / chispa.vida_max
		var direccion := chispa.velocidad.normalized()
		var largo := (7.0 if chispa.rayo else 3.0) * alfa * factor
		var tinta := Color(color, alfa)
		var posicion := _centro_animado + (chispa.posicion - CENTRO) * factor
		draw_line(posicion - direccion * largo, posicion + direccion * largo, tinta, chispa.ancho * factor, true)
		if chispa.rayo:
			draw_line(posicion - direccion.orthogonal() * largo * 0.5, posicion + direccion.orthogonal() * largo * 0.5, tinta, factor, true)


func _dibujar_impacto(color: Color, presencia: float) -> void:
	var t := clampf(_tiempo_cinematica / DURACION_IMPACTO, 0.0, 1.0)
	var centro := _centro_pantalla()
	var radio := minf(_pantalla.x * 0.32, _pantalla.y * 0.38)
	# Dos ondas y doce rayos: geometría acotada, sin bloom ni postprocesado.
	for i in 2:
		var expansion := clampf(t * 1.4 - i * 0.18, 0.0, 1.0)
		var alfa := (1.0 - expansion) * presencia
		draw_arc(centro, radio * (0.5 + expansion * 0.9), 0.0, TAU, 64,
			Color(color, alfa * 0.7), (4.0 - i) * (1.0 - expansion) + 1.0, true)
	for i in 12:
		var direccion := Vector2.from_angle(TAU * i / 12.0 + 0.12)
		var elipse := direccion * Vector2(_pantalla.x * 0.40, radio)
		var desde := centro + elipse * (0.8 + t * 0.15)
		var hasta := centro + elipse * (0.93 + t * 0.16)
		draw_line(desde, hasta, Color(color, presencia * (1.0 - t * 0.65)), 3.0, true)


func _reiniciar_racha() -> void:
	_combo = 0
	_etapa = 0
	_pulso = 0.0
	_hito = 0.0
	_cinematica = false
	_tiempo_cinematica = 0.0
	_centro_animado = CENTRO
	for chispa: Chispa in _chispas:
		chispa.vida = 0.0
	etiqueta.hide()
	etiqueta.scale = Vector2.ONE
	etiqueta.position = POSICION_TEXTO
	etiqueta.rotation = 0.0
	hide()


## Terminal: los callbacks tardíos del informe no reviven efectos ni texto.
func limpiar() -> void:
	_cerrado = true
	_reiniciar_racha()
	queue_redraw()
