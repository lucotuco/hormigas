extends Node2D
## Un solo plano con juntas filtradas, estable incluso con zoom lejano.

const TAMANO := 96.0
const RADIO_MUNDO := 2600.0
func _ready() -> void:
	var piso := ShaderMaterial.new()
	piso.shader = preload("res://mundo/suelo.gdshader")
	var rectangulos: Array[Vector4] = []
	var colores: Array[Color] = []
	var patrones: Array[int] = []
	for a in PlanoCasa.AMBIENTES:
		var r: Rect2 = a.rect
		rectangulos.append(Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
		colores.append(a.color)
		patrones.append(a.patron)
	piso.set_shader_parameter("ambientes", rectangulos)
	piso.set_shader_parameter("tonos", colores)
	piso.set_shader_parameter("patrones", patrones)
	material = piso


func _draw() -> void:
	draw_rect(Rect2(-32000, -32000, 64000, 64000), Color.WHITE)
