extends Node
class_name SceneSafeMpManager
## This is a manager class designed to live as an autoloaded script with the name 
## `SceneSafeMultiplayer`. Everything that happens in here is automatically handled by the bundled
## SceneSafeMpSpawner and SceneSafeMpSynchronizer nodes. You are only intended to interface with the
## signals provided.

## This signal is only emitted on the authority of a SceneSafeMpSpawner when a remote peer has
## confirmed the associated spawner has been added to the scene. This signal is emitted with two
## pieces of data: A String representing the node path of the spawner that should emit, and an int
## representing the id of the peer that has confirmed the handhake of the associated spawner.
## It is possible to receive a spawn signal for a spawner that the authority no longer owns, for
## example if the remote peers are split between two scenes, and a new peer joins a scene that the
## authority is no longer present in. A bit contrived, and definitely not supported, but possible.
signal remote_spawner_ready;


## This signal is only emitted on the authority of a SceneSafeMpSpawner when a remote peer has
## removed a spawner from their node tree. For example, by transitioning scenes. This is not emitted
## when a peer is disconnected, only when the handhake for the associated spawner is intentionally
## broken by the remote peer. This signal is emitted with two pieces of data: A String representing 
## the node path of the spawner that has been removed, and an int representing the id of the peer 
## that has confirmed the removal of the associated spawner. Like the remote_spawner_ready signal,
## it is possible to receive an emission for a spawner that is no longer present on the authority.
signal remote_spawner_removed;


## Stores a collection of node paths, and which peers have confirmed that they contain said nodes.
## The map has the following shape:
## {
##   [node_path]: { 
##		"authority": int,
##		"confirmed_peers": Array[int],
##		"linked_synchronizers": Array[SceneSafeMpSynchronizer],
##	 }
## }
var spawner_map = {};


## Stores a collection of node paths, and which peers have confirmed that they contain said nodes.
## The map has the following shape:
## {
##   [node_path]: { 
##		"authority": int,
##		"confirmed_peers": Array[int],
##	 }
## }
var synchronizer_map = {};


## We need to ensure that whenever a peer disconnects completely that we clean up any references
## in all of the maps, especially from any linked_synchronizers.
func _ready():
	multiplayer.peer_disconnected.connect(_cleanup_peer_data);


## This method is only intended to be called by a SceneSafeMpSpawner that has entered the tree.
## It sets up some handshake data, and RPCs to the authority to confirm the existence of the spawner.
## If running on the authority, it checks for existing & waiting peers and emits spawns for them all.
func register_spawner(node_name: String, id: int, authority_id: int) -> void:
	if not spawner_map.has(node_name):
		spawner_map[node_name] = { 
			"authority": authority_id, 
			"confirmed_peers": [], 
			"linked_synchronizers": [],
		};
	
	var spawner_entry = spawner_map[node_name];
	
	spawner_entry.confirmed_peers.push_back(id);
	
	if multiplayer.get_unique_id() == authority_id:
		if id == authority_id and spawner_entry.confirmed_peers.size() > 1:
			# There are peers here waiting for their spawns...
			for peer in spawner_entry.confirmed_peers:
				remote_spawner_ready.emit(node_name, peer);
		else:
			remote_spawner_ready.emit(node_name, id);
			
		spawner_entry.linked_synchronizers = spawner_entry.linked_synchronizers.filter(
				func(sync): return is_instance_valid(sync)
		);
		
		if spawner_entry.linked_synchronizers.size():
			for sync in spawner_entry.linked_synchronizers:
				if is_instance_valid(sync):
					sync.enable_data_flow_for([id]);
	else:
		peer_confirmed_spawner.rpc_id(authority_id, node_name, id, authority_id);


## This method is only intended to be called by a SceneSafeMpSpawner that has exited the tree.
func unregister_spawner(node_name: String, id: int, authority_id: int) -> void:
	if (
			not spawner_map.has(node_name) 
			or (spawner_map.has(node_name) and not spawner_map[node_name].confirmed_peers.has(id))
	):
		return;

	spawner_map[node_name].confirmed_peers.erase(id);
	
	if spawner_map[node_name].confirmed_peers.size() == 0:
		spawner_map.erase(node_name);
	
	if authority_id != multiplayer.get_unique_id():
		peer_unregistered_spawner.rpc_id(authority_id, node_name, id, authority_id);
	elif(authority_id == multiplayer.get_unique_id()):
		remote_spawner_removed.emit(node_name, id);


## This method is only intended to be called by a SceneSafeMpSynchronizer that has entered the tree.
## Notifies the authority of the synchronizer that it's ready. If running as the authority, it
## enables the handshake-based data flow between the peers.
func register_synchronizer(node_name: String, id: int, authority_id: int) -> void:
	if not synchronizer_map.has(node_name):
		synchronizer_map[node_name] = { "authority": authority_id, "confirmed_peers": [] };
	
	synchronizer_map[node_name].confirmed_peers.push_back(id);
	
	# Dear GDScript style guide maintainers... this looks terrible.
	if (
			multiplayer.get_unique_id() == authority_id 
			and synchronizer_map[node_name].confirmed_peers.has(authority_id)
	):
		get_tree().current_scene.get_node(node_name).enable_data_flow_for(
				synchronizer_map[node_name].confirmed_peers
		);
	elif multiplayer.get_unique_id() != authority_id:
		peer_confirmed_synchronizer.rpc_id(authority_id, node_name, id, authority_id);


## This method is only intended to be called by a SceneSafeMpSynchronizer that has exited the tree.
## It disables the handshake-based data flow between the peers. It cannot guarantee that in-fight
## packets destined for the existing synchronizer won't arrive and attempt to be processed, resulting
## in the "Node not found" error being thrown. However, by removing the visibility and confirming it
## on the other side, the synchronizer cache is cleared and data flow can be resumed later without
## needing to fully reconnect if the handshake is ever reconfirmed in the future.
func unregister_synchronizer(node_name: String, id: int, authority_id: int) -> void:
	if not synchronizer_map.has(node_name):
		return;
	
	synchronizer_map[node_name].confirmed_peers.erase(id);
	
	if synchronizer_map[node_name].confirmed_peers.size() == 0:
		synchronizer_map.erase(node_name);
	
	if multiplayer.get_unique_id() == authority_id and get_tree().current_scene.has_node(node_name):
		get_tree().current_scene.get_node(node_name).disable_data_flow_for(id);
	elif multiplayer.get_unique_id() != authority_id:
		peer_unregistered_synchronizer.rpc_id(authority_id, node_name, id, authority_id);


## This stores a visibility synchronizer associated with a SceneSafeMpSpawner with the spawner's
## disctionary data on the authority's machine. This allows the spawner to send spawned entities
## over the wire to confirmed peers.
func link_visibility_sync_to_spawner(
		spawner_path: String, 
		synchronizer: SceneSafeMpSynchronizer
) -> void:
	if spawner_map.has(spawner_path):
		spawner_map[spawner_path].linked_synchronizers.push_back(synchronizer);
		
		synchronizer.enable_data_flow_for(spawner_map[spawner_path].confirmed_peers);


## Cleans up the visibility synchronizer data in case a peer leaves the scene.
func unlink_visibility_sync_from_spawner(
		spawner_path: String, 
		synchronizer: SceneSafeMpSynchronizer
) -> void:
	if spawner_map.has(spawner_path):
		spawner_map[spawner_path].linked_synchronizers.erase(synchronizer);


## Clean up a disconnected peer's data from all of the confirmed peers lists.
func _cleanup_peer_data(peer: int):
	for key in spawner_map:
		spawner_map[key].confirmed_peers.erase(peer);
		spawner_map[key].linked_synchronizers = spawner_map[key].linked_synchronizers.filter(
			func(sync): return is_instance_valid(sync);
		);
		if spawner_map[key].confirmed_peers.size() == 0:
			spawner_map.erase(key);
	
	for key in synchronizer_map:
		synchronizer_map[key].confirmed_peers.erase(peer);
		if synchronizer_map[key].confirmed_peers.size() == 0:
			synchronizer_map.erase(key);


@rpc("any_peer", "call_local", "reliable")
func peer_confirmed_spawner(node_name: String, id: int, authority_id: int) -> void:
	register_spawner(node_name, id, authority_id);


@rpc("any_peer", "call_local", "reliable")
func peer_unregistered_spawner(node_name: String, id: int, authority_id: int) -> void:
	unregister_spawner(node_name, id, authority_id);


@rpc("any_peer", "call_local", "reliable")
func peer_confirmed_synchronizer(node_name: String, id: int, authority_id: int) -> void:
	register_synchronizer(node_name, id, authority_id);


@rpc("any_peer", "call_local", "reliable")
func peer_unregistered_synchronizer(node_name: String, id: int, authority_id: int) -> void:
	unregister_synchronizer(node_name, id, authority_id);
