shader_type canvas_item;

uniform float corner_radius : hint_range(0.0, 100.0) = 8.0;
uniform float border_width : hint_range(0.0, 10.0) = 1.0;
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 0.1);
uniform vec4 background_color : source_color = vec4(1.0, 1.0, 1.0, 0.05);

uniform vec2 size;

// Calculate rounded rect SDF
float rounded_rect_sdf(vec2 pos, vec2 rect_size, float radius) {
	vec2 center = rect_size * 0.5;
	vec2 d_rect = abs(pos - center) - (center - radius);
	return length(max(d_rect, 0.0)) + min(max(d_rect.x, d_rect.y), 0.0) - radius;
}

void fragment() {
	vec2 pixel_pos = UV * size;
	
	// Calculate panel SDF
	float panel_dist = rounded_rect_sdf(pixel_pos, size, corner_radius);
	
	// Panel alpha (inside = 1, outside = 0)
	float panel_alpha = 1.0 - smoothstep(-0.5, 0.5, panel_dist);
	
	// Background
	vec4 panel_color = background_color;
	
	// Border Logic
	float border_mask = 1.0 - smoothstep(border_width - 0.5, border_width + 0.5, abs(panel_dist + border_width * 0.5));
	panel_color.rgb = mix(panel_color.rgb, border_color.rgb, border_mask * border_color.a);
	panel_color.a = mix(panel_color.a, border_color.a, border_mask * border_color.a);
	
	COLOR = vec4(panel_color.rgb, panel_color.a * panel_alpha);
}
