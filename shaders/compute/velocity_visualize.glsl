#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant) uniform Constants {
    int width;
    int height;
    int _padding0;
    int _padding1;
} grid;

layout(set = 0, binding = 0, std430) readonly buffer HorizontalVelocities {
    float horizontal[];
};

layout(set = 0, binding = 1, std430) readonly buffer VerticalVelocities {
    float vertical[];
};

layout(rgba32f, set = 0, binding = 2) uniform writeonly image2D velocity_image;

void main() {
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);
    if (cell.x >= grid.width || cell.y >= grid.height) {
        return;
    }

    int x = cell.x;
    int y = cell.y;
    float left = horizontal[y * (grid.width + 1) + x];
    float right = horizontal[y * (grid.width + 1) + x + 1];
    float bottom = vertical[y * grid.width + x];
    float top = vertical[(y + 1) * grid.width + x];

    vec2 velocity = vec2((left + right) * 0.5, (bottom + top) * 0.5);
    imageStore(velocity_image, cell, vec4(velocity, 0.0, 1.0));
}
