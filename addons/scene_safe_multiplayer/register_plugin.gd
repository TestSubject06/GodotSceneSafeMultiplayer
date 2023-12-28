@tool
extends EditorPlugin


func _enter_tree():
	add_custom_type(
			"SceneSafeMpSpawner", 
			"MultiplayerSpawner", 
			preload("res://addons/scene_safe_multiplayer/scene_safe_mp_spawner.gd"), 
			preload("res://addons/scene_safe_multiplayer/MultiplayerSpawner.svg")
	);
	add_custom_type(
			"SceneSafeMpSynchronizer", 
			"MultiplayerSynchronizer", 
			preload("res://addons/scene_safe_multiplayer/scene_safe_mp_synchronizer.gd"), 
			preload("res://addons/scene_safe_multiplayer/MultiplayerSynchronizer.svg")
	);
	add_autoload_singleton(
			"SceneSafeMultiplayer", 
			"res://addons/scene_safe_multiplayer/scene_safe_mp_manager.gd"
	);


func _exit_tree():
	remove_custom_type("SceneSafeMpSpawner");
	remove_custom_type("SceneSafeMpSynchronizer");
	remove_autoload_singleton("SceneSafeMultiplayer");
