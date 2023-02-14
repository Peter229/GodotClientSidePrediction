extends Node3D

var water_height = 0.0;
const gravity = 29.1;
const water_density = 9.0;

const jet_acceleration = 59.0;

var jet_velocity = Vector3(0.0, 0.0, 0.0);
var buoyancy = 0.0;

var direction = Vector3(1.0, 0.0, 0.0);

var time_start = 0;
var time_now = 0;

#
# ADD LEANING
# ADD PLANE :)
# ADD THIRD PERSON
#

func _ready():
	time_start = Time.get_ticks_msec();

func _process(delta):
	pass
	
func _physics_process(delta):
	time_now = Time.get_ticks_msec() - time_start;
	time_now /= 1000.0;

	water_height = sea_function(global_transform.origin);
	
	buoyancy = max(water_height - global_transform.origin.y, 0.0) * water_density * gravity;
	
	jet_velocity.y -= gravity * delta;
	jet_velocity.y += buoyancy * delta;
	
	if Input.is_action_pressed("move_forward"):
		jet_velocity.x += jet_acceleration * delta;
	
	if Input.is_action_pressed("move_backward"):
		jet_velocity.x -= jet_acceleration * delta;
	
	if Input.is_action_pressed("move_right"):
		jet_velocity.z += jet_acceleration * delta;
	
	if Input.is_action_pressed("move_left"):
		jet_velocity.z -= jet_acceleration * delta;
	
	
	#Handle friction last
	var friction = 1.0;
	if water_height > global_transform.origin.y:
		friction = 5.0;
	
	var opposing_direction = -(jet_velocity / 2.0);
	
	jet_velocity += opposing_direction * friction * delta;
	
	global_transform.origin += jet_velocity * delta;
	
	var jet_velocity_direction = jet_velocity.normalized();
	
	if !jet_velocity.is_zero_approx() && abs(jet_velocity_direction.dot(Vector3.UP)) != 1.0:
		var g = get_sea_normal().cross(-jet_velocity_direction.cross(Vector3.UP));
		var t = global_transform.looking_at(global_transform.origin + jet_velocity_direction, Vector3.UP);
		if water_height + 0.5 > global_transform.origin.y:
			t = global_transform.looking_at(global_transform.origin + g, Vector3.UP);			
		var trotation = t.basis.get_rotation_quaternion();
		global_rotation = trotation.slerp(Quaternion(global_transform.basis), 0.5).get_euler();
		if abs(jet_velocity_direction.x) > 0.4 || abs(jet_velocity_direction.z) > 0.4:
			direction = jet_velocity_direction;
	else:
		var g = get_sea_normal().cross(direction);
		var t = global_transform.looking_at(global_transform.origin + g, Vector3.UP);
		var trotation = t.basis.get_rotation_quaternion();
		global_rotation = trotation.get_euler();#trotation.slerp(Quaternion(global_transform.basis), 0.5).get_euler();

func sea_function(in_position: Vector3) -> float:
	return sin(((in_position.x * 10.0) / 40.0) + time_now) + cos(((in_position.z * 10.0) / 30.0) + time_now) + 1.0;

func get_sea_normal() -> Vector3:
	var tri_pos_0 = global_transform.origin + Vector3(-1.0, 0.0, -1.0);
	var tri_pos_1 = global_transform.origin + Vector3(1.0, 0.0, -1.0);
	var tri_pos_2 = global_transform.origin + Vector3(0.0, 0.0, 1.0);
	
	tri_pos_0.y = sea_function(tri_pos_0);
	tri_pos_1.y = sea_function(tri_pos_1);
	tri_pos_2.y = sea_function(tri_pos_2);
	
	var tri_line_0 = tri_pos_1 - tri_pos_0;
	var tri_line_1 = tri_pos_2 - tri_pos_1;
	
	var normal = tri_line_0.cross(tri_line_1).normalized();
	
	return normal;
