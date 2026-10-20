shader_type canvas_item;

uniform sampler2D previous_frame_data;
uniform vec2 mouse_position;
uniform vec2 mouse_speed;
uniform bool is_clicking;

void fragment() {
    // 1. Read history data
    vec4 old_data = texture(previous_frame_data, UV);
    
    // Setup clean historical physics slots
    float density = old_data.r;
    vec2 velocity = old_data.gb;
    
    // 2. Apply gentle dissipation over time
    density *= 0.80; 
    velocity *= 0.80;

    // 3. Draw trail when clicking
    if (is_clicking) {
        float dist = distance(UV, mouse_position);
        float brush_radius = 0.03; 
        
        if (dist < brush_radius) {
            float falloff = 1.0 - (dist / brush_radius);
            
            // Add density consistently regardless of direction
            density += falloff * 0.4;
            
            // Store the cursor velocity inside the velocity field channels
            velocity += mouse_speed * falloff * 0.5;
        }
    }
    
    // FIXED: Clamp calculations to prevent infinite values or negative color bounds
    density = clamp(density, 0.0, 1.0);
    velocity = clamp(velocity, vec2(-1.0), vec2(1.0));
    
    // 4. Output the correct layout mapping (Red = Smoke, Green/Blue = XY Motion)
    COLOR = vec4(density, velocity.x, velocity.y, 1.0);
}
