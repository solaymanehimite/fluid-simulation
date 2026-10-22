extends Control

@export_group("Simulation Settings")
@export var width := 10
@export var height := 10

var horizontal: PackedFloat32Array = [];
var vertical: PackedFloat32Array = [];
var pressure: PackedFloat32Array = [];
var divergence: PackedFloat32Array = []

# Rendering Device IDs
var rd: RenderingDevice
var shader_rid: RID
var pipeline_rid: RID

# Buffer IDs
var horizontal_buffer: RID
var vertical_buffer: RID
var divergence_buffer: RID
var uniform_set_rid: RID
var divergence_texture: ImageTexture

func _ready() -> void:
	horizontal.resize((width + 1) * height)
	vertical.resize((height + 1) * width)
	divergence.resize(width * height)
	pressure.resize(width * height)
	
	horizontal.fill(0.)
	divergence.fill(0.)
	vertical.fill(0.)
	pressure.fill(0.)
	
	var cx = width / 2
	var cy = height / 2
	horizontal[cy * (width + 1) + cx] = -10.0      # Left edge pushing in
	horizontal[cy * (width + 1) + (cx + 1)] = 10.0  # Right edge pushing out
	vertical[cy * width + cx] = -10.0               # Bottom edge pushing in
	vertical[(cy + 1) * width + cx] = 10.0           # Top edge pushing out
	
	rd = RenderingServer.create_local_rendering_device()
	if not rd:
		print("Compute shaders are not supported on this renderer mode.")
		return

	var shader_file := load("res://shaders/compute/divergence.glsl") # Make sure this matches your file name!
	shader_rid = rd.shader_create_from_spirv(shader_file.get_spirv())
	pipeline_rid = rd.compute_pipeline_create(shader_rid)

	horizontal_buffer = rd.storage_buffer_create(horizontal.to_byte_array().size(), horizontal.to_byte_array())
	vertical_buffer = rd.storage_buffer_create(vertical.to_byte_array().size(), vertical.to_byte_array())
	divergence_buffer = rd.storage_buffer_create(divergence.to_byte_array().size(), divergence.to_byte_array())

	var u_horiz := RDUniform.new()
	u_horiz.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_horiz.binding = 0
	u_horiz.add_id(horizontal_buffer)

	var u_vert := RDUniform.new()
	u_vert.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_vert.binding = 1
	u_vert.add_id(vertical_buffer)

	var u_div := RDUniform.new()
	u_div.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_div.binding = 2
	u_div.add_id(divergence_buffer)

	uniform_set_rid = rd.uniform_set_create([u_horiz, u_vert, u_div], shader_rid, 0)

	# The canvas shader samples this texture to display the compute result.
	var initial_image := Image.create_from_data(
		width, height, false, Image.FORMAT_RF, divergence.to_byte_array()
	)
	divergence_texture = ImageTexture.create_from_image(initial_image)
	var screen_material := $PanelContainer/Screen.material as ShaderMaterial
	screen_material.set_shader_parameter("divergence_texture", divergence_texture)

func _process(_delta: float) -> void:
	if not rd: return

	# The push-constant block is 16 bytes on Vulkan. The last two values are padding.
	var push_constants := PackedInt32Array([width, height, 0, 0])
	var push_constants_bytes := push_constants.to_byte_array()
	
	# Calculate workgroups based on shader's local_size (8x8)
	var x_groups := int(ceil(width / 8.0))
	var y_groups := int(ceil(height / 8.0))

	# 2. Begin your GPU command stream
	var compute_list := rd.compute_list_begin()
	
	# Bind Pipeline
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_rid)
	
	# Bind Uniform Sets (Binding 0, 1, 2 buffers)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_rid, 0)
	
	# MUST GO HERE: Provide the push constants before dispatching!
	rd.compute_list_set_push_constant(
		compute_list, 
		push_constants_bytes, 
		push_constants_bytes.size()
	)
	
	# 3. Trigger execution grid
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()
	
	# 4. Process calculations
	rd.submit()
	rd.sync()

	# 5. Fetch diagnostic read back
	var output_bytes := rd.buffer_get_data(divergence_buffer)
	divergence = output_bytes.to_float32_array()

	# Upload the GPU result to a texture consumed by the fragment shader.
	var divergence_image := Image.create_from_data(
		width, height, false, Image.FORMAT_RF, output_bytes
	)
	divergence_texture.update(divergence_image)
	
	var center_idx = (height / 2) * width + (width / 2)
	print("Center Cell Net Divergence: ", divergence[center_idx])

	
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and rd:
		rd.free_rid(pipeline_rid)
		rd.free_rid(uniform_set_rid)
		rd.free_rid(horizontal_buffer)
		rd.free_rid(vertical_buffer)
		rd.free_rid(divergence_buffer)
		rd.free_rid(shader_rid)
		rd.free()
