class_name VisionSystem
extends Node
## Team vision and fog-of-war knowledge for the LOCAL player's team (docs/vision.README.md).
##
## Lives in game/match/match.tscn (group "vision_system"). Every peer runs its own copy and
## derives it only from synced world state (unit / structure positions, ownership, level,
## state), so a client never learns more than the replicated nodes already tell it.
##
## Rules:
##  - Vision is shared per team (all Runners together; the Hunter alone).
##  - Living team units and finished structures are vision sources
##    (RoleConfig.vision_range / BuildingDef.vision_range).
##  - Own team is always visible.
##  - Enemy units are visible only while inside current vision. They are never remembered.
##  - Enemy structures are remembered at their last-known state until the spot is seen empty.
##
## Phase 1 is data + queries only. Fog overlay, ghost drawing and minimap use are consumers
## of this API in later phases.

## Emitted after every refresh of the visible / explored masks and last-known memory.
signal vision_updated
signal fog_enabled_changed(enabled: bool)
## Emitted when a remembered structure was added, changed or forgotten.
signal last_known_changed

const GROUP := "vision_system"

## Seconds between vision refreshes (physics time). 0 refreshes every physics frame.
@export var update_interval := 0.1
## Edge length in pixels of one fog cell. Applied when the system enters the tree.
@export var cell_size := VisionKnowledge.DEFAULT_CELL_SIZE
## False = fog off: everything is visible, queries return "visible" and no knowledge is
## gathered. Toggle at runtime with set_fog_enabled() (sandbox / debug tooling).
@export var fog_enabled := true:
	set = set_fog_enabled

var knowledge: VisionKnowledge

var _since_update := 0.0
var _knowledge_role := -1
var _source_centers := PackedVector2Array()
var _source_radii := PackedFloat32Array()


## The VisionSystem of the running match, or null (isolated tests / menus).
static func find_in(tree: SceneTree) -> VisionSystem:
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP) as VisionSystem


func _enter_tree() -> void:
	add_to_group(GROUP)
	knowledge = VisionKnowledge.new(PlateauMap.world_bounds(), cell_size)
	_since_update = update_interval


func _ready() -> void:
	## Run after units and structures moved this physics frame.
	process_physics_priority = 100


func _exit_tree() -> void:
	remove_from_group(GROUP)


func _physics_process(delta: float) -> void:
	if not fog_enabled:
		return
	_since_update += delta
	if _since_update < update_interval:
		return
	_since_update = 0.0
	update_vision()


func set_fog_enabled(enabled: bool) -> void:
	if fog_enabled == enabled:
		return
	fog_enabled = enabled
	## Refresh on the next physics tick after re-enabling instead of showing stale masks.
	_since_update = update_interval
	fog_enabled_changed.emit(enabled)


# --- Viewer ---------------------------------------------------------------------------------


## Role (= team) of the local player. Follows GameManager.local_peer_id(), so the sandbox's
## character switch changes the viewing team. Defaults to Runner outside a roster.
func viewer_role() -> int:
	var entry: Variant = GameManager.players.get(GameManager.local_peer_id())
	if entry is Dictionary:
		var role := int((entry as Dictionary).get("role", RoleConfig.Role.RUNNER))
		if role == RoleConfig.Role.HUNTER or role == RoleConfig.Role.RUNNER:
			return role
	return RoleConfig.Role.RUNNER


# --- Refresh --------------------------------------------------------------------------------


## Recomputes the visible mask, folds it into explored, and updates last-known structures.
## Called on a timer; tests and tools may call it directly for an immediate refresh.
func update_vision() -> void:
	## Fog off gathers no knowledge (docs/vision.README.md §7), also for direct calls.
	if not fog_enabled:
		return
	var tree := get_tree()
	if tree == null or knowledge == null:
		return
	var role := viewer_role()
	if role != _knowledge_role:
		## The viewing team changed (sandbox switch): the old team's knowledge is not ours.
		knowledge.reset()
		_knowledge_role = role
	_collect_sources(tree, role)
	knowledge.begin_update()
	for i in _source_centers.size():
		knowledge.reveal_circle(_source_centers[i], _source_radii[i])
	if _update_last_known(tree, role):
		last_known_changed.emit()
	vision_updated.emit()


func _collect_sources(tree: SceneTree, role: int) -> void:
	_source_centers.clear()
	_source_radii.clear()
	for node in tree.get_nodes_in_group("units"):
		var unit := node as Unit
		if unit == null or unit.team_role() != role or not unit.is_alive():
			continue
		var radius := unit.get_vision_range()
		if radius > 0.0:
			_source_centers.append(unit.global_position)
			_source_radii.append(radius)
	for node in tree.get_nodes_in_group("buildings"):
		var building := node as Building
		if building == null or building.team_role() != role or not building.provides_vision():
			continue
		var radius := building.get_vision_range()
		if radius > 0.0:
			_source_centers.append(building.global_position)
			_source_radii.append(radius)


## Returns true when the remembered set changed.
func _update_last_known(tree: SceneTree, role: int) -> bool:
	var changed := false
	var live: Dictionary = {}
	for node in tree.get_nodes_in_group("buildings"):
		var building := node as Building
		if building == null or building.def == null or not building.is_inside_tree():
			continue
		if building.team_role() == role:
			continue
		if not building.is_attackable() or building.is_queued_for_deletion():
			continue
		var id := _building_id(building)
		live[id] = true
		if knowledge.rect_has_visible(building.world_rect()):
			if knowledge.remember_building(_snapshot(building, id)):
				changed = true
	if knowledge.purge_unseen(live) > 0:
		changed = true
	return changed


static func _building_id(building: Building) -> String:
	return str(building.get_path())


static func _snapshot(building: Building, id: String) -> VisionKnowledge.LastKnownBuilding:
	var entry := VisionKnowledge.LastKnownBuilding.new()
	var rect := building.world_rect()
	entry.id = id
	entry.kind = int(building.def.kind)
	entry.display_name = building.display_name
	entry.owner_peer_id = building.owner_peer_id
	entry.position = rect.get_center()
	entry.footprint = BuildGrid.positive_footprint(building.footprint)
	entry.pixel_size = rect.size
	entry.level = building.level
	entry.under_construction = building.state == Building.State.UNDER_CONSTRUCTION
	entry.last_seen_msec = Time.get_ticks_msec()
	return entry


# --- Public queries -------------------------------------------------------------------------


## Point test against the current vision circles (exact, not cell-quantized).
## Always true while fog is disabled.
func is_world_visible(world_pos: Vector2) -> bool:
	if not fog_enabled:
		return true
	for i in _source_centers.size():
		var radius := _source_radii[i]
		if world_pos.distance_squared_to(_source_centers[i]) <= radius * radius:
			return true
	return false


## Cell-quantized state for fog overlay / minimap: UNEXPLORED, PREVIOUSLY_SEEN or VISIBLE.
## Always VISIBLE while fog is disabled.
func terrain_state(world_pos: Vector2) -> VisionKnowledge.State:
	if not fog_enabled:
		return VisionKnowledge.State.VISIBLE
	return knowledge.state_at(world_pos)


## Own-team units are always visible; enemy units only while in current vision.
## Enemy units have no last-known state: once they leave vision this returns false.
func can_see_unit(unit: Unit) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	if not fog_enabled:
		return true
	if unit.team_role() == viewer_role():
		return true
	return is_world_visible(unit.global_position)


## Own-team structures are always visible; enemy structures only while any part of their
## footprint is currently lit. A false result may still have a last-known entry.
func can_see_building(building: Building) -> bool:
	if building == null or not is_instance_valid(building):
		return false
	if not fog_enabled:
		return true
	if building.team_role() == viewer_role():
		return true
	return knowledge.rect_has_visible(building.world_rect())


## Every remembered enemy structure (including ones currently in view, refreshed each update).
## Empty while fog is disabled.
func last_known_buildings() -> Array[VisionKnowledge.LastKnownBuilding]:
	if not fog_enabled:
		return []
	return knowledge.last_known_buildings()


## Remembered enemy structures outside current vision: the entries a ghost layer should draw.
## Empty while fog is disabled.
func hidden_last_known_buildings() -> Array[VisionKnowledge.LastKnownBuilding]:
	if not fog_enabled:
		return []
	return knowledge.hidden_last_known_buildings()


## Same as Unit.get_vision_range() / Building.get_vision_range(); null-safe convenience.
func get_vision_range(entity: Node) -> float:
	if entity is Unit:
		return (entity as Unit).get_vision_range()
	if entity is Building:
		return (entity as Building).get_vision_range()
	return 0.0


# --- Grid access for presentation (fog overlay, minimap) -------------------------------------


func world_bounds() -> Rect2:
	return knowledge.bounds


func grid_size() -> Vector2i:
	return knowledge.grid_size()


func cell_edge() -> float:
	return knowledge.cell_size


## Row-major bytes, 1 = currently visible. Read only; do not mutate.
func visible_mask() -> PackedByteArray:
	return knowledge.visible_cells


## Row-major bytes, 1 = explored at least once. Read only; do not mutate.
func explored_mask() -> PackedByteArray:
	return knowledge.explored_cells
