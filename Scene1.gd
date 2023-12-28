extends Node3D

var spawn_queue = [];

func _enter_tree():
	SceneSafeMultiplayer.remote_spawner_ready.connect(spawn_player);
	SceneSafeMultiplayer.remote_spawner_removed.connect(remove_player);
	

# Called when the node enters the scene tree for the first time.
func _ready():
	$SceneSafeMpSpawner.spawn_function = player_spawner;
	if(spawn_queue.size()):
		for dict in spawn_queue:
			$SceneSafeMpSpawner.spawn(dict)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if(Input.is_action_pressed("exit")):
		get_tree().quit();
	if(Input.is_action_pressed("load_scene_2")):
		get_tree().change_scene_to_packed(load("res://Scene2.tscn"));
	
func spawn_player(spawner_node_path: String, peer_id: int):
	var spawn_data = {"id": peer_id};
	if(is_node_ready() && get_tree().current_scene.has_node(spawner_node_path)):
		get_tree().current_scene.get_node(spawner_node_path).spawn(spawn_data);
	else:
		spawn_queue.push_back(spawn_data);
	
func remove_player(spawner_node_path: String, peer_id: int):
	if(is_node_ready() && get_tree().current_scene.has_node(spawner_node_path)):
		var spawner: SceneSafeMpSpawner = get_tree().current_scene.get_node(spawner_node_path);
		spawner.get_node(spawner.spawn_path).get_node(str(peer_id)).queue_free();

func player_spawner(data: Dictionary):
	print("Spawning player: ", data.id);
	var player = preload("res://Player.tscn").instantiate();
	player.position = $PlayerSpawn.position;
	player.name = str(data.id);
	player.player_id = data.id;
	
	print("Player created at: ", player.position);
	
	return player;
