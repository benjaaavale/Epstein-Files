shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_amount = 0.0;
uniform float vignette_amount = 0.7;
uniform float grain_amount = 0.06;
uniform float flicker_amount = 0.06;
uniform float darkness = 0.0;
uniform float light_amount = 0.0;
uniform float light_radius = 0.3;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise1(float x) {
	float i = floor(x);
	return mix(hash(vec2(i, 3.1)), hash(vec2(i + 1.0, 3.1)), smoothstep(0.0, 1.0, fract(x)));
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = UV - 0.5;
	uv.x *= aspect;
	float edge = smoothstep(0.3, 0.95, length(uv));

	// Oscuridad con un foco de linterna que deambula (menus)
	float shade = darkness;
	if (light_amount > 0.0) {
		vec2 light_pos = vec2(noise1(TIME * 0.13) - 0.5, noise1(TIME * 0.11 + 17.0) - 0.5) * vec2(1.1 * aspect, 0.8);
		float lit = 1.0 - smoothstep(light_radius * 0.25, light_radius, length(uv - light_pos));
		shade = mix(shade, 0.0, lit * light_amount);
	}

	float flicker = (noise1(TIME * 9.0) - 0.5) * flicker_amount;
	float alpha = clamp(shade + edge * vignette_amount + flicker + edge * tint_amount * 0.5, 0.0, 1.0);
	float grain = (hash(FRAGCOORD.xy + fract(TIME) * vec2(37.0, 17.0)) - 0.5) * grain_amount;
	vec3 col = tint.rgb * tint_amount * edge;
	COLOR = vec4(col + grain, clamp(alpha + abs(grain), 0.0, 1.0));
}
