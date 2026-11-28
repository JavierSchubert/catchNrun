extends Node
## Headless checks for building levels, costs, and the Crystal economy from
## docs/economy.README.md and docs/construction.README.md §7.
##   godot --headless --path . res://tests/construction/building_economy_test.tscn

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_test_building_def_formulas()
	_test_cost_table()
	_test_max_levels()
	_test_build_time_cap()
	_test_crystal_mine_def_matches_docs()
	_test_wall_shield()
	_test_construction_catalog()
	_test_building_icons()
	_test_economy_spend_and_grant()
	_test_damage_resolution()
	_test_attack_range_stat()
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


func _test_cost_table() -> void:
	var expected := {"wall": 8.0, "tower": 24.0, "crystal_mine": 16.0}
	for key in expected.keys():
		var def := _def(str(key))
		if def == null:
			continue
		var base: float = expected[key]
		_near(def.cost_for_level(1), base, "%s level 1 costs %s crystals" % [key, base])
		_near(def.cost_growth, 1.8, "%s cost grows x1.8 per level" % key)
		_near(def.cost_for_level(2), base * 1.8, "%s level 2 costs base x1.8" % key)


func _test_max_levels() -> void:
	var expected := {"wall": 20, "tower": 20, "crystal_mine": 11}
	for key in expected.keys():
		var def := _def(str(key))
		if def == null:
			continue
		_check(def.max_level == int(expected[key]), "%s max level is %d" % [key, int(expected[key])])


func _test_build_time_cap() -> void:
	for key in ["wall", "tower", "crystal_mine"]:
		var def := _def(key)
		if def == null:
			continue
		_check(
			def.build_seconds_for_level(20) <= def.max_build_seconds,
			"%s build time at level 20 stays within max_build_seconds" % key
		)


func _test_crystal_mine_def_matches_docs() -> void:
	var def := _def("crystal_mine")
	if def == null:
		return
	_check(def.kind == BuildingDef.Kind.CRYSTAL_MINE, "crystal mine def is kind CRYSTAL_MINE")
	_near(def.mine_output_for_level(1), 2.0, "level 1 mine produces 2 crystals/tick")
	_near(def.mine_output_for_level(2), 4.0, "level 2 mine produces 4 crystals/tick")
	_near(def.mine_output_for_level(3), 8.0, "level 3 mine produces 8 crystals/tick")
	_near(def.mine_output_for_level(11), 2048.0, "level 11 mine produces 2048 crystals/tick")
	_near(def.mine_output_for_level(12), 2048.0, "mine output is capped at 2048 crystals/tick")
	_near(def.mine_interval, 2.0, "mine generation interval defaults to 2.0 seconds")


func _test_wall_shield() -> void:
	var def := _def("wall")
	if def == null:
		return
	_check(def.shield_unlock_level == 15, "wall shield unlocks at level 15")
	_near(def.shield_for_level(14), 0.0, "wall has no shield below the unlock level")
	_check(def.shield_for_level(15) > 0.0, "wall gains a shield at the unlock level")
	_check(
		def.shield_for_level(16) > def.shield_for_level(15),
		"wall shield grows past the unlock level"
	)


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
		_check(icon != null, "%s has a building icon" % key)
		if icon != null:
			_check(icon.get_width() == BuildingIcons.SIZE, "%s icon has the expected width" % key)
	_check(
		BuildingIcons.texture_for_level("tower", 5, 20)
			== load("res://assets/sprites/buildings/crystal_assets_128/tower_blue_01.png"),
		"tower uses its first art through level 5"
	)
	_check(
		BuildingIcons.texture_for_level("tower", 6, 20)
			== load("res://assets/sprites/buildings/crystal_assets_128/tower_blue_02.png"),
		"tower switches to its second art at level 6"
	)
	_check(
		BuildingIcons.texture_for_level("tower", 10, 20)
			== load("res://assets/sprites/buildings/crystal_assets_128/tower_blue_02.png"),
		"tower level 10 uses the second art"
	)
	_check(
		BuildingIcons.texture_for_level("tower", 20, 20)
			== load("res://assets/sprites/buildings/crystal_assets_128/tower_blue_04.png"),
		"tower uses its fourth art at max level"
	)
	_check(
		BuildingIcons.texture_for_level("crystal_mine", 9, 11)
			== load("res://assets/sprites/buildings/crystal_assets_128/mine_blue_03.png"),
		"mine uses its third art from level 9"
	)


func _test_economy_spend_and_grant() -> void:
	GameManager.prepare_game_test()
	var starting := GameManager.crystals_for(1)
	_near(starting, 20.0, "a fresh match grants 20 starting crystals")
	_near(starting, GameManager.economy_config.starting_crystals, "starting crystals match EconomyConfig")

	var spent := GameManager.try_spend_crystals(1, 8.0)
	_check(spent, "spending less than the balance succeeds")
	_near(GameManager.crystals_for(1), starting - 8.0, "balance decreases by the spent amount")

	var overspent := GameManager.try_spend_crystals(1, starting * 10.0)
	_check(not overspent, "spending more than the balance fails")
	_near(GameManager.crystals_for(1), starting - 8.0, "a failed spend does not change the balance")

	GameManager.grant_crystals(1, 50.0)
	_near(GameManager.crystals_for(1), starting - 8.0 + 50.0, "granting crystals increases the balance")

	_check(not GameManager.try_spend_crystals(999, 1.0), "spending for an unknown player fails")

	_near(
		GameManager.economy_config.hunter_crystals_per_damage,
		0.2,
		"the hunter earns 20% of the damage dealt"
	)
	var before := GameManager.crystals_for(1)
	GameManager.award_damage_crystals(1, 25.0)
	_near(GameManager.crystals_for(1), before + 5.0, "25 damage pays the hunter 5 crystals")
	GameManager.award_damage_crystals(1, 0.0)
	_near(GameManager.crystals_for(1), before + 5.0, "zero damage pays nothing")


func _test_damage_resolution() -> void:
	var attacker := _damage_sheet(10.0, 40.0)
	var target := _damage_sheet(0.0, 0.0)

	var melee := CombatDamage.resolve_melee(attacker, target)
	_check(melee.has("damage"), "resolve_melee returns a damage key")
	_check(melee.has("critical"), "resolve_melee returns a critical key")
	_check(melee.has("lifesteal"), "resolve_melee returns a lifesteal key")
	_near(float(melee.damage), 10.0, "resolve_melee reads MELEE_DAMAGE")

	var ranged := CombatDamage.resolve_ranged(attacker, target)
	_check(ranged.has("damage"), "resolve_ranged returns a damage key")
	_check(ranged.has("critical"), "resolve_ranged returns a critical key")
	_check(ranged.has("lifesteal"), "resolve_ranged returns a lifesteal key")
	_near(float(ranged.damage), 40.0, "resolve_ranged reads RANGED_DAMAGE")


func _test_attack_range_stat() -> void:
	_check(
		int(StatBlock.Stat.ATTACK_RANGE) == int(StatBlock.Stat.ATTACK_SPEED) + 1,
		"ATTACK_RANGE is appended after ATTACK_SPEED"
	)
	var block := StatBlock.new()
	block.attack_range = 200.0
	_near(block.get_base(StatBlock.Stat.ATTACK_RANGE), 200.0, "StatBlock exposes attack_range")

	var sheet := StatSheet.new()
	sheet.set_base(block)
	_near(sheet.final_value(StatBlock.Stat.ATTACK_RANGE), 200.0, "attack range starts at its base value")

	var modifier := StatModifier.new()
	modifier.kind = StatModifier.Kind.PERCENT
	modifier.scope = StatModifier.Scope.ONE_STAT
	modifier.stat = StatBlock.Stat.ATTACK_RANGE
	modifier.value = 0.25
	sheet.add_modifier(modifier)
	_near(sheet.final_value(StatBlock.Stat.ATTACK_RANGE), 250.0, "attack range honours percentage modifiers")

	var penalty := StatModifier.new()
	penalty.kind = StatModifier.Kind.FLAT
	penalty.scope = StatModifier.Scope.ONE_STAT
	penalty.stat = StatBlock.Stat.ATTACK_RANGE
	penalty.value = -1000.0
	sheet.add_modifier(penalty)
	_near(sheet.final_value(StatBlock.Stat.ATTACK_RANGE), 0.0, "attack range is clamped to zero")

	_check(StatIcons.display_name(StatBlock.Stat.ATTACK_RANGE) == "Attack Range", "attack range has a label")
	_check(StatIcons.ICON_PATHS.has(StatBlock.Stat.ATTACK_RANGE), "attack range has an icon path")


func _def(key: String) -> BuildingDef:
	var def := load("res://src/buildings/defs/%s_def.tres" % key) as BuildingDef
	_check(def != null, "%s_def.tres loads" % key)
	return def


func _damage_sheet(melee_damage: float, ranged_damage: float) -> StatSheet:
	var block := StatBlock.new()
	block.melee_damage = melee_damage
	block.ranged_damage = ranged_damage
	block.defense = 0.0
	block.critical_chance = 0.0
	block.lifesteal_chance = 0.0
	var sheet := StatSheet.new()
	sheet.set_base(block)
	return sheet


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _near(actual: float, expected: float, message: String, eps := 0.01) -> void:
	if absf(actual - expected) > eps:
		_failures.append("%s (got %s expected %s)" % [message, actual, expected])
