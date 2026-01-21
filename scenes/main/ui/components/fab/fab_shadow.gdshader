shader_type canvas_item;

// 阴影参数
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.3);
uniform float shadow_size : hint_range(0.0, 32.0) = 8.0;
uniform vec2 shadow_offset = vec2(0.0, 4.0);

// 控件尺寸（包含阴影 padding）
uniform vec2 size;
// 为阴影渲染预留的 padding
uniform float shadow_padding = 0.0;
// 圆角半径
uniform float corner_radius = 16.0;

// SDF 圆角矩形
float rounded_rect_sdf(vec2 pos, vec2 rect_size, float radius) {
	vec2 center = rect_size * 0.5;
	vec2 d = abs(pos - center) - (center - radius);
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
}

void fragment() {
	// 计算实际面板尺寸（不含阴影 padding）
	vec2 panel_size = size - shadow_padding * 2.0;

	// 将 UV 转换为相对于面板的位置（考虑 padding）
	vec2 pixel_pos = UV * size;
	vec2 panel_pos = pixel_pos - shadow_padding;

	// 计算阴影（带偏移）
	vec2 shadow_pos = panel_pos - shadow_offset;
	float shadow_dist = rounded_rect_sdf(shadow_pos, panel_size, corner_radius);

	// 柔和阴影衰减
	float shadow_alpha = 1.0 - smoothstep(-shadow_size * 0.5, shadow_size, shadow_dist);
	shadow_alpha *= shadow_color.a;

	COLOR = vec4(shadow_color.rgb, shadow_alpha);
}
