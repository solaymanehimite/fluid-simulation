shader_type canvas_item;

uniform sampler2D previous_frame_data;
uniform vec2 mouse_position;
uniform bool is_clicking;

void fragment() {
    vec4 old_data = texture(previous_frame_data, UV);
    float density = old_data.r;
    
    density -= 0.01;
    
    if (is_clicking) {
        float dist = distance(UV, mouse_position);
        float brush_radius = 0.03; // Adjust this to change cursor size
        
        if (dist < brush_radius) {
            float falloff = 1.0 - (dist / brush_radius);
            density += falloff * 0.3;
        }
    }
    
    density = clamp(density, 0.0, 1.0);
    
    COLOR = vec4(density, 0.0, 0.0, 1.0);
}
