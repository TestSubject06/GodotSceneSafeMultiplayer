extends MultiplayerSynchronizer
class_name SceneSafeMpSynchronizer
## This is an extended version of the MultiplayerSynchronizer that interfaces with the
## SceneSafeMpManager to ensure that all peers have actually instantiated their respective
## synchronizers before beginning to send data to them. This prevents dreaded "Node not found"
## errors from clogging up the data flow and preventing synchronizers from functioning when users
## change scenes.

## NOTE: When using this node, you MUST NOT set the public_visibility property. If you need to
## change the public visibility after handshaking is completed, you MUST use the 
## set_public_visibility method. Directly setting the property will break this node and the
## guarantees that the handshaking system provides.

## Controls whether this synchronizer is used to share authority with, and control spawns from a 
## SceneSafeMpSpawner node. If true, then this Synchronizer's visibility will be controlled by the 
## authority to manage node spawns between connected peers. One, and only one synchronizer should
## be marked as a spawner visibility controller
@export var is_spawner_visibility_controller: bool = false;

## This is a list of the peers that have confirmed the existence of this synchronizer.
## These peers are safe to send data to, and only make sense from the perspective of the authority
## of this synchronizer.
var _internal_handshake_visibility: Array = [];

## This is a separate visibility map so that we don't clobber existing visibility entirely,
## we want to be able to support both at once: Handshake visibility as well as normal visibility.
var _internal_visibility_map: Dictionary = {};

## This is used internally to store whether the synchronizer should be public once the handshaking
## is completed.
var _internal_public_visibility: bool;

## This is used in conjunction with the spawner visibility controller variable to link this
## synchronizer with the parent spawner that should be controlling it.
var _parent_spawner: SceneSafeMpSpawner;

## Note: It is not possible to re-define a public property so we can't do anything like the below
## to clean up the usage of the public visible property.
#var public_visibility: bool:
#	get:
#		return __internal_public_visibility;
#	set(visibility):
#		__internal_public_visibility = visibiity;

func _ready():
	# Save off the user-intended value of the public_visibility;
	_internal_public_visibility = public_visibility;
	
	# Safe synchronizers are always publicly invisible: this prevents sending data to peers who
	# are not ready yet.
	public_visibility = false;
	
	SceneSafeMultiplayer.register_synchronizer(
			get_path(), 
			multiplayer.get_unique_id(), 
			get_multiplayer_authority(),
	);
	
	if is_spawner_visibility_controller:
		_parent_spawner = _get_parent_spawner(get_parent(), []);

## Cleanup
func _exit_tree():
	if is_spawner_visibility_controller and _parent_spawner:
		SceneSafeMultiplayer.unlink_visibility_sync_from_spawner(_parent_spawner.get_path(), self);
		
	SceneSafeMultiplayer.unregister_synchronizer(
			get_path(), 
			multiplayer.get_unique_id(), 
			get_multiplayer_authority(),
	);


# We cannot use the underying public variable directly, as it's necessary for it to always be false
# for scene safety guarantees.
func set_public_visibility(visible: bool):
	_internal_public_visibility = visible;
	
	_update_underlying_visibiity_for_all();


## Confirms handshake and enables handshake-based visibility for a collection of peers. Often called
## with a single peer, but there are cases where a group of peers is all enabled at the same time.
func enable_data_flow_for(peers: Array):
	for peer in peers:
		if _internal_handshake_visibility.has(peer):
			continue;
		
		_internal_handshake_visibility.push_back(peer);
	
		_update_underlying_visibiity_for(peer);


## Breaks the handshake and disables handshake-based visibility for a specific peer. This does not
## guarantee that a peer won't receive additional in-flight packets after breaking the handshake.
## This case is fine, since clearing the visibility will clean the state if said peer becomes
## enabled again later. 
func disable_data_flow_for(peer: int):
	if _internal_handshake_visibility.has(peer):
		_internal_handshake_visibility.erase(peer);
	
	_update_underlying_visibiity_for(peer);


## This is an overridden native method to set the visibility for a specific peer. This is changed
## to ensure it works correctly with the handshake-based visibility filtering as well. You MUST
## call this when referencing a cast SceneSafeMpSynchronizer to ensure the correct version is called.
@warning_ignore("native_method_override")
func set_visibility_for(peer: int, visible: bool):
	if not visible and _internal_visibility_map.has(str(peer)):
		_internal_visibility_map.erase(peer);
	elif visible and not _internal_visibility_map.has(str(peer)):
		_internal_visibility_map[str(peer)] = visible;
		
	_update_underlying_visibiity_for(peer);


## A recursive method to scan up the node tree to find the SceneSafeMpSpawner that spawned this
## synchronizer.
func _get_parent_spawner(node: Node, parents_checked: Array[Node]):
	for child in node.get_children():
		if child is SceneSafeMpSpawner:
			# If it's the right spawner and we own both...
			if (
					parents_checked.has(child.get_node(child.spawn_path))
					and child.get_multiplayer_authority() == get_multiplayer_authority()
			):
				SceneSafeMultiplayer.link_visibility_sync_to_spawner(child.get_path(), self);
				return child;
	
	if node.get_parent():
		var parents = Array(parents_checked);
		parents.push_back(node);
		return _get_parent_spawner(node.get_parent(), parents);
	else:
		return null;


## Merges the hasndshake-based and normal visibility to determine if the peer should be visible
func _update_underlying_visibiity_for(peer: int):
	var normal_visibility = _internal_public_visibility;
	if _internal_visibility_map.has(str(peer)):
		normal_visibility = _internal_visibility_map[str(peer)];
		
	if _internal_handshake_visibility.has(peer) and normal_visibility:
		super.set_visibility_for(peer, true);
	else:
		super.set_visibility_for(peer, false);


## The same as the above, but for the superset of all peers in both maps.
func _update_underlying_visibiity_for_all():
	var peers = _internal_handshake_visibility;
	for key in _internal_visibility_map:
		if not peers.has(int(key)):
			peers.push_back(int(key));
	
	for peer in peers:
		_update_underlying_visibiity_for(peer);
