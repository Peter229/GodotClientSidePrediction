shader_type spatial;

uniform vec3 player_pos;

void fragment() {
	// Place fragment code here.
	vec3 vertex_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ALBEDO = vertex_pos;
}
