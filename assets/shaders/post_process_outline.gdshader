shader_type spatial;
// unshaded: 不受光照影响
// depth_test_disabled: 确保它画在最前面
// cull_disabled: 关闭背面剔除
render_mode unshaded, depth_test_disabled, cull_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_thickness : hint_range(0.0, 5.0) = 1.0;
// 在兼容模式下，深度阈值可能需要根据场景比例反复微调
uniform float depth_threshold : hint_range(0.0, 0.01, 0.0001) = 0.001;

void vertex() {
	// 强制让面片覆盖整个屏幕投影面
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// 采样当前像素深度
	float depth = texture(depth_texture, uv).r;
	
	// 计算采样偏移量
	vec2 texel_size = 1.0 / VIEWPORT_SIZE * outline_thickness;
	
	// 对周围四个像素进行深度采样 (上下左右)
	float d_up    = texture(depth_texture, uv + vec2(0, texel_size.y)).r;
	float d_down  = texture(depth_texture, uv - vec2(0, texel_size.y)).r;
	float d_left  = texture(depth_texture, uv - vec2(texel_size.x, 0)).r;
	float d_right = texture(depth_texture, uv + vec2(texel_size.x, 0)).r;
	
	// 计算深度变化值
	// 如果深度变化剧烈，说明是物体边缘
	float diff = abs(depth - d_up) + abs(depth - d_down) + abs(depth - d_left) + abs(depth - d_right);
	
	vec4 screen_color = texture(screen_texture, uv);
	
	// 判定：深度差异大于阈值，且不是背景(depth < 1.0)
	if (depth < 1.0 && diff > depth_threshold) {
		ALBEDO = mix(screen_color.rgb, outline_color.rgb, outline_color.a);
	} else {
		ALBEDO = screen_color.rgb;
	}
}
