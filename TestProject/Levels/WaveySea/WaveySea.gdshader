shader_type spatial;

varying float water_depth;
void vertex() {
	VERTEX.y = VERTEX.y + sin(((VERTEX.x * 10.0) / 40.0) + TIME) + cos(((VERTEX.z * 10.0) / 30.0) + TIME) + 1.0;
	water_depth = VERTEX.y / 4.0;
}

void fragment() {
	ALBEDO.r = water_depth;
}
