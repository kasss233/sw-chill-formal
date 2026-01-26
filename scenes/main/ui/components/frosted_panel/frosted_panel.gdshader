shader_type canvas_item;

uniform float corner_radius : hint_range(0.0, 100.0) = 12.0;
uniform float border_width : hint_range(0.0, 10.0) = 1.0;
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 0.2);

uniform float blur_amount : hint_range(0.0, 5.0) = 3.0;
uniform vec4 tint_color : source_color = vec4(0.0, 0.0, 0.0, 0.4);
uniform float noise_amount : hint_range(0.0, 1.0) = 0.03;
uniform sampler2D noise_texture : repeat_enable, filter_linear;

// Shadow parameters
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.3);
uniform float shadow_size : hint_range(0.0, 32.0) = 8.0;
uniform vec2 shadow_offset = vec2(0.0, 4.0);

// Total size of the control (including shadow padding)
uniform vec2 size;
// Padding added for shadow rendering
uniform float shadow_padding = 0.0;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Calculate rounded rect SDF
float rounded_rect_sdf(vec2 pos, vec2 rect_size, float radius) {
	vec2 center = rect_size * 0.5;
	vec2 d_rect = abs(pos - center) - (center - radius);
	return length(max(d_rect, 0.0)) + min(max(d_rect.x, d_rect.y), 0.0) - radius;
}

void fragment() {
	// Calculate the actual panel size (without shadow padding)
	vec2 panel_size = size - shadow_padding * 2.0;
	
	// Convert UV to position relative to panel (accounting for padding)
	vec2 pixel_pos = UV * size;
	vec2 panel_pos = pixel_pos - shadow_padding;
	
	// Calculate shadow (offset from panel position)
	vec2 shadow_pos = panel_pos - shadow_offset;
	float shadow_dist = rounded_rect_sdf(shadow_pos, panel_size, corner_radius);
	
	// Soft shadow falloff
	float shadow_alpha = 1.0 - smoothstep(-shadow_size * 0.5, shadow_size, shadow_dist);
	shadow_alpha *= shadow_color.a;
	
	// Calculate panel SDF
	float panel_dist = rounded_rect_sdf(panel_pos, panel_size, corner_radius);

	// Panel alpha (inside = 1, outside = 0) with adaptive anti-aliasing
	float edge_width = fwidth(panel_dist) * 1.0;
	float panel_alpha = 1.0 - smoothstep(-edge_width, edge_width, panel_dist);
	
	// Screen Blur (use panel UV for proper sampling)
	vec4 screen_color = textureLod(SCREEN_TEXTURE, SCREEN_UV, blur_amount);
	
	// Noise Grain
	vec2 noise_uv = (panel_pos / panel_size) * (panel_size / 100.0);
	float noise = texture(noise_texture, noise_uv).r;
	screen_color.rgb = mix(screen_color.rgb, vec3(noise), noise_amount);

	// Mix Tint
	vec4 panel_color = mix(screen_color, tint_color, tint_color.a);

	// Border Logic with adaptive anti-aliasing
	// 只有当边框宽度大于0.01时才渲染边框
	if (border_width > 0.01) {
		float border_edge = abs(panel_dist + border_width * 0.5);
		float border_width_aa = fwidth(border_edge) * 1.0;
		float border_mask = 1.0 - smoothstep(border_width - border_width_aa, border_width + border_width_aa, border_edge);
		panel_color.rgb = mix(panel_color.rgb, border_color.rgb, border_mask * border_color.a * panel_alpha);
	}

	// Combine: shadow behind, panel on top
	vec3 final_color = shadow_color.rgb;
	float final_alpha = shadow_alpha;
	
	// Blend panel over shadow
	final_color = mix(final_color, panel_color.rgb, panel_alpha);
	final_alpha = shadow_alpha * (1.0 - panel_alpha) + panel_alpha;
	
	COLOR = vec4(final_color, final_alpha);
}
