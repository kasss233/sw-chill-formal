shader_type canvas_item;

// --- 基础参数 ---
uniform float corner_radius : hint_range(0.0, 100.0) = 25.0; // 调大圆角更现代
uniform bool show_border = true;
uniform float border_width : hint_range(0.0, 10.0) = 1.0;
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 0.15); // 建议用半透明白

// --- 毛玻璃核心参数 ---
uniform float blur_amount : hint_range(0.0, 5.0) = 3.5;       // 模糊强度
uniform float saturation : hint_range(0.0, 3.0) = 1.6;      // 关键：背景饱和度提升
uniform float brightness : hint_range(0.0, 2.0) = 1.1;      // 关键：背景亮度提升
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 0.1); // 建议用极淡的白色

// --- 杂点与阴影 ---
uniform float noise_amount : hint_range(0.0, 1.0) = 0.02;
uniform sampler2D noise_texture : repeat_enable, filter_linear;

uniform bool show_shadow = true;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.2);
uniform float shadow_size : hint_range(0.0, 32.0) = 12.0;
uniform vec2 shadow_offset = vec2(0.0, 6.0);

uniform vec2 size;
uniform float shadow_padding = 10.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// 饱和度调整函数
vec3 adjust_saturation(vec3 rgb, float adjustment) {
    const vec3 W = vec3(0.2125, 0.7154, 0.0721);
    vec3 intensity = vec3(dot(rgb, W));
    return mix(intensity, rgb, adjustment);
}

float rounded_rect_sdf(vec2 pos, vec2 rect_size, float radius) {
    vec2 center = rect_size * 0.5;
    vec2 d_rect = abs(pos - center) - (center - radius);
    return length(max(d_rect, 0.0)) + min(max(d_rect.x, d_rect.y), 0.0) - radius;
}

void fragment() {
    vec2 panel_size = size - shadow_padding * 2.0;
    vec2 pixel_pos = UV * size;
    vec2 panel_pos = pixel_pos - shadow_padding;
    
    // 1. 计算面板区域
    float panel_dist = rounded_rect_sdf(panel_pos, panel_size, corner_radius);
    float edge_width = fwidth(panel_dist);
    float panel_alpha = 1.0 - smoothstep(-edge_width, edge_width, panel_dist);
    
    // 2. 采样背景并处理质感
    // 使用 textureLod 采样，Mipmap 会辅助模糊
    vec4 screen_color = textureLod(SCREEN_TEXTURE, SCREEN_UV, blur_amount);
    
    // 【改进点】提升饱和度和亮度，这是第二张图“通透”的秘诀
    screen_color.rgb = adjust_saturation(screen_color.rgb, saturation);
    screen_color.rgb *= brightness;
    
    // 3. 混合杂点 (使用 Overlay 模式而非简单 Mix，让杂点更自然)
    float noise = texture(noise_texture, panel_pos / 200.0).r;
    screen_color.rgb += (noise - 0.5) * noise_amount;

    // 4. 混合色调 (Tint)
    // 对于第二种图，tint_color 应该是透明度很低的纯白
    vec3 final_panel_rgb = mix(screen_color.rgb, tint_color.rgb, tint_color.a);

    // 5. 边框 (使用叠加模式会让边缘有亮部感)
    if (show_border && border_width > 0.01) {
        float border_mask = smoothstep(border_width + edge_width, border_width - edge_width, abs(panel_dist + border_width * 0.5));
        final_panel_rgb = mix(final_panel_rgb, border_color.rgb, border_mask * border_color.a);
    }

    // 6. 阴影计算
    float shadow_alpha = 0.0;
    if (show_shadow) {
        float shadow_dist = rounded_rect_sdf(panel_pos - shadow_offset, panel_size, corner_radius);
        shadow_alpha = 1.0 - smoothstep(-shadow_size, shadow_size, shadow_dist);
        shadow_alpha *= shadow_color.a;
    }

    // 7. 最终合成
    vec3 final_color;
    float final_alpha;

    if (show_shadow) {
        // Alpha Over 合成：面板叠加在阴影之上
        final_alpha = panel_alpha + shadow_alpha * (1.0 - panel_alpha);
        if (final_alpha > 0.001) {
            final_color = (final_panel_rgb * panel_alpha + shadow_color.rgb * shadow_alpha * (1.0 - panel_alpha)) / final_alpha;
        } else {
            final_color = vec3(0.0);
        }
    } else {
        final_color = final_panel_rgb;
        final_alpha = panel_alpha;
    }

    COLOR = vec4(final_color, final_alpha);
}