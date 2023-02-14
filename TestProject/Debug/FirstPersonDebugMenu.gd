extends Control

@onready var graph = $Graph;

var time = 0.0;
var max_height = 140.0;

var number_of_bars = 10.0;

func _ready():
	for i in range(number_of_bars):
		add_bar(i);

func _process(delta):
	$Label.text = "FPS: " + str(1.0 / delta);
	time += delta;

func update_bars(number_of_miss_predictions):
	for i in range(number_of_bars, 1, -1):
		var t = graph.get_node(str(i-2)).size.y;
		graph.get_node(str(i-1)).size.y = graph.get_node(str(i-2)).size.y;
		graph.get_node(str(i-1)).get_child(0).color = graph.get_node(str(i-2)).get_child(0).color;
	
	graph.get_node(str(0)).size.y = number_of_miss_predictions;
	var g = min(2.0 - (number_of_miss_predictions / 33.0), 1.0);
	var r = min((number_of_miss_predictions / 33.0), 1.0);
	graph.get_node(str(0)).get_child(0).color = Color(r, g, 0.0);

func add_bar(i):
	var v = VBoxContainer.new();
	var image = ColorRect.new();
	
	v.custom_minimum_size.x = 10.0;
	v.name = str(i);
	
	image.size_flags_vertical = SIZE_EXPAND_FILL;
	
	v.add_child(image);
	graph.add_child(v);
