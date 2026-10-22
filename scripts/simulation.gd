extends Control

@export_group("Simulation Settings")
@export var width := 10
@export var height := 10

var horizontal: PackedFloat32Array = []
var vertical: PackedFloat32Array = []

var divergence_texture: Texture2DRD

# These variables are only accessed on Godot's render thread after initialization.
var rd: RenderingDevice
var shader_rid: RID
var pipeline_rid: RID
var horizontal_buffer: RID
var vertical_buffer: RID
var divergence_texture_rid: RID
var uniform_set_rid: RID

func _ready() -> void:
	var screen_material := $PanelContainer/Screen.material as ShaderMaterial
	divergence_texture = screen_material.get_shader_parameter(&"divergence_texture") as Texture2DRD

	# RenderingDevice resources must be created on the render thread because they
	# are shared directly with the canvas renderer.
	RenderingServer.call_on_render_thread(_initialize_compute_code)

func _process(_delta: float) -> void:
	# Queue the compute work before Godot renders the canvas for this frame.
	RenderingServer.call_on_render_thread(_render_process)

func _initialize_compute_code() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		push_error("Compute shaders are not supported on this renderer mode.")
		return

	var shader_file := load("res://shaders/compute/divergence.glsl") as RDShaderFile
	shader_rid = rd.shader_create_from_spirv(shader_file.get_spirv())
	pipeline_rid = rd.compute_pipeline_create(shader_rid)

	var horizontal_data := _create_horizontal_data()
	var vertical_data := _create_vertical_data()
	horizontal_buffer = rd.storage_buffer_create(horizontal_data.size(), horizontal_data)
	vertical_buffer = rd.storage_buffer_create(vertical_data.size(), vertical_data)

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
	divergence_texture_rid = rd.texture_create(texture_format, RDTextureView.new(), [])
	rd.texture_clear(divergence_texture_rid, Color(0, 0, 0, 1), 0, 1, 0, 1)

	var u_horiz := RDUniform.new()
	u_horiz.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_horiz.binding = 0
	u_horiz.add_id(horizontal_buffer)

	var u_vert := RDUniform.new()
	u_vert.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_vert.binding = 1
	u_vert.add_id(vertical_buffer)

	var u_div := RDUniform.new()
	u_div.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u_div.binding = 2
	u_div.add_id(divergence_texture_rid)

	uniform_set_rid = rd.uniform_set_create([u_horiz, u_vert, u_div], shader_rid, 0)
	divergence_texture.texture_rd_rid = divergence_texture_rid

func _render_process() -> void:
	if not rd or not pipeline_rid.is_valid() or not uniform_set_rid.is_valid():
		return

	var push_constants := PackedInt32Array([width, height, 0, 0])
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_rid)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_rid, 0)
	rd.compute_list_set_push_constant(
		compute_list, push_constants.to_byte_array(), 16
	)

	var x_groups := (width - 1) / 8 + 1
	var y_groups := (height - 1) / 8 + 1
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()
	# Do not call submit() or sync() here. The main renderer submits this work
	# and inserts the required barrier before sampling the texture.

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

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and rd:
		RenderingServer.call_on_render_thread(_free_compute_resources)

func _free_compute_resources() -> void:
	if divergence_texture:
		divergence_texture.texture_rd_rid = RID()
	if uniform_set_rid.is_valid():
		rd.free_rid(uniform_set_rid)
	if horizontal_buffer.is_valid():
		rd.free_rid(horizontal_buffer)
	if vertical_buffer.is_valid():
		rd.free_rid(vertical_buffer)
	if divergence_texture_rid.is_valid():
		rd.free_rid(divergence_texture_rid)
	if pipeline_rid.is_valid():
		rd.free_rid(pipeline_rid)
	if shader_rid.is_valid():
		rd.free_rid(shader_rid)
