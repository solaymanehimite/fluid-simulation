<div align="center">
  <img src="icon.svg" alt="Navier-Stokes Equations icon" width="96" />

  # Navier-Stokes equations

  **An interactive 2D fluid simulation built with Godot compute shaders.**

  [![Godot 4.6](https://img.shields.io/badge/Godot-4.6-478cbf?style=flat-square&logo=godot-engine&logoColor=white)](https://godotengine.org/)
  [![GDScript](https://img.shields.io/badge/GDScript-2.0-478cbf?style=flat-square&logo=godot-engine&logoColor=white)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html)

  [Run it](#getting-started) · [Controls](#controls) · [How it works](#how-it-works)
</div>

A small, real-time playground for experimenting with incompressible fluid flow. Drag through the field to inject velocity and dye, then turn on the visual overlays to inspect what the solver is doing.

## Highlights

- GPU-accelerated simulation through Godot's `RenderingDevice` and GLSL compute shaders
- Velocity advection, boundary handling, divergence, pressure iterations, and projection
- Interactive dye injection with randomized colors and a lightweight bloom effect
- Optional velocity arrows, divergence visualization, and a vortex obstacle test
- Tunable simulation parameters exposed directly in the Godot editor

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

## Controls

| Input | Action |
| --- | --- |
| Left-click and drag | Inject velocity and dye into the fluid |
| Mouse wheel | Change the brush radius |
| `E` | Toggle velocity arrows |
| `D` | Toggle divergence visualization |
| `T` | Toggle the vortex obstacle test |
| Mouse wheel in vortex test mode | Resize the obstacle |

## How it works

The simulation approximates the incompressible Navier-Stokes equations on a `160 × 160` grid:

$$
\frac{\partial \mathbf{u}}{\partial t} + (\mathbf{u} \cdot \nabla)\mathbf{u}
= -\frac{1}{\rho}\nabla p + \nu\nabla^2\mathbf{u} + \mathbf{f}
$$

$$
\nabla \cdot \mathbf{u} = 0
$$

The first equation describes how the fluid velocity changes over time. It combines advection, where the fluid carries itself along, pressure, viscosity, and external forces. The second equation requires the fluid to remain incompressible, so the velocity field has no net expansion or compression.

In the project, `u` is the velocity field, `p` is pressure, `rho` is density, `nu` is viscosity, and `f` includes mouse input and test inflow. Compute shaders advect the velocity, apply boundary conditions, calculate divergence, solve the pressure field with Jacobi iterations, and project the velocity to reduce divergence. Dye is carried by the velocity field as a visual tracer, then a canvas shader renders the result and its debug overlays.

Most solver settings can be changed on the root `Control` node in the Inspector.

## Project layout

```text
simulation.tscn              Main scene and default settings
scripts/simulation.gd        Input, simulation setup, and render-thread dispatch
shaders/compute/              GPU simulation stages
shaders/navier_stokes.gdshader    Final display and debug overlays
icon.svg                     Project icon
```

## Built with

- [Godot Engine](https://godotengine.org/)
- GDScript
- GLSL compute shaders
