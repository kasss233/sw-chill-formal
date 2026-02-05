shader_type spatial;
render_mode blend_mix, unshaded, cull_back;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float blur_amount : hint_range(0.0, 10.0) = 2;
uniform float mix_amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// 使用 textureLod 来获取模糊后的屏幕背景，lod 越大细节越模糊，只保留色彩块
	vec3 blurred_screen = textureLod(SCREEN_TEXTURE, SCREEN_UV, blur_amount).rgb;
	
	// 混合颜色 tint_color 和模糊后的背景颜色
	ALBEDO = mix(tint_color.rgb, blurred_screen, mix_amount);
	ALPHA = tint_color.a;
}
