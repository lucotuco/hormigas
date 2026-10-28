shader_type canvas_item;
render_mode unshaded;

varying vec2 posicion_mundo;
uniform vec4 ambientes[7];
uniform vec4 tonos[7];
uniform int patrones[7];
uniform sampler2D materiales : source_color, filter_linear_mipmap, repeat_disable;
uniform bool exterior = false;

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
	vec3 color = base;
	if (patron >= 0 && patron < 3) {
		vec2 sector = patron == 1 ? vec2(1.0, 0.0) : (patron == 2 ? vec2(0.0, 1.0) : (exterior ? vec2(1.0) : vec2(0.0)));
		vec2 repeticion = patron == 1 ? vec2(1600.0, 1100.0) : vec2(1200.0);
		vec2 uv = posicion_mundo / repeticion;
		// Derivadas anteriores a fract: el filtrado no salta en cada repetición.
		vec2 margen = vec2(2.0 / 1254.0);
		vec2 textura_uv = sector * 0.5 + margen + fract(uv) * (0.5 - margen * 2.0);
		vec3 muestra = textureGrad(materiales, textura_uv, dFdx(uv) * 0.5, dFdy(uv) * 0.5).rgb;
		// El ambiente conserva su paleta. Del atlas tomamos sólo un relieve leve:
		// sus cambios de color y juntas ya no forman un segundo damero encima.
		float relieve = clamp(dot(muestra, vec3(0.299, 0.587, 0.114)) - 0.62, -0.15, 0.15);
		color += relieve * 0.12;
		vec2 tamano = patron == 1 ? vec2(600.0, 140.0) : (patron == 2 ? vec2(160.0) : (exterior ? vec2(360.0, 240.0) : vec2(280.0)));
		vec2 coordenada = posicion_mundo;
		if (patron == 1 || exterior) {
			coordenada.x += mod(floor(coordenada.y / tamano.y), 2.0) * tamano.x * 0.5;
		}
		vec2 celda = floor(coordenada / tamano);
		vec2 interior = mod(coordenada, tamano);
		vec2 borde = min(interior, tamano - interior);
		float distancia = min(borde.x, borde.y);
		float pixel = max(max(fwidth(posicion_mundo.x), fwidth(posicion_mundo.y)), 0.5);
		float junta = 1.0 - smoothstep(0.7, 0.7 + pixel, distancia);
		// Variación acotada: las losas se leen como una sola superficie tranquila.
		float variacion = fract(sin(dot(celda, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
		color += variacion * (patron == 1 ? 0.025 : 0.009);
		float detalle = smoothstep(5.0, 18.0, min(tamano.x, tamano.y) / pixel);
		color *= 1.0 - junta * detalle * (patron == 1 ? 0.075 : 0.055);
	} else if (patron >= 3) {
		color += sin(posicion_mundo.x * 0.005) * sin(posicion_mundo.y * 0.004) * 0.012;
	}
	if (patron >= 0) {
		color *= mix(exterior ? 0.98 : 0.94, 1.0, smoothstep(0.0, 110.0, borde_ambiente));
	}
	COLOR = vec4(color, 1.0);
}
