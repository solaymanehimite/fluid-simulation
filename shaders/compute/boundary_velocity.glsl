#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant) uniform Constants {
    int width;
    int height;
    float restitution;
    float padding;
    vec4 obstacle; // xy: center in cells, z: radius, w: enabled
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

    // A solid circular obstacle blocks both staggered velocity components.
    if (grid.obstacle.w > 0.5) {
        vec2 obstacle_center = grid.obstacle.xy;
        float radius = grid.obstacle.z;
        if (cell.x < grid.width + 1 && cell.y < grid.height) {
            vec2 face = vec2(cell.x, cell.y + 0.5);
            if (distance(face, obstacle_center) <= radius) {
                horizontal[cell.y * (grid.width + 1) + cell.x] = 0.0;
            }
        }
        if (cell.x < grid.width && cell.y < grid.height + 1) {
            vec2 face = vec2(cell.x + 0.5, cell.y);
            if (distance(face, obstacle_center) <= radius) {
                vertical[cell.y * grid.width + cell.x] = 0.0;
            }
        }
    }
}
