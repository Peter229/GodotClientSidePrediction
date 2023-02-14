extends Node

var current_level;

func _ready():
	get_tree().change_scene_to_file("res://ConnectScene.tscn");

func _process(delta):
	pass

func create_server():
	get_tree().change_scene_to_file("res://FirstPersonScene.tscn");

func create_client():
	get_tree().change_scene_to_file("res://FirstPersonScene.tscn");
