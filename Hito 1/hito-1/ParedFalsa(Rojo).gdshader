shader_type spatial;

// Leemos las variables globales que actualiza tu script
global uniform vec3 flashlight_pos;
global uniform vec3 flashlight_dir;
global uniform bool is_red_light_on;

// Puedes cambiar esta textura en el inspector para que se vea como tu pared normal
uniform sampler2D wall_texture : source_color;
uniform vec4 wall_color : source_color = vec4(1.0);

// Qué tan ancho es el círculo que borra la luz
global uniform float flashlight_angle; 

varying vec3 world_pos;

void vertex() {
	// Guardamos la posición matemática del pixel en el mundo 3D
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// 1. Pintamos la pared normal
	vec4 tex = texture(wall_texture, UV);
	ALBEDO = tex.rgb * wall_color.rgb;

	// 2. Si la luz azul está encendida, hacemos la matemática
	if (is_red_light_on) {
		// Trazamos una línea desde la linterna hasta este pixel exacto de la pared
		vec3 dir_to_pixel = normalize(world_pos - flashlight_pos);
		
		// Calculamos qué tan dentro del foco está este pixel
		float dot_prod = dot(dir_to_pixel, normalize(flashlight_dir));
		float angle_limit = cos(radians(flashlight_angle));
		
		// Si el pixel está dentro del círculo de luz de la linterna...
		if (dot_prod > angle_limit) {
			discard; // ¡Magia! El pixel deja de existir y ves a través de él.
		}
	}
}
