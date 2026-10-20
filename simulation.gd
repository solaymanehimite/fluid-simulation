extends Node2D

@onready var buffer_1 = $Buffers/Buffer1
@onready var buffer_2 = $Buffers/Buffer2
@onready var color_rect_1 = $Buffers/Buffer1/ColorRect
@onready var color_rect_2 = $Buffers/Buffer2/ColorRect
@onready var screen = $Display/Screen

var is_buffer_1_active: bool = true
var mouse_speed := Vector2.ZERO

func _ready() -> void:
	buffer_1.render_target_update_mode = SubViewport.UPDATE_DISABLED
	buffer_2.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_speed = event.relative / get_viewport_rect().size * 20.0

func _process(_delta: float) -> void:
	var screen_size = get_viewport_rect().size
	var raw_mouse = get_global_mouse_position()
	
	var mouse_uv = raw_mouse / screen_size
	var clicking = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	var mat: ShaderMaterial = null
	var buffer_to_write: SubViewport = null
	var texture_to_read: Texture = null
	
	# FIXED: Route the alternate buffer textures to avoid feedback loops
	if is_buffer_1_active:
		mat = color_rect_2.material as ShaderMaterial
		buffer_to_write = buffer_2
		texture_to_read = buffer_1.get_texture()
	else:
		mat = color_rect_1.material as ShaderMaterial
		buffer_to_write = buffer_1
		texture_to_read = buffer_2.get_texture()
			
	if mat:
		mat.set_shader_parameter("previous_frame_data", texture_to_read) # FIXED
		mat.set_shader_parameter("mouse_position", mouse_uv)
		mat.set_shader_parameter("mouse_speed", mouse_speed)
		mat.set_shader_parameter("is_clicking", clicking)
	
	buffer_to_write.render_target_update_mode = SubViewport.UPDATE_ONCE
	screen.texture = buffer_to_write.get_texture()
		
	is_buffer_1_active = !is_buffer_1_active
	
	# FIXED: Slowly decay the mouse speed so it doesn't get stuck when the cursor stops
	mouse_speed = mouse_speed.move_toward(Vector2.ZERO, _delta * 15.0)
