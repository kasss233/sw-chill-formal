shader_type canvas_item;

uniform vec4 bar_color : source_color = vec4(1.0);
uniform int bar_count = 5;
uniform float speed = 5.0;
uniform float bar_width : hint_range(0.1, 0.9) = 0.5;
uniform float playback_intensity : hint_range(0.0, 1.0) = 1.0; 
uniform float min_height = 0.1;
uniform float max_height = 1;

// 完美的圆角矩形/胶囊体函数
float sdCapsule(vec2 p, vec2 a, vec2 b, float r) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

void fragment() {
    // 获取节点的像素尺寸，用于修复变形
    vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
    float aspect = size.x / size.y;
    
    // 将 UV 坐标映射到带宽高比的坐标空间
    vec2 uv = UV;
    
    // 分割列
    float x_grid = uv.x * float(bar_count);
    float bar_id = floor(x_grid);
    float local_x = fract(x_grid) - 0.5;
    
    // 这里的关键：将 local_x 乘以每一格的宽高比，防止横向拉伸导致圆角变尖
    float grid_width = aspect / float(bar_count);
    local_x *= grid_width;

    // --- 优化的动态算法 ---
    // 使用两个不同频率的正弦波叠加，模拟真实的音乐起伏感
    float t = TIME * speed;
    float noise = sin(t + bar_id * 1.5) * 0.4 + sin(t * 1.3 - bar_id * 0.8) * 0.2;
    noise = noise * 0.5 + 0.5; // 映射到 0-1
    
    // 计算当前高度
    float h = mix(min_height, max_height, noise * playback_intensity);
    // 暂停时收缩逻辑：基于 playback_intensity 缩小
    h = max(h, min_height); 

    // 定义胶囊体的顶点（垂直对称）
    float r = (bar_width * grid_width) * 0.5; // 半径基于格子的宽度
    float line_half_len = max(0.0, (h * 0.5) - r);
    vec2 p1 = vec2(0.0, -line_half_len);
    vec2 p2 = vec2(0.0, line_half_len);
    
    // 计算距离（中心点在 0,0）
    float dist = sdCapsule(vec2(local_x, uv.y - 0.5), p1, p2, r);
    
    // 抗锯齿边缘
    float alpha = smoothstep(0.01 * grid_width, 0.0, dist);
    
    COLOR = vec4(bar_color.rgb, alpha * bar_color.a);
}