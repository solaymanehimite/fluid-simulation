#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant) uniform Constants {
    int width;
    int height;
    int _padding0;
    int _padding1;
} grid;

layout(rgba32f, set = 0, binding = 0) uniform readonly image2D pressure_image;

layout(set = 0, binding = 1, std430) buffer HorizontalVelocities {
    float horizontal[];
};

layout(set = 0, binding = 2, std430) buffer VerticalVelocities {
    float vertical[];
};

float pressure_at(ivec2 cell) {
    if (cell.x < 0 || cell.y < 0 ||
        cell.x >= grid.width || cell.y >= grid.height) {
        return 0.0;
    }
    return imageLoad(pressure_image, cell).r;
}

void main() {
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);

    // Horizontal velocity faces: (width + 1) by height.
    if (cell.x < grid.width + 1 && cell.y < grid.height) {
        float pressure_left = pressure_at(cell + ivec2(-1, 0));
        float pressure_right = pressure_at(cell);
        float gradient = pressure_right - pressure_left;
        int index = cell.y * (grid.width + 1) + cell.x;
        horizontal[index] -= gradient;
    }

    // Vertical velocity faces: width by (height + 1).
    if (cell.x < grid.width && cell.y < grid.height + 1) {
        float pressure_bottom = pressure_at(cell + ivec2(0, -1));
        float pressure_top = pressure_at(cell);
        float gradient = pressure_top - pressure_bottom;
        int index = cell.y * grid.width + cell.x;
        vertical[index] -= gradient;
    }
}
