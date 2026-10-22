#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant) uniform Constants {
    int width;
    int height;
    int padding0;
    int padding1;
} grid;

layout(set = 0, binding = 0, std430) readonly buffer HorizontalIn { float horizontal_in[]; };
layout(set = 0, binding = 1, std430) readonly buffer VerticalIn { float vertical_in[]; };
layout(set = 1, binding = 0, std430) buffer HorizontalOut { float horizontal_out[]; };
layout(set = 1, binding = 1, std430) buffer VerticalOut { float vertical_out[]; };

void main() {
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);
    if (cell.x < grid.width + 1 && cell.y < grid.height) {
        horizontal_out[cell.y * (grid.width + 1) + cell.x] =
            horizontal_in[cell.y * (grid.width + 1) + cell.x];
    }
    if (cell.x < grid.width && cell.y < grid.height + 1) {
        vertical_out[cell.y * grid.width + cell.x] =
            vertical_in[cell.y * grid.width + cell.x];
    }
}
