class_name Conquista
extends Node
## El momento de devorar un gran objetivo: cámara lenta, la cámara mira el
## derrumbe, explosiones escalonadas por todo el mueble, lluvia de migas y un
## cartel con las coronas. Es el clímax de cada destino (y lo que se ve en un
## video), así que tiene que sentirse grande. Todo es cosmético: la partida
## ya se actualizó antes (Juego.completar_destino).

const DURACION_LENTA := 1.4      # segundos reales en cámara lenta
const CAMARA_LENTA := 0.25
const ESTALLIDOS := 9

var run: Run
var _rect := Rect2()
var _color := Color.WHITE
var _escala_anterior := 1.0


## Arranca la celebración. `entregadas` son las coronas que dio (0 si ya se
## habían cobrado en esta colonia).
static func celebrar(r: Run, pieza: PiezaCasa, entregadas: int) -> Conquista:
	var c := Conquista.new()
	c.run = r
	c._rect = pieza.rect_mundo
	c._color = pieza.color
	r.add_child(c)
	c._empezar(entregadas)
	return c


func _empezar(entregadas: int) -> void:
	var centro := _rect.get_center()
	var tamano := _rect.size.length()
	# En headless (pruebas y bot) no hay nada que mirar: sin cámara lenta.
	var con_pantalla := DisplayServer.get_name() != "headless"
	run.camara.mirar(centro, _rect.size)
	if con_pantalla:
		_escala_anterior = Engine.time_scale
		Engine.time_scale = CAMARA_LENTA
	run.camara.sacudir(24.0)
	Sonido.tocar("romper", 0.5, 0.0)
	var tween := create_tween().set_ignore_time_scale(true)
	for i in ESTALLIDOS:
		tween.tween_callback(_estallido.bind(i))
		tween.tween_interval(0.09)
	tween.tween_callback(func() -> void:
		run.efectos.explosion(centro, Color("f0d277"), tamano * 0.35)
		run.hud.migas_voladoras(run.a_pantalla(centro), 40)
		Sonido.tocar("crecer", 0.8, 0.0))
	tween.tween_interval(maxf(0.0, DURACION_LENTA - ESTALLIDOS * 0.09))
	tween.tween_callback(_terminar_lenta)
	run.hud.mostrar_conquista(_titulo(), _detalle(entregadas))


func _estallido(i: int) -> void:
	var p := _rect.position + Vector2(randf(), randf()) * _rect.size
	run.efectos.explosion(p, _color.lerp(Color.WHITE, randf() * 0.3), _rect.size.length() * 0.08)
	run.efectos.chispas(p, Color("f0d277"), 10)
	run.camara.sacudir(8.0)
	if i % 3 == 0:
		Sonido.tocar("romper", 0.6 + i * 0.05, 0.05)


func _terminar_lenta() -> void:
	if DisplayServer.get_name() != "headless" and is_equal_approx(Engine.time_scale, CAMARA_LENTA):
		Engine.time_scale = _escala_anterior
	queue_free()


func _exit_tree() -> void:
	# Si la run se cierra en plena cámara lenta, no dejar el juego lento.
	if DisplayServer.get_name() != "headless" and is_equal_approx(Engine.time_scale, CAMARA_LENTA):
		Engine.time_scale = _escala_anterior


func _titulo() -> String:
	if Juego.lugar_actual == Mundos.ORDEN.back():
		return tr("¡La colonia conquistó el mundo!")
	return tr("¡Destino conquistado!")


func _detalle(entregadas: int) -> String:
	var lineas := PackedStringArray()
	lineas.append(tr("%s · gran objetivo devorado: %s") % [tr(Mundos.INFO[Juego.lugar_actual].nombre), tr(Mundos.INFO[Juego.lugar_actual].meta)])
	if entregadas == 1:
		lineas.append(tr("+1 corona"))
	elif entregadas > 1:
		lineas.append(tr("+%d coronas") % entregadas)
	else:
		lineas.append(tr("Las coronas de este destino ya se cobraron en esta colonia"))
	var indice := Mundos.ORDEN.find(Juego.lugar_actual)
	if indice + 1 < Mundos.ORDEN.size():
		lineas.append(tr("Nuevo destino: %s") % tr(Mundos.INFO[Mundos.ORDEN[indice + 1]].nombre))
	else:
		lineas.append(tr("Gracias por jugar. Fundá colonias para batir tus récords."))
	return "\n".join(lineas)
