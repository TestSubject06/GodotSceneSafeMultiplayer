extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	$HBoxContainer/Button2.disabled = (!$HBoxContainer/Address.text || !$HBoxContainer/Port.text);

func _on_host_pressed():
	var peer = ENetMultiplayerPeer.new();
	peer.create_server(19019, 4);
	if(peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED):
		return;
	multiplayer.multiplayer_peer = peer;
	print("server started");
	get_tree().change_scene_to_packed(load("res://Scene1.tscn"));
	pass # Replace with function body.


func _on_connect_pressed():
	var peer = ENetMultiplayerPeer.new();
	peer.create_client($HBoxContainer/Address.text, int($HBoxContainer/Port.text), 0, 0, 0);
	if(peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED):
		return;
	
	multiplayer.multiplayer_peer = peer;
	
	# Connection timeout
	var timeout = Time.get_ticks_msec() + 15000;
	while(peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED):
		if(Time.get_ticks_msec() > timeout ):
			multiplayer.multiplayer_peer = null;
			return;
		await get_tree().create_timer(0.5).timeout;
	print(multiplayer.get_unique_id(), " connected");
	get_tree().change_scene_to_packed(load("res://Scene1.tscn"));
	pass # Replace with function body.
