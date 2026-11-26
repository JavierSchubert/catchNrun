extends Node
## Headless checks for the WP-C tower: projectile impact, the four upgrade stat paths, and
## the host-side pick validation in ConstructionManager (docs/construction.README.md §5, §7).
##   godot --headless --path . res://tests/combat/tower_projectile_test.tscn

const PROJECTILE_SCENE := preload("res://src/combat/projectile.tscn")
const TOWER_SCENE := preload("res://src/buildings/tower.tscn")
const WALL_SCENE := preload("res://src/buildings/wall.tscn")
const MINE_SCENE := preload("res://src/buildings/crystal_mine.tscn")

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

	manager._server_upgrade(1, "UpTower", BuildingDef.TowerPath.CRIT)
	_near(GameManager.crystals_for(1), before - cost, "a tower upgrade with a valid pick spends the cost")
	_check(tower.tower_pick_count(BuildingDef.TowerPath.CRIT) == 1, "the chosen path is recorded")
	_check(tower.state == Building.State.UPGRADING, "a valid tower upgrade starts building")

	## A pick is never half-applied: an unaffordable upgrade must leave the counters alone.
	tower.state = Building.State.IDLE
	GameManager.try_spend_crystals(1, GameManager.crystals_for(1))
	manager._server_upgrade(1, "UpTower", BuildingDef.TowerPath.RANGED_DAMAGE)
	_check(
		tower.tower_pick_count(BuildingDef.TowerPath.RANGED_DAMAGE) == 0,
		"an unaffordable tower upgrade records no pick"
	)
	_check(tower.state == Building.State.IDLE, "an unaffordable tower upgrade does not start")

	## Ownership still wins over a valid pick.
	GameManager.grant_crystals(1, 1000.0)
	var owned_before := GameManager.crystals_for(1)
	manager._server_upgrade(2, "UpTower", BuildingDef.TowerPath.CRIT)
	_near(GameManager.crystals_for(1), owned_before, "another peer cannot upgrade someone else's tower")


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
