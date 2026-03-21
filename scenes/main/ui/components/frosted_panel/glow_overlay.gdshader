shader_type canvas_item;
render_mode unshaded;

// 面板几何参数，由 FrostedPanel 脚本同步。
uniform float corner_radius = 21.0;
uniform vec2 panel_rect_size;
uniform float shadow_padding = 0.0;

// 流光参数
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float glow_width : hint_range(1.0, 20.0) = 4.0;
uniform float glow_speed : hint_range(0.1, 3.0) = 0.8;
uniform float glow_softness : hint_range(0.5, 5.0) = 2.0;


float rounded_rect_sdf(vec2 pos, vec2 rect_size, float radius) {
	vec2 center = rect_size * 0.5;
	vec2 d_rect = abs(pos - center) - (center - radius);
	return length(max(d_rect, 0.0)) + min(max(d_rect.x, d_rect.y), 0.0) - radius;
}


vec3 ai_glow_color(float t) {
	const vec3 c0 = vec3(0.545, 0.361, 0.965);
	const vec3 c1 = vec3(0.231, 0.510, 0.965);
	const vec3 c2 = vec3(0.024, 0.714, 0.831);
	float phase = fract(t) * 3.0;

	if (phase < 1.0) {
		return mix(c0, c1, phase);
	}
	if (phase < 2.0) {
		return mix(c1, c2, phase - 1.0);
	}
	return mix(c2, c0, phase - 2.0);
}


float get_edge_parameter(vec2 pos, vec2 rect_size) {
	vec2 center = rect_size * 0.5;
	float angle = atan(pos.y - center.y, pos.x - center.x);
	return fract(angle / (2.0 * 3.14159265) + 0.5);
}


void fragment() {
	if (glow_intensity < 0.001) {
		COLOR = vec4(0.0);
		return;
	}

	vec2 inner_size = panel_rect_size - vec2(shadow_padding * 2.0);
	vec2 pixel_pos = UV * panel_rect_size;
	vec2 panel_pos = pixel_pos - vec2(shadow_padding);

	float panel_dist = rounded_rect_sdf(panel_pos, inner_size, corner_radius);
	float edge_param = get_edge_parameter(panel_pos, inner_size);
	vec3 glow_rgb = ai_glow_color(edge_param + TIME * glow_speed);

	// 仅在边缘附近显示一圈流光，避免整块面板被覆盖。
	float inner_glow = smoothstep(-glow_width, 0.0, panel_dist);
	float outer_glow = 1.0 - smoothstep(0.0, glow_width * glow_softness, panel_dist);
	float glow_mask = inner_glow * outer_glow;

	float glow_strength = glow_mask * glow_intensity;
	COLOR = vec4(glow_rgb, glow_strength);
}
