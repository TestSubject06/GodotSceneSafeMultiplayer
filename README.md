# Godot Scene Safe Multiplayer
A collection of high level multiplayer nodes that handshake between the authority and remote peers to prevent sending data to peers that are not yet ready to receive data.

## Purpose
To improve the reliability and **eventual consistency** of scene transitions when using the high-level multiplayer nodes MultiplayerSpawner and MultiplayerSynchronizer. 

When you call `get_tree().change_scene_to_packed(...)` there is no guarantee what order your peers will arrive on the new scene. There's no way to know which ones are running on faster or slower machines, and may take more or less time to load into the scene. There exists a possibility that a spawner or synchronizer will attempt to send a spawn event or a synchronizer will attempt to begin replication when a remote peer isn't ready to receive the data. This results in the dreaded `Node not found` errors, and any clients who missed the events will never get them again, unless you write handshaking code. Or you can lean on these nodes which handle that handshaking for you.

This plugin cannot completely prevent these `Node not found` errors, as there will always be a possibility that a packet is already in flight destined for a peer that has moved to a new scene, that's just the nature of networks. However, the handshaking process used here **does guarantee** that if and when the peer returns to the scene, it will receive spawn and synchronizer updates again.

## Installation
The installation is as easy as it gets - until I can get this added to the Godot Asset Library. Then it will be even easier.

Just put the `addons/scene_safe_multiplayer` folder into your Godot project, and enable the plugin in your project settings menu:

![image](https://github.com/TestSubject06/GodotSceneSafeMultiplayer/assets/597840/5d41b862-0d17-4800-a0ce-e03efdfcb6dc)


## Usage Recipes

### I want to spawn player controlled entities
_You can refer to the examples in this repository as you go along._

First, create a SceneSafeMpSpawner, just add a new node and search for it - it should show up in the list:

![image](https://github.com/TestSubject06/GodotSceneSafeMultiplayer/assets/597840/49ed0345-b164-4dfa-b1fa-effc39079b6f)

Our test scene is very small and simple - it's just a spawner, a plank to stand on, and a bucket to place our players into:

![image](https://github.com/TestSubject06/GodotSceneSafeMultiplayer/assets/597840/33b8b3ca-d98d-4170-a67d-3daa1043fcfc)

Our spawner won't do much on its own, so you'll need a scene with at least one SceneSafeMpSynchronizer in it for the spawner to actually spawn. Creating one is the same as creating the spawner. We need at least one because we have to have at least one synchronizer on a spawned scene that has the `is_spawner_visibility_controller` property set to true, and has the same authority as the spawner. In our example, we create two - an _almost_ empty one to serve as the visibility controller for the spawner, and one that our players own to synchronize their position and rotation.

![image](https://github.com/TestSubject06/GodotSceneSafeMultiplayer/assets/597840/ac7f8014-9a9b-481e-9667-ce9a446d2c29)

The authority owned synchronizer must synchronize something - anything, even if the spawn and sync checkboxes are both disabled. It just has to have something in the replication panel or Godot won't process it, and the plugin won't work.

Now that we have a scene with a spawner and a spawnable scene with a synchronizer set up we need to attach to the SceneSafeMpSpawner's signals to let us know when peers are ready to receive spawns:
```
extends Node3D

@onready var spawner: SceneSafeMpSpawner = $SceneSafeMpSpawner as SceneSafeMpSpawner;

func _ready():
	spawner.spawn_function = player_spawner;
	
	if is_multiplayer_authority():
		spawner.peer_ready.connect(spawn_player);
		spawner.peer_removed.connect(remove_player);
		spawner.flush_missed_signals();
		multiplayer.peer_disconnected.connect(remove_player);


func spawn_player(peer_id: int):
	var spawn_data = {"id": peer_id};
	$SceneSafeMpSpawner.spawn(spawn_data);
	
	
func remove_player(peer_id: int):
	if $Multiplayer.has_node(str(peer_id)):
		$Multiplayer.get_node(str(peer_id)).queue_free();
```

We call `spawner.flush_missed_signals()` because the scene's `_ready()` function is executed _after_ the SceneSafeMpSpawner's `_ready()` function. This means that if the multiplayer authority is itself a player in the game, the `peer_ready` signal would have been emitted before the signal was connected in the scene, so the spawner keeps track of signals that would have been emitted when there were no listeners and saves them for later. The SceneSafeMultiplayer autoload handles the rest for us:

1. The multiplayer peer confirms the existence of the spawner.
2. The authority spawns the player's scene locally, including the two synchronizers.
3. The spawned scene's synchronizer with `is_spawner_visibility_controller` set to true links with the parent spawner.
4. At the same time, the synchronizer that the peer owns is registered and a notification from the authority is sent to the peer for later.
5. When the synchronizer links with the spawner, it sees that there is a confirmed peer on the other end for the authority owned spawner.
6. The visibility controller synchronizer enables visibility for the confirmed peer, which allows the underlying MultiplayerSpawner to replicate the instance to the peer.
7. The peer receives their spawned scene and registers the two synchronizers.
8. The synchronizer owned by the peer picks up on the waiting notification from the spawner authority that the synchronizer on the other end is ready and waiting.
9. The visibility is enabled from the peer to the multiplayer authority.
10. All other ready peers simultaneously receive a copy of the spawn and similarly notify the synchronizer's owner that they're ready to receive data.

Note however that there are two signals attached to the `remove_player` function - `multiplayer.peer_disconnected` and `spawner.peer_removed`. The spawner's `peer_removed` signal does not account for the peer exiting the game abruptly, it only accounts for the spawner calling the `_exit_tree()` lifecycle method. You still need to handle `peer_disconnected` to remove the player in the event that the player suddenly disconnects. And in doing so, you must also take care to not to try and delete entities that don't exist - as `peer_disconnected` doesn't care where the peer was when it disconnected. It may not have been ready in the first place.

## What this plugin can't do
These nodes won't allow you to have sets of players freely moving around and existing in different scenes. While these handshakes _could_ allow that, there's a huge amount of work that would have to be done on top of these nodes to handle re-assigning authority of a scene if the current authority leaves, and cleanup if everyone leaves. The example project here allows each peer (including the host/authority) to freely move between scenes - but peers without an authority present are essentially suspended in a void until the authority arrives to provide them with their player spawns. The name of the game here is _eventual consistency_.

## FAQ

### Why am I getting errors printed to the console when peers switch scenes?
blah blah answer the question.

## API Documentation

### SceneSafeMpSpawner

#### Signals

`peer_ready (peer_id: int)`

This signal is only emitted on the **authority** when a peer has confirmed this spawner has been added to the scene. This signal is emitted with one piece of data: an `int` representing the id of the peer that has confirmed the handhake of the associated spawner. This signal does emit for the authority itself, and does so immediately.

It is possible to receive a spawn signal for a spawner that the authority no longer has, for example if the remote peers are split between two scenes, and a new peer joins a scene that the authority is no longer present in. A bit contrived, and definitely not generally supported, but possible.

---

`peer_removed (peer_id: int)`

This signal is only emitted on the **authority** when a peer has removed this spawner from their node tree. For example, by transitioning scenes. This is **not emitted** when a peer is disconnected, only when the handhake for the associated spawner is intentionally broken by the peer. This signal is emitted with one piece of data: an `int` representing the id of the peer that has confirmed the removal of the associated spawner. This signal does emit for the authority itself, but it's uninteresting if the reason it's being emitted is a scene transition - rather than a spawner cleanup.

Like the `peer_ready` signal, it is possible to receive an emission for a spawner that is no longer present on the authority.
