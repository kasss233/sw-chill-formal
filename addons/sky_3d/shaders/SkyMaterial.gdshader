// Toon/Anime Style Sky Shader
// Based on original by Cory Petkovsek, Contributors, and J. Cuellar
// Modified for cartoon/cel-shaded rendering style

shader_type sky;
render_mode use_debanding;

group_uniforms toon_settings;
uniform int toon_color_steps : hint_range(2, 8) = 3;
uniform float toon_smoothness : hint_range(0.0, 0.5) = 0.05;
uniform float toon_saturation_boost : hint_range(0.0, 1.0) = 0.3;
uniform float toon_brightness_boost : hint_range(0.0, 0.5) = 0.1;
uniform bool toon_outline_clouds = true;
uniform float toon_cloud_outline_thickness : hint_range(0.0, 0.1) = 0.02;
uniform vec4 toon_cloud_outline_color : source_color = vec4(0.2, 0.3, 0.5, 1.0);
uniform float toon_cloud_softness : hint_range(0.0, 0.5) = 0.05;

group_uniforms general;
uniform bool sky_visible = true;
uniform vec2 color_correction = vec2(0.0, 1.0);
uniform vec4 ground_color: source_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform float horizon_offset = 0.0;

group_uniforms atmosphere;
uniform float atm_darkness = 0.5;
uniform float atm_sun_intensity = 18.0;
uniform vec4 atm_day_tint: source_color = vec4(0.808, 0.91, 1.0, 1.0);
uniform vec4 atm_horizon_light_tint: source_color = vec4(0.98, 0.635, 0.463, 1.0);
uniform vec4 atm_night_tint: source_color = vec4(0.041, 0.049, 0.061, 0.245);
uniform vec3 atm_level_params = vec3(1.0, 0.0, 0.0);
uniform float atm_thickness = 0.7;
uniform vec3 atm_beta_ray = vec3(0.00001, 0.00001, 0.00003);
uniform vec3 atm_beta_mie = vec3(0.00000003038);

group_uniforms toon_sky_gradient;
uniform vec4 toon_zenith_color : source_color = vec4(0.25, 0.45, 0.85, 1.0);
uniform vec4 toon_horizon_color : source_color = vec4(0.55, 0.75, 0.95, 1.0);
uniform vec4 toon_sunset_color : source_color = vec4(0.95, 0.55, 0.25, 1.0);
uniform vec4 toon_night_zenith_color : source_color = vec4(0.02, 0.02, 0.08, 1.0);
uniform vec4 toon_night_horizon_color : source_color = vec4(0.05, 0.05, 0.15, 1.0);
uniform float toon_gradient_steps : hint_range(2.0, 10.0) = 4.0;
uniform bool use_toon_gradient = true;

group_uniforms sun_disk;
uniform vec4 sun_disk_color: source_color = vec4(0.996, 0.541, 0.14, 1.0);
uniform float sun_disk_intensity = 2.0;
uniform float sun_disk_size = 0.015;
uniform float toon_sun_glow_size : hint_range(0.0, 0.3) = 0.08;
uniform vec4 toon_sun_glow_color : source_color = vec4(1.0, 0.85, 0.5, 0.5);
uniform int toon_sun_glow_rings : hint_range(1, 5) = 3;

group_uniforms sun_mie;
uniform vec4 atm_sun_mie_tint: source_color = vec4(1.0);
uniform float atm_sun_mie_intensity = 1.0;
uniform vec3 atm_sun_partial_mie_phase = vec3(0.36, 1.64, 1.6);

group_uniforms moon;
uniform vec4 moon_color: source_color = vec4(1.0);
uniform sampler2D moon_texture: source_color, repeat_disable;
uniform vec3 moon_texture_alignment = vec3(7.0, 1.4, 4.8);
uniform bool moon_texture_flip_u;
uniform bool moon_texture_flip_v;
uniform float moon_size = 0.07;

group_uniforms moon_mie;
uniform vec4 atm_moon_mie_tint: source_color = vec4(0.137, 0.184, 0.292, 1.0);
uniform float atm_moon_mie_intensity = 0.17152;
uniform vec3 atm_moon_partial_mie_phase = vec3(0.36, 1.64, 1.6);

group_uniforms star_map;
uniform vec4 starmap_color: source_color = vec4(0.71, 0.71, 0.71, 0.855);
uniform sampler2D starmap_texture: source_color;
uniform bool starmap_flip_u = false;
uniform bool starmap_flip_v = false;
uniform vec3 starmap_alignment = vec3(2.68288, -0.25891, 0.40101);
uniform float star_rotation_offset = 9.38899;
uniform float star_rotation = 0.0;
uniform float star_tilt = 0.0;

group_uniforms star_field;
uniform vec4 star_field_color: source_color = vec4(1.0);
uniform sampler2D star_field_texture: source_color;
uniform float star_scintillation = 0.75;
uniform float star_scintillation_speed = 0.01;
uniform sampler2D noise_tex: source_color;
uniform float toon_star_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float toon_star_size : hint_range(0.5, 3.0) = 1.5;

group_uniforms cirrus_clouds;
uniform bool cirrus_visible = true;
uniform float cirrus_coverage = 0.5;
uniform float cirrus_thickness = 10.0;
uniform float cirrus_absorption = 2.0;
uniform float cirrus_sky_tint_fade = 0.5;
uniform float cirrus_intensity = 10.0;
uniform float cirrus_size = 1.0;
uniform vec2 cirrus_uv = vec2(0.16, 0.11);
uniform vec2 cirrus_position1 = vec2(0.0);
uniform vec2 cirrus_position2 = vec2(0.0);
uniform vec4 cirrus_day_color: source_color = vec4(0.824, 0.875, 1.0, 1.0);
uniform vec4 cirrus_horizon_light_color: source_color = vec4(0.98, 0.43, 0.15, 1.0);
uniform vec4 cirrus_night_color: source_color = vec4(0.1, 0.20, 0.28, 1);
uniform sampler2D cirrus_texture;

group_uniforms cumulus_clouds;
uniform bool cumulus_visible = true;
uniform float cumulus_coverage = 0.55;
uniform float cumulus_thickness = 0.0243;
uniform float cumulus_absorption = 2.0;
uniform float cumulus_noise_freq = 2.7;
uniform float cumulus_sky_tint_fade = 0.0;
uniform float cumulus_intensity = 1.0;
uniform float cumulus_size = 0.5;
uniform vec2 cumulus_position = vec2(0.0);
uniform sampler2D cumulus_texture;
uniform vec4 cumulus_day_color: source_color = vec4(0.824, 0.875, 1.0, 1.0);
uniform vec4 cumulus_horizon_light_color: source_color = vec4(0.98, 0.443, 0.15, 1.0);
uniform vec4 cumulus_night_color: source_color = vec4(0.20, 0.22, 0.30, 1.0);
uniform vec3 cumulus_partial_mie_phase = vec3(0.95756, 1.04244, 0.412);
uniform float cumulus_mie_intensity = 1.0;

group_uniforms overlays;
uniform bool show_azimuthal_grid = false;
uniform vec4 azimuthal_grid_color : source_color = vec4(.871, .722, .529, 1.);
uniform float azimuthal_grid_rotation_offset = 0.03;
uniform bool show_equatorial_grid = false;
uniform vec4 equatorial_grid_color : source_color = vec4(0., .75, 1., 1.);
uniform float equatorial_grid_rotation_offset = 0.03;

group_uniforms transform_matrices;
uniform mat3 moon_matrix;

#include "Common.gdshaderinc"

// ============================================================================
// TOON HELPER FUNCTIONS
// ============================================================================

// Quantize a value to discrete steps with optional smoothing
float toon_quantize(float value, float steps, float smoothness_val) {
	float quantized = floor(value * steps) / steps;
	float next_step = ceil(value * steps) / steps;
	float blend = smoothstep(quantized + (1.0 / steps) - smoothness_val, quantized + (1.0 / steps), value);
	return mix(quantized, next_step, blend);
}

// Quantize color to discrete steps
vec3 toon_quantize_color(vec3 color, float steps, float smoothness_val) {
	return vec3(
		toon_quantize(color.r, steps, smoothness_val),
		toon_quantize(color.g, steps, smoothness_val),
		toon_quantize(color.b, steps, smoothness_val)
	);
}

// Boost saturation for more anime-like vivid colors
vec3 boost_saturation(vec3 color, float amount) {
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	return mix(vec3(luminance), color, 1.0 + amount);
}

// Hard step transition (for toon shading)
float hard_step(float edge, float value, float softness) {
	return smoothstep(edge - softness, edge + softness, value);
}

// Create stepped gradient for anime-style sky banding
vec3 stepped_gradient(vec3 color_a, vec3 color_b, float t, float steps) {
	float stepped_t = floor(t * steps + 0.5) / steps;
	return mix(color_a, color_b, stepped_t);
}

// ============================================================================
// ORIGINAL HELPER FUNCTIONS (preserved)
// ============================================================================

mat3 create_rotation_matrix(vec3 r) {
	float c1 = cos(r.x), s1 = sin(r.x);
	float c2 = cos(r.y), s2 = sin(r.y);
	float c3 = cos(r.z), s3 = sin(r.z);

	mat3 rotX = mat3(
		vec3(1.0, 0.0, 0.0),
		vec3(0.0, c1, -s1),
		vec3(0.0, s1, c1)
	);
	mat3 rotY = mat3(
		vec3(c2, 0.0, s2),
		vec3(0.0, 1.0, 0.0),
		vec3(-s2, 0.0, c2)
	);
	mat3 rotZ = mat3(
		vec3(c3, -s3, 0.0),
		vec3(s3, c3, 0.0),
		vec3(0.0, 0.0, 1.0)
	);
	return rotZ * rotY * rotX;
}

vec2 calc_equirect_uv(vec3 norm) {
	float flipu = starmap_flip_u ? -1.0 : 1.0;
	float flipv = starmap_flip_v ? -1.0 : 1.0;
	float u = flipu * ((atan(norm.y, norm.x) + PI) * INV_TAU);
	float v = -flipv * (acos(norm.z) * INV_PI);
	return vec2(u, v);
}

vec3 sample_moon_texture(vec3 dir) {
	dir = moon_matrix * dir * create_rotation_matrix(moon_texture_alignment);
	dir.x = -dir.x;
	dir.z = -dir.z;
	float flipu = moon_texture_flip_u ? 1.0 : -1.0;
	float flipv = moon_texture_flip_v ? 1.0 : -1.0;
	float u = 0.5 + flipu * atan(dir.z, dir.x) * INV_TAU;
	float v = 0.5 + flipv * asin(dir.y) * INV_PI;
	return texture(moon_texture, vec2(u, v)).rgb;
}

float calc_disk_mask(vec3 norm, vec3 coords, lowp float size) {
	float dist = length(norm - coords);
	return 1.0 - step(size, dist);
}

float map_range(float value, float from_min, float from_max, float to_min, float to_max) {
	return to_min + (value - from_min) * (to_max - to_min) / (from_max - from_min);
}

bool ray_sphere_intersect(float r, vec3 origin, vec3 dir, out float t, out vec3 nrm) {
	origin += vec3(0.0, 450.0, 0.0);
	float a = dot(dir, dir);
	float b = 2.0 * dot(origin, dir);
	float c = dot(origin, origin) - r * r;
	float d = b * b - 4.0 * a * c;
	float valid = step(0.0, d);
	d = sqrt(max(d, 0.0));
	a *= 2.0;
	float t1 = 0.5 * (-b + d);
	float t2 = 0.5 * (-b - d);
	float t_min = min(t1, t2);
	t = mix(t2, t1, step(t2, t1) * step(0.0, t1));
	t = mix(0.0, t, step(0.0, t) * valid);
	nrm = mix(vec3(0.0), origin + t * dir, step(0.0, t) * valid);
	return bool(step(0.0, t) * valid);
}

float simple_sphere_intersect(vec3 ray_dir, vec3 sphere_pos, float radius) {
	vec3 oc = -sphere_pos;
	float b = dot(oc, ray_dir);
	float c = dot(oc, oc) - radius * radius;
	float h = b * b - c;
	float valid = step(0.0, h);
	h = sqrt(max(h, 0.0));
	return mix(-1.0, -b - h, valid);
}

// ============================================================================
// TOON ATMOSPHERE
// ============================================================================

vec3 calc_toon_atmospheric_scatter(float sr, float sm, vec2 mu, vec3 mult) {
	vec3 beta_mie = atm_beta_mie;
	vec3 beta_ray = atm_beta_ray * atm_thickness;

	vec3 extc_factor = clamp_rgb_to_unit(exp(-(beta_ray * sr + beta_mie * sm)));

	float extc_ff = mix(clamp_to_unit(atm_thickness * 0.5), 1.0, mult.x);
	vec3 final_extc_factor = mix(1.0 - extc_factor, (1.0 - extc_factor) * extc_factor, extc_ff);
	float rayleigh_phase = calc_rayleigh_phase(mu.x);
	vec3 BRT = beta_ray * rayleigh_phase;
	vec3 BMT = beta_mie * calc_mie_phase(mu.x, atm_sun_partial_mie_phase);
	BMT *= atm_sun_mie_intensity * atm_sun_mie_tint.rgb;

	vec3 BRMT = (BRT + BMT) / (beta_ray + beta_mie);
	vec3 scatter = atm_sun_intensity * (BRMT * final_extc_factor) * atm_day_tint.rgb * mult.y;
	scatter = mix(scatter, scatter * (1.0 - extc_factor), atm_darkness);

	vec3 lcol = mix(atm_day_tint.rgb, atm_horizon_light_tint.rgb, mult.x);
	vec3 nscatter = (1.0 - extc_factor) * atm_night_tint.rgb;
	nscatter += calc_mie_phase(mu.y, atm_moon_partial_mie_phase) *
		atm_moon_mie_tint.rgb * atm_moon_mie_intensity * 0.005;

	vec3 result = (scatter * lcol) + nscatter;

	// Apply toon quantization to scatter
	float steps_f = float(toon_color_steps);
	result = toon_quantize_color(clamp(result, vec3(0.0), vec3(1.0)), steps_f, toon_smoothness);

	// Boost saturation for anime look
	result = boost_saturation(result, toon_saturation_boost);

	return result;
}

// Toon sky gradient (anime-style banded sky)
vec3 calc_toon_sky_gradient(vec3 world_pos, vec3 sun_pos) {
	float height = clamp(world_pos.y, 0.0, 1.0);

	// Day/night factor
	float day_factor = clamp(sun_pos.y + 0.45, 0.0, 1.0);
	float sunset_factor = clamp(1.0 - abs(sun_pos.y) * 3.0, 0.0, 1.0) * clamp(1.0 - sun_pos.y, 0.0, 1.0);

	// Stepped height gradient
	float stepped_height = floor(height * toon_gradient_steps + 0.5) / toon_gradient_steps;

	// Day sky colors
	vec3 day_sky = mix(toon_horizon_color.rgb, toon_zenith_color.rgb, stepped_height);

	// Night sky colors - enforce deep blue minimum for cartoon look
	vec3 deep_blue_zenith = vec3(0.03, 0.05, 0.20);
	vec3 deep_blue_horizon = vec3(0.05, 0.08, 0.25);
	vec3 night_zenith = max(toon_night_zenith_color.rgb, deep_blue_zenith);
	vec3 night_horizon = max(toon_night_horizon_color.rgb, deep_blue_horizon);
	vec3 night_sky = mix(night_horizon, night_zenith, stepped_height);

	// Mix between day and night
	vec3 sky = mix(night_sky, day_sky, day_factor);

	// Add sunset tint
	float sunset_height_factor = 1.0 - clamp(height * 2.0, 0.0, 1.0);
	sunset_height_factor = floor(sunset_height_factor * 3.0 + 0.5) / 3.0; // Step the sunset
	sky = mix(sky, toon_sunset_color.rgb, sunset_factor * sunset_height_factor * 0.7);

	return sky;
}

// ============================================================================
// TOON CLOUDS
// ============================================================================
const int CUMULUS_STEP = 10;

float sample_cirrus_noise(vec2 coords) {
	float a = textureLod(cirrus_texture, coords.xy * cirrus_uv + cirrus_position1, 0.0).r;
	float b = textureLod(cirrus_texture, coords.xy * cirrus_uv + cirrus_position2, 0.0).r;
	return ((a + b) * 0.5);
}

float sample_cumulus_noise(vec3 p) {
	vec3 pos = vec3(p * 0.01);
	pos.z *= 256.0;
	vec2 offset = vec2(0.317, 0.123);
	vec4 uv = vec4(0.0);
	uv.xy = pos.xy + offset * floor(pos.z);
	uv.zw = uv.xy + offset;
	float x1 = textureLod(cumulus_texture, uv.xy, 0.0).r;
	float x2 = textureLod(cumulus_texture, uv.zw, 0.0).r;
	return mix(x1, x2, fract(pos.z));
}

float calc_cumulus_fbm(vec3 p, float l) {
	float ret;
	ret = 0.51749673 * sample_cumulus_noise(p);
	p *= l;
	ret += 0.25584929 * sample_cumulus_noise(p);
	p *= l;
	ret += 0.12527603 * sample_cumulus_noise(p);
	p *= l;
	ret += 0.06255931 * sample_cumulus_noise(p);
	return ret;
}

float calc_cirrus_density(vec2 p) {
	float d = sample_cirrus_noise(p);
	float c = 1.0 - cirrus_coverage;
	d = d - c;
	return clamp_to_unit(d);
}

float calc_cumulus_density(vec3 p, vec3 offset, float t) {
	vec3 pos = p * 0.0212242 - offset;
	float dens = calc_cumulus_fbm(pos, cumulus_noise_freq);
	dens += dens;

	float cov = 1.0 - cumulus_coverage;
	cov = smoothstep(0.00, (cov * 3.5) + t, dens);
	dens *= cov;
	dens = map_range(dens, 1.0 - cov, 1.0, 0.0, 1.0);

	return clamp_to_unit(dens);
}

// Toon cirrus clouds - flat, stylized
vec4 render_toon_cirrus_clouds(vec3 pos) {
	pos.xy = pos.xz / pos.y;
	pos *= cirrus_size;
	float density = calc_cirrus_density(pos.xy);

	// Hard edge threshold for toon look
	float toon_density = smoothstep(0.1 - toon_cloud_softness, 0.1 + toon_cloud_softness, density);

	// Simplified shading - 2 tone
	float sh = toon_density > 0.5 ? 0.8 : 1.0;

	float a = clamp(toon_density * cirrus_thickness, 0.0, 1.0);

	// Hard alpha edge
	a = smoothstep(0.05, 0.05 + toon_cloud_softness * 2.0, a);

	return vec4(vec3(sh) * cirrus_intensity * 0.3, a);
}

// Toon cumulus clouds - cel-shaded, flat colors with hard shadow
vec4 render_toon_cumulus_clouds(vec3 ro, vec3 rd, float am, vec3 sun_pos, vec3 moon_pos) {
	vec4 ret = vec4(0.);
	vec3 wind = -vec3(cumulus_position.x, 0.0, cumulus_position.y);
	float a = 0.0;

	vec3 n; float tt;
	if (ray_sphere_intersect(500., ro, rd, tt, n)) {
		float march_step = float(CUMULUS_STEP) * cumulus_thickness;
		vec3 dir_step = rd / rd.y * march_step;
		vec3 pos = n * cumulus_size;

		vec4 t = vec4(1.0);
		float total_density = 0.0;

		for(int i = 0; i < CUMULUS_STEP; i++) {
			float h = float(i) * 0.1;
			float density = calc_cumulus_density(pos, wind, h);
			float sh = clamp(exp(-cumulus_absorption * density * march_step), 0.0, 1.0);
			t *= sh;
			ret += (t * (exp(h) * 0.571428571) * density * march_step);
			total_density += density;
			a += (1.0 - sh) * (1.0 - a);
			pos += dir_step;
		}

		// Toon-ify the cloud alpha - hard edges
		a = clamp(a, 0.0, 1.0);
		float toon_a = smoothstep(0.15 - toon_cloud_softness, 0.15 + toon_cloud_softness, a);

		// Toon-ify cloud brightness into 2-3 bands
		float brightness = clamp(length(ret.rgb), 0.0, 1.0);

		// Quantize brightness for cel-shaded look
		float toon_bright;
		if (brightness > 0.6) {
			toon_bright = 1.0;
		} else if (brightness > 0.3) {
			toon_bright = 0.75;
		} else {
			toon_bright = 0.55;
		}

		ret.rgb = vec3(toon_bright) * cumulus_intensity;

		return vec4(ret.rgb, toon_a);
	}
	return vec4(ret.rgb * cumulus_intensity, a);
}

// ============================================================================
// TOON SUN
// ============================================================================

vec3 render_toon_sun(vec3 world_pos, vec3 sun_pos, vec3 scatter) {
	float dist_to_sun = length(world_pos - sun_pos);

	// Main sun disk - sharp circle
	float sun_mask = 1.0 - smoothstep(sun_disk_size - 0.001, sun_disk_size + 0.001, dist_to_sun);

	// Anime-style glow rings around sun
	vec3 glow = vec3(0.0);
	for (int i = 0; i < toon_sun_glow_rings; i++) {
		float ring_size = toon_sun_glow_size * (1.0 + float(i) * 0.5);
		float ring = 1.0 - smoothstep(ring_size - 0.01, ring_size + 0.01, dist_to_sun);
		float ring_inner = 1.0 - smoothstep(ring_size * 0.7 - 0.01, ring_size * 0.7 + 0.01, dist_to_sun);
		float ring_band = ring * (1.0 - ring_inner * 0.5);
		float falloff = 1.0 / (1.0 + float(i) * 1.5);
		glow += toon_sun_glow_color.rgb * toon_sun_glow_color.a * ring_band * falloff;
	}

	vec3 sun = sun_mask * sun_disk_color.rgb * sun_disk_intensity;
	sun += glow;

	return sun;
}

// ============================================================================
// TOON MOON
// ============================================================================

vec3 render_toon_moon(vec3 world_pos, vec3 moon_pos, vec3 sun_pos) {
	float moon_intersect = simple_sphere_intersect(world_pos, moon_pos, moon_size);
	float moon_mask = moon_intersect > (-1.0 + sqrt(moon_size)) ? 1.0 : 0.0;
	vec3 moon_normal = normalize(world_pos * moon_intersect - moon_pos);

	float moon_ndotl = clamp(dot(moon_normal, sun_pos), 0.0, 1.0);

	// Toon quantize the moon lighting
	float toon_ndotl;
	if (moon_ndotl > 0.5) {
		toon_ndotl = 1.0;
	} else if (moon_ndotl > 0.2) {
		toon_ndotl = 0.5;
	} else {
		toon_ndotl = 0.15;
	}

	vec3 moon_tex = sample_moon_texture(moon_normal);
	// Quantize moon texture for flat look
	moon_tex = toon_quantize_color(moon_tex, 4.0, 0.02);

	vec3 moon_output = moon_mask * toon_ndotl * exp2(1.0) * moon_tex * moon_color.rgb;
	return moon_output;
}

// ============================================================================
// TOON STARS
// ============================================================================

vec3 render_toon_stars(vec3 world_pos, vec2 deep_space_uv, float angle_mult_z, float moon_mask, float p_time) {
	// Star map - quantize for flat look
	vec3 deep_space_background = textureLod(starmap_texture, deep_space_uv, 0.0).rgb;
	deep_space_background *= starmap_color.rgb;
	deep_space_background = adjust_contrast(deep_space_background, starmap_color.a);

	// Make stars pop more with hard threshold
	float star_brightness = dot(deep_space_background, vec3(0.333));
	deep_space_background *= step(toon_star_threshold * 0.3, star_brightness) * toon_star_size;

	// Star field with twinkle
	float star_scint = textureLod(noise_tex, deep_space_uv + (p_time * star_scintillation_speed), 0.0).r;
	// Make twinkle more dramatic for anime feel
	star_scint = step(0.4, star_scint); // Binary twinkle

	vec3 star_field = textureLod(star_field_texture, deep_space_uv, 0.0).rgb * star_field_color.rgb;
	// Hard threshold for star visibility
	float star_visible = step(toon_star_threshold, dot(star_field, vec3(0.333)));
	star_field = star_field * star_visible * mix(1.0, star_scint, star_scintillation);
	star_field *= toon_star_size;

	vec3 result = (deep_space_background + star_field) * moon_mask * angle_mult_z;
	return result;
}

// ============================================================================
// MAIN RENDER
// ============================================================================

vec3 render_sky(vec3 world_pos, vec3 clouds_pos, vec3 sun_pos, vec3 moon_pos, float p_time) {
	vec3 col = vec3(0.0);

	vec4 angle_mult;
	angle_mult.x = clamp_to_unit(1.0 - sun_pos.y);
	angle_mult.y = clamp_to_unit(sun_pos.y + 0.45);
	angle_mult.z = clamp_to_unit(-sun_pos.y + 0.30);
	angle_mult.w = clamp_to_unit(-sun_pos.y + 0.60);

	// Atmosphere
	vec2 mu = vec2(dot(sun_pos, world_pos), dot(moon_pos, world_pos));
	float sr, sm;
	calc_simple_optical_depth(world_pos.y + atm_level_params.z - horizon_offset, sr, sm, atm_level_params.xy);

	world_pos.y -= horizon_offset;
	float horizonBlend = clamp_to_unit((world_pos.y - 0.03) * 3.0);
	float horizonBlendCumulus = clamp_to_unit((world_pos.y + 0.01) * 50.0);

	// Choose between physical scatter and toon gradient
	vec3 scatter;
	if (use_toon_gradient) {
		// Anime-style banded sky gradient
		scatter = calc_toon_sky_gradient(world_pos, sun_pos);

		// Blend in some atmospheric scatter for light interaction
		// Reduce physical scatter at night to preserve deep blue toon gradient
		vec3 phys_scatter = calc_toon_atmospheric_scatter(sr, sm, mu.xy, angle_mult.xyz);
		float scatter_blend = mix(0.3, 0.08, angle_mult.z);
		scatter = mix(scatter, phys_scatter, scatter_blend);
	} else {
		scatter = calc_toon_atmospheric_scatter(sr, sm, mu.xy, angle_mult.xyz);
	}

	col.rgb += scatter.rgb;

	// Toon Sun
	vec3 toon_sun = render_toon_sun(world_pos, sun_pos, scatter);
	col.rgb += toon_sun;

	// Moon mask (for star rendering - stars should not render behind the moon disk)
	float moon_intersect = simple_sphere_intersect(world_pos, moon_pos, moon_size);
	float moonMask = 1.0 - (moon_intersect > (-1.0 + sqrt(moon_size)) ? 1.0 : 0.0);

	// Deep space / Stars (rendered before clouds so stars appear behind clouds)
	mat3 tilt = create_rotation_matrix(vec3(star_tilt, 0.0, 0.0));
	mat3 rotation = create_rotation_matrix(vec3(0.0, star_rotation + star_rotation_offset, 0.0));
	mat3 alignment_xyz = create_rotation_matrix(starmap_alignment);
	vec3 final_alignment = normalize(alignment_xyz * rotation * tilt * world_pos);
	vec2 deep_space_uv = calc_equirect_uv(normalize(final_alignment));

	vec3 stars = render_toon_stars(world_pos, deep_space_uv, angle_mult.z, moonMask, p_time);
	col.rgb += stars * horizonBlend;

	// Moonlight factor for night cloud illumination
	float moonlight_factor = angle_mult.z * clamp(moon_pos.y * 3.0, 0.0, 1.0);

	// Toon Cirrus Clouds
	if (cirrus_visible) {
		vec4 cirrus_clouds = render_toon_cirrus_clouds(clouds_pos);
		cirrus_clouds.a = clamp(cirrus_clouds.a, 0.0, 1.0);

		// Reduce cirrus opacity at night for clearer sky
		cirrus_clouds.a *= mix(1.0, 0.5, angle_mult.z);

		// Moonlight illumination - blend toward moonlit color when moon is up
		vec3 moonlit_cirrus = vec3(0.35, 0.38, 0.52);
		vec3 cirrus_night = mix(cirrus_night_color.rgb, moonlit_cirrus, moonlight_factor);
		vec3 cloud_color = mix(
			mix(cirrus_day_color.rgb, cirrus_horizon_light_color.rgb, angle_mult.x),
			cirrus_night,
			angle_mult.w
		);
		// Quantize cloud color
		cloud_color = toon_quantize_color(cloud_color, 3.0, toon_smoothness);
		cirrus_clouds.rgb *= cloud_color;

		cirrus_clouds.a = mix(0.0, cirrus_clouds.a, horizonBlend);
		col.rgb = mix(col.rgb, cirrus_clouds.rgb + mix(vec3(0.0), scatter, cirrus_sky_tint_fade), cirrus_clouds.a);
	}

	// Toon Cumulus Clouds
	if (cumulus_visible) {
		vec4 cumulus_clouds = render_toon_cumulus_clouds(vec3(0.0), clouds_pos, angle_mult.z, sun_pos, moon_pos);
		cumulus_clouds.a = clamp(cumulus_clouds.a, 0.0, 1.0);

		// Reduce cumulus opacity at night for clearer sky
		cumulus_clouds.a *= mix(1.0, 0.6, angle_mult.z);

		// Moonlight illumination - blend toward moonlit color when moon is up
		vec3 moonlit_cumulus = vec3(0.40, 0.43, 0.55);
		vec3 cumulus_night = mix(cumulus_night_color.rgb, moonlit_cumulus, moonlight_factor);
		vec3 cloud_color = mix(
			mix(cumulus_day_color.rgb, cumulus_horizon_light_color.rgb, angle_mult.x),
			cumulus_night,
			angle_mult.w
		);
		// Quantize cloud color for toon look
		cloud_color = toon_quantize_color(cloud_color, 3.0, toon_smoothness);
		cumulus_clouds.rgb *= cloud_color;

		// Add toon cloud outline
		if (toon_outline_clouds) {
			float outline = smoothstep(0.1, 0.1 + toon_cloud_outline_thickness, cumulus_clouds.a) *
							(1.0 - smoothstep(0.15, 0.15 + toon_cloud_outline_thickness * 0.5, cumulus_clouds.a));
			cumulus_clouds.rgb = mix(cumulus_clouds.rgb, toon_cloud_outline_color.rgb, outline * toon_cloud_outline_color.a);
		}

		cumulus_clouds.a = mix(0.0, cumulus_clouds.a, horizonBlend);
		col.rgb = mix(col.rgb, cumulus_clouds.rgb + mix(vec3(0.0), scatter, cumulus_sky_tint_fade), cumulus_clouds.a);
	}

	// Toon Moon (rendered after clouds so the moon is visible at night)
	vec3 toon_moon = render_toon_moon(world_pos, moon_pos, sun_pos);
	col.rgb += toon_moon * horizonBlend;

	// Final toon color processing
	col.rgb = apply_photo_tonemap(col.rgb, color_correction.y, color_correction.x);

	// Final quantization pass - use more steps at night to preserve cloud-sky contrast
	float final_steps = float(toon_color_steps) + 2.0 + angle_mult.z * 4.0;
	col.rgb = toon_quantize_color(clamp(col.rgb, vec3(0.0), vec3(1.0)), final_steps, toon_smoothness * 0.5);

	// Boost brightness slightly for anime aesthetic
	col.rgb += toon_brightness_boost;

	// Final saturation boost
	col.rgb = boost_saturation(col.rgb, toon_saturation_boost * 0.5);

	return col;
}

// ============================================================================
// OVERLAY GRIDS (preserved from original)
// ============================================================================

vec4 create_axis_angle_quat(vec3 axis, float angle) {
	float s = sin(angle * 0.5);
	return vec4(axis * s, cos(angle * 0.5));
}

vec3 rotate_vector_by_quat(vec3 v, vec4 q) {
	vec3 t = 2.0 * cross(q.xyz, v);
	return v + q.w * t + cross(q.xyz, t);
}

vec3 align_and_rotate_vector(vec3 dir, vec3 target, float rotation_angle) {
	vec3 z_axis = vec3(0.0, 0.0, 1.0);
	target = normalize(target);
	vec3 axis = cross(z_axis, target);
	float angle = acos(dot(z_axis, target));
	float valid = step(0.0001, length(axis));
	axis = normalize(axis);
	vec4 align_quat = create_axis_angle_quat(axis, angle);
	dir = mix(dir, rotate_vector_by_quat(dir, align_quat), valid);
	vec4 rot_quat = create_axis_angle_quat(vec3(0.0, 0.0, 1.0), rotation_angle);
	dir = mix(dir, rotate_vector_by_quat(dir, rot_quat), valid);
	return dir;
}

void render_grid(vec3 dir, vec3 pole_dir, float rotation_angle, vec4 line_color, float grid_spacing, float line_thickness, inout vec3 color) {
	float spacing = max(grid_spacing, 0.001);
	float thickness = max(line_thickness, 0.0001);

	dir = align_and_rotate_vector(dir, pole_dir, rotation_angle);

	float theta = acos(dir.z);
	float theta_deriv = fwidth(theta);
	float circle_thickness = max(thickness, theta_deriv);
	float circle = mod(theta, spacing);
	float circle_line = 1.0 - smoothstep(0.0, circle_thickness * 1.5, abs(circle - circle_thickness * 0.5));
	circle_line *= clamp_to_unit(thickness / circle_thickness);

	float pole_thickness = circle_thickness;
	float north_pole = 1.0 - smoothstep(0.0, pole_thickness, theta);
	float south_pole = 1.0 - smoothstep(0.0, pole_thickness, abs(theta - PI));
	circle_line = max(circle_line, max(north_pole, south_pole));

	float circle_adjust = sin(theta);
	circle_line *= clamp(circle_adjust, 0.2, 1.0);

	float phi = atan(dir.y, dir.x);
	float phi_deriv = fwidth(phi);
	float radial_thickness = max(thickness, phi_deriv);
	float radial = mod(phi + PI, spacing);
	float radial_line = 1.0 - smoothstep(0.0, radial_thickness * 1.5, abs(radial - radial_thickness));
	radial_line *= clamp_to_unit(thickness / radial_thickness);

	float grid = max(radial_line, circle_line);
	color += line_color.rgb * line_color.a * grid;
}

// ============================================================================
// SKY ENTRY POINT
// ============================================================================

void sky() {
	float current_time = TIME;
	vec3 col = vec3(0.0);
	vec3 world_pos = EYEDIR;
	vec3 clouds_pos = EYEDIR;
	vec3 sun_pos = LIGHT0_DIRECTION;
	vec3 moon_pos = LIGHT1_DIRECTION;

	if (sky_visible) {
		col = render_sky(world_pos, clouds_pos, sun_pos, moon_pos, current_time);
	}

	// Draw overlay grids
	{
		float grid_thickness = 0.0002;
		float grid_spacing = 0.261799;
		vec3 zenith_dir = vec3(0.0, 1.0, 0.0);
		vec3 north_celestial_pole = create_rotation_matrix(vec3(star_tilt, 0.0, 0.0)) * zenith_dir;
		float rotation_angle = star_rotation + star_rotation_offset;
		if (show_azimuthal_grid) {
			render_grid(EYEDIR, zenith_dir, azimuthal_grid_rotation_offset, azimuthal_grid_color, grid_spacing, grid_thickness, col);
		}
		if (show_equatorial_grid) {
			render_grid(EYEDIR, north_celestial_pole, rotation_angle + equatorial_grid_rotation_offset, equatorial_grid_color, grid_spacing, grid_thickness, col);
		}
	}

	COLOR = col.rgb;
}