shader_type canvas_item;

/* ===== 色阶 ===== */
uniform int shade_steps : hint_range(2, 8) = 6;
uniform float light_bias : hint_range(-0.3, 0.3) = 0.1;
uniform float shade_softness : hint_range(0.0, 1.0) = 0.6; // 新增：阶梯柔化

/* ===== 描边 ===== */
uniform float edge_strength : hint_range(0.0, 5.0) = 0.9;
uniform float edge_threshold : hint_range(0.0, 0.5) = 0.22;
uniform float edge_softness : hint_range(0.0, 0.3) = 0.2;
uniform float edge_darkness : hint_range(0.0, 1.0) = 0.35;
uniform float shadow_ignore : hint_range(0.0, 1.0) = 0.4;

/* ===== 工具函数 ===== */
float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 tex = texture(TEXTURE, UV);
	vec3 base = tex.rgb;

	/* ---------- 1. 柔和色阶 ---------- */
	float l = clamp(luma(base) + light_bias, 0.0, 1.0);
	float steps = float(shade_steps);

	// 软量化（比 floor 平滑）
	float q = floor(l * steps) / steps;
	float q2 = ceil(l * steps) / steps;

	// 使用 smoothstep 在相邻阶之间插值
	float f = fract(l * steps);
	float lq = mix(q, q2, smoothstep(0.0, 1.0, f * shade_softness));

	// 保留更多原亮度
	float l_final = mix(lq, l, 0.4);

	float scale = l_final / max(luma(base), 0.001);
	vec3 toon = base * scale;

	/* ---------- 2. 更柔的描边检测 ---------- */
	float l0 = l;
	float l1 = luma(texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb);
	float l2 = luma(texture(TEXTURE, UV - vec2(px.x, 0.0)).rgb);
	float l3 = luma(texture(TEXTURE, UV + vec2(0.0, px.y)).rgb);
	float l4 = luma(texture(TEXTURE, UV - vec2(0.0, px.y)).rgb);

	float diff =
		abs(l0 - l1) +
		abs(l0 - l2) +
		abs(l0 - l3) +
		abs(l0 - l4);

	diff = max(diff - shadow_ignore, 0.0);

	float edge = smoothstep(
		edge_threshold - edge_softness,
		edge_threshold + edge_softness,
		diff * edge_strength
	);

	// 压低弱边
	edge = edge * edge;

	/* ---------- 3. 轻描边叠加 ---------- */
	vec3 edge_color = vec3(0.08); // 更偏暖灰
	vec3 final_color = mix(toon, edge_color, edge * edge_darkness);

	COLOR = vec4(final_color, tex.a);
}
