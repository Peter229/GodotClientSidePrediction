extends Node

var b = 1;

func _ready():
	ComponentHandler.add_lock_on_component(self);

func _process(delta):
	pass

func custom_script():
	b = 2;
