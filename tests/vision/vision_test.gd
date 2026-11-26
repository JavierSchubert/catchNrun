extends Node
## Headless checks for team vision, fog of war and last-known structures from
## docs/vision.README.md (§2 teams, §4 states, §5 entity visibility, §7 fog toggle).
##   godot --headless --path . res://tests/vision/vision_test.tscn
##
## Each scenario builds a throwaway world (a VisionSystem plus real Runner / Hunter units and
## Wall structures), moves things around and refreshes the system by hand with
## update_vision(), so nothing depends on physics frames or on the match scene. Presentation
## nodes are checked through the same VisionSystem API the minimap and ghost layer consume.

const RUNNER_SCENE := preload("res://src/units/runner/runner.tscn")
const HUNTER_SCENE := preload("res://src/units/hunter/hunter.tscn")
const WALL_SCENE := preload("res://src/buildings/wall.tscn")

## The local player (peer 1) only decides which team is viewing. Every spawned entity gets
## another number, so it never counts as the local player's own unit.
const LOCAL_PEER_ID := 1
## Peers that are not in the roster: units take their role from the scene config, structures
## fall back to the Runner team (Building.team_role()).
const ALLY_PEER_A := 2
const ALLY_PEER_B := 3
const ENEMY_PEER := 4
const STRUCTURE_OWNER := 5

var _failures: PackedStringArray = PackedStringArray()
var _world: Node2D
var _vision: VisionSystem
var _fog_signals: Array = []


func _ready() -> void:
	_test_ranges_are_data()
	_test_shared_team_vision()
	_test_enemy_unit_visibility()
	_test_dead_unit_is_not_a_source()
	_test_building_grants_vision()
	_test_terrain_states()
	_test_structure_last_known()
	_test_units_leave_no_last_known()
	_test_destroyed_structure_is_purged_on_re_reveal()
	_test_viewer_team_switch_discards_knowledge()
	_test_fog_disabled()
	_test_presentation_follows_vision()
	if _failures.is_empty():
		print("PASS: vision")
		get_tree().quit(0)
	else:
		print("FAIL: %d check(s)" % _failures.size())
		for failure in _failures:
			print(" - %s" % failure)
		get_tree().quit(1)


# --- Scenarios ----------------------------------------------------------------------------


func _test_ranges_are_data() -> void:
	_begin(RoleConfig.Role.RUNNER)
	var runner := _spawn_unit(RUNNER_SCENE, ALLY_PEER_A, Vector2.ZERO)
	var hunter := _spawn_unit(HUNTER_SCENE, ENEMY_PEER, Vector2(1000.0, 0.0))
	var wall := _spawn_wall("RangeWall", STRUCTURE_OWNER, Vector2(-1000.0, 0.0))
	_check(runner.get_vision_range() > 0.0, "a Runner has a positive vision range")
	_check(hunter.get_vision_range() > 0.0, "the Hunter has a positive vision range")
	_check(wall.get_vision_range() > 0.0, "a Wall has a positive vision range")
	_near(_vision.get_vision_range(runner), runner.get_vision_range(), "VisionSystem reads the Runner range")
	_near(_vision.get_vision_range(hunter), hunter.get_vision_range(), "VisionSystem reads the Hunter range")
	_near(_vision.get_vision_range(wall), wall.get_vision_range(), "VisionSystem reads the Wall range")
	var plain := Node.new()
	_near(_vision.get_vision_range(plain), 0.0, "a non-entity node has no vision range")
	plain.free()
	_end()


## §2: vision is shared inside a team. A Runner that cannot see the Hunter itself still sees
## it through a far-away teammate.
func _test_shared_team_vision() -> void:
	_begin(RoleConfig.Role.RUNNER)
	var runner_a := _spawn_unit(RUNNER_SCENE, ALLY_PEER_A, Vector2.ZERO)
	var reach := runner_a.get_vision_range()
	var far_x := reach * 5.0
	var runner_b := _spawn_unit(RUNNER_SCENE, ALLY_PEER_B, Vector2(far_x, 0.0))
	var hunter := _spawn_unit(HUNTER_SCENE, ENEMY_PEER, Vector2(far_x + reach * 0.5, 0.0))

	_vision.update_vision()
	_check(_vision.can_see_unit(hunter), "the Hunter near teammate B is visible to the team")
	_check(_vision.is_world_visible(hunter.global_position), "teammate B lights the Hunter's position")
	_check(_vision.can_see_unit(runner_a), "own team unit A is visible")
	_check(_vision.can_see_unit(runner_b), "own team unit B is visible")

	## Take B's shared vision away: the Hunter is only near B, so A alone cannot see it.
	_place(runner_b, Vector2(0.0, reach * 4.0))
	_vision.update_vision()
	_check(not _vision.can_see_unit(hunter), "without teammate B nobody on the team sees the Hunter")

	## Bring B back next to the Hunter and A stays far away: B's sight alone is enough.
	_place(runner_b, hunter.global_position + Vector2(reach * 0.25, 0.0))
	_vision.update_vision()
	_check(
		hunter.global_position.distance_to(runner_a.global_position) > reach,
		"scenario sanity: unit A is out of range of the Hunter"
	)
	_check(_vision.can_see_unit(hunter), "teammate B alone grants vision of the Hunter")
	_end()


## §5.2: an enemy unit is visible only while inside current vision, and hidden at once when
## it steps out.
func _test_enemy_unit_visibility() -> void:
	_begin(RoleConfig.Role.RUNNER)
	var runner := _spawn_unit(RUNNER_SCENE, ALLY_PEER_A, Vector2.ZERO)
	var reach := runner.get_vision_range()
	var hunter := _spawn_unit(HUNTER_SCENE, ENEMY_PEER, Vector2(reach * 0.5, 0.0))

	_vision.update_vision()
	_check(_vision.can_see_unit(hunter), "an enemy inside the vision range is visible")
	_check(_vision.is_world_visible(hunter.global_position), "the enemy's position is currently lit")

	_place(hunter, Vector2(reach * 1.5, 0.0))
	_vision.update_vision()
	_check(not _vision.can_see_unit(hunter), "an enemy outside the vision range is hidden")
	_check(not _vision.is_world_visible(hunter.global_position), "the hidden enemy's position is not lit")

	_place(hunter, Vector2(reach * 0.99, 0.0))
	_vision.update_vision()
	_check(_vision.can_see_unit(hunter), "an enemy just inside the range is visible again")

	## Enemy units move between 0.1 s refreshes; the exact point test never leaks them.
	_place(hunter, Vector2(reach * 1.01, 0.0))
	_check(not _vision.can_see_unit(hunter), "stepping out of range hides the enemy without a refresh")

	_check(_vision.can_see_unit(runner), "own team is always visible")
	_check(not _vision.can_see_unit(null), "a null unit is never visible")
	_end()


## §3: dead units are not sources.
func _test_dead_unit_is_not_a_source() -> void:
	_begin(RoleConfig.Role.RUNNER)
	var scout := _spawn_unit(RUNNER_SCENE, ALLY_PEER_A, Vector2.ZERO)
	var hunter := _spawn_unit(HUNTER_SCENE, ENEMY_PEER, Vector2(scout.get_vision_range() * 0.5, 0.0))
	_vision.update_vision()
	_check(_vision.can_see_unit(hunter), "a living scout reveals the Hunter")

	scout.health.take_damage(1.0e6, 1.0e6)
	_check(not scout.is_alive(), "scenario sanity: the scout is dead")
	_vision.update_vision()
	_check(not _vision.can_see_unit(hunter), "a dead scout no longer reveals the Hunter")
	_check(not _vision.is_world_visible(scout.global_position), "a dead unit does not light its surroundings")
	_end()


## §3: finished structures are vision sources for the Runner team; an unfinished one is not.
func _test_building_grants_vision() -> void:
	_begin(RoleConfig.Role.RUNNER)
	var wall := _spawn_wall("SightWall", STRUCTURE_OWNER, Vector2(2000.0, 0.0))
	var reach := wall.get_vision_range()
	var hunter := _spawn_unit(HUNTER_SCENE, ENEMY_PEER, wall.global_position + Vector2(reach * 0.5, 0.0))

	_vision.update_vision()
	_check(wall.provides_vision(), "a finished Wall provides vision")
	_check(_vision.is_world_visible(wall.global_position), "the Wall lights its own position")
	_check(_vision.can_see_unit(hunter), "the Hunter near the Wall is visible through the Wall")
	_check(_vision.can_see_building(wall), "own structures are always visible")

	_place(hunter, wall.global_position + Vector2(reach * 1.5, 0.0))
	_vision.update_vision()
	_check(not _vision.can_see_unit(hunter), "the Hunter beyond the Wall's range is hidden")

	_place(hunter, wall.global_position + Vector2(reach * 0.5, 0.0))
	wall.state = Building.State.UNDER_CONSTRUCTION
	_check(not wall.provides_vision(), "a Wall under its first construction provides no vision")
	_vision.update_vision()
	_check(not _vision.can_see_unit(hunter), "an unfinished Wall does not reveal the Hunter")

	wall.state = Building.State.UPGRADING
	_check(wall.provides_vision(), "an upgrading Wall keeps its vision")
	_vision.update_vision()
	_check(_vision.can_see_unit(hunter), "an upgrading Wall still reveals the Hunter")

	wall.free()
	_vision.update_vision()
	_check(not _vision.can_see_unit(hunter), "a destroyed Wall stops giving vision")
	_end()


## §4: Unexplored -> Currently Visible -> Previously Seen, and explored cells never revert.
func _test_terrain_states() -> void:
	_begin(RoleConfig.Role.RUNNER)
	var runner := _spawn_unit(RUNNER_SCENE, ALLY_PEER_A, Vector2.ZERO)
	var reach := runner.get_vision_range()
	var near_point := Vector2(reach * 0.25, 0.0)
	var far_point := Vector2(reach * 6.0, 0.0)

	_vision.update_vision()
	_check(
		_vision.terrain_state(near_point) == VisionKnowledge.State.VISIBLE,
		"terrain inside a vision circle is Currently Visible"
	)
	_check(
		_vision.terrain_state(far_point) == VisionKnowledge.State.UNEXPLORED,
		"terrain never seen is Unexplored"
	)
	_check(
		_vision.terrain_state(Vector2(1.0e6, 1.0e6)) == VisionKnowledge.State.UNEXPLORED,
		"a point outside the map is Unexplored"
	)
	_check(not _vision.is_world_visible(Vector2(1.0e6, 1.0e6)), "a point outside the map is never visible")

	_place(runner, far_point)
	_vision.update_vision()
	_check(
		_vision.terrain_state(near_point) == VisionKnowledge.State.PREVIOUSLY_SEEN,
		"terrain left behind is Previously Seen"
	)
	_check(
		_vision.terrain_state(far_point) == VisionKnowledge.State.VISIBLE,
		"terrain around the moved unit is Currently Visible"
	)

	_place(runner, Vector2(0.0, reach * 4.0))
	_vision.update_vision()
	_check(
		_vision.terrain_state(near_point) == VisionKnowledge.State.PREVIOUSLY_SEEN,
		"explored terrain never reverts to Unexplored"
	)
	_check(
		_vision.explored_mask().size() == _vision.visible_mask().size(),
		"the visible and explored masks share one grid"
	)
	_check(
		_vision.knowledge.explored_cell_count() > _vision.knowledge.visible_cell_count(),
		"explored terrain grows beyond what is visible now"
	)
	_end()


## §5.3: a structure that was seen stays on the map at its last-known state while hidden.
func _test_structure_last_known() -> void:
	_begin(RoleConfig.Role.HUNTER)
	var hunter := _spawn_unit(HUNTER_SCENE, ALLY_PEER_A, Vector2.ZERO)
	var reach := hunter.get_vision_range()
	var wall_pos := Vector2(reach * 0.5, 0.0)
	var wall := _spawn_wall("SeenWall", STRUCTURE_OWNER, wall_pos)
	var layer := LastKnownBuildingLayer.new()
	_world.add_child(layer)

	_check(_vision.last_known_buildings().is_empty(), "nothing is remembered before the first refresh")
	_check(not _vision.can_see_building(wall), "an enemy structure is hidden before the first refresh")

	_vision.update_vision()
	_check(_vision.can_see_building(wall), "an enemy structure inside vision is visible")
	_check(_vision.last_known_buildings().size() == 1, "a seen enemy structure is remembered")
	_check(_vision.hidden_last_known_buildings().is_empty(), "a structure in view is not a ghost")
	_check(layer.ghosts().is_empty(), "the ghost layer draws nothing while the structure is in view")
	var entry := _vision.last_known_buildings()[0]
	_check(entry.kind == int(BuildingDef.Kind.WALL), "the snapshot records the structure kind")
	_check(entry.position.is_equal_approx(wall_pos), "the snapshot records the footprint center")
	_check(entry.level == 1, "the snapshot records the level")
	_check(not entry.under_construction, "the snapshot records the construction flag")
	_check(entry.owner_peer_id == STRUCTURE_OWNER, "the snapshot records the owner")
	_check(entry.footprint == BuildGrid.positive_footprint(wall.footprint), "the snapshot records the footprint")
	_check(entry.world_rect().is_equal_approx(wall.world_rect()), "the snapshot rect matches the live structure")

	_place(hunter, Vector2(reach * 6.0, 0.0))
	_vision.update_vision()
	_check(not _vision.can_see_building(wall), "the structure is hidden as a live object when it leaves vision")
	_check(_vision.last_known_buildings().size() == 1, "the last-known structure persists after leaving vision")
	_check(_vision.hidden_last_known_buildings().size() == 1, "the remembered structure is now a ghost")
	_check(layer.ghost_ids().size() == 1, "the ghost layer draws the remembered structure")
	_check(
		layer.ghost_ids().size() == 1 and layer.ghost_ids()[0] == entry.id,
		"the ghost layer draws the same structure that was remembered"
	)
	_check(
		_vision.terrain_state(wall_pos) == VisionKnowledge.State.PREVIOUSLY_SEEN,
		"the ground under a remembered structure is Previously Seen"
	)

	## The snapshot is frozen while hidden, even if the live structure changes.
	wall.level = 7
	_vision.update_vision()
	_check(_vision.last_known_buildings()[0].level == 1, "a hidden structure's snapshot is not updated")

	## Back in view: the snapshot is refreshed from the live structure.
	_place(hunter, Vector2.ZERO)
	_vision.update_vision()
	_check(_vision.can_see_building(wall), "the structure is visible again after returning")
	_check(_vision.last_known_buildings().size() == 1, "re-seeing a structure keeps one memory entry")
	_check(_vision.last_known_buildings()[0].level == 7, "re-seeing a structure refreshes its snapshot")
	_check(layer.ghosts().is_empty(), "the ghost disappears when the structure is in view again")
	_end()


## §5.2: enemy units are never remembered. Only structures show up in the last-known API
## that feeds the ghost layer and the minimap.
func _test_units_leave_no_last_known() -> void:
	_begin(RoleConfig.Role.HUNTER)
	var hunter := _spawn_unit(HUNTER_SCENE, ALLY_PEER_A, Vector2.ZERO)
	var reach := hunter.get_vision_range()
	var runner := _spawn_unit(RUNNER_SCENE, ENEMY_PEER, Vector2(reach * 0.5, 0.0))
	var layer := LastKnownBuildingLayer.new()
	_world.add_child(layer)

	_vision.update_vision()
	_check(_vision.can_see_unit(runner), "an enemy Runner inside vision is visible")
	_check(_vision.last_known_buildings().is_empty(), "seeing a unit creates no last-known entry")
	_check(_vision.hidden_last_known_buildings().is_empty(), "seeing a unit creates no minimap ghost")

	var seen_at := runner.global_position
	_place(hunter, Vector2(reach * 6.0, 0.0))
	_vision.update_vision()
	_check(not _vision.can_see_unit(runner), "an enemy Runner that left vision is hidden at once")
	_check(not _vision.is_world_visible(seen_at), "the spot where it was seen is no longer lit")
	_check(
		_vision.terrain_state(seen_at) == VisionKnowledge.State.PREVIOUSLY_SEEN,
		"the explored ground stays Previously Seen"
	)
	_check(_vision.last_known_buildings().is_empty(), "a hidden unit leaves no last-known entry")
	_check(_vision.hidden_last_known_buildings().is_empty(), "a hidden unit leaves no minimap ghost")
	_check(layer.ghosts().is_empty(), "a hidden unit leaves no world ghost")

	## It keeps moving out of sight: still nothing, and never a stale position.
	_place(runner, Vector2(-reach * 3.0, reach))
	_vision.update_vision()
	_check(not _vision.can_see_unit(runner), "a moving hidden unit stays hidden")
	_check(_vision.last_known_buildings().is_empty(), "a moving hidden unit still leaves no last-known entry")
	_check(_vision.hidden_last_known_buildings().is_empty(), "a moving hidden unit still leaves no minimap ghost")
	_end()


## §5.3: a remembered structure is forgotten the moment its spot is seen empty, and kept
## while the spot stays out of sight.
func _test_destroyed_structure_is_purged_on_re_reveal() -> void:
	_begin(RoleConfig.Role.HUNTER)
	var hunter := _spawn_unit(HUNTER_SCENE, ALLY_PEER_A, Vector2.ZERO)
	var reach := hunter.get_vision_range()
	var wall := _spawn_wall("DoomedWall", STRUCTURE_OWNER, Vector2(reach * 0.5, 0.0))
	var layer := LastKnownBuildingLayer.new()
	_world.add_child(layer)

	_vision.update_vision()
	_check(_vision.last_known_buildings().size() == 1, "the structure is remembered while in view")

	_place(hunter, Vector2(reach * 6.0, 0.0))
	_vision.update_vision()
	_check(layer.ghosts().size() == 1, "the structure is a ghost once out of view")

	## Destroyed outside vision: the old state stays on the map.
	wall.free()
	_vision.update_vision()
	_check(_vision.last_known_buildings().size() == 1, "a structure destroyed out of sight is still remembered")
	_check(_vision.hidden_last_known_buildings().size() == 1, "its ghost keeps showing the old state")
	_check(layer.ghosts().size() == 1, "the ghost layer keeps the destroyed structure while unseen")

	## Re-reveal the empty footprint: the memory is removed.
	_place(hunter, Vector2.ZERO)
	_vision.update_vision()
	_check(_vision.last_known_buildings().is_empty(), "seeing the empty footprint removes the destroyed structure")
	_check(_vision.hidden_last_known_buildings().is_empty(), "no ghost remains after the re-reveal")
	_check(layer.ghosts().is_empty(), "the ghost layer drops the destroyed structure")

	## Staying away afterwards does not bring it back.
	_place(hunter, Vector2(reach * 6.0, 0.0))
	_vision.update_vision()
	_check(_vision.last_known_buildings().is_empty(), "a purged structure does not come back out of sight")
	_end()


## §2: Runner and Hunter knowledge are separate. A new viewing team starts from scratch.
func _test_viewer_team_switch_discards_knowledge() -> void:
	_begin(RoleConfig.Role.HUNTER)
	var hunter := _spawn_unit(HUNTER_SCENE, ALLY_PEER_A, Vector2.ZERO)
	var reach := hunter.get_vision_range()
	var wall_pos := Vector2(reach * 0.5, 0.0)
	var wall := _spawn_wall("TeamWall", STRUCTURE_OWNER, wall_pos)
	_vision.update_vision()
	_check(_vision.viewer_role() == RoleConfig.Role.HUNTER, "the viewer is the Hunter team")
	_check(_vision.last_known_buildings().size() == 1, "the Hunter team remembers the Runner structure")

	_place(hunter, Vector2(reach * 6.0, 0.0))
	_set_viewer_role(RoleConfig.Role.RUNNER)
	_vision.update_vision()
	_check(_vision.viewer_role() == RoleConfig.Role.RUNNER, "switching the local role switches the viewing team")
	_check(_vision.last_known_buildings().is_empty(), "the Runner team has no Hunter-team structure knowledge")
	_check(_vision.can_see_building(wall), "the Runner team always sees its own structure")

	_set_viewer_role(RoleConfig.Role.HUNTER)
	_vision.update_vision()
	_check(_vision.last_known_buildings().is_empty(), "the earlier Hunter knowledge was discarded by the switch")
	_check(
		_vision.terrain_state(wall_pos) == VisionKnowledge.State.UNEXPLORED,
		"explored terrain was discarded by the switch"
	)
	_end()


## §7: fog off makes everything visible and reports no remembered structures. Turning it
## back on keeps what was gathered earlier.
func _test_fog_disabled() -> void:
	_begin(RoleConfig.Role.HUNTER)
	var hunter := _spawn_unit(HUNTER_SCENE, ALLY_PEER_A, Vector2.ZERO)
	var reach := hunter.get_vision_range()
	var wall := _spawn_wall("FogWall", STRUCTURE_OWNER, Vector2(reach * 0.5, 0.0))
	var far_runner := _spawn_unit(RUNNER_SCENE, ENEMY_PEER, Vector2(-reach * 6.0, 0.0))
	_vision.fog_enabled_changed.connect(func(enabled: bool) -> void: _fog_signals.append(enabled))

	_check(_vision.fog_enabled, "fog is on by default")
	_vision.update_vision()
	_check(_vision.last_known_buildings().size() == 1, "the structure is remembered with fog on")
	_check(not _vision.can_see_unit(far_runner), "a far enemy is hidden with fog on")

	_place(hunter, Vector2(reach * 6.0, 0.0))
	_vision.update_vision()
	_check(not _vision.can_see_building(wall), "the structure is hidden with fog on")
	_check(_vision.hidden_last_known_buildings().size() == 1, "the structure is a ghost with fog on")

	_vision.set_fog_enabled(false)
	_check(not _vision.fog_enabled, "set_fog_enabled(false) turns fog off")
	_check(_fog_signals == [false], "turning fog off emits fog_enabled_changed(false)")
	_check(_vision.can_see_unit(far_runner), "fog off: a far enemy unit is visible")
	_check(_vision.can_see_building(wall), "fog off: a hidden enemy structure is visible")
	_check(_vision.is_world_visible(Vector2(-3000.0, 2000.0)), "fog off: every point is visible")
	_check(
		_vision.terrain_state(Vector2(-3000.0, 2000.0)) == VisionKnowledge.State.VISIBLE,
		"fog off: terrain is reported Currently Visible"
	)
	_check(_vision.last_known_buildings().is_empty(), "fog off: last_known_buildings() is empty")
	_check(_vision.hidden_last_known_buildings().is_empty(), "fog off: no hidden last-known structures")
	_check(
		VisionPresentation.can_local_see(far_runner),
		"fog off: the presentation helper shows every unit"
	)

	## No knowledge is gathered while fog is off, even through a direct refresh.
	var late_wall := _spawn_wall("LateWall", STRUCTURE_OWNER, hunter.global_position + Vector2(reach * 0.25, 0.0))
	_vision.update_vision()
	_check(
		not _vision.knowledge.has_last_known_building(str(late_wall.get_path())),
		"fog off: a refresh gathers no new knowledge"
	)
	_check(
		_vision.knowledge.last_known_buildings().size() == 1,
		"fog off: earlier knowledge is kept in the background"
	)

	_vision.set_fog_enabled(true)
	_check(_fog_signals == [false, true], "turning fog on emits fog_enabled_changed(true)")
	_vision.set_fog_enabled(true)
	_check(_fog_signals.size() == 2, "setting the same fog state again emits nothing")
	_vision.update_vision()
	_check(not _vision.can_see_unit(far_runner), "fog on again: the far enemy is hidden")
	_check(
		_vision.last_known_buildings().size() == 2,
		"fog on again: earlier knowledge is kept and new sight is gathered"
	)
	_check(_vision.can_see_building(late_wall), "fog on again: the nearby structure is visible")
	_check(not _vision.can_see_building(wall), "fog on again: the far structure is hidden again")
	_end()


## §10: world presentation only follows what VisionSystem allows.
func _test_presentation_follows_vision() -> void:
	_begin(RoleConfig.Role.HUNTER)
	var hunter := _spawn_unit(HUNTER_SCENE, ALLY_PEER_A, Vector2.ZERO)
	var reach := hunter.get_vision_range()
	var runner := _spawn_unit(RUNNER_SCENE, ENEMY_PEER, Vector2(reach * 0.5, 0.0))
	var wall := _spawn_wall("ShownWall", STRUCTURE_OWNER, Vector2(reach * 0.25, 0.0))
	var presenter := EntityVisionPresenter.new()
	_world.add_child(presenter)

	_vision.update_vision()
	presenter._process(0.0)
	_check(runner.visible, "presenter: an enemy unit in view is shown")
	_check(wall.visible, "presenter: an enemy structure in view is shown")
	_check(hunter.visible, "presenter: own units are shown")
	_check(VisionPresentation.can_local_see(runner), "can_local_see: the enemy in view is visible")

	_place(hunter, Vector2(reach * 6.0, 0.0))
	_vision.update_vision()
	presenter._process(0.0)
	_check(not runner.visible, "presenter: an enemy unit out of view is hidden")
	_check(not wall.visible, "presenter: an enemy structure out of view is hidden")
	_check(hunter.visible, "presenter: own units stay shown")
	_check(not VisionPresentation.can_local_see(runner), "can_local_see: the hidden enemy is not visible")

	_place(hunter, Vector2.ZERO)
	_vision.update_vision()
	presenter._process(0.0)
	_check(runner.visible and wall.visible, "presenter: entities return when they re-enter vision")
	_end()


# --- Harness ------------------------------------------------------------------------------


## Fresh world with a VisionSystem and `viewer` as the local player's team.
func _begin(viewer: int) -> void:
	GameManager.prepare_game_test()
	_set_viewer_role(viewer)
	_fog_signals.clear()
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	_vision = VisionSystem.new()
	_vision.name = "VisionSystem"
	_world.add_child(_vision)
	## Tests refresh by hand; the physics tick must not interleave.
	_vision.set_physics_process(false)


func _end() -> void:
	if _world != null and is_instance_valid(_world):
		_world.free()
	_world = null
	_vision = null


func _set_viewer_role(role: int) -> void:
	var entry: Dictionary = GameManager.players[LOCAL_PEER_ID]
	entry["role"] = role
	GameManager.players[LOCAL_PEER_ID] = entry


func _spawn_unit(scene: PackedScene, peer_id: int, at: Vector2) -> Unit:
	var unit := scene.instantiate() as Unit
	## Unit reads its peer id from the node name.
	unit.name = str(peer_id)
	_world.add_child(unit)
	## Positions are driven by the test, not by movement or replication.
	unit.set_physics_process(false)
	_place(unit, at)
	return unit


func _spawn_wall(node_name: String, owner_peer_id: int, at: Vector2) -> Building:
	var wall := WALL_SCENE.instantiate() as Building
	wall.name = node_name
	wall.owner_peer_id = owner_peer_id
	_world.add_child(wall)
	wall.set_physics_process(false)
	## Skip the construction timer: a finished structure.
	wall.state = Building.State.IDLE
	wall.global_position = at
	return wall


func _place(unit: Unit, at: Vector2) -> void:
	unit.global_position = at
	unit.sync_position = at


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _near(actual: float, expected: float, message: String, eps := 0.01) -> void:
	if absf(actual - expected) > eps:
		_failures.append("%s (got %s expected %s)" % [message, actual, expected])
