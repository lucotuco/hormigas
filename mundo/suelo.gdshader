shader_type canvas_item;
render_mode unshaded;

varying vec2 posicion_mundo;
uniform vec4 ambientes[7];
uniform vec4 tonos[7];
uniform int patrones[7];
uniform bool exterior = false;
uniform vec4 tono_exterior : source_color = vec4(0.55, 0.60, 0.46, 1.0);
uniform int patron_exterior = 4;

void vertex() {
	posicion_mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float tono_celda(vec2 celda) {
	// Una variación por pieza, sin textura repetida ni ruido de alta frecuencia.
	vec2 mezcla = fract(celda * vec2(0.1031, 0.11369));
	mezcla += dot(mezcla, mezcla.yx + 19.19);
	return fract((mezcla.x + mezcla.y) * mezcla.x);
}

void fragment() {
	// El paisaje continúa fuera del edificio. Sigue siendo una superficie
	// compartida: no se amplía el bucle por ambiente ni se agregan texturas.
	vec3 base = tono_exterior.rgb;
	int patron = patron_exterior;
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
		float junta = 1.0 - smoothstep(0.35, 0.35 + pixel, distancia);
		float semilla = tono_celda(celda);
		color += (semilla - 0.5) * (patron == 1 ? 0.022 : 0.006);
		float detalle = smoothstep(5.0, 18.0, min(tamano.x, tamano.y) / pixel);
		// Juntas finas y filtradas: al alejarse se atenúan, no forman un damero.
		color *= 1.0 - junta * detalle * (patron == 1 ? 0.055 : 0.034);
		if (patron == 1) {
			// Vetas amplias y suaves dentro de la tabla. La curva es analítica:
			// no requiere muestras, mipmaps ni una imagen de baja definición.
			vec2 local = interior / tamano;
			float curva = local.y * 2.0 + (local.x - 0.5) * (local.x - 0.5) * (0.4 + semilla * 0.4) + semilla;
			float veta = abs(fract(curva) - 0.5);
			color -= (1.0 - smoothstep(0.025, 0.12, veta)) * 0.007 * detalle;
		} else {
			// Canto mate, apenas visible de cerca; la pieza conserva una cara lisa.
			float canto = (1.0 - smoothstep(1.2, 2.6 + pixel, distancia)) - junta;
			color += canto * 0.005 * detalle;
		}
	} else if (patron >= 3) {
		// Arena y césped se leen como superficies amplias, sin punteado repetido.
		float franja = sin(posicion_mundo.y * (patron == 4 ? 0.002 : 0.0008));
		color += franja * (patron == 4 ? 0.006 : 0.003);
	}
	if (patron >= 0) {
		color *= mix(exterior ? 0.99 : 0.97, 1.0, smoothstep(0.0, 90.0, borde_ambiente));
	}
	COLOR = vec4(color, 1.0);
}
