shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, billboard;

uniform vec4 glow_color : source_color = vec4(1.0, 0.6, 0.15, 1.0);
uniform float pulse_speed : hint_range(0.5, 5.0) = 2.5;
uniform float pulse_phase : hint_range(0.0, 6.28) = 0.0;

void fragment() {
	float dist = length(UV - vec2(0.5));
	float circle = smoothstep(0.5, 0.1, dist);
	float pulse = 0.85 + 0.15 * sin(TIME * pulse_speed + pulse_phase);
	ALBEDO = glow_color.rgb;
	ALPHA = clamp(circle * pulse * glow_color.a, 0.0, 1.0);
}
