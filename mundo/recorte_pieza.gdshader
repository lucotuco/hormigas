shader_type canvas_item;
render_mode unshaded;
varying vec2 local;
uniform vec2 tamano = vec2(140.0, 190.0);
uniform ivec2 grilla = ivec2(3, 4);
uniform int material_id = 1;
uniform float corrosion = 0.0;
// x: resistencia restante; yz: punto de mordida dentro de la celda.
uniform vec4 cortes[16];
void vertex() { local = VERTEX; }
void fragment() {
	vec2 uv = (local + tamano * 0.5) / tamano;
	vec2 celda = floor(uv * vec2(grilla));
	vec4 color = COLOR;
	if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
		int id = int(celda.y) * grilla.x + int(celda.x);
		vec4 estado = cortes[id];
		color.rgb = mix(color.rgb, color.rgb * vec3(0.7, 1.2, 0.55), corrosion * 0.45);
		if (estado.x < 0.001) { color.a = 0.0; }
		else if (estado.x < 0.999) {
			vec2 p = fract(uv * vec2(grilla));
			vec2 d = p - estado.yz;
			float rugoso = material_id == 1 ? sin(p.y * 65.0) * 0.07 : sin(p.x * 29.0 + p.y * 17.0) * 0.035;
			float radio = sqrt(1.0 - estado.x) * 1.3;
			float borde = length(d) + rugoso - radio;
			color.a *= smoothstep(-0.015, 0.015, borde);
			color.rgb *= mix(0.65, 1.0, smoothstep(0.0, 0.06, borde));
		}
	}
	COLOR = color;
}
