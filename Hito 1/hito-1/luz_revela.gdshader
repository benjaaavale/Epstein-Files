shader_type spatial;
render_mode depth_prepass_alpha, cull_disabled;

global uniform vec3 flashlight_pos;
global uniform vec3 flashlight_dir;
global uniform bool is_blue_light_on;
global uniform bool is_red_light_on;
global uniform float flashlight_angle;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.0;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.8;
uniform float fade_degrees = 6.0;
uniform bool unshaded_look = false;
uniform int light_channel = 0; // 0 = azul, 1 = roja, 2 = morada

uniform sampler2D reveal_mask : hint_default_black, filter_linear;
uniform bool use_reveal_mask = false;
uniform mat4 world_to_mask;
uniform vec2 mask_min = vec2(-0.5, 0.0);
uniform vec2 mask_size = vec2(1.0, 1.0);

instance uniform float force_visible = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base_color = albedo.rgb * texture(albedo_texture, UV * uv_scale).rgb;
	if (unshaded_look) {
		ALBEDO = vec3(0.0);
		EMISSION = base_color;
	} else {
		ALBEDO = base_color;
	}
	METALLIC = metallic_amount;
	ROUGHNESS = roughness_amount;

	float reveal = 0.0;
	bool light_on = is_blue_light_on && is_red_light_on;
	if (light_channel == 0) {
		light_on = is_blue_light_on;
	} else if (light_channel == 1) {
		light_on = is_red_light_on;
	}
	if (light_on) {
		vec3 dir_to_pixel = normalize(world_pos - flashlight_pos);
		float cos_angle = clamp(dot(dir_to_pixel, normalize(flashlight_dir)), -1.0, 1.0);
		float angle_deg = degrees(acos(cos_angle));
		reveal = 1.0 - smoothstep(flashlight_angle - fade_degrees, flashlight_angle, angle_deg);
	}
	if (use_reveal_mask) {
		vec3 local_pos = (world_to_mask * vec4(world_pos, 1.0)).xyz;
		vec2 mask_uv = (local_pos.xy - mask_min) / mask_size;
		mask_uv.y = 1.0 - mask_uv.y;
		reveal = max(reveal, texture(reveal_mask, mask_uv).r);
	}
	ALPHA = max(reveal, force_visible);
}
