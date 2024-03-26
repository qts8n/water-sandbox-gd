shader_type spatial;

uniform vec3 color;

void fragment() {
	ALBEDO = color;
}
