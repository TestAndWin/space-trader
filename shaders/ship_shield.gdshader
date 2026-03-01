shader_type spatial;
render_mode blend_add, cull_disabled, unshaded;

uniform vec4 shield_color : source_color = vec4(0.2, 0.5, 1.0, 0.8);
uniform float shield_strength : hint_range(0.0, 1.0) = 0.5;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 hit_color : source_color = vec4(0.8, 0.9, 1.0, 1.0);

void fragment() {
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	vec4 base = mix(shield_color, hit_color, hit_flash);
	ALBEDO = base.rgb;
	ALPHA = clamp(fresnel * shield_strength * base.a, 0.0, 1.0);
}
