extends Node2D
## Headless checks for WP-16 D: ShieldComponent, the wall shield track, Building.apply_damage()
## as the single structure damage entry point, the Runner `repair` skill, and Hunter Crystal
## income from melee hits.
##   godot --headless --path . res://tests/skills/repair_skill_test.tscn

const BUILDING_SCENE := preload("res://src/buildings/building.tscn")
const WALL_SCENE := preload("res://src/buildings/wall.tscn")
const TOWER_SCENE := preload("res://src/buildings/tower.tscn")
const RUNNER_SCENE := preload("res://src/units/runner/runner.tscn")
const HUNTER_SCENE := preload("res://src/units/hunter/hunter.tscn")

const RUNNER_PEER_ID := 1
const OTHER_PEER_ID := 2

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	GameManager.prepare_game_test()
	_test_shield_component()
	_test_level_one_wall_has_no_shield()
	_test_shield_unlocks_at_its_level()
	_test_shield_soaks_damage_first()
	_test_shield_recharges_after_its_delay()
	_test_only_walls_get_a_shield()
	_test_legacy_building_ignores_damage_and_repair()
	_test_repair_validation()
	_test_shared_skill_icons()
	_test_repair_channel_heals_until_full()
	_test_repair_walks_into_range()
	_test_other_commands_cancel_repair()
	_test_death_and_phase_lock_cancel_repair()
	_test_repair_reaims_while_out_of_reach()
	_test_shield_and_repair_numbers_are_pinned()
	_test_repair_never_restores_the_shield()
	_test_hunter_earns_crystals_on_hits()
	if _failures.is_empty():
		print("PASS: repair skill")
		get_tree().quit(0)
	else:
		print("FAIL: %d check(s)" % _failures.size())
		for failure in _failures:
			print(" - %s" % failure)
		get_tree().quit(1)


func _test_shield_component() -> void:
	var shield := ShieldComponent.new()
	add_child(shield)
	shield.setup(100.0, 2.0, 0.1)
	_check(shield.has_shield(), "a shield with a positive maximum is active")
	_near(shield.current, 100.0, "a shield starts full")
	_near(shield.absorb(30.0), 30.0, "a shield absorbs a hit smaller than itself")
	_near(shield.current, 70.0, "the absorbed amount leaves the shield")
	_near(shield.absorb(100.0), 70.0, "a shield absorbs at most what it has left")
	_near(shield.current, 0.0, "an overflowing hit empties the shield")

	shield.tick(1.0)
	shield.tick(1.0)
	_near(shield.current, 0.0, "no recharge until the delay has fully elapsed")
	shield.tick(1.0)
	_near(shield.current, 10.0, "after the delay the shield restores recharge_per_second of its maximum")

	shield.absorb(5.0)
	shield.tick(1.0)
	_near(shield.current, 5.0, "a new hit restarts the recharge delay")
	shield.absorb(0.0)
	_near(shield.current, 5.0, "a zero hit changes nothing")

	shield.set_maximum(0.0)
	_check(not shield.has_shield(), "a zero maximum means no shield")
	_near(shield.current, 0.0, "a zero maximum clamps the current value")
	shield.tick(10.0)
	_near(shield.current, 0.0, "a shield with no maximum never recharges")

	var empty := ShieldComponent.new()
	add_child(empty)
	empty.setup(0.0, 6.0, 0.05)
	_near(empty.absorb(10.0), 0.0, "a zero shield absorbs nothing and passes the hit on")
	shield.queue_free()
	empty.queue_free()


func _test_level_one_wall_has_no_shield() -> void:
	var wall := _wall("LvOneWall", RUNNER_PEER_ID, Vector2.ZERO)
	_near(wall.max_shield, 0.0, "a level 1 wall has no shield")
	_check(not wall.shield_bar.visible, "a level 1 wall hides its shield bar")
	var before := wall.health.current
	_near(wall.apply_damage(50.0), 50.0, "apply_damage returns what it applied")
	_near(wall.health.current, before - 50.0, "without a shield the hit goes straight to health")
	_near(wall.sync_current_health, wall.health.current, "apply_damage keeps the health shadow in sync")
	wall.queue_free()


func _test_shield_unlocks_at_its_level() -> void:
	var wall := _wall("UnlockWall", RUNNER_PEER_ID, Vector2.ZERO)
	var def := wall.def
	_level_to(wall, def.shield_unlock_level - 1)
	_near(wall.max_shield, 0.0, "no shield one level below shield_unlock_level")
	_level_to(wall, def.shield_unlock_level)
	_near(wall.max_shield, def.shield_base, "the shield appears at shield_base on the unlock level")
	_near(wall.shield.current, wall.max_shield, "a freshly unlocked shield starts full")
	_near(wall.sync_current_shield, wall.shield.current, "the shield shadow is replicated state")
	_check(wall.shield_bar.visible, "an unlocked shield shows its bar")
	_level_to(wall, def.shield_unlock_level + 1)
	_near(
		wall.max_shield,
		def.shield_base * def.shield_growth,
		"the shield grows by shield_growth per level above the unlock"
	)
	_near(wall.shield.current, wall.max_shield, "a level-up grants the extra shield immediately")
	wall.queue_free()


func _test_shield_soaks_damage_first() -> void:
	var wall := _wall("SoakWall", RUNNER_PEER_ID, Vector2.ZERO)
	_level_to(wall, wall.def.shield_unlock_level)
	var shield_max := wall.max_shield
	var health_max := wall.max_health
	_near(wall.apply_damage(100.0), 100.0, "a shielded hit reports its full amount as applied")
	_near(wall.shield.current, shield_max - 100.0, "the shield takes the hit first")
	_near(wall.health.current, health_max, "health is untouched while the shield holds")
	var overflow := 300.0
	var big_hit := wall.shield.current + overflow
	_near(wall.apply_damage(big_hit), big_hit, "a hit that breaks the shield applies shield + health")
	_near(wall.shield.current, 0.0, "the shield is empty after a breaking hit")
	_near(wall.health.current, health_max - overflow, "only the overflow reaches health")
	wall.queue_free()


func _test_shield_recharges_after_its_delay() -> void:
	var wall := _wall("RechargeWall", RUNNER_PEER_ID, Vector2.ZERO)
	var def := wall.def
	_level_to(wall, def.shield_unlock_level)
	wall.apply_damage(wall.shield.current)
	_near(wall.shield.current, 0.0, "the shield is drained for the recharge check")
	wall.server_tick(def.shield_recharge_delay - 0.5)
	wall.server_tick(0.5)
	_near(wall.shield.current, 0.0, "the shield waits out shield_recharge_delay")
	wall.server_tick(1.0)
	_near(
		wall.shield.current,
		wall.max_shield * def.shield_recharge_per_second,
		"after the delay the shield refills shield_recharge_per_second of its maximum per second"
	)
	_near(wall.sync_current_shield, wall.shield.current, "server_tick replicates the recharged shield")
	wall.queue_free()


func _test_only_walls_get_a_shield() -> void:
	var tower := _building(TOWER_SCENE, "NoShieldTower", RUNNER_PEER_ID, Vector2.ZERO)
	_level_to(tower, tower.def.max_level)
	_near(tower.max_shield, 0.0, "a max-level tower never gets a shield")
	tower.queue_free()


func _test_legacy_building_ignores_damage_and_repair() -> void:
	## def == null is the CP-11 footprint-only path (building_grid_test.tscn).
	var legacy := BUILDING_SCENE.instantiate() as Building
	legacy.name = "LegacyBuilding"
	add_child(legacy)
	_check(not legacy.is_attackable(), "a legacy building is not attackable")
	_near(legacy.apply_damage(50.0), 0.0, "apply_damage on a legacy building applies nothing")
	_near(legacy.repair(50.0), 0.0, "repair on a legacy building restores nothing")
	_check(not legacy.is_damaged(), "a legacy building never counts as damaged")
	_check(not legacy.shield_bar.visible, "a legacy building hides the shield bar")
	legacy.queue_free()


func _test_repair_validation() -> void:
	var runner := _runner("RunnerA", RUNNER_PEER_ID, Vector2(40.0, 0.0))
	var wall := _wall("ValidWall", RUNNER_PEER_ID, Vector2.ZERO)
	_check(not RepairSkill.can_repair(runner, wall), "a full-HP structure cannot be repaired")
	## Host and client can disagree (healed meanwhile): the click must still do something.
	runner._server_begin_repair(wall)
	_check(not runner.is_repairing(), "a rejected repair starts no channel")
	_check(runner.movement.has_order(), "a rejected repair falls back to a move toward the structure")
	runner.movement.clear_order()
	wall.apply_damage(100.0)
	_check(RepairSkill.can_repair(runner, wall), "an own, finished, damaged structure can be repaired")

	var foreign := _wall("ForeignWall", OTHER_PEER_ID, Vector2(200.0, 0.0))
	foreign.apply_damage(100.0)
	_check(not RepairSkill.can_repair(runner, foreign), "another player's structure cannot be repaired")

	var fresh := WALL_SCENE.instantiate() as Building
	fresh.name = "FreshWall"
	fresh.owner_peer_id = RUNNER_PEER_ID
	add_child(fresh)
	fresh.apply_damage(50.0)
	_check(fresh.state == Building.State.UNDER_CONSTRUCTION, "a fresh wall is still under construction")
	_check(not RepairSkill.can_repair(runner, fresh), "a structure under construction cannot be repaired")
	_near(fresh.repair(10.0), 0.0, "Building.repair refuses a structure under construction")

	wall.state = Building.State.UPGRADING
	_check(RepairSkill.can_repair(runner, wall), "an upgrading structure can still be repaired")
	wall.state = Building.State.IDLE

	var hunter := _hunter("HunterA", RUNNER_PEER_ID, Vector2(40.0, 0.0))
	_check(not RepairSkill.can_repair(hunter, wall), "only the Runner role can repair")
	_check(not RepairSkill.can_repair(runner, null), "a null structure is rejected")

	runner.get_parent().queue_free()
	hunter.get_parent().queue_free()
	wall.queue_free()
	foreign.queue_free()
	fresh.queue_free()


func _test_shared_skill_icons() -> void:
	_check(
		SkillIcons.icon_for(RepairSkill.DEF.id) != null,
		"Runner Repair has a shared skill icon"
	)
	_check(
		SkillIcons.icon_for(SeekSkill.DEF.id) != null,
		"Hunter Seek has a shared skill icon"
	)


func _test_repair_channel_heals_until_full() -> void:
	var wall := _wall("ChannelWall", RUNNER_PEER_ID, Vector2.ZERO)
	var runner := _runner("RunnerB", RUNNER_PEER_ID, Vector2(40.0, 0.0))
	var missing := RepairSkill.DEF.value_per_second * 3.5
	wall.apply_damage(missing)
	var damaged := wall.health.current
	_check(RepairSkill.in_range(runner, wall), "a Runner next to the wall is in repair reach")
	runner._server_begin_repair(wall)
	_check(runner.is_repairing(), "a valid repair order starts the channel")
	_check(not runner.movement.has_order(), "an in-reach repair does not walk")
	runner.server_repair_tick(1.0)
	_near(wall.health.current, damaged + RepairSkill.DEF.value_per_second, "one second heals value_per_second")
	_near(wall.sync_current_health, wall.health.current, "repair keeps the health shadow in sync")
	for _i in 5:
		runner.server_repair_tick(1.0)
	_near(wall.health.current, wall.max_health, "repair never overheals past max HP")
	runner.server_repair_tick(1.0)
	_check(not runner.is_repairing(), "the channel ends once the structure is full")
	runner.get_parent().queue_free()
	wall.queue_free()


func _test_repair_walks_into_range() -> void:
	var wall := _wall("FarWall", RUNNER_PEER_ID, Vector2.ZERO)
	var runner := _runner("RunnerC", RUNNER_PEER_ID, Vector2(600.0, 0.0))
	wall.apply_damage(100.0)
	var damaged := wall.health.current
	_check(not RepairSkill.in_range(runner, wall), "a distant Runner is out of repair reach")
	runner._server_begin_repair(wall)
	_check(runner.is_repairing(), "an out-of-reach repair order is still accepted")
	_check(runner.movement.has_order(), "an out-of-reach repair walks toward the structure")
	runner.server_repair_tick(1.0)
	_near(wall.health.current, damaged, "nothing is healed while out of reach")
	var stand := RepairSkill.approach_point(runner, wall)
	_check(
		stand.distance_to(wall.global_position) <= RepairSkill.reach(wall),
		"the approach point lies inside the repair reach"
	)
	runner.get_parent().queue_free()
	wall.queue_free()


func _test_other_commands_cancel_repair() -> void:
	var wall := _wall("CancelWall", RUNNER_PEER_ID, Vector2.ZERO)
	var runner := _runner("RunnerD", RUNNER_PEER_ID, Vector2(40.0, 0.0))
	wall.apply_damage(100.0)
	runner._server_begin_repair(wall)
	runner._request_move(Vector2(300.0, 0.0))
	_check(not runner.is_repairing(), "a move order cancels the repair")
	runner._server_begin_repair(wall)
	runner._server_chain_append(Vector2(300.0, 0.0))
	_check(not runner.is_repairing(), "a chain waypoint cancels the repair")
	runner._server_begin_repair(wall)
	_check(runner.is_repairing(), "the repair restarts for the freed-structure check")
	## free(), not queue_free(): the structure must be gone before the next tick.
	wall.free()
	runner.server_repair_tick(1.0)
	_check(not runner.is_repairing(), "a freed structure ends the channel without an error")
	runner.get_parent().queue_free()


func _test_death_and_phase_lock_cancel_repair() -> void:
	var wall := _wall("LockWall", RUNNER_PEER_ID, Vector2.ZERO)
	var runner := _runner("RunnerF", RUNNER_PEER_ID, Vector2(40.0, 0.0))
	wall.apply_damage(100.0)

	runner._server_begin_repair(wall)
	runner._request_attack_move(Vector2(300.0, 0.0))
	_check(not runner.is_repairing(), "an attack-move cancels the repair")

	runner._server_begin_repair(wall)
	var previous_phase := GameManager.phase
	GameManager.phase = GameManager.Phase.LOBBY
	runner._physics_process(0.1)
	GameManager.phase = previous_phase
	_check(not runner.is_repairing(), "a phase that locks movement cancels the repair")

	## Peer 6 is not in the roster, so its death cannot end the test match.
	var doomed_wall := _wall("DoomedOwnerWall", 6, Vector2(200.0, 0.0))
	doomed_wall.apply_damage(100.0)
	var doomed := _runner("RunnerDoomed", 6, Vector2(240.0, 0.0))
	doomed._server_begin_repair(doomed_wall)
	_check(doomed.is_repairing(), "the doomed Runner starts repairing its own wall")
	doomed.health.take_damage(doomed.health.current, doomed.health.current)
	_check(not doomed.is_repairing(), "death cancels the repair")

	runner.get_parent().queue_free()
	doomed.get_parent().queue_free()
	wall.queue_free()
	doomed_wall.queue_free()


func _test_repair_reaims_while_out_of_reach() -> void:
	var wall := _wall("ReaimWall", RUNNER_PEER_ID, Vector2.ZERO)
	var runner := _runner("RunnerG", RUNNER_PEER_ID, Vector2(600.0, 0.0))
	wall.apply_damage(100.0)
	runner._server_begin_repair(wall)
	## Simulate an order that ended (or got stuck) short of the reach.
	runner.movement.clear_order()
	runner.server_repair_tick(0.2)
	_check(not runner.movement.has_order(), "no re-aim before the 0.5 s cadence")
	runner.server_repair_tick(0.4)
	_check(runner.movement.has_order(), "the repair re-aims toward the structure every 0.5 s")
	_check(runner.is_repairing(), "re-aiming keeps the channel alive")
	runner.get_parent().queue_free()
	wall.queue_free()


## The other checks compare against values read back from the defs; these pin the balance
## literally so a bad edit to wall_def.tres / repair_def.tres fails loudly.
func _test_shield_and_repair_numbers_are_pinned() -> void:
	var def := ConstructionManager.WALL_DEF
	_check(def.shield_unlock_level == 15, "wall shield unlocks at level 15")
	_near(def.shield_base, 900.0, "wall shield base")
	_near(def.shield_growth, 1.18, "wall shield growth")
	_near(def.shield_recharge_delay, 6.0, "wall shield recharge delay")
	_near(def.shield_recharge_per_second, 0.05, "wall shield recharge rate")
	_near(RepairSkill.DEF.value_per_second, 20.0, "repair HP per second")
	_near(RepairSkill.DEF.cast_range, 48.0, "repair cast range")
	_check(RepairSkill.DEF.role == RoleConfig.Role.RUNNER, "repair belongs to the Runner")


func _test_repair_never_restores_the_shield() -> void:
	var wall := _wall("ShieldRepairWall", RUNNER_PEER_ID, Vector2.ZERO)
	_level_to(wall, wall.def.shield_unlock_level)
	var runner := _runner("RunnerE", RUNNER_PEER_ID, Vector2(40.0, 0.0))
	wall.apply_damage(wall.shield.current + 200.0)
	runner._server_begin_repair(wall)
	runner.server_repair_tick(1.0)
	_near(wall.shield.current, 0.0, "repair restores health only, never the shield")
	_near(
		wall.health.current,
		wall.max_health - 200.0 + RepairSkill.DEF.value_per_second,
		"repair on a shielded wall still heals its health"
	)
	runner.get_parent().queue_free()
	wall.queue_free()


func _test_hunter_earns_crystals_on_hits() -> void:
	var rate := GameManager.economy_config.hunter_crystals_per_damage
	## award_damage_crystals pays the attacker's roster entry; peer 1 is the only one.
	var hunter := _hunter("HunterB", RUNNER_PEER_ID, Vector2.ZERO)

	var wall := _wall("IncomeWall", OTHER_PEER_ID, Vector2(40.0, 0.0))
	var wall_before := wall.health.current + wall.shield.current
	var crystals_before := GameManager.crystals_for(RUNNER_PEER_ID)
	hunter._perform_melee_on_building(wall)
	var wall_applied := wall_before - (wall.health.current + wall.shield.current)
	_check(wall_applied > 0.0, "a Hunter swing damages a structure")
	_near(
		GameManager.crystals_for(RUNNER_PEER_ID) - crystals_before,
		wall_applied * rate,
		"a hit on a structure pays hunter_crystals_per_damage per point applied"
	)

	var victim := _runner("RunnerVictim", 5, Vector2(-40.0, 0.0))
	var victim_before := victim.health.current
	crystals_before = GameManager.crystals_for(RUNNER_PEER_ID)
	hunter._perform_melee_on_unit(victim)
	var unit_applied := victim_before - victim.health.current
	_check(unit_applied > 0.0, "a Hunter swing damages a Runner")
	_near(
		GameManager.crystals_for(RUNNER_PEER_ID) - crystals_before,
		unit_applied * rate,
		"a hit on a Runner pays hunter_crystals_per_damage per point applied"
	)
	hunter.get_parent().queue_free()
	victim.get_parent().queue_free()
	wall.queue_free()


## Levels a building up by running the real upgrade path without waiting for build timers.
func _level_to(building: Building, target_level: int) -> void:
	while building.level < target_level:
		building.state = Building.State.IDLE
		building.begin_upgrade()
		building._complete_construction()
	building.state = Building.State.IDLE


## A finished (IDLE) level 1 wall.
func _wall(node_name: String, owner_id: int, at: Vector2) -> Building:
	return _building(WALL_SCENE, node_name, owner_id, at)


func _building(scene: PackedScene, node_name: String, owner_id: int, at: Vector2) -> Building:
	var building := scene.instantiate() as Building
	building.name = node_name
	building.owner_peer_id = owner_id
	add_child(building)
	building.global_position = at
	building.state = Building.State.IDLE
	building.progress_ratio = 0.0
	return building


## Units take their peer id from the node name, so each one gets its own parent to keep
## the name ("1", "5", ...) from colliding with a sibling.
func _runner(holder_name: String, peer: int, at: Vector2) -> Unit:
	return _unit(RUNNER_SCENE, holder_name, peer, at)


func _hunter(holder_name: String, peer: int, at: Vector2) -> Unit:
	return _unit(HUNTER_SCENE, holder_name, peer, at)


func _unit(scene: PackedScene, holder_name: String, peer: int, at: Vector2) -> Unit:
	var holder := Node2D.new()
	holder.name = holder_name
	add_child(holder)
	var unit := scene.instantiate() as Unit
	unit.name = str(peer)
	holder.add_child(unit)
	unit.global_position = at
	return unit


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _near(actual: float, expected: float, message: String, eps := 0.01) -> void:
	if absf(actual - expected) > eps:
		_failures.append("%s (got %s expected %s)" % [message, actual, expected])
