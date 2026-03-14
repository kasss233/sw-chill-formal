shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 glass_tint : source_color = vec4(0.78, 0.9, 1.0, 0.22);
uniform float refraction_strength : hint_range(0.0, 0.12, 0.001) = 0.03;
uniform float distortion_scale : hint_range(0.1, 24.0, 0.1) = 6.0;
uniform vec2 flow_speed = vec2(0.03, -0.02);

uniform float fresnel_power : hint_range(1.0, 8.0, 0.1) = 4.0;
uniform float fresnel_strength : hint_range(0.0, 1.0, 0.01) = 0.45;

uniform float roughness_min : hint_range(0.0, 1.0, 0.01) = 0.02;
uniform float roughness_max : hint_range(0.0, 1.0, 0.01) = 0.14;
uniform float normal_strength : hint_range(0.0, 1.0, 0.01) = 0.12;
uniform float frosted_strength : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform float frosted_radius : hint_range(0.0, 0.02, 0.0005) = 0.003;

uniform sampler2D noise_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 flow_uv = UV * distortion_scale + TIME * flow_speed;
	vec2 noise = texture(noise_tex, flow_uv).rg * 2.0 - 1.0;

	vec2 refract_uv = SCREEN_UV + noise * refraction_strength;
	vec2 blur_offset = noise * frosted_radius;
	vec3 c0 = texture(screen_tex, refract_uv).rgb;
	vec3 c1 = texture(screen_tex, refract_uv + vec2( blur_offset.x,  blur_offset.y)).rgb;
	vec3 c2 = texture(screen_tex, refract_uv + vec2(-blur_offset.x,  blur_offset.y)).rgb;
	vec3 c3 = texture(screen_tex, refract_uv + vec2( blur_offset.x, -blur_offset.y)).rgb;
	vec3 c4 = texture(screen_tex, refract_uv + vec2(-blur_offset.x, -blur_offset.y)).rgb;
	vec3 blurred_color = (c0 + c1 + c2 + c3 + c4) * 0.2;
	vec3 scene_color = mix(c0, blurred_color, frosted_strength);

	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, fresnel_power);

	float tint_mix = clamp(0.26 + fresnel * 0.34, 0.0, 1.0);
	ALBEDO = mix(scene_color, glass_tint.rgb, tint_mix);

	float noise_amount = clamp(length(noise), 0.0, 1.0);
	ROUGHNESS = mix(roughness_min, roughness_max, clamp(noise_amount + frosted_strength * 0.45, 0.0, 1.0));
	SPECULAR = 0.95;
	METALLIC = 0.0;

	vec3 n = normalize(vec3(noise * normal_strength, 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;

	ALPHA = clamp(glass_tint.a + fresnel * fresnel_strength, 0.0, 1.0);
	EMISSION = glass_tint.rgb * fresnel * 0.08;
}
