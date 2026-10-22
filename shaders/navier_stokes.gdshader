shader_type canvas_item;

uniform sampler2D divergence_texture : filter_nearest;

void fragment() {
    float divergence = texture(divergence_texture, UV).r;

    // Diverging map: zero is neutral, negative is blue, positive is red.
    float strength = clamp(abs(divergence) / 40.0, 0.0, 1.0);
    vec3 color = divergence >= 0.0
        ? mix(vec3(1.0), vec3(0.95, 0.08, 0.02), strength)
        : mix(vec3(1.0), vec3(0.05, 0.15, 0.9), strength);
    COLOR = vec4(color, 1.0);
}
