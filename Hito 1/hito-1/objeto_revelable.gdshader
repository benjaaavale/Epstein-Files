shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back;

global uniform vec3 flashlight_pos;
global uniform vec3 flashlight_dir;
global uniform bool is_violet_light_on;
global uniform float flashlight_angle;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale : hint_range(-16.0, 16.0) = 0.5;
uniform vec2 uv_scale = vec2(1.0);

uniform float roughness : hint_range(0.0, 1.0) = 0.6;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float fade_degrees = 6.0;
uniform bool revelado = false;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv_ajustada = UV * uv_scale;
	vec4 tex = texture(texture_albedo, uv_ajustada);

	ALBEDO = albedo.rgb * tex.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	NORMAL_MAP = texture(texture_normal, uv_ajustada).rgb;
	NORMAL_MAP_DEPTH = normal_scale;

	if (revelado) {
		ALPHA = albedo.a * tex.a;
	} else {
		float light_intensity = 0.0;
		if (is_violet_light_on) {
			vec3 dir_to_pixel = normalize(world_pos - flashlight_pos);
			float cos_angle = clamp(dot(dir_to_pixel, normalize(flashlight_dir)), -1.0, 1.0);
			float angle_deg = degrees(acos(cos_angle));
			light_intensity = 1.0 - smoothstep(flashlight_angle - fade_degrees, flashlight_angle, angle_deg);
		}
		ALPHA = light_intensity * albedo.a * tex.a;
	}
}