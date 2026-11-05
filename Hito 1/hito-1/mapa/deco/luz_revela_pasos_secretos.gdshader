shader_type spatial;
render_mode depth_prepass_alpha, cull_disabled;

// --- VARIABLES LINTERNA ---
global uniform vec3 flashlight_pos;
global uniform vec3 flashlight_dir;
global uniform bool is_blue_light_on;
global uniform bool is_red_light_on;
global uniform bool is_violet_light_on;
global uniform float flashlight_angle;

uniform float fade_degrees = 6.0;
uniform int light_channel = 0; // 0 = azul, 1 = roja, 2 = morada
uniform sampler2D reveal_mask : hint_default_black, filter_linear;
uniform bool use_reveal_mask = false;
uniform mat4 world_to_mask;
uniform vec2 mask_min = vec2(-0.5, 0.0);
uniform vec2 mask_size = vec2(1.0, 1.0);
instance uniform float force_visible = 0.0;

// --- CONFIGURACIONES DE MATERIAL (Tus fotos) ---
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

// Normal Map
uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale : hint_range(-16.0, 16.0) = 0.5;

// Triplanar y UVs
varying vec3 uv1_triplanar_pos;
uniform vec3 uv1_scale = vec3(1.0, 1.0, 1.0);
uniform vec3 uv1_offset = vec3(0.0, 0.0, 0.0);
varying vec3 uv1_power_normal;
uniform float triplanar_sharpness = 6.0;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Cálculo Triplanar (Mundo)
	vec3 normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	uv1_power_normal = pow(abs(normal), vec3(triplanar_sharpness));
	uv1_power_normal /= dot(uv1_power_normal, vec3(1.0));
	uv1_triplanar_pos = world_pos * uv1_scale + uv1_offset;
	uv1_triplanar_pos *= vec3(1.0, -1.0, 1.0);
}

vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, p_triplanar_pos.xy) * p_weights.z;
	samp += texture(p_sampler, p_triplanar_pos.xz) * p_weights.y;
	samp += texture(p_sampler, p_triplanar_pos.zy * vec2(-1.0,1.0)) * p_weights.x;
	return samp;
}

void fragment() {
	// Base
	vec4 albedo_tex = triplanar_texture(texture_albedo, uv1_power_normal, uv1_triplanar_pos);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	
	// Normal Map
	vec4 normal_tex = triplanar_texture(texture_normal, uv1_power_normal, uv1_triplanar_pos);
	NORMAL_MAP = normal_tex.rgb;
	NORMAL_MAP_DEPTH = normal_scale;

	// Linterna y Borrado
	float light_intensity = 0.0;
	bool light_on = is_violet_light_on;
	if (light_channel == 0) { light_on = is_blue_light_on; }
	else if (light_channel == 1) { light_on = is_red_light_on; }
	
	if (light_on) {
		vec3 dir_to_pixel = normalize(world_pos - flashlight_pos);
		float cos_angle = clamp(dot(dir_to_pixel, normalize(flashlight_dir)), -1.0, 1.0);
		float angle_deg = degrees(acos(cos_angle));
		light_intensity = 1.0 - smoothstep(flashlight_angle - fade_degrees, flashlight_angle, angle_deg);
	}
	
	float opacity = 1.0; 
	
	if (use_reveal_mask) {
		vec3 local_pos = (world_to_mask * vec4(world_pos, 1.0)).xyz;
		vec2 mask_uv = (local_pos.xy - mask_min) / mask_size;
		mask_uv.y = 1.0 - mask_uv.y;
		float mask_val = texture(reveal_mask, mask_uv).r;
		
		opacity = min(mask_val, 1.0 - light_intensity);
	} else {
		opacity = 1.0 - light_intensity;
	}
	
	ALPHA = max(opacity, force_visible) * albedo.a * albedo_tex.a;
}