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
	float borde_ambiente = 1000.0;
	for (int i = 0; i < 7; i++) {
		vec4 r = ambientes[i];
		if (posicion_mundo.x >= r.x && posicion_mundo.y >= r.y && posicion_mundo.x < r.x + r.z && posicion_mundo.y < r.y + r.w) {
			base = tonos[i].rgb;
			patron = patrones[i];
			vec2 borde = min(posicion_mundo - r.xy, r.xy + r.zw - posicion_mundo);
			borde_ambiente = min(borde.x, borde.y);
		}
	}
	if (patron < 0) {
		COLOR = vec4(base, 1.0);
	} else {
	vec2 tamano = patron == 1 ? vec2(460.0, 108.0) : (patron == 2 ? vec2(150.0) : vec2(240.0));
	vec2 coordenada = posicion_mundo;
	if (patron == 1) { coordenada.x += mod(floor(coordenada.y / tamano.y), 3.0) * 153.0; }
	vec2 celda = floor(coordenada / tamano);
	vec2 interior = mod(coordenada, tamano);
	vec2 borde = min(interior, tamano - interior);
	float distancia = min(borde.x, borde.y);
	float pixel = max(fwidth(posicion_mundo.x), fwidth(posicion_mundo.y));
	// Juntas filtradas: no aparecen cuadrículas falsas al alejar la cámara.
	float junta = 1.0 - smoothstep(0.6, 0.6 + pixel, distancia);
	if (patron >= 3) { junta = 0.0; } // Arena y césped no son baldosas.
	float variacion = fract(sin(dot(celda, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 baldosa = base + (variacion - 0.5) * (patron == 1 ? 0.065 : 0.018);
	if (patron >= 3) {
		baldosa = base + sin(posicion_mundo.x * 0.005) * sin(posicion_mundo.y * 0.004) * 0.012;
	}
	if (patron == 1) {
		// Veta longitudinal filtrada; desaparece antes de producir moiré.
		float veta = sin(posicion_mundo.y * 0.15 + sin(posicion_mundo.x * 0.009) * 1.4);
		baldosa += veta * 0.009 * (1.0 - smoothstep(3.0, 8.0, pixel));
	}
	float detalle = smoothstep(5.0, 18.0, min(tamano.x, tamano.y) / pixel);
	vec3 color = mix(baldosa, base * 0.78, junta * 0.5 * detalle);
	color *= mix(0.94, 1.0, smoothstep(0.0, 120.0, borde_ambiente));
	COLOR = vec4(color, 1.0);
	}
}
