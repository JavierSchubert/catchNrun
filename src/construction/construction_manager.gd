class_name ConstructionManager
extends Node
## Host-authoritative build / upgrade / destroy requests for Runner structures.
## Ghost preview + cost/footprint validation run client-side too (see building.README.md
## §4); only the host actually spends Crystals and spawns / frees Building nodes.

const WALL_SCENE := preload("res://src/buildings/wall.tscn")
const TOWER_SCENE := preload("res://src/buildings/tower.tscn")
const MINE_SCENE := preload("res://src/buildings/crystal_mine.tscn")

const WALL_DEF: BuildingDef = preload("res://src/buildings/defs/wall_def.tres")
const TOWER_DEF: BuildingDef = preload("res://src/buildings/defs/tower_def.tres")
const MINE_DEF: BuildingDef = preload("res://src/buildings/defs/crystal_mine_def.tres")

const CELL_SIZE := 32.0

var grid := BuildGrid.new(
	CELL_SIZE,
	Unit.MAP_BOUNDS.position,
	Rect2i(0, 0, int(Unit.MAP_BOUNDS.size.x / CELL_SIZE), int(Unit.MAP_BOUNDS.size.y / CELL_SIZE))
)
var validator := PlacementValidator.new(grid)

var _next_building_id := 1

@onready var buildings_root: Node2D = %BuildingsRoot
@onready var building_spawner: MultiplayerSpawner = %BuildingSpawner


func _ready() -> void:
	add_to_group("construction_manager")
	building_spawner.spawn_function = _spawn_building


static func scene_for(building_key: String) -> PackedScene:
	match building_key:
		"wall":
			return WALL_SCENE
		"tower":
			return TOWER_SCENE
		"crystal_mine":
			return MINE_SCENE
	return null


static func def_for(building_key: String) -> BuildingDef:
	match building_key:
		"wall":
			return WALL_DEF
		"tower":
			return TOWER_DEF
		"crystal_mine":
			return MINE_DEF
	return null


func can_place_preview(building_key: String, anchor_cell: Vector2i) -> bool:
	var def := def_for(building_key)
	if def == null:
		return false
	var space := get_viewport().world_2d.direct_space_state
	return validator.can_place(anchor_cell, def.footprint, space)


func request_build(building_key: String, anchor_cell: Vector2i) -> void:
	if _is_net_server():
		_server_build(_local_peer_id(), building_key, anchor_cell)
	else:
		_rpc_request_build.rpc_id(1, building_key, anchor_cell)


@rpc("any_peer", "reliable")
func _rpc_request_build(building_key: String, anchor_cell: Vector2i) -> void:
	if not multiplayer.is_server():
		return
	_server_build(GameManager.sender_id(multiplayer), building_key, anchor_cell)


func _server_build(peer_id: int, building_key: String, anchor_cell: Vector2i) -> void:
	if not multiplayer.is_server() or not _can_build(peer_id):
		return
	var def := def_for(building_key)
	if def == null:
		return
	var space := get_viewport().world_2d.direct_space_state
	if not validator.can_place(anchor_cell, def.footprint, space):
		return
	if not GameManager.try_spend_crystals(peer_id, def.cost_for_level(1)):
		return
	var building_id := _next_building_id
	_next_building_id += 1
	building_spawner.spawn({
		"id": building_id,
		"key": building_key,
		"anchor_cell": anchor_cell,
		"owner_peer_id": peer_id,
	})
	GameLog.info("CONSTRUCTION", "peer %d built %s at %s" % [peer_id, building_key, anchor_cell])


func _spawn_building(data: Dictionary) -> Node:
	var scene := scene_for(str(data.key))
	if scene == null:
		return null
	var building := scene.instantiate() as Building
	building.name = "B%d" % int(data.id)
	building.anchor_cell = data.anchor_cell
	building.owner_peer_id = int(data.owner_peer_id)
	building.grid = grid
	return building


func _can_build(peer_id: int) -> bool:
	if not GameManager.players.has(peer_id) or GameManager.is_eliminated(peer_id):
		return false
	var entry: Dictionary = GameManager.players[peer_id]
	if int(entry.get("role", RoleConfig.Role.RUNNER)) != RoleConfig.Role.RUNNER:
		return false
	return GameManager.phase == GameManager.Phase.RUNNER_PREPARATION \
		or GameManager.phase == GameManager.Phase.HUNTER_ACTIVE


func request_upgrade(building_name: String) -> void:
	if _is_net_server():
		_server_upgrade(_local_peer_id(), building_name)
	else:
		_rpc_request_upgrade.rpc_id(1, building_name)


@rpc("any_peer", "reliable")
func _rpc_request_upgrade(building_name: String) -> void:
	if not multiplayer.is_server():
		return
	_server_upgrade(GameManager.sender_id(multiplayer), building_name)


func _server_upgrade(peer_id: int, building_name: String) -> void:
	if not multiplayer.is_server():
		return
	var building := buildings_root.get_node_or_null(building_name) as Building
	if building == null or building.owner_peer_id != peer_id or not building.can_upgrade():
		return
	var cost := building.next_upgrade_cost()
	if not GameManager.try_spend_crystals(peer_id, cost):
		return
	var next_level := building.level + 1
	building.begin_upgrade()
	GameLog.info("CONSTRUCTION", "peer %d upgraded %s to level %d" % [peer_id, building_name, next_level])


func request_destroy(building_name: String) -> void:
	if _is_net_server():
		_server_destroy(_local_peer_id(), building_name)
	else:
		_rpc_request_destroy.rpc_id(1, building_name)


@rpc("any_peer", "reliable")
func _rpc_request_destroy(building_name: String) -> void:
	if not multiplayer.is_server():
		return
	_server_destroy(GameManager.sender_id(multiplayer), building_name)


func _server_destroy(peer_id: int, building_name: String) -> void:
	if not multiplayer.is_server():
		return
	var building := buildings_root.get_node_or_null(building_name) as Building
	if building == null or building.owner_peer_id != peer_id:
		return
	GameLog.info("CONSTRUCTION", "peer %d destroyed %s" % [peer_id, building_name])
	building.queue_free()


func _is_net_server() -> bool:
	return is_inside_tree() and multiplayer != null and multiplayer.is_server()


func _local_peer_id() -> int:
	if multiplayer != null and multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1
