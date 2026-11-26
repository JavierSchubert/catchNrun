extends Node2D
## Match scene. The host spawns one unit per peer through the MultiplayerSpawner.
## Runners spawn as soon as every peer has loaded. The Hunter spawns only once the
## match phase is HUNTER_ACTIVE.

@export var hunter_scene: PackedScene
@export var runner_scene: PackedScene
## Players spawn on a ring around map center so they do not stack on top of each other.
@export var spawn_ring_radius := 160.0
## Sandbox only: Runner and Hunter spawn this far left / right of the map center.
const SANDBOX_SPAWN_OFFSET := 450.0

var _spawned: Dictionary = {}

@onready var spawner: MultiplayerSpawner = $PlayerSpawner
@onready var players_root: Node2D = $Players
@onready var spawn_points: Node2D = $SpawnPoints


func _ready() -> void:
	_hide_spawn_gizmos()
	spawner.spawn_function = _spawn_unit
	GameManager.all_players_loaded.connect(_spawn_pending)
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.player_removed.connect(_on_player_removed)
	if GameManager.players.is_empty():
		return
	if multiplayer.is_server():
		GameManager.report_scene_ready()
	else:
		GameManager.report_scene_ready.rpc_id(1)


func _hide_spawn_gizmos() -> void:
	## Spawn_mark sprites are editor/layout aids; hide them during play.
	for marker in spawn_points.get_children():
		var gizmo := marker.get_node_or_null("Gizmo") as CanvasItem
		if gizmo != null:
			gizmo.visible = false
	var arena := get_node_or_null("ArenaPlateau")
	if arena != null:
		var preview := arena.get_node_or_null("EditorSpawnPreview") as CanvasItem
		if preview != null:
			preview.visible = false


func _on_phase_changed(_phase: GameManager.Phase) -> void:
	_spawn_pending()


func _spawn_pending() -> void:
	if not multiplayer.is_server() or not GameManager.everyone_loaded():
		return
	if GameManager.phase == GameManager.Phase.LOBBY \
			or GameManager.phase == GameManager.Phase.ROLE_SELECTION \
			or GameManager.phase == GameManager.Phase.ENDED:
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
	if GameManager.sandbox_mode:
		## Far enough apart that the Hunter's acquisition range (500) does not reach the Runner.
		var side := 1.0 if role == RoleConfig.Role.HUNTER else -1.0
		return PlateauMap.spawn_center() + Vector2(SANDBOX_SPAWN_OFFSET * side, 0.0)
	var ids: Array[int] = []
	for key in GameManager.players.keys():
		ids.append(int(key))
	ids.sort()
	var count := maxi(ids.size(), 1)
	var slot := maxi(ids.find(peer_id), 0)
	var positions := PlateauMap.spawn_ring_positions(count, spawn_ring_radius)
	return positions[slot % positions.size()]


func _on_player_removed(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_spawned.erase(peer_id)
	var unit := players_root.get_node_or_null(str(peer_id))
	if unit:
		unit.queue_free()
