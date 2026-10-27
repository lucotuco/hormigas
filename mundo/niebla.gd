class_name Niebla
extends Node2D
## Una sola superficie, en lugar de 384 polígonos separados.
var radio := 200.0:
	set(valor):
		radio = valor
		if material:
			material.set_shader_parameter("radio", valor)

func _ready() -> void:
	var niebla := ShaderMaterial.new()
	niebla.shader = preload("res://mundo/niebla.gdshader")
	material = niebla
	niebla.set_shader_parameter("radio", radio)

func _draw() -> void:
	draw_rect(Rect2(-32000, -32000, 64000, 64000), Color.WHITE)
