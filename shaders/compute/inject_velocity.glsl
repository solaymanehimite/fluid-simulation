#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant) uniform MouseInput {
    // x/y: mouse position, z: brush radius, w: maximum velocity.
    vec4 mouse;
    // x/y: drag direction impulse, z: grid width, w: grid height.
    vec4 impulse;
} input_data;

layout(set = 0, binding = 0, std430) buffer HorizontalVelocities {
    float horizontal[];
};

layout(set = 0, binding = 1, std430) buffer VerticalVelocities {
    float vertical[];
};

void main() {
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);
    int width = int(input_data.impulse.z);
    int height = int(input_data.impulse.w);

    float radius = input_data.mouse.z;
    float maximum_velocity = input_data.mouse.w;
    vec2 mouse = input_data.mouse.xy;

    // Horizontal faces: (width + 1) by height.
    if (cell.x < width + 1 && cell.y < height) {
        float distance_to_mouse = distance(vec2(cell), mouse);
        float falloff = max(0.0, 1.0 - distance_to_mouse / radius);
        int index = cell.y * (width + 1) + cell.x;
        horizontal[index] = clamp(
            horizontal[index] + input_data.impulse.x * falloff,
            -maximum_velocity, maximum_velocity
        );
    }

    // Vertical faces: width by (height + 1).
    if (cell.x < width && cell.y < height + 1) {
        float distance_to_mouse = distance(vec2(cell), mouse);
        float falloff = max(0.0, 1.0 - distance_to_mouse / radius);
        int index = cell.y * width + cell.x;
        vertical[index] = clamp(
            vertical[index] + input_data.impulse.y * falloff,
            -maximum_velocity, maximum_velocity
        );
    }
}
