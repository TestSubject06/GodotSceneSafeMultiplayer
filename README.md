# Godot Scene Safe Multiplayer
A collection of high level multiplayer nodes that handshake between the authority and remote peers to prevent sending data to peers that are not yet ready to receive data.

## Purpose
To improve the reliability and **eventual consistency** of scene transitions when using the high-level multiplayer nodes MultiplayerSpawner and MultiplayerSynchronizer. 

When you call `get_tree().change_scene_to_packed(...)` there is no guarantee what order your peers will arrive on the new scene. There's no way to know which ones are running on faster or slower machines, and may take more or less time to load into the scene. There exists a possibility that a spawner or synchronizer will attempt to send a spawn event or a synchronizer will attempt to begin replication when a remote peer isn't ready to receive the data. This results in the dreaded `Node not found` errors, and any clients who missed the events will never get them again, unless you write handshaking code. Or you can lean on these nodes which handle that handshaking for you.

## Installation
The installation is as easy as it gets - until I can get this added to the Godot Asset Library. Then it will be even easier.

Just put the `addons/scene_safe_multiplayer` folder into your Godot project, and you're ready to start.

## Usage
First, you need to create an Autoload for the `scene_safe_mp_manager.gd` named "**SceneSafeMultiplayer**". go to your project settings, and make sure the name and file are correct - and that it's a global variable script:
<img width="581" alt="image" src="https://github.com/TestSubject06/GodotSceneSafeMultiplayer/assets/597840/52d56b4a-063f-4214-a0c7-fc608aa459e2">

Next, to create a SceneSafeMpSpawner, just add a new node and search for it - it should show up in the list:


## What these can't do
These nodes won't allow you to have sets of players freely moving around and existing in different scenes. While these handshakes _could_ allow that, there's a huge amount of work that would have to be done on top of these nodes to handle re-assigning authority of a scene if the current authority leaves, and cleanup if everyone leaves. The example project here allows each peer (including the host/authority) to freely move between scenes - but peers without an authority present are essentially suspended in a void until the authority arrives to provide them with their player spawns. The name of the game here is _eventual consistency_.
