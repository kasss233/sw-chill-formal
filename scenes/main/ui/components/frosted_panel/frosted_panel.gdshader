shader_type canvas_item;

uniform float corner_radius : hint_range(0.0, 100.0) = 12.0;
uniform float border_width : hint_range(0.0, 10.0) = 1.0;
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 0.2);

uniform float blur_amount : hint_range(0.0, 5.0) = 3.0;
uniform vec4 tint_color : source_color = vec4(0.0, 0.0, 0.0, 0.4);
uniform float noise_amount : hint_range(0.0, 1.0) = 0.03;
uniform sampler2D noise_texture : repeat_enable, filter_linear;

uniform vec2 size; 

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	// Screen Blur
	vec4 screen_color = textureLod(SCREEN_TEXTURE, SCREEN_UV, blur_amount);
	
	// Noise Grain (Optional)
	// Use UV for noise to keep it relative to panel
	vec2 noise_uv = UV * (size / 100.0); 
	float noise = texture(noise_texture, noise_uv).r;
	screen_color.rgb = mix(screen_color.rgb, vec3(noise), noise_amount);

	// Mix Tint, apply alpha from tint_color to the mix
	vec4 color = mix(screen_color, tint_color, tint_color.a);
	
	// Rounded Corners Logic (SDF)
	vec2 uv_pos = UV * size;
	vec2 center = size * 0.5;
	vec2 d_rect = abs(uv_pos - center) - (center - corner_radius);
	float dist = length(max(d_rect, 0.0)) + min(max(d_rect.x, d_rect.y), 0.0) - corner_radius;
	
	// Smooth alpha for rounded corners
	// dist > 0 is outside, dist < 0 is inside
	float alpha = 1.0 - smoothstep(-0.5, 0.5, dist);
	
	// Border Logic
    // We want the border to be inside the shape, from dist = 0 to dist = -border_width
    float border_mask = 1.0 - smoothstep(border_width - 0.5, border_width + 0.5, abs(dist + border_width * 0.5));
    
    color.rgb = mix(color.rgb, border_color.rgb, border_mask * border_color.a);
	
	COLOR = vec4(color.rgb, alpha);
}
