shader_type canvas_item;

uniform sampler2D divergence_texture : filter_nearest;
uniform sampler2D velocity_texture : filter_nearest;
uniform vec2 grid_size = vec2(48.0, 48.0);

void fragment() {
    float divergence = texture(divergence_texture, UV).r;
    // Divergence is usually much smaller than the velocity values, so use a
    // separate visual scale to make weak divergence visible.
    float value = clamp(abs(divergence) / 5.0, 0.0, 1.0);
    vec3 background = divergence >= 0.0
        ? mix(vec3(0.01, 0.01, 0.02), vec3(0.9, 0.03, 0.01), value)
        : mix(vec3(0.01, 0.01, 0.02), vec3(0.02, 0.15, 0.95), value);

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
    float head_line = abs(across - (head_center - along) * 0.9);
    float arrow_head = 1.0 - smoothstep(0.025, 0.05, head_line);
    arrow_head *= step(0.0, head_center - along);
    arrow_head *= step(head_center - arrow_length, along);

    float arrow = clamp(max(shaft, arrow_head) * step(0.001, speed), 0.0, 1.0);
    COLOR = vec4(mix(background, vec3(1.0, 0.9, 0.35), arrow), 1.0);
}
