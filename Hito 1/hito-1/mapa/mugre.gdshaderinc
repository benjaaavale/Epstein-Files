// Suciedad procedural en espacio de mundo para la mansion.
// Se calcula sobre la textura base: humedad que sube desde el piso, chorreos desde el techo,
// manchas de agua, moho, grietas, papel despegado y polvo en los pisos.
// Como trabaja en coordenadas de mundo, las manchas no se repiten junto con la textura base.

uniform sampler2D mugre_ruido : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D mugre_chorreos : hint_default_black, filter_linear_mipmap, repeat_enable;

// cuanta suciedad lleva esta superficie (0 = limpia)
uniform float mugre : hint_range(0.0, 1.5) = 1.0;
// partes donde el papel tapiz se cayo y deja ver el yeso (solo paredes)
uniform float descascarado : hint_range(0.0, 1.0) = 0.0;
uniform vec3 color_debajo : source_color = vec3(0.52, 0.48, 0.41);
uniform float humedad_altura = 0.55;
uniform float grietas : hint_range(0.0, 1.0) = 0.5;
uniform float desaturar : hint_range(0.0, 1.0) = 0.2;
// altura del piso y del techo de cada nivel (piso 1, piso 2)
uniform vec2 niveles_piso = vec2(-0.4, 2.35);
uniform vec2 niveles_techo = vec2(2.25, 5.19);

vec4 mugre_tri(vec3 p, vec3 w) {
	return texture(mugre_ruido, p.xy) * w.z
		+ texture(mugre_ruido, p.xz) * w.y
		+ texture(mugre_ruido, p.zy) * w.x;
}

// Devuelve el color sucio y modifica la rugosidad.
vec3 ensuciar(vec3 c, inout float rough, vec3 wp, vec3 wn) {
	if (mugre <= 0.001) {
		return c;
	}
	vec3 w = pow(abs(wn), vec3(4.0));
	w /= dot(w, vec3(1.0));
	float grande = mugre_tri(wp * 0.11 + vec3(0.37, 0.11, 0.73), w).r;
	float medio = mugre_tri(wp * 0.33, w).g;
	float fino = mugre_tri(wp * 1.9, w).b;
	float grieta = mugre_tri(wp * 0.21 + vec3(0.5), w).a;

	bool arriba = wp.y > niveles_piso.y - 0.15;
	float h = wp.y - (arriba ? niveles_piso.y : niveles_piso.x);
	float hc = (arriba ? niveles_techo.y : niveles_techo.x) - wp.y;

	float pared = 1.0 - smoothstep(0.35, 0.65, abs(wn.y));
	float piso = smoothstep(0.5, 0.8, wn.y);
	float techo = smoothstep(0.5, 0.8, -wn.y);

	// manchas grandes, marrones
	float mancha = smoothstep(0.52, 0.85, grande * 0.75 + medio * 0.45 - 0.08) * mugre;
	// suciedad general a mediana escala (rompe la repeticion de la textura)
	float sucio = smoothstep(0.3, 0.9, medio) * 0.35 * mugre;

	vec3 r = c;

	// --- paredes ---
	if (pared > 0.01) {
		// papel despegado: bordes duros, deja ver lo de abajo
		float n_peel = medio * 0.62 + grande * 0.5;
		float peel = smoothstep(0.735, 0.745, n_peel) * descascarado * pared;
		float borde = (smoothstep(0.70, 0.735, n_peel) - peel) * descascarado * pared;
		r = mix(r, color_debajo * (0.75 + 0.5 * fino) * (1.0 - 0.35 * mancha), peel);
		r *= 1.0 - borde * 0.55;

		// humedad que sube del piso, con borde irregular y linea de sal
		float limite = humedad_altura * (0.45 + 0.9 * medio);
		float humedad = (1.0 - smoothstep(limite - 0.2, limite, h)) * pared * mugre;
		float linea = (1.0 - smoothstep(0.0, 0.05, abs(h - limite))) * pared * mugre;
		r = mix(r, r * vec3(0.42, 0.36, 0.27), humedad * 0.85);
		r = mix(r, vec3(0.5, 0.46, 0.36) * 0.6, linea * 0.35);
		rough = mix(rough, 0.55, humedad * 0.5);

		// chorreos que bajan del techo
		float a_lo_largo = abs(wn.x) > abs(wn.z) ? wp.z : wp.x;
		float chorro = texture(mugre_chorreos, vec2(a_lo_largo * 0.32, wp.y * 0.09)).r;
		chorro *= (1.0 - smoothstep(0.0, 2.2, hc)) * (0.35 + grande) * pared * mugre;
		r *= 1.0 - clamp(chorro, 0.0, 1.0) * 0.7;
		rough = mix(rough, 0.5, chorro * 0.4);

		// moho cerca del techo y del piso
		float zona_moho = max(1.0 - smoothstep(0.0, 0.9, hc), 1.0 - smoothstep(0.0, 0.5, h));
		float moho = smoothstep(0.66, 0.8, fino * 0.55 + grande * 0.6) * zona_moho * pared * mugre;
		r = mix(r, vec3(0.04, 0.05, 0.03), moho * 0.85);
	}

	// --- pisos: polvo, manchas viejas y rayones ---
	if (piso > 0.01) {
		float polvo = smoothstep(0.55, 0.9, medio) * piso * mugre;
		r = mix(r, r * 0.55 + vec3(0.045, 0.04, 0.035) * (0.7 + 0.6 * fino), polvo * 0.6);
		float charco = smoothstep(0.7, 0.78, grande) * piso * mugre;
		r = mix(r, r * vec3(0.3, 0.22, 0.16), charco * 0.75);
		rough = mix(rough, 0.35, charco * 0.4);
	}

	// --- techos: aureolas de agua (anillos marrones) ---
	if (techo > 0.01) {
		float anillo = (1.0 - smoothstep(0.0, 0.025, abs(grande - 0.64))) * techo * mugre;
		float aureola = smoothstep(0.64, 0.74, grande) * techo * mugre;
		r = mix(r, r * vec3(0.62, 0.5, 0.32), aureola * 0.8);
		r = mix(r, vec3(0.2, 0.14, 0.08), anillo * 0.6);
		float moho_t = smoothstep(0.7, 0.82, fino * 0.5 + medio * 0.6) * techo * mugre;
		r = mix(r, vec3(0.05, 0.06, 0.04), moho_t * 0.7);
	}

	r = mix(r, r * vec3(0.55, 0.47, 0.37), mancha * 0.75);
	r *= 1.0 - sucio;
	r *= 1.0 - grieta * grietas * 0.9 * mugre;

	float lum = dot(r, vec3(0.3, 0.59, 0.11));
	r = mix(r, vec3(lum), desaturar);
	return r;
}
