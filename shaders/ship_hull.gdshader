shader_type spatial;
render_mode cull_back, unshaded;

uniform vec4 hull_color : source_color = vec4(0.3, 0.85, 0.3, 1.0);
uniform float emissive_strength : hint_range(0.0, 2.0) = 0.0;
uniform vec4 emissive_color : source_color = vec4(1.0, 0.3, 0.2, 1.0);

void fragment() {
	ALBEDO = mix(hull_color.rgb, emissive_color.rgb, clamp(emissive_strength, 0.0, 1.0));
	ALPHA = hull_color.a;
}
