shader_type canvas_item;

uniform vec4 ripple_color : source_color = vec4(1.0, 1.0, 1.0, 0.3);
uniform vec2 ripple_center = vec2(0.5, 0.5);  // UV 坐标中的涟漪中心
uniform float ripple_radius : hint_range(0.0, 2.0) = 0.0;  // 当前涟漪半径
uniform float ripple_alpha : hint_range(0.0, 1.0) = 0.0;  // 涟漪透明度
uniform float edge_softness : hint_range(0.0, 0.5) = 0.1;  // 边缘柔和度
uniform vec2 aspect_ratio = vec2(1.0, 1.0);  // 用于修正宽高比
uniform float corner_radius : hint_range(0.0, 0.5) = 0.0;  // 圆角半径 (相对于按钮尺寸)
uniform vec2 button_size = vec2(100.0, 40.0);  // 按钮实际尺寸

// 计算到圆角矩形边界的距离
float rounded_rect_sdf(vec2 uv, vec2 size, float radius) {
	vec2 center = vec2(0.5, 0.5);
	vec2 pos = (uv - center) * size;
	vec2 corner_pos = abs(pos) - (size * 0.5 - radius);
	float corner_dist = length(max(corner_pos, 0.0)) + min(max(corner_pos.x, corner_pos.y), 0.0);
	return corner_dist - radius;
}

void fragment() {
	// 计算当前像素到涟漪中心的距离（考虑宽高比）
	vec2 uv_adjusted = (UV - ripple_center) * aspect_ratio;
	float dist = length(uv_adjusted);
	
	// 计算涟漪的可见度（从中心向外扩散的圆形）
	// 使用 smoothstep 实现柔和边缘
	float inner_edge = ripple_radius - edge_softness;
	float outer_edge = ripple_radius;
	
	// 涟漪是一个从内到外扩散的圆环，内部完全填充
	float ripple = 1.0 - smoothstep(inner_edge, outer_edge, dist);
	
	// 计算圆角裁切遮罩
	float corner_mask = 1.0;
	if (corner_radius > 0.0) {
		float sdf_dist = rounded_rect_sdf(UV, button_size, corner_radius);
		// 使用 smoothstep 实现抗锯齿的圆角裁切
		corner_mask = 1.0 - smoothstep(-1.0, 1.0, sdf_dist);
	}
	
	// 应用圆角裁切到涟漪效果
	ripple *= corner_mask;
	
	// 应用颜色和透明度
	COLOR = vec4(ripple_color.rgb, ripple * ripple_alpha * ripple_color.a);
}
