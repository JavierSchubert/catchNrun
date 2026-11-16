extends Node2D
## Match scene. The host spawns one unit per peer through the MultiplayerSpawner.
## Runners spawn as soon as every peer has loaded. The Hunter spawns only once the
## match phase is HUNTER_ACTIVE.

@export var hunter_scene: PackedScene
@export var runner_scene: PackedScene

var _spawned: Dictionary = {}

@onready var spawner: MultiplayerSpawner = $PlayerSpawner
@onready var players_root: Node2D = $Players
@onready var spawn_points: Node2D = $SpawnPoints


func _ready() -> void:
	spawner.spawn_function = _spawn_unit
	GameManager.all_players_loaded.connect(_spawn_pending)
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.player_removed.connect(_on_player_removed)
	if multiplayer.is_server():
		GameManager.report_scene_ready()
	else:
		GameManager.report_scene_ready.rpc_id(1)


func _on_phase_changed(_phase: GameManager.Phase) -> void:
	_spawn_pending()


func _spawn_pending() -> void:
	if not multiplayer.is_server() or not GameManager.everyone_loaded():
		return
	if GameManager.phase == GameManager.Phase.LOBBY or GameManager.phase == GameManager.Phase.ENDED:
		return
	for key in GameManager.players.keys():
		var id := int(key)
		if _spawned.has(id):
			continue
		var role := int(GameManager.players[id].role)
		var spawn_now := role == RoleConfig.Role.RUNNER or GameManager.phase == GameManager.Phase.HUNTER_ACTIVE
		if spawn_now:
			_spawn_one(id, role)


func _spawn_one(peer_id: int, role: int) -> void:
	var at := _position_for(peer_id, role)
	_spawned[peer_id] = true
	GameManager.note_unit_spawned(role)
	spawner.spawn({"peer_id": peer_id, "role": role, "position": at})
	GameLog.info("MATCH", "spawned peer %d as %s at %s" % [peer_id, GameManager.role_label(role), at])


func _spawn_unit(data: Dictionary) -> Node:
	var role := int(data.role)
	var scene := hunter_scene if role == RoleConfig.Role.HUNTER else runner_scene
	var unit := scene.instantiate() as Unit
	unit.name = str(int(data.peer_id))
	unit.position = data.position
	unit.sync_position = data.position
	return unit


func _position_for(peer_id: int, role: int) -> Vector2:
	if role == RoleConfig.Role.HUNTER:
		return _marker_position("HunterSpawn")
	var runner_ids: Array[int] = []
	for key in GameManager.players.keys():
		var id := int(key)
		if int(GameManager.players[id].role) == RoleConfig.Role.RUNNER:
			runner_ids.append(id)
	runner_ids.sort()
	var slot := maxi(runner_ids.find(peer_id), 0)
	var markers: Array[Node] = []
	for child in spawn_points.get_children():
		if child.name != "HunterSpawn":
			markers.append(child)
	if markers.is_empty():
		return Vector2.ZERO
	return (markers[slot % markers.size()] as Node2D).global_position


func _marker_position(marker_name: String) -> Vector2:
	var marker := spawn_points.get_node_or_null(marker_name) as Node2D
	if marker == null:
		return Vector2.ZERO
	return marker.global_position


func _on_player_removed(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_spawned.erase(peer_id)
	var unit := players_root.get_node_or_null(str(peer_id))
	if unit:
		unit.queue_free()
