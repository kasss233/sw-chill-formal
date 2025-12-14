shader_type spatial;
//v.01
// Completely free to use by Lonely_Studios, please credit if you want.Thanks! 

// water properties
uniform vec3 primary_water_color : source_color = vec3(0.0, 0.1, 0.4);
uniform vec3 secondary_water_color : source_color = vec3(0.0, 0.4, 0.8);
uniform float water_depth = 5.0;
uniform float water_clarity = 0.5;
uniform float edge_scale = 0.1;
uniform float overall_transparency : hint_range(0.0, 1.0) = 0.9;

// Reflections and surface properties
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform float fresnel_power = 5.0;
uniform float reflection_strength = 0.5;

// Wave properties
uniform sampler2D wave_height_map;
uniform sampler2D wave_normal_map1;
uniform sampler2D wave_normal_map2;
uniform float wave_speed = 0.1;
uniform float wave_height = 0.2;
uniform float wave_scale = 10.0;
uniform vec2 wave_direction1 = vec2(1.0, 0.0);
uniform vec2 wave_direction2 = vec2(0.5, 0.5);
uniform float wave_time_scale = 1.0;

// Foam properties
uniform sampler2D foam_texture : hint_default_white;
uniform vec3 foam_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float foam_amount = 0.5;
uniform float foam_cutoff = 0.8;
uniform float shore_foam_distance = 1.0;

// Caustics properties
uniform sampler2D caustics_texture;
uniform float caustics_strength = 0.5;
uniform float caustics_scale = 5.0;
uniform float caustics_speed = 0.05;

// Droplet properties
uniform sampler2D droplet_normal_map;
uniform float droplet_amount : hint_range(0.0, 1.0) = 0.7;
uniform float droplet_size : hint_range(0.1, 5.0) = 1.0;
uniform float droplet_speed : hint_range(0.1, 10.0) = 2.0;
uniform float droplet_strength : hint_range(0.1, 5.0) = 2.0;
uniform float droplet_persistence : hint_range(0.1, 10.0) = 3.0;

// Refraction properties
uniform float refraction_strength = 0.1;

// Depth texture for water depth calculations
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Varying variables for passing data between vertex and fragment shaders
varying vec3 world_position;
varying float height_value;
varying vec3 vertex_normal;
varying vec3 binormal;
varying vec3 tangent;
varying vec3 camera_position;

// Utility functions
float fresnel_effect(float amount, vec3 normal, vec3 view) {
    return pow(1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0), amount);
}

// Hash function for random number generation
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Additional hash function for more variation
float hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Function to create ripple droplet shape
float droplet_ripple(vec2 uv, float size, float time_factor) {
    // Distance from center
    float dist = length(uv - 0.5);
    
    // Basic droplet shape
    float droplet = smoothstep(0.5 * size, 0.0, dist);
    
    // Add ripple rings that expand over time
    float ripple_speed = 3.0 * time_factor;
    float ripple = sin(dist * 50.0 - ripple_speed) * 0.5 + 0.5;
    
    // Add second ripple ring for more complexity
    float ripple2 = sin(dist * 30.0 - ripple_speed * 0.7) * 0.5 + 0.5;
    
    // Fade ripple at edges
    ripple *= smoothstep(0.5 * size, 0.0, dist);
    ripple2 *= smoothstep(0.5 * size, 0.0, dist);
    
    // Combine base droplet with ripple effects
    return droplet * (0.6 + 0.2 * ripple + 0.2 * ripple2);
}

void vertex() {
    // Store camera position for fragment shader
    camera_position = CAMERA_POSITION_WORLD;
    
    // Calculate world position for use in fragment shader
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // Sample wave height map for vertex displacement
    vec2 wave_uv = world_position.xz / wave_scale;
    vec2 time_offset = TIME * wave_speed * wave_time_scale * vec2(1.0, 1.0);
    
    // Sample height map at two different offsets and blend
    float height1 = texture(wave_height_map, wave_uv + time_offset * wave_direction1).r;
    float height2 = texture(wave_height_map, wave_uv * 0.5 + time_offset * wave_direction2).r;
    height_value = mix(height1, height2, 0.5) * 2.0 - 1.0; // Convert to -1 to 1 range
    
    // Apply height displacement to vertex
    VERTEX.y += height_value * wave_height;
    
    // Calculate normal, tangent, and binormal for normal mapping
    vertex_normal = normalize(NORMAL);
    // Fix for the .a error - use a simpler approach for binormal calculation
    binormal = normalize(cross(NORMAL, TANGENT.xyz));
    tangent = normalize(TANGENT.xyz);
    
    // Adjust normal based on wave height gradient for more realistic wave shape
    vec2 du = vec2(0.01, 0.0);
    vec2 dv = vec2(0.0, 0.01);
    
    float h_u1 = texture(wave_height_map, (world_position.xz + du) / wave_scale + time_offset * wave_direction1).r;
    float h_u2 = texture(wave_height_map, (world_position.xz + du) * 0.5 + time_offset * wave_direction2).r;
    float h_u = mix(h_u1, h_u2, 0.5) * 2.0 - 1.0;
    
    float h_v1 = texture(wave_height_map, (world_position.xz + dv) / wave_scale + time_offset * wave_direction1).r;
    float h_v2 = texture(wave_height_map, (world_position.xz + dv) * 0.5 + time_offset * wave_direction2).r;
    float h_v = mix(h_v1, h_v2, 0.5) * 2.0 - 1.0;
    
    vec3 grad = vec3((h_u - height_value) / du.x, 1.0, (h_v - height_value) / dv.y);
    NORMAL = normalize(grad);
}

void fragment() {
    // Calculate view direction using the passed camera_position
    vec3 view_dir = normalize(camera_position - world_position);
    
    // Calculate depth for water effects
    float depth_tex = texture(DEPTH_TEXTURE, SCREEN_UV).r;
    vec3 depth_world_pos = (INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_tex, 1.0)).xyz;
    float depth_distance = distance(depth_world_pos, world_position);
    
    // Calculate water depth factor
    float water_depth_factor = 1.0 - exp(-depth_distance * water_clarity);
    
    // Calculate shore proximity for foam
    float shore_proximity = 1.0 - smoothstep(0.0, shore_foam_distance, depth_distance);
    
    // Calculate wave normals
    vec2 wave_uv = world_position.xz / wave_scale;
    vec2 time_offset = TIME * wave_speed * wave_time_scale * vec2(1.0, 1.0);
    
    // Sample normal maps with different scales and directions
    vec3 normal1 = texture(wave_normal_map1, wave_uv + time_offset * wave_direction1).rgb * 2.0 - 1.0;
    vec3 normal2 = texture(wave_normal_map2, wave_uv * 0.5 + time_offset * wave_direction2).rgb * 2.0 - 1.0;
    
    // Blend normal maps
    vec3 blend_normal = normalize(mix(normal1, normal2, 0.5));
    
    // Create droplet effect
    // Initialize droplet normal and intensity
    vec3 droplet_normal = vec3(0.0, 0.0, 1.0);
    float total_droplet_intensity = 0.0;
    
    // Constants for droplet sizes
    float large_droplet_count = 8.0 * droplet_size;
    float medium_droplet_count = 15.0 * droplet_size;
    float small_droplet_count = 25.0 * droplet_size;
    
    // Large droplets
    {
        vec2 tiled_uv = UV * large_droplet_count;
        vec2 tile_id = floor(tiled_uv);
        vec2 tile_uv = fract(tiled_uv);
        
        float rand_val = hash21(tile_id);
        float rand_val2 = hash22(tile_id);
        
        if (rand_val < 0.3 * droplet_amount) {
            float drop_time_offset = rand_val2 * 10.0;
            float drop_lifetime = 1.0 + rand_val * 2.0 * droplet_persistence;
            float drop_time = fract((TIME * droplet_speed + drop_time_offset) / drop_lifetime);
            
            float drop_fade_in = smoothstep(0.0, 0.1, drop_time);
            float drop_fade_out = 1.0 - smoothstep(0.6, 1.0, drop_time);
            float drop_intensity = drop_fade_in * drop_fade_out;
            
            vec2 drop_center = vec2(0.2 + 0.6 * hash21(tile_id + 0.1), 
                                    0.2 + 0.6 * hash22(tile_id + 0.2));
            vec2 centered_uv = tile_uv - drop_center;
            
            float drop_shape = droplet_ripple(tile_uv, 0.4 + 0.2 * rand_val, drop_time * 3.0);
            
            vec2 droplet_uv = centered_uv + 0.5;
            vec3 large_droplet_normal = texture(droplet_normal_map, droplet_uv).rgb * 2.0 - 1.0;
            
            large_droplet_normal.xy *= 1.5 * droplet_strength;
            large_droplet_normal = normalize(large_droplet_normal);
            
            float large_intensity = drop_intensity * drop_shape * 1.2;
            droplet_normal = mix(droplet_normal, large_droplet_normal, large_intensity);
            total_droplet_intensity += large_intensity;
        }
    }
    
    // Medium droplets
    {
        vec2 tiled_uv = UV * medium_droplet_count;
        vec2 tile_id = floor(tiled_uv);
        vec2 tile_uv = fract(tiled_uv);
        
        float rand_val = hash21(tile_id + vec2(33.33, 66.66));
        float rand_val2 = hash22(tile_id + vec2(11.11, 22.22));
        
        if (rand_val < 0.25 * droplet_amount) {
            float drop_time_offset = rand_val2 * 15.0;
            float drop_lifetime = 0.8 + rand_val * 1.5 * droplet_persistence;
            float drop_time = fract((TIME * droplet_speed + drop_time_offset) / drop_lifetime);
            
            float drop_fade_in = smoothstep(0.0, 0.05, drop_time);
            float drop_fade_out = 1.0 - smoothstep(0.5, 0.9, drop_time);
            float drop_intensity = drop_fade_in * drop_fade_out;
            
            vec2 drop_center = vec2(0.3 + 0.4 * hash21(tile_id + 0.3), 
                                   0.3 + 0.4 * hash22(tile_id + 0.4));
            vec2 centered_uv = tile_uv - drop_center;
            
            float drop_shape = droplet_ripple(tile_uv, 0.3 + 0.15 * rand_val, drop_time * 2.5);
            
            vec2 droplet_uv = centered_uv + 0.5;
            vec3 medium_droplet_normal = texture(droplet_normal_map, droplet_uv).rgb * 2.0 - 1.0;
            
            medium_droplet_normal.xy *= 1.3 * droplet_strength;
            medium_droplet_normal = normalize(medium_droplet_normal);
            
            float medium_intensity = drop_intensity * drop_shape * 0.8;
            droplet_normal = mix(droplet_normal, medium_droplet_normal, medium_intensity);
            total_droplet_intensity += medium_intensity;
        }
    }
    
    // Small droplets
    {
        vec2 tiled_uv = UV * small_droplet_count;
        vec2 tile_id = floor(tiled_uv);
        vec2 tile_uv = fract(tiled_uv);
        
        float rand_val = hash21(tile_id + vec2(77.77, 88.88));
        float rand_val2 = hash22(tile_id + vec2(99.99, 44.44));
        
        if (rand_val < 0.2 * droplet_amount) {
            float drop_time_offset = rand_val2 * 20.0;
            float drop_lifetime = 0.5 + rand_val * droplet_persistence;
            float drop_time = fract((TIME * droplet_speed + drop_time_offset) / drop_lifetime);
            
            float drop_fade_in = smoothstep(0.0, 0.03, drop_time);
            float drop_fade_out = 1.0 - smoothstep(0.4, 0.8, drop_time);
            float drop_intensity = drop_fade_in * drop_fade_out;
            
            vec2 drop_center = vec2(0.4 + 0.2 * hash21(tile_id + 0.5), 
                                   0.4 + 0.2 * hash22(tile_id + 0.6));
            vec2 centered_uv = tile_uv - drop_center;
            
            float drop_shape = droplet_ripple(tile_uv, 0.2 + 0.1 * rand_val, drop_time * 2.0);
            
            vec2 droplet_uv = centered_uv + 0.5;
            vec3 small_droplet_normal = texture(droplet_normal_map, droplet_uv).rgb * 2.0 - 1.0;
            
            small_droplet_normal.xy *= 1.2 * droplet_strength;
            small_droplet_normal = normalize(small_droplet_normal);
            
            float small_intensity = drop_intensity * drop_shape * 0.6;
            droplet_normal = mix(droplet_normal, small_droplet_normal, small_intensity);
            total_droplet_intensity += small_intensity;
        }
    }
    
    // Ensure droplet normal is properly normalized
    droplet_normal = normalize(droplet_normal);
    
    // Combine wave normals with droplet normals
    float final_droplet_influence = min(total_droplet_intensity, 1.0) * droplet_amount * 0.7;
    vec3 final_normal = normalize(mix(blend_normal, droplet_normal, final_droplet_influence));
    
    // Transform normal from tangent space to world space
    mat3 TBN = mat3(tangent, binormal, vertex_normal);
    vec3 world_normal = normalize(TBN * final_normal);
    
    // Calculate fresnel effect for reflections
    float fresnel_factor = fresnel_effect(fresnel_power, world_normal, view_dir);
    
    // Calculate foam
    vec2 foam_uv = world_position.xz / (wave_scale * 0.5);
    vec2 foam_offset1 = TIME * wave_speed * 0.05 * wave_direction1;
    vec2 foam_offset2 = TIME * wave_speed * 0.07 * wave_direction2;
    
    float foam_noise1 = texture(foam_texture, foam_uv + foam_offset1).r;
    float foam_noise2 = texture(foam_texture, foam_uv * 2.0 + foam_offset2).r;
    float foam_blend = mix(foam_noise1, foam_noise2, 0.5);
    
    // Enhance foam near shores and on wave crests
    float height_foam = smoothstep(0.6, 1.0, height_value + 0.5); // Foam on wave crests
    float shore_foam = shore_proximity * foam_amount * 2.0;
    float final_foam = smoothstep(foam_cutoff, 1.0, foam_blend * (shore_foam + height_foam));
    
    // Calculate caustics
    vec2 caustics_uv = depth_world_pos.xz / caustics_scale;
    vec2 caustics_offset = TIME * caustics_speed * vec2(0.3, 0.4);
    float caustics1 = texture(caustics_texture, caustics_uv + caustics_offset).r;
    float caustics2 = texture(caustics_texture, caustics_uv * 1.5 - caustics_offset * 0.8).r;
    float caustics_blend = max(caustics1, caustics2) * caustics_strength;
    
    // Apply caustics only to underwater areas
    caustics_blend *= (1.0 - shore_proximity) * (1.0 - water_depth_factor);
    
    // Calculate refraction offset
    vec2 refraction_offset = world_normal.xz * refraction_strength;
    vec2 refracted_uv = SCREEN_UV + refraction_offset;
    
    // Sample screen texture with refraction offset
    vec3 refracted_color = texture(SCREEN_TEXTURE, refracted_uv).rgb;
    
    // Apply caustics to refracted color
    refracted_color += caustics_blend * vec3(0.5, 0.7, 1.0);
    
    // Blend between deep and shallow water colors based on depth
    vec3 water_color = mix(secondary_water_color, primary_water_color, water_depth_factor);
    
    // Blend water color with refracted color based on depth
    vec3 final_color = mix(refracted_color, water_color, water_depth_factor * overall_transparency);
    
    // Add foam
    final_color = mix(final_color, foam_color, final_foam);
    
    // Apply fresnel reflections
    final_color = mix(final_color, vec3(1.0), fresnel_factor * reflection_strength);
    
    // Apply final color and material properties
    ALBEDO = final_color;
    METALLIC = metallic;
    ROUGHNESS = roughness - (final_droplet_influence * 0.05); // Reduce roughness where droplets are
    SPECULAR = specular + (final_droplet_influence * 0.2); // Enhance specular where droplets are
    
    // Apply normal mapping
    NORMAL_MAP = final_normal;
    
    // Set transparency
    ALPHA = min(overall_transparency + fresnel_factor * 0.2, 1.0);
}