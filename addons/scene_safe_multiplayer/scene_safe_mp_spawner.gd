extends MultiplayerSpawner
class_name SceneSafeMpSpawner 
## Handshakes spawnable nodes before allowing them to be spawned on remote peers.


## Compared to the SceneSafeMpSynchronizer, this class is miniscule. The only thing it does is
## register itself with the manager. This is mostly because MultiplayerSpawners don't have a lot of
## control over anything. They don't control visibility, and they don't control which entities are
## replicated across the wire. They lean on the synchronizers that they create to do so.

## The authority does not receive spawn entity signal emissions for a peer until the peer has 
## confirmed the existence of the matching spawner.

## Associated peers will not receive their copies of the entities spawned by the authority until
## after the entity is added to the scene tree for the authority, and the remote peers have
## confirmed the existence of the spawner. This is done by enabling the data flow for an associated
## SceneSafeMpSynchronizer with the `is_spawner_visibility_controller` property set to true. To
## ensure proper synchronization, any entity spawned by a SceneSafeMpSpawner MUST have at least one
## SceneSafeMpSynchronizer with the `is_spawner_visibility_controller` property set to true.

## Register the spawner
func _ready():
	SceneSafeMultiplayer.register_spawner(
			get_path(), 
			multiplayer.get_unique_id(), 
			get_multiplayer_authority()
	);


## Unreguster the spawner
func _exit_tree():
	SceneSafeMultiplayer.unregister_spawner(
			get_path(), 
			multiplayer.get_unique_id(), 
			get_multiplayer_authority()
	);
