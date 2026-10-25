shader_type canvas_item;

uniform sampler2D divergence_texture : filter_nearest;
uniform sampler2D velocity_texture : filter_nearest;
uniform sampler2D dye_texture : filter_nearest;
uniform sampler2D dye_bloom_texture : filter_linear;
uniform vec2 grid_size = vec2(16.0, 16.0);
uniform bool show_arrows = true;
uniform bool show_divergence = true;
uniform bool show_brush = false;
uniform vec2 brush_position = vec2(0.5, 0.5);
uniform float brush_radius = 2.0;
uniform bool bloom_enabled = true;
uniform float bloom_strength = 0.8;
uniform float bloom_radius = 2.0;
uniform bool obstacle_enabled = false;
uniform vec2 obstacle_position = vec2(0.5, 0.5);
uniform float obstacle_radius = 0.15;

void fragment() {
    float divergence = texture(divergence_texture, UV).r;
    // Divergence is usually much smaller than the velocity values, so use a
    // separate visual scale to make weak divergence visible.
    float value = clamp(abs(divergence) / 5.0, 0.0, 1.0);
    vec3 background = divergence >= 0.0
        ? mix(vec3(0.01, 0.01, 0.02), vec3(0.9, 0.03, 0.01), value)
        : mix(vec3(0.01, 0.01, 0.02), vec3(0.02, 0.15, 0.95), value);
    if (!show_divergence) {
        background = vec3(0.01, 0.01, 0.02);
    }

    vec4 dye = texture(dye_texture, UV);
    background = mix(background, dye.rgb, clamp(dye.a, 0.0, 1.0));

    // Small screen-space blur around the dye acts as a post-process bloom.
    if (bloom_enabled) {
        vec3 glow = vec3(0.0);
        float total_weight = 0.0;
        vec2 texel = 1.0 / grid_size;
        for (int x = -2; x <= 2; x++) {
            for (int y = -2; y <= 2; y++) {
                vec2 offset = vec2(float(x), float(y));
                float weight = exp(-dot(offset, offset) / (2.0 * bloom_radius * bloom_radius));
                vec4 sample_dye = texture(dye_bloom_texture, clamp(UV + offset * texel, vec2(0.0), vec2(1.0)));
                glow += sample_dye.rgb * sample_dye.a * weight;
                total_weight += weight;
            }
        }
        background += glow / total_weight * bloom_strength;
    }

    if (obstacle_enabled) {
        float obstacle_distance = length((UV - obstacle_position) * grid_size);
        float obstacle_fill = 1.0 - smoothstep(obstacle_radius * max(grid_size.x, grid_size.y) - 0.15, obstacle_radius * max(grid_size.x, grid_size.y), obstacle_distance);
        float obstacle_edge = 1.0 - smoothstep(0.08, 0.2, abs(obstacle_distance - obstacle_radius * max(grid_size.x, grid_size.y)));
        background = mix(background, vec3(0.015, 0.018, 0.025), obstacle_fill);
        background = mix(background, vec3(0.8, 0.85, 0.9), obstacle_edge);
    }

    if (show_arrows) {
        vec2 velocity = texture(velocity_texture, UV).rg;
        float speed = length(velocity);
        vec2 local = fract(UV * grid_size) - 0.5;
        vec2 direction = speed > 0.0001 ? velocity / speed : vec2(1.0, 0.0);
        vec2 perpendicular = vec2(-direction.y, direction.x);

        float along = dot(local, direction);
        float across = abs(dot(local, perpendicular));
        float arrow_length = clamp(speed * 0.08, 0.08, 0.38);
        float shaft = 1.0 - smoothstep(0.025, 0.045, across);
        shaft *= 1.0 - smoothstep(arrow_length - 0.02, arrow_length, abs(along));

        float head_center = arrow_length * 0.72;
        float head_line = abs(across - (head_center - along) * 0.45);
        float arrow_head = 1.0 - smoothstep(0.025, 0.05, head_line);
        arrow_head *= step(0.0, head_center - along);
        arrow_head *= step(head_center - arrow_length, along);

        float arrow = clamp(max(shaft, arrow_head) * step(0.001, speed), 0.0, 1.0);
        background = mix(background, vec3(1.0, 0.9, 0.35), arrow);
    }

    if (show_brush) {
        // Convert UV distance into grid-cell units so the circle matches the
        // actual velocity brush radius.
        float brush_distance = length((UV - brush_position) * grid_size);
        float fill = 1.0 - smoothstep(brush_radius - 0.12, brush_radius, brush_distance);
        background = mix(background, vec3(0.2, 0.2, 0.23), fill * 0.45);
    }

    COLOR = vec4(background, 1.0);
}
