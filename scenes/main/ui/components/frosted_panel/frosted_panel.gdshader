shader_type canvas_item;

uniform float corner_radius : hint_range(0.0, 100.0) = 25.0;
uniform bool show_border = true;
uniform float border_width : hint_range(0.0, 10.0) = 1.0;
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 0.15);

uniform float blur_amount : hint_range(0.0, 5.0) = 3.5;
uniform float saturation : hint_range(0.0, 3.0) = 1.6;
uniform float brightness : hint_range(0.0, 2.0) = 1.1;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 0.1);

uniform float noise_amount : hint_range(0.0, 1.0) = 0.02;
uniform sampler2D noise_texture : repeat_enable, filter_linear;

uniform bool show_shadow = true;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.2);
uniform float shadow_size : hint_range(0.0, 32.0) = 12.0;
uniform vec2 shadow_offset = vec2(0.0, 6.0);

uniform vec2 size = vec2(200.0, 100.0);
uniform float shadow_padding = 10.0;

uniform float glow_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float glow_width : hint_range(1.0, 8.0) = 3.0;
uniform float glow_speed : hint_range(0.1, 3.0) = 0.8;
uniform float glow_softness : hint_range(0.5, 3.0) = 1.5;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;


vec3 adjust_saturation(vec3 rgb, float adjustment) {
	const vec3 weights = vec3(0.2125, 0.7154, 0.0721);
	vec3 intensity = vec3(dot(rgb, weights));
	return mix(intensity, rgb, adjustment);
}


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


vec4 smooth_glass_blur(sampler2D tex, vec2 uv, float lod) {
	vec2 tex_size = vec2(textureSize(tex, 0));
	vec2 pixel_size = 1.0 / tex_size;
	vec2 offset = pixel_size * pow(2.0, lod) * 0.5;

	vec4 col = textureLod(tex, uv, lod) * 4.0;
	col += textureLod(tex, uv + vec2(-offset.x, -offset.y), lod);
	col += textureLod(tex, uv + vec2(offset.x, -offset.y), lod);
	col += textureLod(tex, uv + vec2(-offset.x, offset.y), lod);
	col += textureLod(tex, uv + vec2(offset.x, offset.y), lod);
	col += textureLod(tex, uv + vec2(0.0, -offset.y), lod) * 2.0;
	col += textureLod(tex, uv + vec2(0.0, offset.y), lod) * 2.0;
	col += textureLod(tex, uv + vec2(-offset.x, 0.0), lod) * 2.0;
	col += textureLod(tex, uv + vec2(offset.x, 0.0), lod) * 2.0;

	return col / 16.0;
}


void fragment() {
	vec2 panel_size = size - vec2(shadow_padding * 2.0);
	vec2 pixel_pos = UV * size;
	vec2 panel_pos = pixel_pos - vec2(shadow_padding);

	float panel_dist = rounded_rect_sdf(panel_pos, panel_size, corner_radius);
	float edge_width = fwidth(panel_dist);
	float panel_alpha = 1.0 - smoothstep(-edge_width, edge_width, panel_dist);

	vec4 screen_color = smooth_glass_blur(SCREEN_TEXTURE, SCREEN_UV, blur_amount);
	screen_color.rgb = adjust_saturation(screen_color.rgb, saturation);
	screen_color.rgb *= brightness;

	if (noise_amount > 0.0) {
		float noise = texture(noise_texture, panel_pos / 200.0).r;
		screen_color.rgb += (noise - 0.5) * noise_amount;
	}

	vec3 final_panel_rgb = mix(screen_color.rgb, tint_color.rgb, tint_color.a);

	if (show_border && border_width > 0.01) {
		float border_mask = smoothstep(
			border_width + edge_width,
			border_width - edge_width,
			abs(panel_dist + border_width * 0.5)
		);
		final_panel_rgb = mix(final_panel_rgb, border_color.rgb, border_mask * border_color.a);
	}

	float shadow_alpha = 0.0;
	if (show_shadow) {
		float shadow_dist = rounded_rect_sdf(panel_pos - shadow_offset, panel_size, corner_radius);
		shadow_alpha = 1.0 - smoothstep(-shadow_size, shadow_size, shadow_dist);
		shadow_alpha *= shadow_color.a;
	}

	vec3 final_color;
	float final_alpha;

	if (show_shadow) {
		final_alpha = panel_alpha + shadow_alpha * (1.0 - panel_alpha);
		if (final_alpha > 0.001) {
			final_color = (
				final_panel_rgb * panel_alpha +
				shadow_color.rgb * shadow_alpha * (1.0 - panel_alpha)
			) / final_alpha;
		} else {
			final_color = vec3(0.0);
		}
	} else {
		final_color = final_panel_rgb;
		final_alpha = panel_alpha;
	}

	if (glow_intensity > 0.001) {
		float edge_param = get_edge_parameter(panel_pos, panel_size);
		vec3 glow_rgb = ai_glow_color(edge_param + TIME * glow_speed);
		float inner_glow = smoothstep(-glow_width, 0.0, panel_dist);
		float outer_glow = 1.0 - smoothstep(0.0, glow_width * glow_softness, panel_dist);
		float glow_mask = inner_glow * outer_glow * glow_intensity;

		final_color = min(final_color + glow_rgb * glow_mask, vec3(1.0));
		final_alpha = clamp(final_alpha + glow_mask * 0.35, 0.0, 1.0);
	}

	COLOR = vec4(final_color, final_alpha);
}
