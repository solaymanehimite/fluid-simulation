#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant) uniform Constants {
    int width;
    int height;
    float restitution;
    float padding;
} grid;

layout(set = 0, binding = 0, std430) buffer HorizontalVelocities {
    float horizontal[];
};

layout(set = 0, binding = 1, std430) buffer VerticalVelocities {
    float vertical[];
};

void main() {
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);

    // Reflect horizontal velocity at the left and right walls.
    if (cell.y < grid.height) {
        if (cell.x == 0) {
            int index = cell.y * (grid.width + 1);
            if (horizontal[index] < 0.0) {
                horizontal[index] *= -grid.restitution;
            }
        } else if (cell.x == grid.width) {
            int index = cell.y * (grid.width + 1) + grid.width;
            if (horizontal[index] > 0.0) {
                horizontal[index] *= -grid.restitution;
            }
        }
    }

    // Reflect vertical velocity at the bottom and top walls.
    if (cell.x < grid.width) {
        if (cell.y == 0) {
            int index = cell.x;
            if (vertical[index] < 0.0) {
                vertical[index] *= -grid.restitution;
            }
        } else if (cell.y == grid.height) {
            int index = grid.height * grid.width + cell.x;
            if (vertical[index] > 0.0) {
                vertical[index] *= -grid.restitution;
            }
        }
    }
}
