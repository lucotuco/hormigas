shader_type canvas_item;
render_mode unshaded;
varying vec2 local;
varying float es_cuerpo;
uniform vec2 tamano = vec2(140.0, 190.0);
uniform sampler2D mascara_bocados : filter_nearest, repeat_disable;
uniform bool usar_mascara = false;
// Compatibilidad de llamadas antiguas. El dibujo ya no depende de 64 frentes.
uniform ivec2 grilla = ivec2(3, 4);
uniform vec4 frentes[64];
uniform vec4 cortes[16];
uniform int material_id = 1;
uniform float corrosion = 0.0;
uniform bool sombra_activa = false;
uniform vec4 region_cuerpo = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 uv_por_unidad = vec2(0.0);
uniform vec2 desplazamiento_sombra = vec2(4.0, 7.0);

float material_en(vec2 punto) {
	vec2 uv = (punto + tamano * 0.5) / max(tamano, vec2(0.0001));
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) {
		return 0.0;
	}
	return usar_mascara ? texture(mascara_bocados, uv).r : 1.0;
}

float dentro_region(vec2 uv) {
	// repeat_disable no evita leer otro sprite del MISMO atlas.
	if (any(lessThan(uv, region_cuerpo.xy)) || any(greaterThanEqual(uv, region_cuerpo.zw))) {
		return 0.0;
	}
	return 1.0;
}

void vertex() {
	local = VERTEX;
	// draw_rect usa UV 0..1 aunque sea una primitiva sin textura. Reconocer
	// la transformación del cuerpo en los VÉRTICES evita confundirla con él.
	vec2 esperada = region_cuerpo.xy + (VERTEX + tamano * 0.5) * uv_por_unidad;
	es_cuerpo = distance(UV, esperada) < 0.00001 ? 1.0 : 0.0;
}

void fragment() {
	vec4 color = COLOR;
	if (sombra_activa && es_cuerpo > 0.5) {
		vec2 uv_sombra = UV - desplazamiento_sombra * uv_por_unidad;
		float cuerpo = texture(TEXTURE, UV).a * dentro_region(UV) * material_en(local);
		float sombra = texture(TEXTURE, uv_sombra).a * dentro_region(uv_sombra) * material_en(local - desplazamiento_sombra) * 0.14;
		float alpha = cuerpo + sombra * (1.0 - cuerpo);
		vec3 rgb = alpha > 0.0 ? (color.rgb * cuerpo + vec3(0.19, 0.16, 0.11) * sombra * (1.0 - cuerpo)) / alpha : vec3(0.0);
		// Esta pasada sólo dibuja el cuerpo y su sombra. Las barras se
		// dibujan fuera de la región del atlas y conservan sus propios colores.
		if (local.y >= -tamano.y * 0.5 - 12.0 && local.y <= tamano.y * 0.5 + 12.0) {
			color = vec4(rgb, alpha);
		}
		if (corrosion > 0.0 && cuerpo > 0.0) {
			color.rgb = mix(color.rgb, color.rgb * vec3(0.82, 1.025, 0.75), min(corrosion, 1.0) * 0.18);
		}
		COLOR = color;
	} else {
	vec2 uv = (local + tamano * 0.5) / max(tamano, vec2(0.0001));
	if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
		float material = 1.0;
		if (usar_mascara) {
			material = texture(mascara_bocados, uv).r;
			color.a *= material;
		}
		if (corrosion > 0.0 && material > 0.0) {
			vec2 hasta_borde = min(uv, vec2(1.0) - uv) * tamano;
			float borde = min(hasta_borde.x, hasta_borde.y);
			float residuo = 1.0 - smoothstep(0.0, 6.0, borde);
			if (usar_mascara) {
				vec2 texel = vec2(1.0) / vec2(textureSize(mascara_bocados, 0));
				float vecino = min(min(texture(mascara_bocados, uv + vec2(texel.x, 0.0)).r,
					texture(mascara_bocados, uv - vec2(texel.x, 0.0)).r),
					min(texture(mascara_bocados, uv + vec2(0.0, texel.y)).r,
					texture(mascara_bocados, uv - vec2(0.0, texel.y)).r));
				residuo = max(residuo, 1.0 - vecino);
			}
			color.rgb = mix(color.rgb, color.rgb * vec3(0.82, 1.025, 0.75), min(corrosion, 1.0) * residuo * 0.5);
		}
	}
	// Barras y detalles fuera del cuerpo no reciben el recorte.
	COLOR = color;
	}
}
