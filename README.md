# Godot Scene Safe Multiplayer
A collection of high level multiplayer nodes that handshake between the authority and remote peers to prevent sending data to peers that are not yet ready to receive data.

## Purpose
To improve the reliability and **eventual consistency** of scene transitions when using the high-level multiplayer nodes MultiplayerSpawner and MultiplayerSynchronizer. 

When you call `get_tree().change_scene_to_packed(...)` there is no guarantee what order your peers will arrive on the new scene. There's no way to know which ones are running on faster or slower machines, and may take more or less time to load into the scene. There exists a possibility that a spawner or synchronizer will attempt to send a spawn event or a synchronizer will attempt to begin replication when a remote peer isn't ready to receive the data. This results in the dreaded `Node not found` errors, and any clients who missed the events will never get them again, unless you write handshaking code. Or you can lean on these nodes which handle that handshaking for you.

## Installation
The installation is as easy as it gets - until I can get this added to the Godot Asset Library. Then it will be even easier.

Just put the `addons/scene_safe_multiplayer` folder into your Godot project, then enable the "SceneSafeMultiplayer" plugin in the project settings menu. This will automatically add the required autoload, and insert the new nodes into your editor.

![image](https://github.com/TestSubject06/GodotSceneSafeMultiplayer/assets/597840/fe7a1a22-b6f1-47fb-ad77-e63d1249090c)


## Usage
<This section is in flux, still writing it up and making it easy to follow>

Create a SceneSafeMpSpawner node - it should show up in the list if the plugin is enabled:
![image](https://github.com/TestSubject06/GodotSceneSafeMultiplayer/assets/597840/6f853fb7-8c48-4403-b150-63064950d610)

You'll use the spawner pretty much as you would the underlying spawner node. You need to set up a `spawn_path` and at least one entry in the `auto_spawn_list` before doing anything else.

Your spawner won't do much on its own, so you'll need a spawnable scene with at least one **SceneSafeMpSynchronizer** in it for the spawner to actually spawn. Creating one is the same as creating the spawner. We need _at least one_ because we have to have at least one synchronizer on a spawned scene that has the `is_spawner_visibility_controller` property set to true, and has the same authority as the spawner.
![image](https://github.com/TestSubject06/GodotSceneSafeMultiplayer/assets/597840/73c83c18-d223-40d9-943d-3cd86e74e36e)


Now that we have a spawner and a synchronizer set up, we need to listen for for the SceneSafeMultiplayer's `remote_spawner_ready` signal. This tells us that a remote peer has finished adding a spawner to their scene tree. The godot multiplayer tutorials add new player spawns as a part of the `peer_connected` signal, but when using these nodes, we make sure our peer is actually ready to receive.

The example project included here has this in the scene's scripts:
```
func _enter_tree():
	SceneSafeMultiplayer.remote_spawner_ready.connect(spawn_player);
	SceneSafeMultiplayer.remote_spawner_removed.connect(remove_player);

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

```

## What these can't do
These nodes won't allow you to have sets of players freely moving around and existing in different scenes. While these handshakes _could_ allow that, there's a huge amount of work that would have to be done on top of these nodes to handle re-assigning authority of a scene if the current authority leaves, and cleanup if everyone leaves. The example project here allows each peer (including the host/authority) to freely move between scenes - but peers without an authority present are essentially suspended in a void until the authority arrives to provide them with their player spawns. The name of the game here is _eventual consistency_.
