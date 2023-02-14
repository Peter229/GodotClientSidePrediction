extends Node

var lock_on_components = [];
 
func _ready():
	pass

func _process(delta):
	pass

func add_lock_on_component(a : Node):
	lock_on_components.append(a);

func get_lock_on_components() -> Array:
	return lock_on_components;
