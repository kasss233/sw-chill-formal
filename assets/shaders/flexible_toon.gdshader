shader_type spatial;
// cull_disabled: 关闭背面剔除，解决旋转视角变黑的问题
// depth_draw_always: 确保五官等透明部件在任何时候都正确渲染
render_mode cull_disabled, depth_draw_always; 

// --- 基础颜色参数 ---
uniform vec4 albedo : source_color = vec4(1.0);
// 【核心修改】hint_default_white: 如果脚本没传贴图，系统会自动给一张白图，防止变黑
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform bool use_vertex_color = false; 

// --- 卡通阶梯参数 ---
uniform int cuts : hint_range(1, 8) = 3;
uniform float wrap : hint_range(-2.0, 2.0) = 0.1; // 调整受光范围
uniform float steepness : hint_range(1.0, 8.0) = 1.0;
uniform float shadow_brightness : hint_range(0.0, 1.0) = 0.2; // 阴影处的基础亮度

// --- 辅助功能 ---
uniform bool use_attenuation = true;
uniform bool clamp_diffuse_to_max = false;

// --- 镜面反射 (Specular) ---
uniform bool use_specular = true;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.175;
uniform float specular_shininess : hint_range(0.0, 32.0) = 4.0;
uniform sampler2D specular_map : source_color, hint_default_white;

// --- 边缘光 (Rim) ---
uniform bool use_rim = true;
uniform float rim_width : hint_range(0.0, 16.0) = 8.0;
uniform vec4 rim_color : source_color = vec4(1.0);

// --- 渐变纹理 (Ramp) ---
uniform bool use_ramp = false;
uniform sampler2D ramp : source_color;

varying vec3 vertex_pos;
varying vec3 normal;
varying vec4 v_color;

float split_specular(float specular) {
	return step(0.5, specular);
}

void vertex() {
	vertex_pos = VERTEX;
	normal = NORMAL;
	v_color = COLOR; 
}

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	vec3 base_color = albedo.rgb * tex_color.rgb;
	
	if (use_vertex_color) {
		base_color *= v_color.rgb;
	}
	
	ALBEDO = base_color;
	//ALPHA = albedo.a * tex_color.a;
}

void light() {
	float attenuation = 1.0;
	if (use_attenuation) {
		attenuation = ATTENUATION; 
	}
	
	// 漫反射计算
	float NdotL = dot(NORMAL, LIGHT);
	
	// 使用类似 Half-Lambert 的处理方式，让光照更均匀，避免视角转动导致的死黑
	float diffuse_amount = (NdotL + 1.0) * 0.5; 
	diffuse_amount = clamp(diffuse_amount + (attenuation - 1.0) + wrap, 0.0, 1.0);
	
	float cuts_inv = 1.0 / float(cuts);
	float diffuse_stepped = clamp(ceil(diffuse_amount * float(cuts)) / float(cuts), 0.0, 1.0);

	// 确保暗部亮度不低于 shadow_brightness
	float light_intensity = max(diffuse_stepped, shadow_brightness);
	
	vec3 diffuse_base = ALBEDO.rgb * LIGHT_COLOR / PI;
	vec3 diffuse_final;
	
	if (use_ramp) {
		diffuse_final = diffuse_base * texture(ramp, vec2(light_intensity, 0.0)).rgb;
	} else {
		diffuse_final = diffuse_base * light_intensity;
	}
	
	if (clamp_diffuse_to_max) {
		DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, diffuse_final);
	} else {
		DIFFUSE_LIGHT += diffuse_final;
	}
	
	if (use_specular) {
		vec3 H = normalize(LIGHT + VIEW);
		float NdotH = dot(NORMAL, H);
		float spec_map_val = texture(specular_map, UV).r;
		float specular_amount = max(pow(NdotH, specular_shininess * specular_shininess), 0.0)
							    * spec_map_val
								* attenuation;
		specular_amount = split_specular(specular_amount);
		SPECULAR_LIGHT += specular_strength * specular_amount * LIGHT_COLOR;
	}
	
	if (use_rim) {
		float NdotV = dot(NORMAL, VIEW);
		float rim_light = pow(1.0 - clamp(NdotV, 0.0, 1.0), rim_width);
		DIFFUSE_LIGHT += rim_light * rim_color.rgb * rim_color.a * LIGHT_COLOR / PI;
	}
}