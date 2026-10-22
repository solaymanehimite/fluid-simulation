#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant) uniform Params {
    int width;
    int height;
    float delta;
    float dissipation;
} params;

layout(rgba32f, set = 0, binding = 0) uniform readonly image2D dye_in;
layout(rgba32f, set = 1, binding = 0) uniform writeonly image2D dye_out;
layout(set = 2, binding = 0, std430) readonly buffer HorizontalVelocities { float horizontal[]; };
layout(set = 2, binding = 1, std430) readonly buffer VerticalVelocities { float vertical[]; };

float load_u(ivec2 cell) {
    cell.x = clamp(cell.x, 0, params.width);
    cell.y = clamp(cell.y, 0, params.height - 1);
    return horizontal[cell.y * (params.width + 1) + cell.x];
}

float load_v(ivec2 cell) {
    cell.x = clamp(cell.x, 0, params.width - 1);
    cell.y = clamp(cell.y, 0, params.height);
    return vertical[cell.y * params.width + cell.x];
}

float sample_u(vec2 p) {
    p = clamp(p, vec2(0.0), vec2(params.width, params.height - 1));
    ivec2 base = ivec2(floor(p));
    vec2 f = fract(p);
    float left = mix(load_u(base), load_u(base + ivec2(1, 0)), f.x);
    float right = mix(load_u(base + ivec2(0, 1)), load_u(base + ivec2(1, 1)), f.x);
    return mix(left, right, f.y);
}

float sample_v(vec2 p) {
    p = clamp(p, vec2(0.0), vec2(params.width - 1, params.height));
    ivec2 base = ivec2(floor(p));
    vec2 f = fract(p);
    float left = mix(load_v(base), load_v(base + ivec2(1, 0)), f.x);
    float right = mix(load_v(base + ivec2(0, 1)), load_v(base + ivec2(1, 1)), f.x);
    return mix(left, right, f.y);
}

vec2 sample_velocity(vec2 p) {
    return vec2(sample_u(p), sample_v(p));
}

vec4 load_dye(ivec2 cell) {
    cell = clamp(cell, ivec2(0), ivec2(params.width - 1, params.height - 1));
    return imageLoad(dye_in, cell);
}

vec4 sample_dye(vec2 p) {
    p = clamp(p, vec2(0.0), vec2(params.width - 1, params.height - 1));
    ivec2 base = ivec2(floor(p));
    vec2 f = fract(p);
    vec4 left = mix(load_dye(base), load_dye(base + ivec2(1, 0)), f.x);
    vec4 right = mix(load_dye(base + ivec2(0, 1)), load_dye(base + ivec2(1, 1)), f.x);
    return mix(left, right, f.y);
}

void main() {
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);
    if (cell.x >= params.width || cell.y >= params.height) {
        return;
    }

    vec2 velocity = sample_velocity(vec2(cell));
    vec2 previous = vec2(cell) - velocity * params.delta;
    float remaining = exp(-params.dissipation * params.delta);
    imageStore(dye_out, cell, sample_dye(previous) * remaining);
}
