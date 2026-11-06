shader_type canvas_item;
render_mode unshaded;
// Se aplica al sprite YA compuesto, una sola vez al preparar el atlas.
// Conserva el sombreado pintado sobre material opaco, no la sombra proyectada.
void fragment() {
	vec4 cuerpo = COLOR;
	// La cobertura subpíxel del borde es información del dibujo. El cutoff
	// binario la perdía y formaba escalones al ampliar. Las sombras de apoyo
	// quedan fuera (<0.5); alfa>0.5 conserva el mismo umbral físico >0.75.
	cuerpo.a = clamp((cuerpo.a - 0.5) * 2.0, 0.0, 1.0);
	// Una pincelada finísima aislada puede tener cobertura, pero ningún
	// texel material. No convertirla en un resto imposible de comer. Sólo
	// el AA exterior necesita esta vecindad, una vez al hornear el atlas.
	if (cuerpo.a > 0.0 && cuerpo.a < 1.0) {
		float vecino = 0.0;
		float menor = 1.0;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				float a = texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE).a;
				vecino = max(vecino, a);
				menor = min(menor, a);
			}
		}
		if (cuerpo.a > 0.5 && menor > 0.75) {
			// Las piezas contiguas pueden dejar una costura de cobertura
			// dentro de material sólido. La clasificación física no cambia.
			cuerpo.a = 1.0;
		} else if (cuerpo.a <= 0.5 && (vecino <= 0.75 || menor > 0.5)) {
			cuerpo.a = 0.0;
		}
	}
	COLOR = cuerpo;
}
