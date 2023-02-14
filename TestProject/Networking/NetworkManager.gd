extends Node

var is_server = false;
var is_connected = false; 

var time = 0.0;
var server_tick_rate = 0.015;
var current_tick = 0;
var last_applied_tick = -1;

var loaded_player = preload("res://Players/FirstPerson/FirstPersonPlayer.tscn");

const CHANGE_TYPE: int = 0;
const INPUTS_TYPE: int = 1;
const ARRAY_TYPE: int = 2;
const PLAYER_TYPE: int = 3;
const GAME_STATE_TYPE: int = 4;

#Use type to index to get size
const SIZE_TABLE = [32, 40, 16, 104, 8];

class SArray:
	var type: int
	var size: int
	var array: Array

class GameState:
	var type: int
	var players: SArray

class Player:
	var type: int
	var id: int
	var tick: int
	var x: float
	var y: float
	var z: float
	var vx: float
	var vy: float
	var vz: float
	var yaw: float
	var pitch: float
	var speed: float
	var state: int

class Change:
	var type: int
	var tick: int
	var change: int
	var id: int 

class Inputs:
	var type: int
	var tick: int
	var input: int
	var yaw: float
	var pitch: float

var changes_since_last_state = [];
var last_confirmed_client_state = -1;

var sv_active_game_state = GameState.new();

var last_player_applied_tick = { };

var player_input_buffer = { };

var player_input_buffer_size = 4;

func _ready():
	sv_active_game_state.type = GAME_STATE_TYPE;
	sv_active_game_state.players = SArray.new();
	sv_active_game_state.players.type = ARRAY_TYPE;
	multiplayer.peer_connected.connect(self._player_connected);
	multiplayer.connected_to_server.connect(self._connect_to_server);
	multiplayer.peer_disconnected.connect(self._disconnect_from_server);

func _process(delta):
	if is_connected:
		time += delta;
		while time >= server_tick_rate:
			time -= server_tick_rate;
			tick();
			current_tick += 1;

func tick():
	if is_server:
		server_tick();
	else:
		client_tick();

func server_tick():
	update_game_state();
	if current_tick - player_input_buffer_size >= 0:
		player_input_buffer.erase(current_tick - player_input_buffer_size);
	player_input_buffer[current_tick+1] = {};
	rpc("cl_recieve_game_state", serialize_b(sv_active_game_state));

func client_tick():
	#Up date player
	apply_game_state();
	#Finish update
	send_player_input()

func send_player_input():
	var player_inst = get_node_or_null("/root/FirstPersonScene/" + str(multiplayer.get_unique_id()));
	if player_inst:
		player_inst.my_inputs.tick = NetworkManager.current_tick;
		player_inst.my_inputs.yaw = player_inst.yaw;
		player_inst.my_inputs.pitch = player_inst.pitch;
		player_inst.tick(server_tick_rate, player_inst.my_inputs);
		rpc_id(1, "sv_recieve_player_input", serialize_b(player_inst.my_inputs));
		player_inst.my_inputs.input = 0b00000000;

func update_game_state():
	var i = 0;
	for sv_player in sv_active_game_state.players.array:
		i += 1;
		var player_inst = get_node_or_null("/root/FirstPersonScene/" + str(sv_player.id));
		if !player_inst:
			spawn_player(sv_player.id);
		player_inst = get_node_or_null("/root/FirstPersonScene/" + str(sv_player.id));
		if player_input_buffer[current_tick - player_input_buffer_size].has(sv_player.id):
			var inp = deserialize_b(player_input_buffer[current_tick - player_input_buffer_size][sv_player.id]);
			player_inst.yaw = inp.yaw;
			player_inst.pitch = inp.pitch;
			#Should update players shooting either before moving any of them or after moving all of them
			player_inst.tick(server_tick_rate, inp);
			player_inst.update_look();
			var player = player_inst.get_serializable_version();
			sv_player.x = player.x;
			sv_player.y = player.y;
			sv_player.z = player.z;
			sv_player.vx = player.vx;
			sv_player.vy = player.vy;
			sv_player.vz = player.vz;
			sv_player.yaw = player.yaw;
			sv_player.pitch = player.pitch;
			sv_player.speed = player.speed;
			sv_player.state = player.state;
			sv_player.tick = inp.tick;
		else:
			print(str(current_tick - player_input_buffer_size) + " No new input recieved for player " + str(i));

func apply_game_state():
	for sv_player in sv_active_game_state.players.array:
		var player_inst = get_node_or_null("/root/FirstPersonScene/" + str(sv_player.id));
		if !player_inst:
			spawn_player(sv_player.id);
			player_inst = get_node_or_null("/root/FirstPersonScene/" + str(sv_player.id));
			player_inst.apply_serializable_version(sv_player);
		else:
			player_inst.apply_serializable_version(sv_player);

@rpc(unreliable)
func cl_recieve_game_state(in_game_state):
	sv_active_game_state = deserialize_b(in_game_state);

@rpc(any_peer)
func sv_recieve_player_input(in_inputs):
	var i = current_tick - player_input_buffer_size;
	while player_input_buffer[i].has(multiplayer.get_remote_sender_id()):
		i += 1;
		if i > current_tick:
			#Recieving packets to quickly, throw away
			print("Huh shouldnt be here");
			return;
	player_input_buffer[i][multiplayer.get_remote_sender_id()] = in_inputs;

func _player_connected(id):
	if is_server:
		spawn_player(id);

func _connect_to_server():
	is_connected = true;

func _disconnect_from_server(id):
	var player_inst = get_node_or_null("/root/FirstPersonScene/" + str(id));
	if player_inst:
		player_inst.queue_free();
	for i in range(sv_active_game_state.players.array.size(), 0, -1):
		if sv_active_game_state.players.array[i - 1].id == id:
			sv_active_game_state.players.array.remove_at(i - 1);
			sv_active_game_state.players.size -= 1;
	
func create_server() -> bool:
	var network = ENetMultiplayerPeer.new();
	var error = network.create_server(9999);
	if error != OK:
		printerr("Error: ", error);
		return false;
	multiplayer.multiplayer_peer = network;
	is_server = true;
	is_connected = true;
	player_input_buffer[0] = {};
	return true;

func create_client(server_ip) -> bool:
	var network = ENetMultiplayerPeer.new();
	var error = network.create_client(server_ip, 9999);
	if error != OK:
		printerr("Error: ", error);
		return false;
	multiplayer.multiplayer_peer = network;
	is_server = false;
	return true;

func spawn_player(id):
	var player = loaded_player.instantiate();
	player.set_name(str(id));
	get_node("/root/FirstPersonScene").add_child(player);
	player.global_position.y = 3.126;
	var sv_player = Player.new();
	sv_player.type = PLAYER_TYPE;
	sv_player.id = id;
	sv_player.x = 0.0;
	sv_player.y = 3.126;
	sv_player.z = 0.0;
	sv_player.vx = 0.0;
	sv_player.vy = 0.0;
	sv_player.vz = 0.0;
	sv_player.yaw = 0.0;
	sv_player.pitch = 0.0;
	sv_player.state = 0;
	if is_server:
		sv_active_game_state.players.array.append(sv_player);
		sv_active_game_state.players.size += 1;

func serialize_b(item) -> PackedByteArray:
	var bytes = PackedByteArray();
	var array = item.get_property_list();
	for i in range(3, array.size()):
		if array[i].get("type") == TYPE_OBJECT:
			bytes.append_array(serialize_b(item[array[i].get("name")]));
		elif array[i].get("type") == TYPE_ARRAY:
			for arr in item[array[i].get("name")]:
				bytes.append_array(serialize_b(arr));
		else:
			var offset = bytes.size();
			bytes.resize(offset + 8);
			var t = item[array[i].get("name")];
			if array[i].get("type") == TYPE_INT:
				bytes.encode_s64(offset, t);
			elif array[i].get("type") == TYPE_FLOAT:
				bytes.encode_double(offset, t);
	return bytes;

func serialize_a(item) -> PackedByteArray:
	if is_server:
		var array = item.get_property_list();
		for i in range(3, array.size()):
			#if array[i].get("type") == 24:
			#	continue;
			print(array[i]);
			print(item[array[i].get("name")]);
	print("\n");
	print("\n");
	var s_s = PackedByteArray();
	s_s.resize(SIZE_TABLE[item.type]);
	s_s.encode_s64(0, item.type)
	match item.type:
		CHANGE_TYPE:
			s_s.encode_s64(8, item.tick);
			s_s.encode_s64(16, item.change);
			s_s.encode_s64(24, item.id);
		INPUTS_TYPE:
			s_s.encode_s64(8, item.tick);
			s_s.encode_s64(16, item.input);
			s_s.encode_double(24, item.yaw);
			s_s.encode_double(32, item.pitch);
		PLAYER_TYPE:
			s_s.encode_s64(8, item.id);
			s_s.encode_s64(16, item.tick);
			s_s.encode_double(24, item.x);
			s_s.encode_double(32, item.y);
			s_s.encode_double(40, item.z);
			s_s.encode_double(48, item.vx);
			s_s.encode_double(56, item.vy);
			s_s.encode_double(64, item.vz);
			s_s.encode_double(72, item.yaw);
			s_s.encode_double(80, item.pitch);
			s_s.encode_double(88, item.speed);
			s_s.encode_s64(96, item.state);
		ARRAY_TYPE:
			s_s.encode_s64(8, item.array.size());
			for array_element in item.array:
				s_s.append_array(serialize_b(array_element));
		GAME_STATE_TYPE:
			s_s.append_array(serialize_b(item.players));
	return s_s;

func deserialize_b(item) -> Variant:
	var type = item.decode_s64(0);
	match type:
		CHANGE_TYPE:
			var change = Change.new();
			change.type = CHANGE_TYPE;
			change.tick = item.decode_s64(8);
			change.change = item.decode_s64(16);
			change.id = item.decode_s64(24);
			return change;
		INPUTS_TYPE:
			var inputs = Inputs.new();
			inputs.type = INPUTS_TYPE;
			inputs.tick = item.decode_s64(8);
			inputs.input = item.decode_s64(16);
			inputs.yaw = item.decode_double(24);
			inputs.pitch = item.decode_double(32);
			return inputs;
		PLAYER_TYPE:
			var player = Player.new();
			player.type = PLAYER_TYPE;
			player.id = item.decode_s64(8);
			player.tick = item.decode_s64(16);
			player.x = item.decode_double(24);
			player.y = item.decode_double(32);
			player.z = item.decode_double(40);
			player.vx = item.decode_double(48);
			player.vy = item.decode_double(56);
			player.vz = item.decode_double(64);
			player.yaw = item.decode_double(72);
			player.pitch = item.decode_double(80);
			player.speed = item.decode_double(88);
			player.state = item.decode_s64(96);
			return player;
		ARRAY_TYPE:
			var array = SArray.new();
			array.type = ARRAY_TYPE;
			array.size  = item.decode_s64(8);
			var byte_index = 16;
			for i in range(array.size):
				var item_type = item.decode_s64(byte_index);
				var last_index = byte_index + SIZE_TABLE[item_type];
				var full_item = item.slice(byte_index, last_index);
				byte_index = last_index;
				array.array.append(deserialize_b(full_item));
			return array;
		GAME_STATE_TYPE:
			var game_state = GameState.new();
			game_state.type = GAME_STATE_TYPE;
			var slice_size = item.decode_s64(16) * SIZE_TABLE[PLAYER_TYPE];
			game_state.players = deserialize_b(item.slice(8, 8 + 16 + slice_size));
			return game_state;
	return -1;

func array_to_sarray(array) -> SArray:
	var sarray = SArray.new();
	sarray.type = ARRAY_TYPE;
	sarray.size = array.size();
	sarray.array = array;
	return sarray;

func dupe_inputs(in_inputs) -> Inputs:
	var inputs = Inputs.new();
	inputs.type = in_inputs.type;
	inputs.tick = in_inputs.tick;
	inputs.input = in_inputs.input;
	inputs.yaw = in_inputs.yaw;
	inputs.pitch = in_inputs.pitch;
	return inputs;
