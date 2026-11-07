shader_type spatial;

// Material triplanar (en coordenadas de mundo) con suciedad procedural encima.
// Reemplaza a los StandardMaterial3D de paredes, pisos, techos y muebles.

#include "res://mapa/mugre.gdshaderinc"

uniform vec4 tinte : source_color = vec4(1.0);
uniform sampler2D textura : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D textura_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_fuerza : hint_range(-4.0, 4.0) = 0.5;
uniform float rugosidad : hint_range(0.0, 1.0) = 0.9;
uniform float metalico : hint_range(0.0, 1.0) = 0.0;
uniform vec3 escala_uv = vec3(1.0);
uniform vec3 desfase_uv = vec3(0.0);
uniform float nitidez = 6.0;

varying vec3 pos_mundo;
varying vec3 normal_mundo;
varying vec3 tri_pos;
varying vec3 tri_peso;

void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tri_peso = pow(abs(normal_mundo), vec3(nitidez));
	tri_peso /= dot(tri_peso, vec3(1.0));
	tri_pos = pos_mundo * escala_uv + desfase_uv;
	tri_pos *= vec3(1.0, -1.0, 1.0);
}

vec4 tri(sampler2D s, vec3 p, vec3 w) {
	return texture(s, p.xy) * w.z
		+ texture(s, p.xz) * w.y
		+ texture(s, p.zy * vec2(-1.0, 1.0)) * w.x;
}

void fragment() {
	vec3 base = tri(textura, tri_pos, tri_peso).rgb * tinte.rgb;
	float rough = rugosidad;
	ALBEDO = ensuciar(base, rough, pos_mundo, normalize(normal_mundo));
	ROUGHNESS = rough;
	METALLIC = metalico;
	NORMAL_MAP = tri(textura_normal, tri_pos, tri_peso).rgb;
	NORMAL_MAP_DEPTH = normal_fuerza;
}
