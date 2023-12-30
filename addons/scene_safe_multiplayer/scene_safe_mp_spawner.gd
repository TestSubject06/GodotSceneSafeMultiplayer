extends MultiplayerSpawner
class_name SceneSafeMpSpawner 
## Handshakes spawnable nodes before allowing them to be spawned on remote peers.


## The authority does not receive spawn entity signal emissions for a peer until the peer has 
## confirmed the existence of the matching spawner.

## Associated peers will not receive their copies of the entities spawned by the authority until
## after the entity is added to the scene tree for the authority, and the remote peers have
## confirmed the existence of the spawner. This is done by enabling the data flow for an associated
## SceneSafeMpSynchronizer with the `is_spawner_visibility_controller` property set to true. To
## ensure proper synchronization, any entity spawned by a SceneSafeMpSpawner MUST have at least one
## SceneSafeMpSynchronizer with the `is_spawner_visibility_controller` property set to true.

## This signal is only emitted on the authority when a peer has
## confirmed this spawner has been added to the scene. This signal is emitted with two
## pieces of data: A String representing the node path of the spawner that should emit, and an int
## representing the id of the peer that has confirmed the handhake of the associated spawner.
## It is possible to receive a spawn signal for a spawner that the authority no longer owns, for
## example if the remote peers are split between two scenes, and a new peer joins a scene that the
## authority is no longer present in. A bit contrived, and definitely not supported, but possible.
signal peer_ready;


## This signal is only emitted on the authority when a peer has
## removed this spawner from their node tree. For example, by transitioning scenes. This is not emitted
## when a peer is disconnected, only when the handhake for the associated spawner is intentionally
## broken by the remote peer. This signal is emitted with two pieces of data: A String representing 
## the node path of the spawner that has been removed, and an int representing the id of the peer 
## that has confirmed the removal of the associated spawner. Like the remote_spawner_ready signal,
## it is possible to receive an emission for a spawner that is no longer present on the authority.
signal peer_removed;


## Especially with a peer that is also the host, it's possible for a signal to be fired before the
## host's ready function is called. So the spawner holds missed signals until flush_missed_signals
## is called. A ready and a remove will cancel out and remove themselves from the missed signals.
var _missed_ready_signals: Array[int] = [];
var _missed_removed_signals: Array[int] = [];


## Register the spawner
func _ready():
	SceneSafeMultiplayer.register_spawner(
			get_path(), 
			multiplayer.get_unique_id(), 
			get_multiplayer_authority(),
	);


## Unreguster the spawner
func _exit_tree():
	SceneSafeMultiplayer.unregister_spawner(
			get_path(), 
			multiplayer.get_unique_id(), 
			get_multiplayer_authority(),
	);


## Intended to be called by the SceneSafeManager autoload. Lets this spawner know that a peer
## is ready to receive their spawn.
func activate_ready_singal(peer: int):
	if peer_ready.get_connections().size() == 0:
		_missed_ready_signals.push_back(peer);
		
		# If there was already a removed signal pending, then just clear them both.
		if _missed_removed_signals.has(peer):
			_missed_ready_signals.erase(peer);
			_missed_removed_signals.erase(peer);
	else:
		peer_ready.emit(peer);


## Intended to be called by the SceneSafeManager autoload. Lets this spawner know that a peer should
## be removed from consideration.
func activate_removed_signal(peer: int):
	if peer_removed.get_connections().size() == 0:
		_missed_removed_signals.push_back(peer);
		
		# If there was already a ready signal pending, just clear them both.
		if _missed_ready_signals.has(peer):
			_missed_ready_signals.erase(peer);
			_missed_removed_signals.erase(peer);
	else:
		peer_removed.emit(peer);


func flush_missed_signals():
	for peer in _missed_ready_signals:
		peer_ready.emit(peer);

	for peer in _missed_removed_signals:
		peer_removed.emit(peer);
