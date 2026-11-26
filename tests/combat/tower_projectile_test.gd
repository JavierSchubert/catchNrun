extends Node
## Headless checks for the WP-C tower: projectile impact, the four upgrade stat paths, and
## the host-side pick validation in ConstructionManager (docs/construction.README.md §5, §7).
##   godot --headless --path . res://tests/combat/tower_projectile_test.tscn

const PROJECTILE_SCENE := preload("res://src/combat/projectile.tscn")
const TOWER_SCENE := preload("res://src/buildings/tower.tscn")
const WALL_SCENE := preload("res://src/buildings/wall.tscn")
const MINE_SCENE := preload("res://src/buildings/crystal_mine.tscn")
const HUNTER_SCENE := preload("res://src/units/hunter/hunter.tscn")

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_test_projectile_hits_once()
	_test_projectile_skips_a_dead_target()
	_test_projectile_skips_a_freed_target()
	_test_projectile_expires()
	_test_tower_stats_come_from_the_stat_block()
	_test_each_pick_moves_its_stat()
	_test_picks_stack()
	_test_legacy_tower_fields_are_gone()
	_test_tower_def_numbers_are_pinned()
	_test_tower_shot_damages_a_hunter()
	_test_tower_upgrade_requires_a_pick()
	_test_wall_and_mine_upgrade_without_a_pick()
	if _failures.is_empty():
		print("PASS: tower projectile")
		get_tree().quit(0)
	else:
		print("FAIL: %d check(s)" % _failures.size())
		for failure in _failures:
			print(" - %s" % failure)
		get_tree().quit(1)


func _test_projectile_hits_once() -> void:
	var target := _dummy_target(Vector2(200.0, 0.0))
	var health := HealthComponent.new()
	add_child(health)
	health.setup(100.0)
	## Boxed so the lambda can mutate it: GDScript lambdas capture locals by value.
	var hits := [0]
	var on_hit := func(_hit_target: Node2D) -> void:
		hits[0] += 1
		health.take_damage(25.0, 100.0)
	var projectile := _projectile(target, 400.0, on_hit)

	projectile.advance(0.3)
	_check(hits[0] == 0, "a projectile in flight has not hit yet")
	_check(projectile.global_position.distance_to(Vector2.ZERO) > 0.0, "a projectile moves toward its target")

	projectile.advance(0.3)
	_check(hits[0] == 1, "a projectile hits when it arrives")
	_near(health.current, 75.0, "the impact applies its damage")

	projectile.advance(0.3)
	projectile.advance(0.3)
	_check(hits[0] == 1, "a projectile applies its damage exactly once")
	_near(health.current, 75.0, "no further damage after the impact")


func _test_projectile_skips_a_dead_target() -> void:
	var target := _dummy_target(Vector2(200.0, 0.0))
	var hits := [0]
	var on_hit := func(_hit_target: Node2D) -> void:
		hits[0] += 1
	var projectile := _projectile(target, 400.0, on_hit)
	projectile.advance(0.3)
	target.alive = false
	projectile.advance(0.3)
	projectile.advance(0.3)
	_check(hits[0] == 0, "a projectile applies nothing when the target dies in flight")


func _test_projectile_skips_a_freed_target() -> void:
	var target := _dummy_target(Vector2(200.0, 0.0))
	var hits := [0]
	var on_hit := func(_hit_target: Node2D) -> void:
		hits[0] += 1
	var projectile := _projectile(target, 400.0, on_hit)
	projectile.advance(0.3)
	target.free()
	projectile.advance(0.3)
	_check(hits[0] == 0, "a projectile applies nothing when the target is freed in flight")


func _test_projectile_expires() -> void:
	## A target far outside any reachable distance: the sanity timeout must clean up.
	var target := _dummy_target(Vector2(1.0e9, 0.0))
	var hits := [0]
	var on_hit := func(_hit_target: Node2D) -> void:
		hits[0] += 1
	var projectile := _projectile(target, 10.0, on_hit)
	projectile.advance(Projectile.MAX_LIFETIME + 1.0)
	_check(hits[0] == 0, "an expired projectile applies nothing")
	_check(projectile.is_queued_for_deletion(), "an expired projectile frees itself")


func _test_tower_stats_come_from_the_stat_block() -> void:
	var tower := _building(TOWER_SCENE, "StatTower")
	var def := tower.def
	_check(def != null, "the tower scene carries a BuildingDef")
	if def == null:
		return
	_check(def.tower_base_stats != null, "the tower def carries a tower_base_stats StatBlock")
	_near(
		tower.stats.final_value(StatBlock.Stat.RANGED_DAMAGE),
		def.tower_base_stats.ranged_damage,
		"a fresh tower's ranged damage is the StatBlock base"
	)
	## The HP trap: tower_base_stats.max_health must never reach the HealthComponent.
	_near(tower.max_health, def.hp_for_level(1), "tower max HP comes from hp_for_level, not the StatBlock")
	_near(tower.health.current, def.hp_for_level(1), "a fresh tower starts at full HP")
	_check(tower.health.is_alive(), "a fresh tower is alive and targetable")
	_check(tower.tower_picks.size() == BuildingDef.TowerPath.size(), "a tower has one counter per TowerPath")
	## The attack controller is derived from the sheet, mirroring Unit._apply_derived_stats().
	_near(
		tower.attack.attack_range,
		def.tower_base_stats.attack_range,
		"the attack range is derived from ATTACK_RANGE"
	)
	_near(tower.attack.acquisition_range, tower.attack.attack_range, "acquisition range matches attack range")
	_near(
		tower.attack.attack_interval,
		1.0 / def.tower_base_stats.attack_speed,
		"the attack interval is 1 / ATTACK_SPEED"
	)
	tower.queue_free()


func _test_each_pick_moves_its_stat() -> void:
	var tower := _building(TOWER_SCENE, "PickTower")
	var def := tower.def
	if def == null:
		return
	var base_damage := tower.stats.final_value(StatBlock.Stat.RANGED_DAMAGE)
	var base_speed := tower.stats.final_value(StatBlock.Stat.ATTACK_SPEED)
	var base_crit := tower.stats.final_value(StatBlock.Stat.CRITICAL_CHANCE)
	var base_crit_damage := tower.stats.final_value(StatBlock.Stat.CRITICAL_DAMAGE_MULTIPLIER)
	var base_range := tower.stats.final_value(StatBlock.Stat.ATTACK_RANGE)

	tower.apply_tower_pick(BuildingDef.TowerPath.RANGED_DAMAGE)
	_near(
		tower.stats.final_value(StatBlock.Stat.RANGED_DAMAGE),
		base_damage * (1.0 + def.tower_damage_per_pick),
		"a Damage pick raises RANGED_DAMAGE by tower_damage_per_pick"
	)

	tower.apply_tower_pick(BuildingDef.TowerPath.ATTACK_SPEED)
	var expected_speed := base_speed * (1.0 + def.tower_attack_speed_per_pick)
	_near(
		tower.stats.final_value(StatBlock.Stat.ATTACK_SPEED),
		expected_speed,
		"an Attack Speed pick raises ATTACK_SPEED by tower_attack_speed_per_pick"
	)
	_near(tower.attack.attack_interval, 1.0 / expected_speed, "the cooldown follows the new attack speed")

	tower.apply_tower_pick(BuildingDef.TowerPath.CRIT)
	## Flat, not percent: the base crit chance is 0 and a percentage of zero is still zero.
	_near(
		tower.stats.final_value(StatBlock.Stat.CRITICAL_CHANCE),
		base_crit + def.tower_crit_chance_per_pick,
		"a Crit pick adds tower_crit_chance_per_pick as a flat value"
	)
	_check(
		tower.stats.final_value(StatBlock.Stat.CRITICAL_CHANCE) > 0.0,
		"a Crit pick actually grants crit chance from a zero base"
	)
	_near(
		tower.stats.final_value(StatBlock.Stat.CRITICAL_DAMAGE_MULTIPLIER),
		base_crit_damage + def.tower_crit_damage_per_pick,
		"a Crit pick also adds tower_crit_damage_per_pick to the crit multiplier"
	)

	tower.apply_tower_pick(BuildingDef.TowerPath.ATTACK_RANGE)
	var expected_range := base_range * (1.0 + def.tower_range_per_pick)
	_near(
		tower.stats.final_value(StatBlock.Stat.ATTACK_RANGE),
		expected_range,
		"a Range pick raises ATTACK_RANGE by tower_range_per_pick"
	)
	_near(tower.attack.attack_range, expected_range, "the attack controller follows the new range")

	## Paths are independent: taking three others must not move the first one.
	_near(
		tower.stats.final_value(StatBlock.Stat.RANGED_DAMAGE),
		base_damage * (1.0 + def.tower_damage_per_pick),
		"picks on other paths leave RANGED_DAMAGE alone"
	)
	tower.queue_free()


func _test_picks_stack() -> void:
	var tower := _building(TOWER_SCENE, "StackTower")
	var def := tower.def
	if def == null:
		return
	var base_damage := tower.stats.final_value(StatBlock.Stat.RANGED_DAMAGE)
	var base_crit := tower.stats.final_value(StatBlock.Stat.CRITICAL_CHANCE)
	for _i in 3:
		tower.apply_tower_pick(BuildingDef.TowerPath.RANGED_DAMAGE)
	_check(tower.tower_pick_count(BuildingDef.TowerPath.RANGED_DAMAGE) == 3, "three Damage picks are counted")
	## Percentage modifiers sum, they do not compound.
	_near(
		tower.stats.final_value(StatBlock.Stat.RANGED_DAMAGE),
		base_damage * (1.0 + 3.0 * def.tower_damage_per_pick),
		"stacked Damage picks sum their percentages"
	)
	for _i in 4:
		tower.apply_tower_pick(BuildingDef.TowerPath.CRIT)
	_near(
		tower.stats.final_value(StatBlock.Stat.CRITICAL_CHANCE),
		base_crit + 4.0 * def.tower_crit_chance_per_pick,
		"stacked Crit picks accumulate flat crit chance"
	)
	## An out-of-range path is ignored instead of corrupting the counters.
	tower.apply_tower_pick(-1)
	tower.apply_tower_pick(BuildingDef.TowerPath.size())
	_check(tower.tower_pick_count(BuildingDef.TowerPath.RANGED_DAMAGE) == 3, "an invalid path records nothing")
	tower.queue_free()


func _test_legacy_tower_fields_are_gone() -> void:
	var def := ConstructionManager.TOWER_DEF
	for legacy in ["tower_base_damage", "tower_damage_growth", "tower_range", "tower_attack_interval"]:
		_check(not _has_property(def, legacy), "the legacy field %s is removed from BuildingDef" % legacy)
	_check(
		not def.has_method("tower_damage_for_level"),
		"the legacy per-level damage curve tower_damage_for_level() is removed"
	)


## The checks above compare against values read back from the def, so a bad edit to
## tower_def.tres would still pass them. These pin the confirmed balance literally.
func _test_tower_def_numbers_are_pinned() -> void:
	var def := ConstructionManager.TOWER_DEF
	var base := def.tower_base_stats
	_check(base != null, "tower_def.tres carries tower_base_stats")
	if base == null:
		return
	_near(base.ranged_damage, 18.0, "tower base ranged damage")
	_near(base.attack_speed, 1.0, "tower base attack speed")
	_near(base.attack_range, 280.0, "tower base attack range")
	_near(base.critical_chance, 0.0, "tower base crit chance")
	_near(base.critical_damage_multiplier, 1.5, "tower base crit multiplier")
	_near(def.tower_damage_per_pick, 0.30, "Damage pick increment")
	_near(def.tower_attack_speed_per_pick, 0.20, "Attack Speed pick increment")
	_near(def.tower_crit_chance_per_pick, 0.08, "Crit pick chance increment")
	_near(def.tower_crit_damage_per_pick, 0.15, "Crit pick multiplier increment")
	_near(def.tower_range_per_pick, 0.15, "Range pick increment")
	_near(def.tower_projectile_speed, 650.0, "tower projectile speed")


## The real path end to end: _tick_tower picks the Hunter, the projectile lands, and the HP
## drop arrives through _on_projectile_hit with the replicated shadow updated.
func _test_tower_shot_damages_a_hunter() -> void:
	var tower := _building(TOWER_SCENE, "ShotTower")
	tower.state = Building.State.IDLE
	tower.global_position = Vector2.ZERO
	var holder := Node2D.new()
	holder.name = "ShotHunterHolder"
	add_child(holder)
	var hunter := HUNTER_SCENE.instantiate() as Unit
	## Unit takes its peer id from the node name.
	hunter.name = "7"
	holder.add_child(hunter)
	hunter.global_position = Vector2(100.0, 0.0)
	var max_hp := hunter.health.current
	var expected := maxf(
		0.0,
		tower.stats.final_value(StatBlock.Stat.RANGED_DAMAGE)
			- hunter.stats.final_value(StatBlock.Stat.DEFENSE) * 0.25
	)

	tower.server_tick(0.1)
	var shot := _projectile_aimed_at(hunter)
	_check(shot != null, "a tower fires at a Hunter in range")
	_near(hunter.health.current, max_hp, "the Hunter loses nothing at the moment of firing")
	if shot != null:
		for _i in 10:
			shot.advance(0.1)
	_near(hunter.health.current, max_hp - expected, "the landed shot applies ranged damage minus defense")
	_near(hunter.sync_health, hunter.health.current, "the hit updates the Hunter's replicated health")

	tower.server_tick(0.1)
	_check(
		_projectile_aimed_at(hunter) == null,
		"the tower waits out its attack interval before the next shot"
	)
	holder.queue_free()
	tower.queue_free()


func _projectile_aimed_at(target: Node2D) -> Projectile:
	var host := get_tree().current_scene
	if host == null:
		return null
	for child in host.get_children():
		var shot := child as Projectile
		if shot != null and shot.target == target and not shot._consumed:
			return shot
	return null


func _test_tower_upgrade_requires_a_pick() -> void:
	GameManager.prepare_game_test()
	GameManager.grant_crystals(1, 1000.0)
	var manager := _manager()
	if manager == null:
		return
	var tower := _owned_building(manager, TOWER_SCENE, "UpTower")
	var cost := tower.next_upgrade_cost()
	var before := GameManager.crystals_for(1)

	manager._server_upgrade(1, "UpTower", -1)
	_near(GameManager.crystals_for(1), before, "a tower upgrade with no pick spends no Crystals")
	_check(tower.state == Building.State.IDLE, "a tower upgrade with no pick does not start")

	manager._server_upgrade(1, "UpTower", BuildingDef.TowerPath.size())
	_near(GameManager.crystals_for(1), before, "a tower upgrade with an out-of-range pick spends no Crystals")
	_check(tower.state == Building.State.IDLE, "a tower upgrade with an out-of-range pick does not start")

	var base_crit := tower.stats.final_value(StatBlock.Stat.CRITICAL_CHANCE)
	manager._server_upgrade(1, "UpTower", BuildingDef.TowerPath.CRIT)
	_near(GameManager.crystals_for(1), before - cost, "a tower upgrade with a valid pick spends the cost")
	_check(tower.state == Building.State.UPGRADING, "a valid tower upgrade starts building")
	## The pick waits for the build like the HP gain: picks never exceed levels.
	_check(tower.pending_tower_pick() == BuildingDef.TowerPath.CRIT, "the chosen path is queued")
	_check(tower.tower_pick_count(BuildingDef.TowerPath.CRIT) == 0, "a queued pick is not counted mid-upgrade")
	_near(
		tower.stats.final_value(StatBlock.Stat.CRITICAL_CHANCE),
		base_crit,
		"a queued pick grants nothing until the upgrade completes"
	)
	tower._complete_construction()
	_check(tower.level == 2, "the upgrade completes to level 2")
	_check(tower.tower_pick_count(BuildingDef.TowerPath.CRIT) == 1, "the chosen path is recorded on completion")
	_check(tower.pending_tower_pick() == -1, "completion clears the queued pick")
	_near(
		tower.stats.final_value(StatBlock.Stat.CRITICAL_CHANCE),
		base_crit + tower.def.tower_crit_chance_per_pick,
		"the pick's bonus applies on completion"
	)

	## A pick is never half-applied: an unaffordable upgrade must leave the counters alone.
	GameManager.try_spend_crystals(1, GameManager.crystals_for(1))
	manager._server_upgrade(1, "UpTower", BuildingDef.TowerPath.RANGED_DAMAGE)
	_check(tower.pending_tower_pick() == -1, "an unaffordable tower upgrade queues no pick")
	_check(tower.state == Building.State.IDLE, "an unaffordable tower upgrade does not start")

	## Ownership still wins over a valid pick. Peer 2 is not in the roster, so its own
	## balance proves nothing — assert on the tower instead.
	GameManager.grant_crystals(1, 1000.0)
	var owned_before := GameManager.crystals_for(1)
	manager._server_upgrade(2, "UpTower", BuildingDef.TowerPath.RANGED_DAMAGE)
	_near(GameManager.crystals_for(1), owned_before, "another peer's upgrade spends nothing of the owner's")
	_check(tower.state == Building.State.IDLE, "another peer cannot start an upgrade on someone else's tower")
	_check(tower.pending_tower_pick() == -1, "another peer cannot queue a pick on someone else's tower")
	_check(tower.level == 2, "another peer's upgrade leaves the level alone")


func _test_wall_and_mine_upgrade_without_a_pick() -> void:
	var manager := _manager()
	if manager == null:
		return
	GameManager.grant_crystals(1, 1000.0)
	_check_upgrades_without_pick(manager, WALL_SCENE, "UpWall")
	_check_upgrades_without_pick(manager, MINE_SCENE, "UpMine")


func _check_upgrades_without_pick(
	manager: ConstructionManager, scene: PackedScene, node_name: String
) -> void:
	var building := _owned_building(manager, scene, node_name)
	var label := building.def.display_name
	var cost := building.next_upgrade_cost()
	var before := GameManager.crystals_for(1)
	manager._server_upgrade(1, node_name, -1)
	_near(GameManager.crystals_for(1), before - cost, "%s upgrades with no pick and spends its cost" % label)
	_check(building.state == Building.State.UPGRADING, "%s starts upgrading with no pick" % label)


func _manager() -> ConstructionManager:
	var manager := get_tree().get_first_node_in_group("construction_manager") as ConstructionManager
	_check(manager != null, "the test scene provides a ConstructionManager")
	return manager


## A Building outside the BuildingsRoot, used for pure stat checks.
func _building(scene: PackedScene, node_name: String) -> Building:
	var building := scene.instantiate() as Building
	building.name = node_name
	add_child(building)
	return building


## A Building owned by peer 1 and parked in the manager's BuildingsRoot, forced to IDLE so
## can_upgrade() passes without waiting for the construction timer.
func _owned_building(manager: ConstructionManager, scene: PackedScene, node_name: String) -> Building:
	var building := scene.instantiate() as Building
	building.name = node_name
	building.owner_peer_id = 1
	manager.buildings_root.add_child(building)
	building.state = Building.State.IDLE
	building.progress_ratio = 0.0
	return building


func _projectile(target: Node2D, speed: float, on_hit: Callable) -> Projectile:
	var projectile := PROJECTILE_SCENE.instantiate() as Projectile
	add_child(projectile)
	projectile.setup(Vector2.ZERO, target, speed, on_hit)
	return projectile


func _dummy_target(at: Vector2) -> DummyTarget:
	var target := DummyTarget.new()
	add_child(target)
	target.global_position = at
	return target


func _has_property(object: Object, property: String) -> bool:
	for entry in object.get_property_list():
		if str(entry.get("name", "")) == property:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _near(actual: float, expected: float, message: String, eps := 0.01) -> void:
	if absf(actual - expected) > eps:
		_failures.append("%s (got %s expected %s)" % [message, actual, expected])


## Minimal stand-in for a Hunter: the projectile only needs a position and is_attackable().
class DummyTarget extends Node2D:
	var alive := true

	func is_attackable() -> bool:
		return alive
