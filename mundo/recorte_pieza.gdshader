shader_type canvas_item;
render_mode unshaded;
varying vec2 local;
uniform vec2 tamano = vec2(140.0, 190.0);
uniform ivec2 grilla = ivec2(3, 4);
uniform int material_id = 1;
uniform float corrosion = 0.0;
// x: resistencia; yz: mordida dentro del material; w: bordes rotos vecinos.
uniform vec4 cortes[16];
// Región ocupada de cada sección; el borde transparente no agranda el mordisco.
uniform vec4 zonas[16];
void vertex() { local = VERTEX; }
void fragment() {
	vec2 uv = (local + tamano * 0.5) / tamano;
	vec2 celda = floor(uv * vec2(grilla));
	vec4 color = COLOR;
	if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
		int id = int(celda.y) * grilla.x + int(celda.x);
		vec4 estado = cortes[id];
		if (estado.x < 0.001) { color.a = 0.0; }
		else if (estado.x < 0.999) {
			vec4 zona = zonas[id];
			vec2 p = (uv - zona.xy) / max(zona.zw, vec2(0.0001));
			vec2 d = p - estado.yz;
			float rugoso = material_id == 1 ? sin(p.y * 65.0) * 0.07 : sin(p.x * 29.0 + p.y * 17.0) * 0.035;
			float radio = sqrt(1.0 - estado.x) * 1.3;
			float borde = length(d) + rugoso - radio;
			color.a *= smoothstep(-0.015, 0.015, borde);
			color.rgb *= mix(0.65, 1.0, smoothstep(0.0, 0.06, borde));
			// El veneno marca sólo el contorno de las mordidas: la piedra,
			// la madera y la tela mantienen su material y su silueta.
			float residuo = (1.0 - smoothstep(0.025, 0.14, borde)) * smoothstep(-0.015, 0.01, borde);
			color.rgb = mix(color.rgb, color.rgb * vec3(0.82, 1.025, 0.75), corrosion * residuo * 0.5);
		}
		if (estado.x > 0.001 && estado.w > 0.5) {
			// Un borde de piedra astillado en lugar de cortes de regla sobre
			// la grilla lógica. Sólo unos píxeles, sin sumar material ni colisión.
			vec2 dentro = fract(uv * vec2(grilla)) * tamano / vec2(grilla);
			vec2 seccion = tamano / vec2(grilla);
			int bordes = int(estado.w);
			float distancia = 10000.0;
			if ((bordes & 1) != 0) { distancia = min(distancia, dentro.x); }
			if ((bordes & 2) != 0) { distancia = min(distancia, seccion.x - dentro.x); }
			if ((bordes & 4) != 0) { distancia = min(distancia, dentro.y); }
			if ((bordes & 8) != 0) { distancia = min(distancia, seccion.y - dentro.y); }
			float astilla = 5.0 + sin(local.x * 0.18 + local.y * 0.11) * 2.5 + sin(local.x * 0.43 - local.y * 0.29) * 1.5;
			color.a *= smoothstep(astilla - 1.0, astilla + 1.0, distancia);
			color.rgb *= mix(0.72, 1.0, smoothstep(astilla, astilla + 7.0, distancia));
		}
	}
	COLOR = color;
}
