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

Now that we have a scene with a spawner and a spawnable scene with a synchronizer set up... TODO: draw the rest of the owl.
This tells us that a remote peer has finished adding a spawner to their scene tree. The godot multiplayer tutorials add new player spawns as a part of the `peer_connected` signal, but when using these nodes, we make sure our peer is actually ready to receive.


## What these can't do
These nodes won't allow you to have sets of players freely moving around and existing in different scenes. While these handshakes _could_ allow that, there's a huge amount of work that would have to be done on top of these nodes to handle re-assigning authority of a scene if the current authority leaves, and cleanup if everyone leaves. The example project here allows each peer (including the host/authority) to freely move between scenes - but peers without an authority present are essentially suspended in a void until the authority arrives to provide them with their player spawns. The name of the game here is _eventual consistency_.
