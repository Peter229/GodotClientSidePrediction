extends ShapeCast3D

var velo = Vector3(0.0, 0.0, 2.0);
var done = false;

func _ready():
	pass

func _process(delta):
	pass

func _physics_process(delta):
	target_position = velo * delta;
	force_shapecast_update();
	if is_colliding() && !done:
		position += target_position * get_closest_collision_safe_fraction();
		done = true;
	elif !done:
		position += velo * delta;
