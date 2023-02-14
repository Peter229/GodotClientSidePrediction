extends Node3D

func _ready():
	pass

func _process(delta):
	$Control/Label.text = "Speed: " + str($Car.velocity.length());
	$Control/Label.text +="\nFPS: " + str(1.0 / delta);
	$Control/Label.text +="\nTurning amount: " + str($Car.g_direction);
