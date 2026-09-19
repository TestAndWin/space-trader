shader_type canvas_item;

// Fakes a 3D camera over a flat illustration: every pixel is displaced by
// its depth, so near geometry swings further than the skyline. Also carries
// the hub's camera zoom. Driven by scripts/components/depth_parallax.gd;
// the TextureRect must use STRETCH_SCALE so UV spans the whole control.

uniform sampler2D depth_map : filter_linear, repeat_disable;
// Aspect-cover crop: the fraction of the texture visible along each axis.
uniform vec2 cover_scale = vec2(1.0, 1.0);
// Displacement at depth 0 / 1 relative to focus_depth, in texture UV.
uniform vec2 parallax_offset = vec2(0.0, 0.0);
uniform float focus_depth = 0.5;
// Constant overscan that keeps the displaced edges off screen.
uniform float edge_zoom = 1.03;
// Camera: the screen-UV point shown at the centre, and its magnification.
uniform vec2 cam_center = vec2(0.5, 0.5);
uniform float cam_zoom = 1.0;

const int REFINE_STEPS = 3;

void fragment() {
	vec2 s = cam_center + (UV - 0.5) / cam_zoom;
	s = 0.5 + (s - 0.5) / edge_zoom;
	vec2 t = 0.5 + (s - 0.5) * cover_scale;
	// Fixed-point refinement: look up depth where the sample will land, not
	// where it started, which keeps thin foreground edges from doubling.
	vec2 p = t;
	for (int i = 0; i < REFINE_STEPS; i++) {
		float d = texture(depth_map, p).r;
		p = t + parallax_offset * (d - focus_depth);
	}
	COLOR = texture(TEXTURE, clamp(p, vec2(0.0), vec2(1.0)));
}
