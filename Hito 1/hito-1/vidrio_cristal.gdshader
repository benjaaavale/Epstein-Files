shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 color_vidrio : source_color = vec4(0.75, 0.92, 1.0, 0.16);
uniform vec4 color_grieta : source_color = vec4(0.95, 0.99, 1.0, 0.85);
uniform float cristalizacion : hint_range(0.0, 1.0) = 0.0;
uniform float escala_cristales = 14.0;
uniform float brillo_fresnel : hint_range(0.0, 1.0) = 0.35;

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV * escala_cristales;
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	
	float dist1 = 8.0;
	float dist2 = 8.0;

	// Calculamos distancia a los dos centros más cercanos (Voronoi para bordes afilados)
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 pt = hash2(i + neighbor);
			float d = length(neighbor + pt - f);
			if (d < dist1) {
				dist2 = dist1;
				dist1 = d;
			} else if (d < dist2) {
				dist2 = d;
			}
		}
	}

	// La diferencia (dist2 - dist1) dibuja el borde exacto entre cada trozo de vidrio
	float borde = dist2 - dist1;
	float grosor = mix(0.02, 0.14, cristalizacion);
	float grietas = (1.0 - smoothstep(0.0, grosor, borde)) * step(0.01, cristalizacion);
	
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * brillo_fresnel;
	
	vec4 final_col = mix(color_vidrio, color_grieta, grietas);
	ALBEDO = mix(final_col.rgb, vec3(0.9, 0.97, 1.0), fresnel);
	ALPHA = clamp(final_col.a + fresnel, 0.0, 0.92);
	ROUGHNESS = mix(0.05, 0.45, grietas);
	SPECULAR = 0.95;
}