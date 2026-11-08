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
uniform float nitidez = 6.0; // (sin uso: se conserva para no romper materiales)

varying vec3 pos_mundo;
varying vec3 normal_mundo;
varying vec2 uv_plano;

void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// proyeccion por el eje dominante (igual que el triplanar en cajas, pero 3 veces mas barato)
	vec3 p = (pos_mundo * escala_uv + desfase_uv) * vec3(1.0, -1.0, 1.0);
	vec3 a = abs(normal_mundo);
	if (a.x >= a.y && a.x >= a.z) {
		uv_plano = p.zy * vec2(-1.0, 1.0);
	} else if (a.y >= a.z) {
		uv_plano = p.xz;
	} else {
		uv_plano = p.xy;
	}
}

void fragment() {
	vec3 base = texture(textura, uv_plano).rgb * tinte.rgb;
	float rough = rugosidad;
	ALBEDO = ensuciar(base, rough, pos_mundo, normalize(normal_mundo));
	ROUGHNESS = rough;
	METALLIC = metalico;
	NORMAL_MAP = texture(textura_normal, uv_plano).rgb;
	NORMAL_MAP_DEPTH = normal_fuerza;
}
