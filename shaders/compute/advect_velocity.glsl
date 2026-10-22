#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant) uniform Params {
    int width;
    int height;
    float delta;
    float dissipation;
} params;

layout(set = 0, binding = 0, std430) readonly buffer HorizontalIn { float horizontal_in[]; };
layout(set = 0, binding = 1, std430) readonly buffer VerticalIn { float vertical_in[]; };
layout(set = 1, binding = 0, std430) buffer HorizontalOut { float horizontal_out[]; };
layout(set = 1, binding = 1, std430) buffer VerticalOut { float vertical_out[]; };

float load_u(ivec2 cell) {
    cell.x = clamp(cell.x, 0, params.width);
    cell.y = clamp(cell.y, 0, params.height - 1);
    return horizontal_in[cell.y * (params.width + 1) + cell.x];
}

float load_v(ivec2 cell) {
    cell.x = clamp(cell.x, 0, params.width - 1);
    cell.y = clamp(cell.y, 0, params.height);
    return vertical_in[cell.y * params.width + cell.x];
}

// Bilinear sampling lets sub-cell movement accumulate. Nearest-neighbor
// sampling would return the exact same value while displacement is below 0.5 cells.
float sample_u(vec2 p) {
    p = clamp(p, vec2(0.0), vec2(params.width, params.height - 1));
    ivec2 base = ivec2(floor(p));
    vec2 fraction = fract(p);
    float bottom_left = load_u(base);
    float bottom_right = load_u(base + ivec2(1, 0));
    float top_left = load_u(base + ivec2(0, 1));
    float top_right = load_u(base + ivec2(1, 1));
    float bottom = mix(bottom_left, bottom_right, fraction.x);
    float top = mix(top_left, top_right, fraction.x);
    return mix(bottom, top, fraction.y);
}

float sample_v(vec2 p) {
    p = clamp(p, vec2(0.0), vec2(params.width - 1, params.height));
    ivec2 base = ivec2(floor(p));
    vec2 fraction = fract(p);
    float bottom_left = load_v(base);
    float bottom_right = load_v(base + ivec2(1, 0));
    float top_left = load_v(base + ivec2(0, 1));
    float top_right = load_v(base + ivec2(1, 1));
    float bottom = mix(bottom_left, bottom_right, fraction.x);
    float top = mix(top_left, top_right, fraction.x);
    return mix(bottom, top, fraction.y);
}

vec2 sample_velocity(vec2 p) {
    return vec2(sample_u(p), sample_v(p));
}

void main() {
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);
    vec2 velocity = sample_velocity(vec2(cell));
    vec2 previous = vec2(cell) - velocity * params.delta;

    float remaining = exp(-params.dissipation * params.delta);
    if (cell.x < params.width + 1 && cell.y < params.height) {
        horizontal_out[cell.y * (params.width + 1) + cell.x] = sample_u(previous) * remaining;
    }
    if (cell.x < params.width && cell.y < params.height + 1) {
        vertical_out[cell.y * params.width + cell.x] = sample_v(previous) * remaining;
    }
}
