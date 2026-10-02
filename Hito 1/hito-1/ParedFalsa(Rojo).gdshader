shader_type spatial;
render_mode depth_prepass_alpha;

// Leemos las variables globales que actualiza tu script
global uniform vec3 flashlight_pos;
global uniform vec3 flashlight_dir;
global uniform bool is_red_light_on;

// Puedes cambiar esta textura en el inspector para que se vea como tu pared normal
uniform sampler2D wall_texture : source_color;
uniform vec4 wall_color : source_color = vec4(1.0);

// Qué tan ancho es el círculo que borra la luz
global uniform float flashlight_angle; 

uniform float fade_degrees = 6.0;

varying vec3 world_pos;

void vertex() {
	// Guardamos la posición matemática del pixel en el mundo 3D
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// 1. Pintamos la pared normal
	vec4 tex = texture(wall_texture, UV);
	ALBEDO = tex.rgb * wall_color.rgb;

	// 2. Si la luz esta encendida, la pared se desvanece dentro del foco (fade suave)
	float wall_alpha = 1.0;
	if (is_red_light_on) {
		vec3 dir_to_pixel = normalize(world_pos - flashlight_pos);
		float cos_angle = clamp(dot(dir_to_pixel, normalize(flashlight_dir)), -1.0, 1.0);
		float angle_deg = degrees(acos(cos_angle));
		wall_alpha = smoothstep(flashlight_angle - fade_degrees, flashlight_angle, angle_deg);
	}
	ALPHA = wall_alpha;
}
