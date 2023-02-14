extends Node3D

@onready var front_left = $FrontLeft;
@onready var front_right = $FrontRight;
@onready var back_left = $BackLeft;
@onready var back_right = $BackRight;

@onready var center_mass = $CenterMass;

@onready var car_wall_collider = $StaticBody3D;

var wheels = [];

var line_mesh;

var h = true;

var veh_up = Vector3.UP;

var velocity = Vector3(0.0, 0.0, 0.0);

const max_speed = 30.0;
const acceleration_constant = 10;

var acceleration_amount = 0.0;

var g_turn_amount = 0.0;
var g_direction = Vector3(0.0, 0.0, 0.0);

var collision_velocity = Vector3(0.0, 0.0, 0.0);

var max_wheel_turn_amount = PI / 4.0; #45 degrees
var car_length = 3.8;

#For anti gravity
#have cube defining area
#on enter your real orientation is gravity
#on exit return gravity to normal

#First single centre of mass ray cast down to get actual orientation
#then wheel raycasts for model orientation (visual only)

func _ready():
	wheels.append(front_left);
	wheels.append(front_right);
	wheels.append(back_left);
	wheels.append(back_right);

func _process(delta):
	pass

func _physics_process(delta):
	car_move(delta);
	#set_center_mass_angle();
	set_car_angle(); 

func get_turn_amount() -> float:
	var speed = velocity.length();
	var turning_radius = car_length / sin(max_wheel_turn_amount);
	var turn_amount = speed / turning_radius;
	return turn_amount;

func car_move(delta):
	var speed = 10.0;
	var friction = 2.0;
	acceleration_amount = 0.0;
	var direction = velocity.dot(global_transform.basis.x);
	var normalized_direction = 0.0;
	if direction > 0.0:
		normalized_direction = 1.0;
	else:
		normalized_direction = -1.0;
	if Input.is_action_pressed("accelerate"):
		acceleration_amount += speed;
	if Input.is_action_pressed("brake"):
		acceleration_amount -= speed;
	if Input.is_action_pressed("turn_right"):
		var turn_amount = -get_turn_amount() * normalized_direction * delta;
		global_rotate(global_transform.basis.y, turn_amount);
	if Input.is_action_pressed("turn_left"):
		var turn_amount = get_turn_amount() * normalized_direction * delta;
		global_rotate(global_transform.basis.y, turn_amount);
	
	#Correct velocity to new direction		
	var velocity_diff = velocity.dot(global_transform.basis.x);
	velocity = velocity_diff * global_transform.basis.x;
	if collision_velocity.length_squared() != 0.0:
		velocity_diff = velocity.dot(collision_velocity);
		velocity = velocity_diff * collision_velocity;
	velocity += collision_velocity;
	g_direction = global_transform.basis.x;
	velocity += global_transform.basis.x * acceleration_amount * delta;
	if velocity.length() > 0.1:
		velocity -= velocity.normalized() * friction * delta;
	else:
		velocity = Vector3(0.0, 0.0, 0.0);
	#g_direction = global_transform.basis.x;
	
	var data = car_wall_collider.move_and_collide(velocity * delta, true);
	if data != null:
		var desired_position = global_transform.origin + velocity * delta;
		var correct_position = global_transform.origin + data.get_travel();
		var plane_point = data.get_position();
		var plane_normal = data.get_normal();
		var d_to_p = correct_position - desired_position;
		var n_dot_dp = d_to_p.dot(plane_normal);
		var desired_plane_point = desired_position + plane_normal * n_dot_dp;
		var desired_direction = (desired_plane_point - correct_position).normalized();
		#velocity = desired_direction * velocity.length();
		collision_velocity = desired_direction;
		velocity = desired_direction * velocity.dot(desired_direction);
		global_transform.origin = correct_position;
	else:
		collision_velocity = Vector3(0.0, 0.0, 0.0);
	global_transform.origin += velocity * delta;

func set_center_mass_angle():
	if center_mass.is_colliding():
		var dist = center_mass.global_position.distance_to(center_mass.get_collision_point());
		global_transform.basis.y = center_mass.get_collision_normal();
		global_transform.basis.x = global_transform.basis.y.cross(global_transform.basis.z).normalized();
		global_transform.basis.z = global_transform.basis.x.cross(global_transform.basis.y).normalized();
		global_transform.origin += -global_transform.basis.y * dist + global_transform.basis.y * 0.6;

func set_car_angle():
	
	var collision_points = [];
	var collision_dists = [];
	
	var index_of_furthest_wheel = 0;
	var index_of_nearest_wheel = 0;
	var current_closest_distance = 2048.0;
	var current_furthest_distance = 0.0;
	
	var index = 0;
	
	for wheel in wheels:
		wheel.force_raycast_update();
		if wheel.is_colliding():
			collision_points.append(wheel.get_collision_point());
			var wheel_dist = wheel.global_position.distance_to(wheel.get_collision_point());
			collision_dists.append(wheel_dist);
			#g_see = wheel.get_collision_point();
			if wheel_dist < current_closest_distance:
				index_of_nearest_wheel = index;
				current_closest_distance = wheel_dist;
			if wheel_dist > current_furthest_distance:
				index_of_furthest_wheel = index;
				current_furthest_distance = wheel_dist;
			index += 1;
	$Area3D
	if collision_points.size() > 0:
		global_transform.origin += -global_transform.basis.y * current_closest_distance + global_transform.basis.y * 0.5;
	
	#DO NOT USE INDEX OF NEAREST AND FURTHEST POINTS PAST THIS POINT
	if collision_points.size() == 4:
		collision_points.remove_at(index_of_furthest_wheel);
	
	match collision_points.size():
		0:
			handle_air_angle();
		1:
			handle_one_point_angle();
		2:
			handle_two_point_angle(collision_points);
		3:
			handle_three_point_angle(collision_points);
			
	global_transform.basis.y = veh_up;
	global_transform.basis.x = global_transform.basis.y.cross(global_transform.basis.z).normalized();
	global_transform.basis.z = global_transform.basis.x.cross(global_transform.basis.y).normalized();
	line_mesh = line(global_position, global_position + veh_up);
		
func handle_air_angle():
	pass;
	
func handle_one_point_angle():
	pass;
	
func handle_two_point_angle(collision_points):
	var up_rotation = global_transform.basis.z.cross((collision_points[1] - collision_points[0]).normalized()).normalized();
	if global_transform.basis.y.dot(up_rotation) < 0.0:
		up_rotation = -up_rotation;
	veh_up = up_rotation;
	
func handle_three_point_angle(collision_points):
	var ab = (collision_points[1] - collision_points[0]).normalized();
	var ac = (collision_points[2] - collision_points[0]).normalized();
	
	var abxac = ab.cross(ac).normalized();
	if global_transform.basis.y.dot(abxac) < 0.0:
		abxac = -abxac;
	veh_up = abxac;

func speed_function():
	#Using asymptotes
	var in_var = 0.1;
	velocity.x = (max_speed * (acceleration_amount * acceleration_amount)) / ((acceleration_amount * acceleration_amount) + acceleration_constant);

func line(pos1: Vector3, pos2: Vector3, color = Color.RED) -> MeshInstance3D:
	
	if line_mesh != null:
		line_mesh.queue_free();
	
	var mesh_instance = MeshInstance3D.new();
	var immediate_mesh = ImmediateMesh.new();
	var material = ORMMaterial3D.new();
	
	mesh_instance.mesh = immediate_mesh;
	mesh_instance.cast_shadow = false;
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material);
	immediate_mesh.surface_add_vertex(pos1);
	immediate_mesh.surface_add_vertex(pos2);
	immediate_mesh.surface_end();
	
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;
	material.albedo_color = color;
	
	get_tree().get_root().add_child(mesh_instance);
	
	return mesh_instance;
