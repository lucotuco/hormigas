shader_type canvas_item;
render_mode unshaded;
varying vec2 mundo;
uniform float radio = 620.0;
uniform vec4 tono : source_color = vec4(0.055, 0.075, 0.065, 0.56);
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	float d = length(mundo);
	float pixel = max(fwidth(d), 0.5);
	// El territorio sigue teniendo su radio exacto; el borde se desvanece
	// sobre el suelo, sin una circunferencia luminosa que corte el escenario.
	float ancho = max(62.0, pixel * 10.0);
	float sombra = smoothstep(radio - ancho, radio + ancho, d);
	COLOR = vec4(tono.rgb, tono.a * sombra);
}
