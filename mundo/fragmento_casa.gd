class_name FragmentoCasa
extends Comida
## Montón agregado, sin rigid bodies. Hasta 64 activos en una expedición.
var peso := 1
var material_id := 1
var clave_apilado := ""

func iniciar(pos: Vector2, valor: float, material_tipo: int) -> void:
	position = pos
	material_id = material_tipo
	peso = 1 if material_tipo == 1 else 2
	var tonos := [Color("e7c77d"), Color("bc9364"), Color("9cb5ac"), Color("c8bba2")]
	var nombres := [tr("Fragmentos de comida"), tr("Fragmentos de madera y tela"), tr("Fragmentos de material resistente"), tr("Fragmentos de muro")]
	configurar({"id": "fragmento", "nombre": nombres[material_tipo], "forma": "fragmento", "color": tonos[material_tipo], "vida": 1, "recompensa": valor, "radio": 8}, 17)
	rotation = 0

func sumar(valor: float, nuevo_material := -1) -> void:
	# La recompensa de los fragmentos ya incluye el multiplicador al extraerse.
	recompensa += valor
	if nuevo_material > material_id:
		material_id = nuevo_material
		peso = 1 if material_id == 1 else 2
		nombre = tr("Montón mixto de fragmentos")
	queue_redraw()

func morder(dano: float) -> float:
	if muerta or dano <= 0:
		return 0
	vida = 0
	muerta = true
	destruida.emit(self)
	queue_free()
	return recompensa

func _draw() -> void:
	if Graficos.listo:
		Graficos.dibujar(self, "resto:%d" % material_id)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-7, 1), Vector2(-4, -6), Vector2(6, -3), Vector2(7, 5), Vector2(-2, 7)]), color)
	if recompensa > 100:
		draw_circle(Vector2(5, 4), 2, color.lightened(0.3))
