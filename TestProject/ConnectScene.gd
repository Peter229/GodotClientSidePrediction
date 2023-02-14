extends Control

var my_arr = [];

func _ready():
	pass

func _process(delta):
	if $ServerIP.text == "":
		$CreateServer.text = "Create Server";
	else:
		$CreateServer.text = "Join Server";

func _on_create_server_pressed():
	if $ServerIP.text == "":
		if NetworkManager.create_server():
			MasterScene.create_server();
	else:
		MasterScene.create_client();
		var did = NetworkManager.create_client($ServerIP.text)


func _on_auto_connect_pressed():
	if NetworkManager.create_client("127.0.0.1"):
		MasterScene.create_client();
