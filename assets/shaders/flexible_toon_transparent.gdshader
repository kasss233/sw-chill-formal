shader_type spatial;
// 保持 cull_disabled 以显示鱼缸背面
// depth_draw_always 确保透明排序正确
render_mode cull_disabled;

// --- 基础外观 ---
uniform vec4 albedo : source_color = vec4(0.8, 0.9, 1.0, 0.3); // 建议设为淡蓝色，Alpha设为0.1-0.3
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;

// --- 玻璃菲涅尔效果 (核心优化) ---
// 控制边缘和中心的透明度变化，让玻璃更有体积感
uniform float fresnel_power : hint_range(0.1, 8.0) = 2.0;
uniform float edge_opacity : hint_range(0.0, 1.0) = 0.8; // 边缘不透明度
uniform float center_opacity : hint_range(0.0, 1.0) = 0.1; // 中心不透明度

// --- 卡通高光 (Specular) ---
// 玻璃质感主要靠高光体现
uniform float specular_strength : hint_range(0.0, 5.0) = 2.0; // 玻璃高光通常很亮
uniform float specular_shininess : hint_range(0.0, 64.0) = 32.0; // 玻璃高光通常很小很锐利
uniform float specular_smoothness : hint_range(0.0, 1.0) = 0.05; // 高光边缘软硬度

// --- 边缘光 (Rim) ---
uniform float rim_width : hint_range(0.0, 16.0) = 4.0;
uniform vec4 rim_color : source_color = vec4(1.0);
uniform float rim_smoothness : hint_range(0.0, 1.0) = 0.1;

varying vec3 vertex_pos;

void vertex() {
	vertex_pos = VERTEX;
}

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	ALBEDO = albedo.rgb * tex_color.rgb;
	
	// 【核心修复】双面渲染法线修正
	// 如果渲染的是背面（鱼缸内壁），我们需要反转法线，否则光照会变黑
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	
	// 【核心优化】菲涅尔透明度计算
	// 计算视线与法线的夹角
	float NdotV = dot(NORMAL, VIEW);
	// 限制范围防止错误
	float rim = 1.0 - clamp(abs(NdotV), 0.0, 1.0);
	float fresnel = pow(rim, fresnel_power);
	
	// 混合中心透明度和边缘透明度
	float final_alpha = mix(center_opacity, edge_opacity, fresnel);
	
	// 叠加贴图原本的Alpha
	ALPHA = final_alpha * albedo.a * tex_color.a;
	
	// 增加一些粗糙度，让玻璃看起来不那么像镜子
	ROUGHNESS = 0.1; 
	METALLIC = 0.0;
}

void light() {
	// --- 漫反射 (Diffuse) 简化 ---
	// 玻璃不应该有复杂的阶梯阴影，它主要是透光的
	// 我们只给一点点基础亮度，防止背光面死黑
	float NdotL = dot(NORMAL, LIGHT);
	// 使用 half-lambert 并让它很平滑，不要 cuts/stepping
	float diffuse_intensity = (NdotL * 0.5 + 0.5); 
	// 稍微抑制漫反射，玻璃主要看高光
	vec3 diffuse = ALBEDO * LIGHT_COLOR * diffuse_intensity * 0.5; 
	
	// --- 高光 (Specular) ---
	// 卡通风格的高光通常是锐利的圆点
	vec3 H = normalize(LIGHT + VIEW);
	float NdotH = dot(NORMAL, H);
	float specular_dot = max(NdotH, 0.0);
	
	// 使用 smoothstep 制作卡通边缘的高光，而不是 step，这样稍微柔和一点点
	float specular_cutoff = 1.0 - (1.0 / specular_shininess);
	float specular_val = smoothstep(specular_cutoff, specular_cutoff + specular_smoothness, specular_dot);
	
	vec3 specular = LIGHT_COLOR * specular_val * specular_strength;
	
	// --- 边缘光 (Rim) ---
	float NdotV = dot(NORMAL, VIEW);
	float rim_dot = 1.0 - clamp(abs(NdotV), 0.0, 1.0);
	float rim_threshold = 1.0 - (1.0 / rim_width); // 动态调整阈值
	float rim_val = smoothstep(rim_threshold, rim_threshold + rim_smoothness, rim_dot);
	
	// 边缘光通常只出现在受光面 (可选)
	rim_val *= max(0.0, NdotL + 0.5); 
	
	vec3 rim = rim_color.rgb * rim_val;

	// --- 最终合成 ---
	// 玻璃材质：漫反射很弱 + 强高光 + 强边缘
	DIFFUSE_LIGHT += diffuse + specular + rim;
}
