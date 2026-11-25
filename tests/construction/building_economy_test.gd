extends Node
## Headless checks for building levels, costs, and the Crystal economy from
## docs/economy.README.md and docs/construction.README.md §7.
##   godot --headless --path . res://tests/construction/building_economy_test.tscn

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_test_building_def_formulas()
	_test_crystal_mine_def_matches_docs()
	_test_construction_catalog()
	_test_building_icons()
	_test_economy_spend_and_grant()
	if _failures.is_empty():
		print("PASS: building economy")
		get_tree().quit(0)
	else:
		print("FAIL: %d check(s)" % _failures.size())
		for failure in _failures:
			print(" - %s" % failure)
		get_tree().quit(1)


func _test_building_def_formulas() -> void:
	var def := BuildingDef.new()
	def.base_cost = 40.0
	def.cost_growth = 1.5
	def.base_hp = 100.0
	def.hp_growth = 1.3
	def.base_build_seconds = 3.0
	def.build_time_growth = 1.2
	_near(def.cost_for_level(1), 40.0, "level 1 cost equals base_cost")
	_near(def.cost_for_level(2), 60.0, "level 2 cost applies cost_growth once")
	_near(def.hp_for_level(1), 100.0, "level 1 hp equals base_hp")
	_near(def.hp_for_level(3), 100.0 * 1.3 * 1.3, "level 3 hp applies hp_growth twice")
	_near(def.build_seconds_for_level(1), 3.0, "level 1 build time equals base_build_seconds")
	_check(def.build_seconds_for_level(4) > def.build_seconds_for_level(1), "build time increases with level")
	_check(def.cost_for_level(5) > def.cost_for_level(1), "build cost increases with level")
	_check(def.hp_for_level(5) > def.hp_for_level(1), "max hp increases with level")


func _test_crystal_mine_def_matches_docs() -> void:
	var def := load("res://src/buildings/defs/crystal_mine_def.tres") as BuildingDef
	_check(def != null, "crystal_mine_def.tres loads")
	if def == null:
		return
	_check(def.kind == BuildingDef.Kind.CRYSTAL_MINE, "crystal mine def is kind CRYSTAL_MINE")
	_near(def.mine_output_for_level(1), 1.0, "level 1 mine produces 1 crystal/tick")
	_near(def.mine_output_for_level(2), 2.0, "level 2 mine produces 2 crystals/tick")
	_near(def.mine_output_for_level(3), 4.0, "level 3 mine produces 4 crystals/tick")
	_near(def.mine_output_for_level(12), 2048.0, "level 12 mine produces 2048 crystals/tick")
	_near(def.mine_interval, 2.0, "mine generation interval defaults to 2.0 seconds")


func _test_construction_catalog() -> void:
	_check(ConstructionManager.scene_for("wall") != null, "wall has a scene")
	_check(ConstructionManager.scene_for("tower") != null, "tower has a scene")
	_check(ConstructionManager.scene_for("crystal_mine") != null, "crystal mine has a scene")
	_check(ConstructionManager.scene_for("nope") == null, "unknown key has no scene")
	_check(ConstructionManager.def_for("wall").footprint == Vector2i(1, 1), "wall footprint is 1x1")
	_check(ConstructionManager.def_for("tower").footprint == Vector2i(2, 2), "tower footprint is 2x2")
	_check(ConstructionManager.def_for("crystal_mine").footprint == Vector2i(2, 2), "mine footprint is 2x2")


func _test_building_icons() -> void:
	for key in ["wall", "tower", "crystal_mine"]:
		var icon := BuildingIcons.icon_for(key)
		_check(icon != null, "%s has a generated icon" % key)
		if icon != null:
			_check(icon.get_width() == BuildingIcons.SIZE, "%s icon has the expected width" % key)


func _test_economy_spend_and_grant() -> void:
	GameManager.prepare_game_test()
	var starting := GameManager.crystals_for(1)
	_check(starting > 0.0, "a fresh match grants starting crystals")
	_near(starting, GameManager.economy_config.starting_crystals, "starting crystals match EconomyConfig")

	var spent := GameManager.try_spend_crystals(1, 100.0)
	_check(spent, "spending less than the balance succeeds")
	_near(GameManager.crystals_for(1), starting - 100.0, "balance decreases by the spent amount")

	var overspent := GameManager.try_spend_crystals(1, starting * 10.0)
	_check(not overspent, "spending more than the balance fails")
	_near(GameManager.crystals_for(1), starting - 100.0, "a failed spend does not change the balance")

	GameManager.grant_crystals(1, 50.0)
	_near(GameManager.crystals_for(1), starting - 100.0 + 50.0, "granting crystals increases the balance")

	_check(not GameManager.try_spend_crystals(999, 1.0), "spending for an unknown player fails")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _near(actual: float, expected: float, message: String, eps := 0.01) -> void:
	if absf(actual - expected) > eps:
		_failures.append("%s (got %s expected %s)" % [message, actual, expected])
