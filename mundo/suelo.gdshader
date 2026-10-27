shader_type canvas_item;
render_mode unshaded;

varying vec2 posicion_mundo;
uniform vec4 ambientes[7];
uniform vec4 tonos[7];
uniform int patrones[7];

void vertex() {
	posicion_mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec3 base = vec3(0.12, 0.16, 0.14);
	int patron = -1;
	for (int i = 0; i < 7; i++) {
		vec4 r = ambientes[i];
		if (posicion_mundo.x >= r.x && posicion_mundo.y >= r.y && posicion_mundo.x < r.x + r.z && posicion_mundo.y < r.y + r.w) {
			base = tonos[i].rgb;
			patron = patrones[i];
		}
	}
	if (patron < 0) {
		COLOR = vec4(base, 1.0);
	} else {
	vec2 tamano = patron == 1 ? vec2(320.0, 72.0) : (patron == 2 ? vec2(96.0) : vec2(144.0));
	vec2 coordenada = posicion_mundo;
	if (patron == 1) { coordenada.x += mod(floor(coordenada.y / tamano.y), 2.0) * 160.0; }
	vec2 celda = floor(coordenada / tamano);
	vec2 interior = mod(coordenada, tamano);
	vec2 borde = min(interior, tamano - interior);
	float distancia = min(borde.x, borde.y);
	float pixel = max(fwidth(posicion_mundo.x), fwidth(posicion_mundo.y));
	// Juntas filtradas: no aparecen cuadrículas falsas al alejar la cámara.
	float junta = 1.0 - smoothstep(0.6, 0.6 + pixel, distancia);
	float variacion = fract(sin(dot(celda, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 baldosa = base + (variacion - 0.5) * (patron == 1 ? 0.055 : 0.012);
	if (patron == 1) { baldosa += sin(posicion_mundo.x * 0.035 + sin(posicion_mundo.y * 0.05)) * 0.007; }
	float detalle = smoothstep(5.0, 18.0, min(tamano.x, tamano.y) / pixel);
	vec3 color = mix(baldosa, base * 0.76, junta * 0.65 * detalle);
	COLOR = vec4(color, 1.0);
	}
}
