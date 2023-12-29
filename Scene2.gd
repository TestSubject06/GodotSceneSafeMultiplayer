extends Node3D

@onready var spawner: SceneSafeMpSpawner = $SceneSafeMpSpawner;
# Called when the node enters the scene tree for the first time.
func _ready():
	spawner.spawn_function = player_spawner;
	
	spawner.peer_ready.connect(spawn_player);
	spawner.peer_removed.connect(remove_player);
	spawner.flush_missed_signals();
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if(Input.is_action_pressed("exit")):
		get_tree().quit();
	if(Input.is_action_pressed("load_scene_1")):
		get_tree().change_scene_to_packed(load("res://Scene1.tscn"));

# We wrap this in a deferred lambda expression because when the authority's spawner confirms itself
# and emits the signal, the scene itself isn't actually ready yet.
func spawn_player(peer_id: int):
	var spawn_data = {"id": peer_id};
	$SceneSafeMpSpawner.spawn(spawn_data);
	
	
func remove_player(peer_id: int):
	$Multiplayer.get_node(str(peer_id)).queue_free();

func player_spawner(data: Dictionary):
	print("Spawning player: ", data.id);
	var player = preload("res://Player.tscn").instantiate();
	player.position = $PlayerSpawn.position;
	player.name = str(data.id);
	player.player_id = data.id;
	
	print("Player created at: ", player.position);
	
	return player;
