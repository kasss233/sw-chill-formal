shader_type spatial;
render_mode cull_front, unshaded; // 依然使用背面剔除

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 1.0) = 0.005; // 建议给很小的值，比如 0.02

void vertex() {
	// 1. 将顶点和法线转换到视图空间（相机的视角）
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);

	// 2. 关键点：在视图空间沿着法线挤出
	// 这样做比在屏幕空间挤出更稳定，不会出现乱飞的情况
	// 为了让远处也能看到，我们根据深度的绝对值 (z) 稍微补偿一下宽度
	float dist_scaling = -view_pos.z * 0.1; // 随着距离增加增加一点点宽度
	view_pos.xyz += view_normal * outline_width * (1.0 + dist_scaling);

	// 3. 转换到裁剪空间
	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	//ALPHA = outline_color.a;
}
