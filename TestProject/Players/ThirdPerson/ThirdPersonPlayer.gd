extends CharacterBody3D

const gravity = -29.1;

const player_acceleration = 90.0;
const player_air_acceleration = 20.0;
const jump_acceleration = 20.0;
const boost_amount = 20.0;
const angler_dampening = 0.88;

var direction = Vector3(1.0, 0.0, 0.0);

var yaw = 0.0;
var pitch = 0.0;
var mouse_senitivity = 0.002;

var is_grounded = false;

var forward = Vector3(0.0, 0.0, -1.0);
var flat_forward = Vector3(0.0, 0.0, -1.0);
var right = Vector3(1.0, 0.0, 0.0);

var camera_desired_distance = 5.0;

var grapple_position = Vector3(0.0, 0.0, 0.0);
var grapple_max_range = 100.0;
var grapple_length = 100.0;
var is_grappling = false;

var line_mesh;

var locked_on = false;

var target = null;

var current_lock = 0;

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	#motion_mode = MOTION_MODE_FLOATING;
	#set_wall_min_slide_angle(3.14);
	#set_floor_max_angle(0.0);

func _process(delta):

	if locked_on:
		update_camera_lock_on_direction();
	
	var desired_camera_position = global_position + forward * -camera_desired_distance + Vector3(0.0, 1.0, 0.0);
	
	var params = PhysicsRayQueryParameters3D.new();
	params.from = global_position;
	params.to = desired_camera_position;
	params.exclude = [];
	params.collision_mask = 1;

	var result = get_world_3d().get_direct_space_state().intersect_ray(params);
	if result.has("position"):
		$Camera3D.global_position = result.get("position") + forward * 0.1
	else:
		$Camera3D.global_position = desired_camera_position

func _physics_process(delta):

	if Input.is_action_just_pressed("lock_on"):
		if locked_on:
			locked_on = false;
		else:
			get_lock_on_target();

	if Input.is_action_just_pressed("next_target"):
		current_lock += 1;
		if locked_on:
			get_lock_on_target();

	if Input.is_action_just_pressed("shoot"):
		grapple_hook_shoot();
	
	if Input.is_action_just_released("shoot"):
		is_grappling = false;
		if line_mesh != null:
			line_mesh.queue_free();
	
	if !$RayCast3D.is_colliding():
		air_move(delta);
	else:
		is_grounded = true;
	
	if Input.is_action_pressed("jump") && is_grounded:
		velocity.y = jump_acceleration;
		is_grounded = false;
	
	var direction = Vector3(0.0, 0.0, 0.0);
	
	if Input.is_action_pressed("move_forward"):
		direction += flat_forward;
	
	if Input.is_action_pressed("move_backward"):
		direction -= flat_forward;
	
	if Input.is_action_pressed("move_right"):
		direction += right;
	
	if Input.is_action_pressed("move_left"):
		direction -= right;

	var acceleration = player_acceleration;
	if !is_grounded:
		acceleration = player_air_acceleration;

	velocity += direction.normalized() * acceleration * delta;

	var friction = 20.0;
	if !is_grounded:
		friction = 2.0;
	var opposing_direction = -(velocity / 3.0);
	velocity += opposing_direction * friction * delta;
	
	handle_grapple_physics(delta);
	
	move_and_slide();
	
	if is_grappling:
		line_mesh = line(global_position, grapple_position);

func air_move(delta):
	velocity.y += gravity * delta;
	is_grounded = false;

func grapple_hook_shoot():
	var params = PhysicsRayQueryParameters3D.new();
	params.from = global_position;
	params.to = get_camera_lookat_point();
	params.exclude = [self.get_rid()];
	params.collision_mask = 1;
	
	var result = get_world_3d().get_direct_space_state().intersect_ray(params);
	if result.has("collider"):
		grapple_position = result.get("position");
		grapple_length = global_position.distance_to(grapple_position);
		is_grappling = true;

func get_camera_lookat_point() -> Vector3:
	var return_position = $Camera3D.global_position + forward * 2048.0;
	var params = PhysicsRayQueryParameters3D.new();
	params.from = $Camera3D.global_position;
	params.to = $Camera3D.global_position + forward * 2048.0;
	params.exclude = [self.get_rid()];
	params.collision_mask = 1;
	
	var result = get_world_3d().get_direct_space_state().intersect_ray(params);
	if result.has("collider"):
		return_position = result.position;
	return return_position;

func handle_grapple_physics(delta):
	
	if is_grappling:
		var aprox_desired_location = global_position + velocity * delta;
		if aprox_desired_location.distance_to(grapple_position) > grapple_length:
			var direction_to_player = (global_position - grapple_position).normalized();
			var plane_normal = -direction_to_player;
			var corrected_position = grapple_position + (direction_to_player * grapple_length);
			var aprox_nearst_plane_position = aprox_desired_location + plane_normal * (corrected_position - aprox_desired_location).dot(plane_normal);
			var new_velocity_direction = (aprox_nearst_plane_position - corrected_position).normalized();
			var boost = 0.0;
			global_position = corrected_position;
			if Input.is_action_just_pressed("boost"):
				boost = boost_amount;
			velocity = new_velocity_direction * (velocity.length() + boost);

func get_lock_on_target():
	var targets = ComponentHandler.get_lock_on_components();
	if current_lock >= targets.size():
		current_lock = 0;
	target = targets[current_lock];
	if target != null:
		locked_on = true;
	else:
		locked_on = false;

func update_camera_lock_on_direction():
	forward = (target.global_position - $Camera3D.global_position).normalized();
	
	flat_forward = forward;
	flat_forward.y = 0.0;
	flat_forward.normalized();
	
	right = flat_forward.cross(Vector3.UP);
	
	var look_at_transform = global_transform.looking_at(global_position + forward);
	$Camera3D.basis = look_at_transform.basis;
	pitch = look_at_transform.basis.get_euler().x;
	yaw = look_at_transform.basis.get_euler().y;
	
func _input(event):
	if event is InputEventMouseMotion:
		if locked_on:
			return;
		yaw -= event.relative.x * mouse_senitivity
		pitch -= event.relative.y * mouse_senitivity
		pitch = clamp(pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
		if yaw > deg_to_rad(360.0):
			yaw -= deg_to_rad(360.0)
		elif yaw < deg_to_rad(-360.0):
			yaw += deg_to_rad(360.0)
		
		$Camera3D.rotation.x = pitch
		$Camera3D.rotation.y = yaw
		
		forward.x = cos(-yaw - PI/2) * cos(pitch)
		forward.y = sin(pitch)
		forward.z = sin(-yaw - PI/2) * cos(pitch)
		forward.normalized()
		
		flat_forward.x = cos(-yaw - PI/2)
		flat_forward.y = 0.0
		flat_forward.z = sin(-yaw - PI/2)
		flat_forward.normalized()
		
		right = flat_forward.cross(Vector3.UP);
		
	elif event is InputEventKey:
		if event.get_keycode_with_modifiers() == KEY_ESCAPE:
			get_tree().quit()

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
