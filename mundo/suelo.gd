extends Node2D
## Un solo plano con juntas filtradas, estable incluso con zoom lejano.

const TAMANO := 96.0
const RADIO_MUNDO := 2600.0
func _ready() -> void:
	var piso := ShaderMaterial.new()
	piso.shader = preload("res://mundo/suelo.gdshader")
	piso.set_shader_parameter("materiales", preload("res://arte/realista/materiales.png"))
	piso.set_shader_parameter("exterior", Juego.lugar_actual in ["obelisco", "coliseo", "eiffel"])
	var plano := Mundos.plano(Juego.lugar_actual)
	piso.set_shader_parameter("tono_exterior", plano.color_exterior)
	piso.set_shader_parameter("patron_exterior", plano.patron_exterior)
	var rectangulos: Array[Vector4] = []
	var colores: Array[Color] = []
	var patrones: Array[int] = []
	for a in PlanoCasa.ambientes():
		var r: Rect2 = a.rect
		rectangulos.append(Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
		colores.append(a.color)
		patrones.append(a.patron)
	while rectangulos.size() < 7:
		rectangulos.append(Vector4(0, 0, 0, 0))
		colores.append(Color.TRANSPARENT)
		patrones.append(0)
	piso.set_shader_parameter("ambientes", rectangulos)
	piso.set_shader_parameter("tonos", colores)
	piso.set_shader_parameter("patrones", patrones)
	material = piso


func _draw() -> void:
	draw_rect(PlanoCasa.limites_visuales(), Color.WHITE)
