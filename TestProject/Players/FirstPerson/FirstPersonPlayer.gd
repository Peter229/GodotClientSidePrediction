extends CharacterBody3D

var number_of_miss_predictions_per_second = 0;

var total_time = 0.0;

const gravity = -29.1;

const player_acceleration = 90.0;
const player_air_acceleration = 20.0;
const jump_acceleration = 20.0;
const boost_amount = 20.0;
const angler_dampening = 0.88;
const crouch_time = 0.2;
const crouch_height = 1.5;
const standing_height = 3.0;
const firing_speed = 0.2;
const hitmarker_time = 0.2;

var direction = Vector3(1.0, 0.0, 0.0);

var yaw = 0.0;
var pitch = 0.0;
var mouse_senitivity = 0.002;

var is_grounded = false;

var forward = Vector3(0.0, 0.0, -1.0);
var flat_forward = Vector3(0.0, 0.0, -1.0);
var right = Vector3(1.0, 0.0, 0.0);

var step_down_distance = -0.1;

var line_mesh;

var speed = 0.0;

@onready var mesh = $character;

@onready var gun_mesh = $Camera3D/SubViewportContainer/SubViewport/Camera3D2/gun;

var crouching = false;
var crouch_amount = 0.0;

var firing_timer = 0.0;
var hitmarker_timer = 0.0;

var gun_pos;

var state = 0;
var firing_tick = 0;

var depth = 0;

var recusive_velocity = Vector3(0.0, 0.0, 0.0);

var my_inputs = NetworkManager.Inputs.new();

var pitch_factor = 0.0;
var pitch_speed = 4.0;

var gun_pitch_factor = 0.02;
var gun_pitch_speed = 0.4;

const FORWARD_FLAG 	= 0b00000001;
const BACKWARD_FLAG = 0b00000010;
const RIGHT_FLAG 	= 0b00000100;
const LEFT_FLAG 	= 0b00001000;
const CROUCH_FLAG	= 0b00010000;
const SHOOT_FLAG 	= 0b00100000;
const JUMP_FLAG 	= 0b01000000;

const MAX_PLAYER_STATES = 32;

var prev_player_states = [];
var prev_player_inputs = [];

func _ready():
	var name = get_name();
	var unique_id = str(multiplayer.get_unique_id());
	if name != unique_id:
		gun_mesh.visible = false;
		return;
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	$Camera3D.current = true;
	mesh.visible = false;
	$HUD.visible = true;
	$Camera3D/SubViewportContainer/SubViewport/Camera3D2/gun/AnimationPlayer.play("Holding");
	gun_pos = gun_mesh.global_position;
	my_inputs.type = NetworkManager.INPUTS_TYPE;
	prev_player_states.resize(MAX_PLAYER_STATES);
	prev_player_inputs.resize(MAX_PLAYER_STATES);

func _process(delta):
	$Camera3D.global_position = global_position + Vector3(0.0, 2.8 - (crouch_amount * crouch_height), 0.0);
	var name = get_name();
	var unique_id = str(multiplayer.get_unique_id());
	if name != unique_id:
		return;
	gun_mesh.global_position.z = gun_pos.z + firing_timer * 2.0;
	
	if Input.is_action_pressed("move_forward"):
		my_inputs.input |= FORWARD_FLAG;
	
	if Input.is_action_pressed("move_backward"):
		my_inputs.input |= BACKWARD_FLAG;
	
	if Input.is_action_pressed("move_right"):
		my_inputs.input |= RIGHT_FLAG;
	
	if Input.is_action_pressed("move_left"):
		my_inputs.input |= LEFT_FLAG;
	
	if Input.is_action_pressed("crouch"):
		my_inputs.input |= CROUCH_FLAG;
	
	if Input.is_action_pressed("shoot"):
		my_inputs.input |= SHOOT_FLAG;
	
	if Input.is_action_pressed("jump"):
		my_inputs.input |= JUMP_FLAG;
	
	total_time += delta;
	while total_time >= 1.0:
		total_time -= 1.0;
		$HUD.update_bars(number_of_miss_predictions_per_second);
		number_of_miss_predictions_per_second = 0;

func update_look():
	mesh.rotation.y = yaw;
	
	$character/AnimationTree.set("parameters/Blend2/blend_amount", min(speed, 1.0));
	
	var normalized_pitch = (pitch + deg_to_rad(89.0)) / deg_to_rad(89.0 * 2.0);
	normalized_pitch = (1.0 - normalized_pitch) * 0.4167;

	$character/AnimationTree.set("parameters/Seek/seek_position", normalized_pitch);
	
	var indi = $character/Armature/Skeleton3D.find_bone("Neck");
	var look_dir = Quaternion.from_euler(Vector3(pitch, 0.0, 0.0));
	$character/Armature/Skeleton3D.set_bone_pose_rotation(indi, look_dir);
	
	if state == 1:
		$Camera3D.rotation.x = pitch
		$Camera3D.rotation.y = yaw
		shoot();
		var bone_index = $character/Armature/Skeleton3D.find_bone("Hand.R");
		var muzzle_transform = $character/Armature/Skeleton3D.get_bone_global_pose(bone_index);
		print(bone_index, " ", muzzle_transform.origin);
		$character/Sprite3D.global_transform = $Camera3D.global_transform;
		$character/Sprite3D.global_position += forward * 1.0;
		$character/Sprite3D.scale *= 3.0;
		$character/Sprite3D.visible = true;
	else:
		$character/Sprite3D.visible = false;

func tick(delta, inputs):
	$BloodSplash.visible = false;
	state = 0;
	pitch = clamp(pitch + pitch_factor, deg_to_rad(-89.0), deg_to_rad(89.0));
	pitch_factor = max(pitch_factor - (delta * pitch_speed), 0.0);
	update_look_dir();
	
	crouching = inputs.input & CROUCH_FLAG;
	if crouching:
		crouch_amount = min(crouch_amount + (delta / crouch_time), 1.0);
		$CollisionShape3D/MeshInstance3D.mesh.height = standing_height - (crouch_amount * crouch_height);
		$CollisionShape3D/MeshInstance3D.global_position.y = global_position.y + (standing_height - (crouch_amount * crouch_height)) / 2.0;
		$CollisionShape3D.shape.height = standing_height - (crouch_amount * crouch_height);
		$CollisionShape3D.global_position.y = global_position.y + (standing_height - (crouch_amount * crouch_height)) / 2.0;
	else:
		if $Area3D.has_overlapping_bodies():
			crouching = true;
		else:
			crouch_amount = max(crouch_amount - (delta / crouch_time), 0.0);
			$CollisionShape3D/MeshInstance3D.mesh.height = standing_height;
			$CollisionShape3D/MeshInstance3D.global_position.y = global_position.y + standing_height / 2.0;
			$CollisionShape3D.shape.height = standing_height;
			$CollisionShape3D.global_position.y = global_position.y + standing_height / 2.0;
	
	speed = velocity.length();
	
	mesh.rotation.y = yaw;
	
	$RayCast3D.global_position = global_position;
	$RayCast3D.global_position.y += 0.225;
	$RayCast3D.force_raycast_update();
	if !$RayCast3D.is_colliding():
		air_move(delta);
	else:
		is_grounded = true;
	
	if inputs.input & JUMP_FLAG && is_grounded:
		velocity.y = jump_acceleration;
		is_grounded = false;
	
	var direction = Vector3(0.0, 0.0, 0.0);
	
	if inputs.input & FORWARD_FLAG:
		direction += flat_forward;
	
	if inputs.input & BACKWARD_FLAG:
		direction -= flat_forward;
	
	if inputs.input & RIGHT_FLAG:
		direction += right;
	
	if inputs.input & LEFT_FLAG:
		direction -= right;

	var acceleration = player_acceleration;
	if !is_grounded:
		acceleration = player_air_acceleration;

	velocity += direction.normalized() * acceleration * delta;

	var friction = 50.0;
	if !is_grounded:
		friction = 2.0;
	var opposing_direction = -velocity.normalized();
	var friction_vector = opposing_direction * friction * delta;
	if friction_vector.length() >= velocity.length():
		velocity = Vector3(0.0, 0.0, 0.0);
	else:
		velocity += friction_vector;
	
	var max_speed = 10.0;
	
	if velocity.length() > max_speed && is_grounded:
		velocity = velocity.normalized() * max_speed;

	depth = 0;
	recusive_velocity = velocity;
	player_sweep(delta, inputs.tick);
	var new_dir = recusive_velocity.normalized();
	var amount = velocity.normalized().dot(new_dir);
	velocity = recusive_velocity;
	
	firing_timer = max(firing_timer -  delta, 0.0);		
	hitmarker_timer = max(hitmarker_timer - delta, 0.0);
	if hitmarker_timer == 0.0:
		$HUD/CenterContainer/HitMarker.visible = false;
	
	if firing_tick != NetworkManager.current_tick:
		state = 0;
	if inputs.input & SHOOT_FLAG:
		if firing_timer == 0.0:
			shoot();
	
	var name = get_name();
	var unique_id = str(multiplayer.get_unique_id());
	if name == unique_id:
		prev_player_states[NetworkManager.current_tick % MAX_PLAYER_STATES] = get_serializable_version();
		prev_player_inputs[NetworkManager.current_tick % MAX_PLAYER_STATES] = NetworkManager.dupe_inputs(inputs);

func air_move(delta):
	velocity.y += gravity * delta;
	is_grounded = false;

func apply_serializable_version(sv_player):
	if sv_player.id == multiplayer.get_unique_id():
		if sv_player.tick % MAX_PLAYER_STATES < prev_player_states.size():
			var prediction = prev_player_states[(sv_player.tick) % MAX_PLAYER_STATES];
			if !prediction: #Catch start of game case where still loading where server has finished
				return;
			var p_v = Vector3(prediction.x, prediction.y, prediction.z);
			var s_v = Vector3(sv_player.x, sv_player.y, sv_player.z);
			#if (prediction.speed == sv_player.speed):
				#return;
			if prediction.x == sv_player.x && prediction.y == sv_player.y && prediction.z == sv_player.z:
				#print(str(sv_player.tick) + " SUCCESS");
				return;
			print("ERROR: " + str(sv_player.tick));
			if false:
				print(prediction.speed);
				print(sv_player.speed);
				if prediction.x != sv_player.x:
					print(str(sv_player.tick) + " X Wrong");
				if prediction.y != sv_player.y:
					print(str(sv_player.tick) + " Y Wrong");
					print(sv_player.y);
					print(prediction.y);
				if prediction.z != sv_player.z:
					print(str(sv_player.tick) + " Z Wrong");
			number_of_miss_predictions_per_second += 1;
			var inp = prev_player_inputs[(sv_player.tick) % MAX_PLAYER_STATES];
			print(str(sv_player.tick) + " " + str(inp.tick) + " " + str(inp.input) + " " + str(sv_player.state) + " " + str(p_v) + " " + str(s_v));
			if sv_player.tick != inp.tick:
				print(str(inp.tick) + " WHYYY");
			#print("Predicted " + str(prediction.z) + "  Server " + str(sv_player.z) + " p_t " + str(prediction.tick) + " s_t " + str(sv_player.tick));
			#print(str(NetworkManager.current_tick) + " " + str(sv_player.tick));
			global_position.x = sv_player.x;
			global_position.y = sv_player.y;
			global_position.z = sv_player.z;
			velocity.x = sv_player.vx;
			velocity.y = sv_player.vy;
			velocity.z = sv_player.vz;
			for i in range(sv_player.tick+1, NetworkManager.current_tick):
				tick(NetworkManager.server_tick_rate, prev_player_inputs[i % MAX_PLAYER_STATES]);
			return;
	global_position.x = sv_player.x;
	global_position.y = sv_player.y;
	global_position.z = sv_player.z;
	velocity.x = sv_player.vx;
	velocity.y = sv_player.vy;
	velocity.z = sv_player.vz;
	speed = sv_player.speed;
	if sv_player.id != multiplayer.get_unique_id():
		yaw = sv_player.yaw;
		pitch = sv_player.pitch;
		update_look();
	state = sv_player.state;

func get_serializable_version() -> NetworkManager.Player:
	var sv_player = NetworkManager.Player.new();
	sv_player.type = NetworkManager.PLAYER_TYPE;
	sv_player.id = multiplayer.get_unique_id();
	sv_player.tick = NetworkManager.current_tick;
	sv_player.x = global_position.x;
	sv_player.y = global_position.y;
	sv_player.z = global_position.z;
	sv_player.vx = velocity.x;
	sv_player.vy = velocity.y;
	sv_player.vz = velocity.z;
	sv_player.yaw = yaw;
	sv_player.pitch = pitch;
	sv_player.speed = speed;
	sv_player.state = state;
	return sv_player;

func shoot():
	state = 1;
	$character/Sprite3D.visible = true;
	firing_tick = NetworkManager.current_tick;
	firing_timer = firing_speed;
	
	var return_position = $Camera3D.global_position + forward * 2048.0;
	var params = PhysicsRayQueryParameters3D.new();
	params.from = $Camera3D.global_position;
	params.to = $Camera3D.global_position + forward * 2048.0;
	params.exclude = [self.get_rid()];
	params.collision_mask = 2;
	pitch_factor = gun_pitch_factor;
	pitch_speed = gun_pitch_speed;
	var result = get_world_3d().get_direct_space_state().intersect_ray(params);
	if result.has("collider"):
		$BloodSplash.visible = true;
		$BloodSplash.global_position = result.position;
		$BloodSplash.global_rotation = get_viewport().get_camera_3d().rotation;
		$BloodSplash.rotate_x(PI/2.0);
		#return_position = result.position;
		#line_mesh = line(params.from, return_position);
		#hitmarker_timer = hitmarker_time;
		#$HUD/CenterContainer/HitMarker.visible = true;
		if NetworkManager.is_server:
			rpc_id(get_name().to_int(), "cl_show_hit_marker");

@rpc(unreliable)
func cl_show_hit_marker():
	hitmarker_timer = hitmarker_time;
	$HUD/CenterContainer/HitMarker.visible = true;

func player_sweep(delta, tick):
	depth += 1;
	if depth > 8 || recusive_velocity.length() == 0.0:
		return;
	var params = PhysicsTestMotionParameters3D.new();
	params.from = global_transform;
	params.motion = recusive_velocity * delta;
	var out = PhysicsTestMotionResult3D.new();
	var did_hap = PhysicsServer3D.body_test_motion(self, params, out);
	if did_hap:
		global_position = global_position + (out.get_collision_unsafe_fraction() * params.motion) + out.get_collision_normal(0) * 0.001;
		recusive_velocity = recusive_velocity.slide(out.get_collision_normal(0));
		var amount_of_delta = out.get_collision_unsafe_fraction() * delta;
		player_sweep(delta - amount_of_delta, tick);
	else:
		global_position += recusive_velocity * delta;

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

func apply_input(input):
	pass

func _input(event):
	if event is InputEventMouseMotion:
		var name = get_name();
		var unique_id = str(multiplayer.get_unique_id());
		if name != unique_id:
			return;
		yaw -= event.relative.x * mouse_senitivity
		pitch -= event.relative.y * mouse_senitivity
		pitch = clamp(pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
		if yaw > deg_to_rad(360.0):
			yaw -= deg_to_rad(360.0)
		elif yaw < deg_to_rad(-360.0):
			yaw += deg_to_rad(360.0)
		update_look_dir();
	elif event is InputEventKey:
		if event.get_keycode_with_modifiers() == KEY_ESCAPE:
			get_tree().quit()

func update_look_dir():
	
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
