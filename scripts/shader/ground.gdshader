shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D city_texture; // 4.5 不需要 hint_albedo
uniform vec3 sky_top_color : source_color = vec3(0.1, 0.2, 0.5);
uniform vec3 sky_bottom_color : source_color = vec3(0.8, 0.6, 0.3);
uniform float horizon_height : hint_range(0.0, 1.0) = 0.3;
uniform float city_height_factor : hint_range(0.0, 1.0) = 0.5;
uniform float city_light_strength : hint_range(0.0, 1.0) = 0.5;
uniform float time_speed : hint_range(0.0, 5.0) = 0.5;

varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // 1. 计算天空渐变
    float t = clamp((world_pos.y + 1.0) * 0.5, 0.0, 1.0);
    vec3 sky_color = mix(sky_bottom_color, sky_top_color, t);

    // 2. 计算城市剪影
    float city_mask = smoothstep(horizon_height, horizon_height + 0.2, world_pos.y);
    vec2 uv = vec2(world_pos.x * 0.1 + TIME * time_speed, world_pos.y * 0.1);
    vec3 city_color = texture(city_texture, uv).rgb;
    
    // 3. 夜晚灯光闪烁
    float light_noise = fract(sin(dot(world_pos.xy * 10.0, vec2(12.9898, 78.233))) * 43758.5453);
    city_color += city_light_strength * light_noise * (1.0 - city_mask);

    // 4. 混合天空和城市
    vec3 final_color = mix(city_color, sky_color, city_mask);

    ALBEDO = final_color;
    ALPHA = 1.0;
}
