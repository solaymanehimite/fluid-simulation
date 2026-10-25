#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant) uniform Inflow {
    int width;
    int height;
    float speed;
    float padding;
} input_data;

layout(set = 0, binding = 0, std430) buffer HorizontalVelocities {
    float horizontal[];
};

void main() {
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);
    if (cell.x != 0 || cell.y >= input_data.height) {
        return;
    }

    // The left boundary face of every row continuously feeds the domain.
    horizontal[cell.y * (input_data.width + 1)] = input_data.speed;
}
