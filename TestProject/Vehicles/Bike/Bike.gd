extends Node3D

@onready var front_wheel = $FrontWheel;
@onready var back_wheel = $BackWheel;

var line_mesh;

var h = true;

func _ready():
	pass

func _process(delta):
	if front_wheel.is_colliding() && back_wheel.is_colliding() && h:
		var front_loc = front_wheel.get_collision_point();
		var back_loc = back_wheel.get_collision_point();
		var up_rotation = global_transform.basis.z.cross((front_loc - back_loc).normalized()).normalized();
		
		line_mesh = line(global_position, global_position + up_rotation);
		
		global_transform.basis.y = up_rotation;
		global_transform.basis.x = global_transform.basis.y.cross(global_transform.basis.z).normalized();
		global_transform.basis.z = global_transform.basis.y.cross(global_transform.basis.x).normalized();
		
		#global_transform.basis = Basis(global_transform.basis.x, up_rotation, global_transform.basis.z);
		#var x = global_transform.basis.get_rotation_quaternion();
		#look_at(global_position + up_rotation, Vector3.RIGHT);
		h = false;

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
