#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant) uniform Params {
    vec4 mouse; // x/y: grid position, z: radius, w: active flag
    vec4 color; // rgb: dye color, a: amount
} params;

layout(rgba32f, set = 0, binding = 0) uniform image2D dye_image;

void main() {
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(dye_image);
    if (cell.x >= size.x || cell.y >= size.y || params.mouse.w == 0.0) {
        return;
    }

    float distance_to_mouse = distance(vec2(cell), params.mouse.xy);
    float falloff = max(0.0, 1.0 - distance_to_mouse / params.mouse.z);
    if (falloff <= 0.0) {
        return;
    }

    vec4 current = imageLoad(dye_image, cell);
    vec3 color = min(current.rgb + params.color.rgb * falloff * params.color.a, vec3(1.0));
    float density = min(current.a + falloff * params.color.a, 1.0);
    imageStore(dye_image, cell, vec4(color, density));
}
