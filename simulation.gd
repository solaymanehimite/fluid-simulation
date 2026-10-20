extends Node2D

@onready var buffer_1 = $Buffers/Buffer1
@onready var buffer_2 = $Buffers/Buffer2
@onready var color_rect_1 = $Buffers/Buffer1/ColorRect
@onready var color_rect_2 = $Buffers/Buffer2/ColorRect
@onready var screen = $Display/Screen

var is_buffer_1_active: bool = true

func _ready() -> void:
	buffer_1.render_target_update_mode = SubViewport.UPDATE_DISABLED
	buffer_2.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _process(_delta: float) -> void:
	var screen_size = get_viewport_rect().size
	var raw_mouse = get_global_mouse_position()
	
	var mouse_uv = raw_mouse / screen_size
	var clicking = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	if is_buffer_1_active:
		var mat2 = color_rect_2.material as ShaderMaterial
		if mat2:
			mat2.set_shader_parameter("previous_frame_data", buffer_1.get_texture())
			mat2.set_shader_parameter("mouse_position", mouse_uv)
			mat2.set_shader_parameter("is_clicking", clicking)
		
		buffer_2.render_target_update_mode = SubViewport.UPDATE_ONCE
		screen.texture = buffer_2.get_texture()
	else:
		var mat1 = color_rect_1.material as ShaderMaterial
		if mat1:
			mat1.set_shader_parameter("previous_frame_data", buffer_2.get_texture())
			mat1.set_shader_parameter("mouse_position", mouse_uv)
			mat1.set_shader_parameter("is_clicking", clicking)
		
		buffer_1.render_target_update_mode = SubViewport.UPDATE_ONCE
		screen.texture = buffer_1.get_texture()
		
	is_buffer_1_active = !is_buffer_1_active
