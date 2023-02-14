shader_type spatial;

render_mode cull_front;
render_mode unshaded;

void vertex() {
	VERTEX = VERTEX + NORMAL * 0.2;
}

void fragment() {
	ALBEDO = vec3(0.0, 0.0, 0.0);
}
