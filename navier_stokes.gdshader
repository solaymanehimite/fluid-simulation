shader_type canvas_item;

void fragment() {
	COLOR = vec4(UV.r, UV.g, sqrt(pow(UV.r, 2.) + pow(UV.g, 2.)), 1.);
}
