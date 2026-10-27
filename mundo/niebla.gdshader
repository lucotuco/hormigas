shader_type canvas_item;
render_mode unshaded;
varying vec2 mundo;
uniform float radio = 620.0;
uniform vec4 tono : source_color = vec4(0.055, 0.075, 0.065, 0.56);
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	float d = length(mundo);
	float pixel = max(fwidth(d), 0.5);
	float sombra = smoothstep(radio - 30.0, radio + 8.0, d);
	float linea = 1.0 - smoothstep(pixel * 0.3, pixel * 1.5, abs(d - radio));
	vec4 color = vec4(tono.rgb, tono.a * sombra);
	color.rgb = mix(color.rgb, vec3(0.85, 0.9, 0.68), linea * 0.3);
	color.a = max(color.a, linea * 0.22);
	COLOR = color;
}
