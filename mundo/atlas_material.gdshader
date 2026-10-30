shader_type canvas_item;
render_mode unshaded;
// Se aplica al sprite YA compuesto, una sola vez al preparar el atlas.
// Conserva el sombreado pintado sobre material opaco, no la sombra proyectada.
void fragment() {
	vec4 cuerpo = COLOR;
	cuerpo.a = step(0.75001, cuerpo.a);
	COLOR = cuerpo;
}
