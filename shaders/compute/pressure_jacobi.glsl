#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant) uniform Constants {
    int width;
    int height;
    int _padding0;
    int _padding1;
} grid;

// Input divergence calculated by divergence.glsl.
layout(rgba32f, set = 0, binding = 0) uniform readonly image2D divergence_image;

// The previous Jacobi estimate of pressure.
layout(rgba32f, set = 1, binding = 0) uniform readonly image2D pressure_in;

// The next Jacobi estimate of pressure.
layout(rgba32f, set = 2, binding = 0) uniform writeonly image2D pressure_out;

float pressure_at(ivec2 cell) {
    if (cell.x < 0 || cell.y < 0 ||
        cell.x >= grid.width || cell.y >= grid.height) {
        // Zero-pressure boundary condition.
        return 0.0;
    }
    return imageLoad(pressure_in, cell).r;
}

void main() {
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);
    if (cell.x >= grid.width || cell.y >= grid.height) {
        return;
    }

    float left   = pressure_at(cell + ivec2(-1, 0));
    float right  = pressure_at(cell + ivec2( 1, 0));
    float bottom = pressure_at(cell + ivec2(0, -1));
    float top    = pressure_at(cell + ivec2(0,  1));
    float div = imageLoad(divergence_image, cell).r;

    // Solve: Laplacian(pressure) = divergence.
    float pressure = (left + right + bottom + top - div) * 0.25;
    imageStore(pressure_out, cell, vec4(pressure, 0.0, 0.0, 1.0));
}
