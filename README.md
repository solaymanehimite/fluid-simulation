<div align="center">
  
  # Interactive 2D fluid simulation.

  [![Godot 4.6](https://img.shields.io/badge/Godot-4.6-478cbf?style=flat-square&logo=godot-engine&logoColor=white)](https://godotengine.org/)
</div>

A small, real-time playground for experimenting with incompressible 2d fluid flow. built with godot 4.6 

## Getting started

### Requirements

- [Godot 4.6](https://godotengine.org/download/)
- A desktop renderer with compute shader support

> [!NOTE]
> The project uses Godot's Forward+ renderer and GPU compute pipelines. If the simulation does not start, check that your graphics driver supports the required renderer.

### Run locally

1. Clone the repository.
2. Open the project folder in Godot.
3. Press **F6** or **F5** to run the simulation.

The main scene is `simulation.tscn`.

## How it works

The simulation approximates the incompressible Navier-Stokes equations on a `160 × 160` grid:

$$
\rho \left( \frac{\partial \mathbf{u}}{\partial t} + (\mathbf{u} \cdot \nabla) \mathbf{u} \right) = -\nabla p + \mu \nabla^2 \mathbf{u} + \mathbf{f}$$

$$
\nabla \cdot \mathbf{u} = 0
$$

The first equation describes how the fluid velocity changes over time. It combines advection, where the fluid carries itself along, pressure, viscosity, and external forces. The second equation requires the fluid to remain incompressible, so the velocity field has no net expansion or compression.

In the project, `u` is the velocity field, `p` is pressure, `rho` is density, `nu` is viscosity, and `f` includes mouse input and test inflow. Compute shaders advect the velocity, apply boundary conditions, calculate divergence, solve the pressure field with Jacobi iterations, and project the velocity to reduce divergence. Dye is carried by the velocity field as a visual tracer, then a canvas shader renders the result and its debug overlays.

Most solver settings can be changed on the root `Control` node in the Inspector.

## Built with

- [Godot Engine](https://godotengine.org/)
- GDScript
- GLSL compute shaders
