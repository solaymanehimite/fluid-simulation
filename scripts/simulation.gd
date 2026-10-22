extends Control

@export_group("Simulation Settings")
@export var width := 16
@export var height := 16
@export_range(1, 200) var pressure_iterations := 100
@export_range(0.5, 10.0, 0.5) var mouse_brush_radius := 2.0
@export_range(0.1, 100.0, 0.5) var mouse_max_velocity := 10.0
@export_range(0.0, 2.0, 0.01) var advection_time_scale := 1.0
@export var enable_pressure_projection := false
@export_range(0.0, 1.0, 0.05) var boundary_restitution := 1.0
@export_range(0.0, 10.0, 0.1) var dye_dissipation := 0.5

var divergence_texture: Texture2DRD
var velocity_texture: Texture2DRD
var dye_texture: Texture2DRD
var screen_material: ShaderMaterial
var arrows_enabled := true
var divergence_enabled := true
var dye_is_a_current := true
var mouse_grid_position := Vector2.ZERO
var mouse_uv := Vector2(0.5, 0.5)
var brush_visible := false
var mouse_impulse := Vector2.ZERO
var mouse_direction := Vector2.ZERO
var mouse_is_down := false

# These resources are accessed on Godot's render thread after initialization.
var rd: RenderingDevice
var injection_shader_rid: RID
var injection_pipeline_rid: RID
var velocity_visualize_shader_rid: RID
var velocity_visualize_pipeline_rid: RID
var divergence_shader_rid: RID
var divergence_pipeline_rid: RID
var pressure_shader_rid: RID
var pressure_pipeline_rid: RID
var projection_shader_rid: RID
var projection_pipeline_rid: RID
var dye_advect_shader_rid: RID
var dye_advect_pipeline_rid: RID
var dye_inject_shader_rid: RID
var dye_inject_pipeline_rid: RID
var boundary_shader_rid: RID
var boundary_pipeline_rid: RID
var advect_shader_rid: RID
var advect_pipeline_rid: RID
var copy_shader_rid: RID
var copy_pipeline_rid: RID
var horizontal_buffer: RID
var vertical_buffer: RID
var horizontal_scratch_buffer: RID
var vertical_scratch_buffer: RID
var advect_input_set_rid: RID
var advect_output_set_rid: RID
var copy_input_set_rid: RID
var copy_output_set_rid: RID
var injection_uniform_set_rid: RID
var velocity_visualize_uniform_set_rid: RID
var divergence_texture_rid: RID
var velocity_texture_rid: RID
var pressure_texture_a_rid: RID
var pressure_texture_b_rid: RID
var divergence_uniform_set_rid: RID
var pressure_divergence_set_rid: RID
var pressure_a_to_b_input_set_rid: RID
var pressure_a_to_b_output_set_rid: RID
var pressure_b_to_a_input_set_rid: RID
var pressure_b_to_a_output_set_rid: RID
var projection_a_pressure_set_rid: RID
var projection_b_pressure_set_rid: RID
var dye_texture_a_rid: RID
var dye_texture_b_rid: RID
var dye_velocity_set_rid: RID
var dye_a_to_b_input_set_rid: RID
var dye_a_to_b_output_set_rid: RID
var dye_b_to_a_input_set_rid: RID
var dye_b_to_a_output_set_rid: RID
var dye_inject_a_set_rid: RID
var dye_inject_b_set_rid: RID
var boundary_uniform_set_rid: RID

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	screen_material = $PanelContainer/Screen.material as ShaderMaterial
	divergence_texture = screen_material.get_shader_parameter(&"divergence_texture") as Texture2DRD
	velocity_texture = screen_material.get_shader_parameter(&"velocity_texture") as Texture2DRD
	dye_texture = screen_material.get_shader_parameter(&"dye_texture") as Texture2DRD
	# Keep the procedural arrow grid aligned with the simulation dimensions.
	screen_material.set_shader_parameter(&"grid_size", Vector2(width, height))
	screen_material.set_shader_parameter(&"show_arrows", arrows_enabled)
	screen_material.set_shader_parameter(&"show_divergence", divergence_enabled)
	_update_brush_visual()

	# These resources are shared with the canvas renderer, so create them on
	# the render thread and use the main RenderingDevice.
	RenderingServer.call_on_render_thread(_initialize_compute_code)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			arrows_enabled = not arrows_enabled
			if screen_material:
				screen_material.set_shader_parameter(&"show_arrows", arrows_enabled)
			return
		if event.keycode == KEY_D:
			divergence_enabled = not divergence_enabled
			if screen_material:
				screen_material.set_shader_parameter(&"show_divergence", divergence_enabled)
			return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			mouse_brush_radius = min(mouse_brush_radius + 0.5, 10.0)
			_update_brush_visual()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			mouse_brush_radius = max(mouse_brush_radius - 0.5, 0.5)
			_update_brush_visual()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_is_down = event.pressed
			mouse_uv = _screen_to_uv(event.position)
			brush_visible = true
			if event.pressed:
				mouse_grid_position = _screen_to_grid(event.position)
				mouse_impulse = Vector2.ZERO
				mouse_direction = Vector2.ZERO
			else:
				mouse_direction = Vector2.ZERO
	elif event is InputEventMouseMotion:
		mouse_uv = _screen_to_uv(event.position)
		brush_visible = true
		if mouse_is_down:
			mouse_grid_position = _screen_to_grid(event.position)
			var screen_size := ($PanelContainer/Screen as Control).size
			var drag_in_grid: Vector2 = event.relative / screen_size * Vector2(width, height)
			if drag_in_grid.length_squared() > 0.000001:
				mouse_direction = drag_in_grid.normalized()
				mouse_impulse = mouse_direction * mouse_max_velocity
	_update_brush_visual()

func _screen_to_grid(screen_position: Vector2) -> Vector2:
	return _screen_to_uv(screen_position) * Vector2(width, height)

func _screen_to_uv(screen_position: Vector2) -> Vector2:
	var screen := $PanelContainer/Screen as Control
	var local_position := screen.get_global_transform().affine_inverse() * screen_position
	return Vector2(
		clamp(local_position.x / screen.size.x, 0.0, 1.0),
		clamp(local_position.y / screen.size.y, 0.0, 1.0)
	)

func _update_brush_visual() -> void:
	if not screen_material:
		return
	screen_material.set_shader_parameter(&"brush_position", mouse_uv)
	screen_material.set_shader_parameter(&"brush_radius", mouse_brush_radius)
	screen_material.set_shader_parameter(&"show_brush", brush_visible)

func _process(delta: float) -> void:
	var position := mouse_grid_position
	# Keep applying the last drag direction while the button is held. This
	# makes the cursor act like a continuous force instead of a one-frame kick.
	var impulse := mouse_impulse
	if mouse_is_down and mouse_direction.length_squared() > 0.000001:
		impulse = mouse_direction * mouse_max_velocity
	var active := mouse_is_down
	mouse_impulse = Vector2.ZERO
	RenderingServer.call_on_render_thread(
		_render_process.bind(position, impulse, active, delta * advection_time_scale)
	)

func _initialize_compute_code() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		push_error("Compute shaders are not supported on this renderer mode.")
		return

	var dye_advect_file := load("res://shaders/compute/advect_dye.glsl") as RDShaderFile
	dye_advect_shader_rid = rd.shader_create_from_spirv(dye_advect_file.get_spirv())
	dye_advect_pipeline_rid = rd.compute_pipeline_create(dye_advect_shader_rid)

	var dye_inject_file := load("res://shaders/compute/inject_dye.glsl") as RDShaderFile
	dye_inject_shader_rid = rd.shader_create_from_spirv(dye_inject_file.get_spirv())
	dye_inject_pipeline_rid = rd.compute_pipeline_create(dye_inject_shader_rid)

	var boundary_file := load("res://shaders/compute/boundary_velocity.glsl") as RDShaderFile
	boundary_shader_rid = rd.shader_create_from_spirv(boundary_file.get_spirv())
	boundary_pipeline_rid = rd.compute_pipeline_create(boundary_shader_rid)

	var advect_file := load("res://shaders/compute/advect_velocity.glsl") as RDShaderFile
	advect_shader_rid = rd.shader_create_from_spirv(advect_file.get_spirv())
	advect_pipeline_rid = rd.compute_pipeline_create(advect_shader_rid)

	var copy_file := load("res://shaders/compute/copy_velocity.glsl") as RDShaderFile
	copy_shader_rid = rd.shader_create_from_spirv(copy_file.get_spirv())
	copy_pipeline_rid = rd.compute_pipeline_create(copy_shader_rid)

	var injection_file := load("res://shaders/compute/inject_velocity.glsl") as RDShaderFile
	injection_shader_rid = rd.shader_create_from_spirv(injection_file.get_spirv())
	injection_pipeline_rid = rd.compute_pipeline_create(injection_shader_rid)

	var velocity_visualize_file := load("res://shaders/compute/velocity_visualize.glsl") as RDShaderFile
	velocity_visualize_shader_rid = rd.shader_create_from_spirv(velocity_visualize_file.get_spirv())
	velocity_visualize_pipeline_rid = rd.compute_pipeline_create(velocity_visualize_shader_rid)

	var divergence_file := load("res://shaders/compute/divergence.glsl") as RDShaderFile
	divergence_shader_rid = rd.shader_create_from_spirv(divergence_file.get_spirv())
	divergence_pipeline_rid = rd.compute_pipeline_create(divergence_shader_rid)

	var pressure_file := load("res://shaders/compute/pressure_jacobi.glsl") as RDShaderFile
	pressure_shader_rid = rd.shader_create_from_spirv(pressure_file.get_spirv())
	pressure_pipeline_rid = rd.compute_pipeline_create(pressure_shader_rid)

	var projection_file := load("res://shaders/compute/project_velocity.glsl") as RDShaderFile
	projection_shader_rid = rd.shader_create_from_spirv(projection_file.get_spirv())
	projection_pipeline_rid = rd.compute_pipeline_create(projection_shader_rid)

	var horizontal_data := _create_horizontal_data()
	var vertical_data := _create_vertical_data()
	horizontal_buffer = rd.storage_buffer_create(horizontal_data.size(), horizontal_data)
	vertical_buffer = rd.storage_buffer_create(vertical_data.size(), vertical_data)
	horizontal_scratch_buffer = rd.storage_buffer_create(horizontal_data.size())
	vertical_scratch_buffer = rd.storage_buffer_create(vertical_data.size())

	advect_input_set_rid = _create_velocity_set(advect_shader_rid, 0, horizontal_buffer, vertical_buffer)
	advect_output_set_rid = _create_velocity_set(advect_shader_rid, 1, horizontal_scratch_buffer, vertical_scratch_buffer)
	copy_input_set_rid = _create_velocity_set(copy_shader_rid, 0, horizontal_scratch_buffer, vertical_scratch_buffer)
	copy_output_set_rid = _create_velocity_set(copy_shader_rid, 1, horizontal_buffer, vertical_buffer)

	var texture_format := RDTextureFormat.new()
	texture_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	texture_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	texture_format.width = width
	texture_format.height = height
	texture_format.depth = 1
	texture_format.array_layers = 1
	texture_format.mipmaps = 1
	texture_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	)

	divergence_texture_rid = _create_cleared_texture(texture_format)
	velocity_texture_rid = _create_cleared_texture(texture_format)
	pressure_texture_a_rid = _create_cleared_texture(texture_format)
	pressure_texture_b_rid = _create_cleared_texture(texture_format)
	dye_texture_a_rid = _create_cleared_texture(texture_format, Color(0, 0, 0, 0))
	dye_texture_b_rid = _create_cleared_texture(texture_format, Color(0, 0, 0, 0))
	dye_is_a_current = true

	var injection_horiz := RDUniform.new()
	injection_horiz.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	injection_horiz.binding = 0
	injection_horiz.add_id(horizontal_buffer)

	var injection_vert := RDUniform.new()
	injection_vert.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	injection_vert.binding = 1
	injection_vert.add_id(vertical_buffer)
	injection_uniform_set_rid = rd.uniform_set_create(
		[injection_horiz, injection_vert], injection_shader_rid, 0
	)

	var visual_horiz := RDUniform.new()
	visual_horiz.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	visual_horiz.binding = 0
	visual_horiz.add_id(horizontal_buffer)

	var visual_vert := RDUniform.new()
	visual_vert.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	visual_vert.binding = 1
	visual_vert.add_id(vertical_buffer)

	var visual_velocity := RDUniform.new()
	visual_velocity.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	visual_velocity.binding = 2
	visual_velocity.add_id(velocity_texture_rid)
	velocity_visualize_uniform_set_rid = rd.uniform_set_create(
		[visual_horiz, visual_vert, visual_velocity], velocity_visualize_shader_rid, 0
	)

	var u_horiz := RDUniform.new()
	u_horiz.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_horiz.binding = 0
	u_horiz.add_id(horizontal_buffer)

	var u_vert := RDUniform.new()
	u_vert.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_vert.binding = 1
	u_vert.add_id(vertical_buffer)

	var u_divergence := RDUniform.new()
	u_divergence.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u_divergence.binding = 2
	u_divergence.add_id(divergence_texture_rid)
	divergence_uniform_set_rid = rd.uniform_set_create(
		[u_horiz, u_vert, u_divergence], divergence_shader_rid, 0
	)

	var p_divergence := RDUniform.new()
	p_divergence.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	p_divergence.binding = 0
	p_divergence.add_id(divergence_texture_rid)
	pressure_divergence_set_rid = rd.uniform_set_create(
		[p_divergence], pressure_shader_rid, 0
	)

	var a_to_b_sets := _create_pressure_sets(pressure_texture_a_rid, pressure_texture_b_rid)
	pressure_a_to_b_input_set_rid = a_to_b_sets[0]
	pressure_a_to_b_output_set_rid = a_to_b_sets[1]
	var b_to_a_sets := _create_pressure_sets(pressure_texture_b_rid, pressure_texture_a_rid)
	pressure_b_to_a_input_set_rid = b_to_a_sets[0]
	pressure_b_to_a_output_set_rid = b_to_a_sets[1]

	dye_velocity_set_rid = _create_velocity_set(dye_advect_shader_rid, 2, horizontal_buffer, vertical_buffer)
	dye_a_to_b_input_set_rid = _create_image_set(dye_advect_shader_rid, 0, dye_texture_a_rid)
	dye_a_to_b_output_set_rid = _create_image_set(dye_advect_shader_rid, 1, dye_texture_b_rid)
	dye_b_to_a_input_set_rid = _create_image_set(dye_advect_shader_rid, 0, dye_texture_b_rid)
	dye_b_to_a_output_set_rid = _create_image_set(dye_advect_shader_rid, 1, dye_texture_a_rid)
	dye_inject_a_set_rid = _create_image_set(dye_inject_shader_rid, 0, dye_texture_a_rid)
	dye_inject_b_set_rid = _create_image_set(dye_inject_shader_rid, 0, dye_texture_b_rid)
	boundary_uniform_set_rid = _create_velocity_set(
		boundary_shader_rid, 0, horizontal_buffer, vertical_buffer
	)

	projection_a_pressure_set_rid = _create_projection_set(pressure_texture_a_rid)
	projection_b_pressure_set_rid = _create_projection_set(pressure_texture_b_rid)

	# Both textures are displayed by the fragment shader.
	divergence_texture.texture_rd_rid = divergence_texture_rid
	velocity_texture.texture_rd_rid = velocity_texture_rid
	dye_texture.texture_rd_rid = dye_texture_a_rid

func _create_velocity_set(shader_rid: RID, set_index: int, horizontal_rid: RID, vertical_rid: RID) -> RID:
	var horizontal := RDUniform.new()
	horizontal.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	horizontal.binding = 0
	horizontal.add_id(horizontal_rid)

	var vertical := RDUniform.new()
	vertical.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	vertical.binding = 1
	vertical.add_id(vertical_rid)

	return rd.uniform_set_create([horizontal, vertical], shader_rid, set_index)

func _create_image_set(shader_rid: RID, set_index: int, texture_rid: RID) -> RID:
	var image := RDUniform.new()
	image.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	image.binding = 0
	image.add_id(texture_rid)
	return rd.uniform_set_create([image], shader_rid, set_index)

func _create_cleared_texture(texture_format: RDTextureFormat, clear_color := Color(0, 0, 0, 1)) -> RID:
	var texture_rid := rd.texture_create(texture_format, RDTextureView.new(), [])
	rd.texture_clear(texture_rid, clear_color, 0, 1, 0, 1)
	return texture_rid

func _create_pressure_sets(input_rid: RID, output_rid: RID) -> Array[RID]:
	var input := RDUniform.new()
	input.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	input.binding = 0
	input.add_id(input_rid)

	var output := RDUniform.new()
	output.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output.binding = 0
	output.add_id(output_rid)

	var input_set_rid := rd.uniform_set_create([input], pressure_shader_rid, 1)
	var output_set_rid := rd.uniform_set_create([output], pressure_shader_rid, 2)
	return [input_set_rid, output_set_rid]

func _create_projection_set(pressure_rid: RID) -> RID:
	var pressure := RDUniform.new()
	pressure.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	pressure.binding = 0
	pressure.add_id(pressure_rid)

	var horizontal := RDUniform.new()
	horizontal.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	horizontal.binding = 1
	horizontal.add_id(horizontal_buffer)

	var vertical := RDUniform.new()
	vertical.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	vertical.binding = 2
	vertical.add_id(vertical_buffer)

	return rd.uniform_set_create(
		[pressure, horizontal, vertical], projection_shader_rid, 0
	)

func _render_process(position: Vector2, impulse: Vector2, active: bool, delta: float) -> void:
	if not rd or not divergence_pipeline_rid.is_valid():
		return

	var push_constants := PackedInt32Array([width, height, 0, 0]).to_byte_array()
	var boundary_constants := PackedInt32Array([width, height]).to_byte_array()
	boundary_constants.append_array(
		PackedFloat32Array([boundary_restitution, 0.0]).to_byte_array()
	)
	var x_groups := (width - 1) / 8 + 1
	var y_groups := (height - 1) / 8 + 1
	var compute_list := rd.compute_list_begin()

	# Pass 1: semi-Lagrangian advection. Read the old velocity field and write
	# the backtraced result into scratch buffers.
	var advection_constants := PackedInt32Array([width, height]).to_byte_array()
	advection_constants.append_array(
		PackedFloat32Array([delta, 0.0]).to_byte_array()
	)
	rd.compute_list_bind_compute_pipeline(compute_list, advect_pipeline_rid)
	rd.compute_list_bind_uniform_set(compute_list, advect_input_set_rid, 0)
	rd.compute_list_bind_uniform_set(compute_list, advect_output_set_rid, 1)
	rd.compute_list_set_push_constant(
		compute_list, advection_constants, 16
	)
	var advection_x_groups := width / 8 + 1
	var advection_y_groups := height / 8 + 1
	rd.compute_list_dispatch(compute_list, advection_x_groups, advection_y_groups, 1)
	rd.compute_list_add_barrier(compute_list)

	# Copy the advected scratch buffers back into the buffers used by the rest
	# of the pipeline.
	rd.compute_list_bind_compute_pipeline(compute_list, copy_pipeline_rid)
	rd.compute_list_bind_uniform_set(compute_list, copy_input_set_rid, 0)
	rd.compute_list_bind_uniform_set(compute_list, copy_output_set_rid, 1)
	rd.compute_list_set_push_constant(compute_list, push_constants, 16)
	rd.compute_list_dispatch(compute_list, advection_x_groups, advection_y_groups, 1)
	rd.compute_list_add_barrier(compute_list)

	# Pass 2: inject the held mouse direction into the velocity buffers.
	var injection_x_groups := width / 8 + 1
	var injection_y_groups := height / 8 + 1
	if active and impulse.length_squared() > 0.000001 and injection_pipeline_rid.is_valid():
		var mouse_constants := PackedFloat32Array([
			position.x, position.y, mouse_brush_radius, mouse_max_velocity,
			impulse.x, impulse.y, float(width), float(height)
		])
		rd.compute_list_bind_compute_pipeline(compute_list, injection_pipeline_rid)
		rd.compute_list_bind_uniform_set(compute_list, injection_uniform_set_rid, 0)
		rd.compute_list_set_push_constant(
			compute_list, mouse_constants.to_byte_array(), mouse_constants.size() * 4
		)
		rd.compute_list_dispatch(compute_list, injection_x_groups, injection_y_groups, 1)
		rd.compute_list_add_barrier(compute_list)

	# Reflect velocities at the grid boundaries.
	rd.compute_list_bind_compute_pipeline(compute_list, boundary_pipeline_rid)
	rd.compute_list_bind_uniform_set(compute_list, boundary_uniform_set_rid, 0)
	rd.compute_list_set_push_constant(compute_list, boundary_constants, 16)
	rd.compute_list_dispatch(compute_list, injection_x_groups, injection_y_groups, 1)
	rd.compute_list_add_barrier(compute_list)

	# Advect dye using the current velocity field, then swap the dye textures.
	var dye_x_groups := (width - 1) / 8 + 1
	var dye_y_groups := (height - 1) / 8 + 1
	var dye_input_set := dye_a_to_b_input_set_rid if dye_is_a_current else dye_b_to_a_input_set_rid
	var dye_output_set := dye_a_to_b_output_set_rid if dye_is_a_current else dye_b_to_a_output_set_rid
	rd.compute_list_bind_compute_pipeline(compute_list, dye_advect_pipeline_rid)
	rd.compute_list_bind_uniform_set(compute_list, dye_input_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, dye_output_set, 1)
	rd.compute_list_bind_uniform_set(compute_list, dye_velocity_set_rid, 2)
	var dye_advection_constants := PackedInt32Array([width, height]).to_byte_array()
	dye_advection_constants.append_array(
		PackedFloat32Array([delta, dye_dissipation]).to_byte_array()
	)
	rd.compute_list_set_push_constant(compute_list, dye_advection_constants, 16)
	rd.compute_list_dispatch(compute_list, dye_x_groups, dye_y_groups, 1)
	rd.compute_list_add_barrier(compute_list)
	dye_is_a_current = not dye_is_a_current
	var current_dye_rid := dye_texture_b_rid if not dye_is_a_current else dye_texture_a_rid
	dye_texture.texture_rd_rid = current_dye_rid

	# Add dye at the mouse position while the mouse is held.
	if active and impulse.length_squared() > 0.000001 and dye_inject_pipeline_rid.is_valid():
		var dye_constants := PackedFloat32Array([
			position.x, position.y, mouse_brush_radius, 1.0,
			1.0, 0.2, 0.03, 0.8
		])
		var dye_inject_set := dye_inject_a_set_rid if dye_is_a_current else dye_inject_b_set_rid
		rd.compute_list_bind_compute_pipeline(compute_list, dye_inject_pipeline_rid)
		rd.compute_list_bind_uniform_set(compute_list, dye_inject_set, 0)
		rd.compute_list_set_push_constant(
			compute_list, dye_constants.to_byte_array(), dye_constants.size() * 4
		)
		rd.compute_list_dispatch(compute_list, dye_x_groups, dye_y_groups, 1)
		rd.compute_list_add_barrier(compute_list)

	# Pass 2: calculate divergence.
	rd.compute_list_bind_compute_pipeline(compute_list, divergence_pipeline_rid)
	rd.compute_list_bind_uniform_set(compute_list, divergence_uniform_set_rid, 0)
	rd.compute_list_set_push_constant(compute_list, push_constants, 16)
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_add_barrier(compute_list)

	if enable_pressure_projection:
		# Pass 4: repeatedly estimate pressure using Jacobi iteration.
		rd.compute_list_bind_compute_pipeline(compute_list, pressure_pipeline_rid)
		rd.compute_list_bind_uniform_set(compute_list, pressure_divergence_set_rid, 0)
		for iteration in pressure_iterations:
			var input_set := pressure_a_to_b_input_set_rid if iteration % 2 == 0 else pressure_b_to_a_input_set_rid
			var output_set := pressure_a_to_b_output_set_rid if iteration % 2 == 0 else pressure_b_to_a_output_set_rid
			rd.compute_list_bind_uniform_set(compute_list, input_set, 1)
			rd.compute_list_bind_uniform_set(compute_list, output_set, 2)
			rd.compute_list_set_push_constant(compute_list, push_constants, 16)
			rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
			if iteration < pressure_iterations - 1:
				rd.compute_list_add_barrier(compute_list)

		# Pass 5: subtract the pressure gradient from the velocities.
		var final_pressure_set := projection_b_pressure_set_rid if pressure_iterations % 2 == 0 else projection_a_pressure_set_rid
		var projection_x_groups := width / 8 + 1
		var projection_y_groups := height / 8 + 1
		rd.compute_list_bind_compute_pipeline(compute_list, projection_pipeline_rid)
		rd.compute_list_bind_uniform_set(compute_list, final_pressure_set, 0)
		rd.compute_list_set_push_constant(compute_list, push_constants, 16)
		rd.compute_list_dispatch(compute_list, projection_x_groups, projection_y_groups, 1)
		rd.compute_list_add_barrier(compute_list)

		# Re-apply reflective boundaries after pressure projection.
		rd.compute_list_bind_compute_pipeline(compute_list, boundary_pipeline_rid)
		rd.compute_list_bind_uniform_set(compute_list, boundary_uniform_set_rid, 0)
		rd.compute_list_set_push_constant(compute_list, boundary_constants, 16)
		rd.compute_list_dispatch(compute_list, injection_x_groups, injection_y_groups, 1)
		rd.compute_list_add_barrier(compute_list)

		# Pass 6: recompute divergence after projection.
		rd.compute_list_bind_compute_pipeline(compute_list, divergence_pipeline_rid)
		rd.compute_list_bind_uniform_set(compute_list, divergence_uniform_set_rid, 0)
		rd.compute_list_set_push_constant(compute_list, push_constants, 16)
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
		rd.compute_list_add_barrier(compute_list)

	# Pass 7: visualize the current velocities.
	rd.compute_list_bind_compute_pipeline(compute_list, velocity_visualize_pipeline_rid)
	rd.compute_list_bind_uniform_set(compute_list, velocity_visualize_uniform_set_rid, 0)
	rd.compute_list_set_push_constant(compute_list, push_constants, 16)
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()

func _create_horizontal_data() -> PackedByteArray:
	var values := PackedFloat32Array()
	values.resize((width + 1) * height)
	values.fill(0.0)
	var cx := width / 2
	var cy := height / 2
	values[cy * (width + 1) + cx] = -10.0
	values[cy * (width + 1) + cx + 1] = 10.0
	return values.to_byte_array()

func _create_vertical_data() -> PackedByteArray:
	var values := PackedFloat32Array()
	values.resize((height + 1) * width)
	values.fill(0.0)
	var cx := width / 2
	var cy := height / 2
	values[cy * width + cx] = -10.0
	values[(cy + 1) * width + cx] = 10.0
	return values.to_byte_array()

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and rd:
		RenderingServer.call_on_render_thread(_free_compute_resources)

func _free_compute_resources() -> void:
	if divergence_texture:
		divergence_texture.texture_rd_rid = RID()
	if velocity_texture:
		velocity_texture.texture_rd_rid = RID()
	if dye_texture:
		dye_texture.texture_rd_rid = RID()
	for resource in [
		advect_input_set_rid, advect_output_set_rid,
		copy_input_set_rid, copy_output_set_rid,
		injection_uniform_set_rid, velocity_visualize_uniform_set_rid,
		divergence_uniform_set_rid, pressure_divergence_set_rid,
		pressure_a_to_b_input_set_rid, pressure_a_to_b_output_set_rid,
		pressure_b_to_a_input_set_rid, pressure_b_to_a_output_set_rid,
		projection_a_pressure_set_rid, projection_b_pressure_set_rid,
		dye_velocity_set_rid, dye_a_to_b_input_set_rid, dye_a_to_b_output_set_rid,
		dye_b_to_a_input_set_rid, dye_b_to_a_output_set_rid,
		dye_inject_a_set_rid, dye_inject_b_set_rid,
		boundary_uniform_set_rid,
		horizontal_buffer, vertical_buffer, horizontal_scratch_buffer, vertical_scratch_buffer,
		divergence_texture_rid, velocity_texture_rid, dye_texture_a_rid, dye_texture_b_rid,
		pressure_texture_a_rid, pressure_texture_b_rid,
		dye_advect_pipeline_rid, dye_inject_pipeline_rid, boundary_pipeline_rid,
		advect_pipeline_rid, copy_pipeline_rid,
		velocity_visualize_pipeline_rid, injection_pipeline_rid, divergence_pipeline_rid,
		pressure_pipeline_rid, projection_pipeline_rid,
		dye_advect_shader_rid, dye_inject_shader_rid, boundary_shader_rid,
		advect_shader_rid, copy_shader_rid,
		velocity_visualize_shader_rid, injection_shader_rid, divergence_shader_rid,
		pressure_shader_rid, projection_shader_rid
	]:
		if resource.is_valid():
			rd.free_rid(resource)
