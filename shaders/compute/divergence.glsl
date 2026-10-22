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

layout(set = 0, binding = 2, std430) writeonly buffer DivergenceOut {
    float divergence[];
};

void main() {
    int x = int(gl_GlobalInvocationID.x);
    int y = int(gl_GlobalInvocationID.y);

    if (x >= grid.width || y >= grid.height) {
        return;
    }

    int u_left_idx  = y * (grid.width + 1) + x;
    int u_right_idx = y * (grid.width + 1) + (x + 1);

    int v_bottom_idx = y * grid.width + x;
    int v_top_idx    = (y + 1) * grid.width + x;

    float u_left  = horizontal[u_left_idx];
    float u_right = horizontal[u_right_idx];
    float v_bottom = vertical[v_bottom_idx];
    float v_top    = vertical[v_top_idx];

    float div = (u_right - u_left) + (v_top - v_bottom);

    int cell_center_idx = y * grid.width + x;
    divergence[cell_center_idx] = div;
}

