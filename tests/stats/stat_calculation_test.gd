extends Node
## Checks final stat values from docs/stats.README.md.
##   godot --headless --path . res://tests/stats/stat_calculation_test.tscn

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_test_formula()
	_test_documented_damage_example()
	_test_constraints()
	_test_hud_display_format()
	if _failures.is_empty():
		print("PASS: stat calculation")
		get_tree().quit(0)
	else:
		print("FAIL: %d check(s)" % _failures.size())
		for failure in _failures:
			print(" - %s" % failure)
		get_tree().quit(1)


func _test_formula() -> void:
	var sheet := _sheet(10.0)
	_near(sheet.final_value(StatBlock.Stat.MELEE_DAMAGE), 10.0, "no modifiers leaves the base value")
	var health := StatSheet.new()
	var health_base := StatBlock.new()
	health_base.max_health = 100.0
	health.set_base(health_base)
	health.add_modifier(_mod(StatModifier.Kind.PERCENT, StatModifier.Scope.ONE_STAT, StatBlock.Stat.MAX_HEALTH, 0.20))
	_near(health.final_value(StatBlock.Stat.MAX_HEALTH), 120.0, "+20% of 100 is 120")
	health.add_modifier(_mod(StatModifier.Kind.PERCENT, StatModifier.Scope.ONE_STAT, StatBlock.Stat.MAX_HEALTH, -0.20))
	_near(health.final_value(StatBlock.Stat.MAX_HEALTH), 100.0, "percentage modifiers sum before they are applied")
	sheet.add_modifier(_mod(StatModifier.Kind.FLAT, StatModifier.Scope.ONE_STAT, StatBlock.Stat.MELEE_DAMAGE, 5.0))
	sheet.add_modifier(_mod(StatModifier.Kind.PERCENT, StatModifier.Scope.ONE_STAT, StatBlock.Stat.MELEE_DAMAGE, 0.50))
	_near(sheet.final_value(StatBlock.Stat.MELEE_DAMAGE), 22.5, "flat is added before the percentage")


func _test_documented_damage_example() -> void:
	var sheet := _sheet(10.0)
	sheet.add_modifier(_mod(StatModifier.Kind.FLAT, StatModifier.Scope.ONE_STAT, StatBlock.Stat.MELEE_DAMAGE, 5.0))
	sheet.add_modifier(_mod(StatModifier.Kind.PERCENT, StatModifier.Scope.ONE_STAT, StatBlock.Stat.MELEE_DAMAGE, 0.20))
	sheet.add_modifier(_mod(StatModifier.Kind.PERCENT, StatModifier.Scope.ALL_DAMAGE, StatBlock.Stat.MELEE_DAMAGE, 0.10))
	_near(sheet.final_value(StatBlock.Stat.MELEE_DAMAGE), 19.5, "sword, berserker perk, and all-damage ring make 19.5 melee damage")
	_near(sheet.final_value(StatBlock.Stat.RANGED_DAMAGE), 11.0, "all-damage percent also applies to ranged damage")
	_near(sheet.final_value(StatBlock.Stat.MAGIC_DAMAGE), 11.0, "all-damage percent also applies to magic damage")
	_near(sheet.final_value(StatBlock.Stat.DEFENSE), 20.0, "all-damage does not change defense")


func _test_constraints() -> void:
	var sheet := _sheet(0.0)
	sheet.add_modifier(_mod(StatModifier.Kind.FLAT, StatModifier.Scope.ONE_STAT, StatBlock.Stat.CRITICAL_CHANCE, 2.0))
	_near(sheet.final_value(StatBlock.Stat.CRITICAL_CHANCE), 1.0, "critical chance clamps to 1")
	sheet.clear_modifiers()
	sheet.add_modifier(_mod(StatModifier.Kind.FLAT, StatModifier.Scope.ONE_STAT, StatBlock.Stat.LIFESTEAL_CHANCE, -1.0))
	_near(sheet.final_value(StatBlock.Stat.LIFESTEAL_CHANCE), 0.0, "lifesteal chance clamps to 0")
	sheet.clear_modifiers()
	sheet.add_modifier(_mod(StatModifier.Kind.FLAT, StatModifier.Scope.ONE_STAT, StatBlock.Stat.MAX_HEALTH, -1000.0))
	_near(sheet.final_value(StatBlock.Stat.MAX_HEALTH), 0.0, "max health cannot fall below 0")
	sheet.clear_modifiers()
	sheet.add_modifier(_mod(StatModifier.Kind.FLAT, StatModifier.Scope.ONE_STAT, StatBlock.Stat.MOVEMENT_SPEED, -100.0))
	_near(sheet.final_value(StatBlock.Stat.MOVEMENT_SPEED), 0.0, "movement speed cannot fall below 0")
	sheet.clear_modifiers()
	sheet.add_modifier(_mod(StatModifier.Kind.FLAT, StatModifier.Scope.ONE_STAT, StatBlock.Stat.CRITICAL_DAMAGE_MULTIPLIER, -10.0))
	_near(sheet.final_value(StatBlock.Stat.CRITICAL_DAMAGE_MULTIPLIER), 0.0, "critical damage multiplier cannot fall below 0")


func _test_hud_display_format() -> void:
	var sheet := _sheet(10.0)
	_near(sheet.base_value(StatBlock.Stat.MELEE_DAMAGE), 10.0, "base_value exposes the unmodded base")
	_near(sheet.modifier_delta(StatBlock.Stat.MELEE_DAMAGE), 0.0, "no modifiers means zero delta")
	if StatIcons.format_value(sheet, StatBlock.Stat.MELEE_DAMAGE) != "10":
		_failures.append("plain base displays without parentheses")
	sheet.add_modifier(_mod(StatModifier.Kind.FLAT, StatModifier.Scope.ONE_STAT, StatBlock.Stat.MELEE_DAMAGE, 5.0))
	sheet.add_modifier(_mod(StatModifier.Kind.PERCENT, StatModifier.Scope.ONE_STAT, StatBlock.Stat.MELEE_DAMAGE, 0.20))
	sheet.add_modifier(_mod(StatModifier.Kind.PERCENT, StatModifier.Scope.ALL_DAMAGE, StatBlock.Stat.MELEE_DAMAGE, 0.10))
	_near(sheet.modifier_delta(StatBlock.Stat.MELEE_DAMAGE), 9.5, "delta is final minus base")
	## Final 19.5 vs base 10 → green final value (no parenthetical delta).
	var shown := StatIcons.format_value(sheet, StatBlock.Stat.MELEE_DAMAGE)
	if shown != "[color=#6fdf8a]19.5[/color]":
		_failures.append("positive final HUD format (got %s)" % shown)
	var lower := StatSheet.new()
	var block := StatBlock.new()
	block.melee_damage = 10.0
	lower.set_base(block)
	lower.add_modifier(_mod(StatModifier.Kind.FLAT, StatModifier.Scope.ONE_STAT, StatBlock.Stat.MELEE_DAMAGE, -4.0))
	var negative := StatIcons.format_value(lower, StatBlock.Stat.MELEE_DAMAGE)
	if negative != "[color=#f07178]6[/color]":
		_failures.append("negative final HUD format (got %s)" % negative)


func _sheet(melee_damage: float) -> StatSheet:
	var block := StatBlock.new()
	block.melee_damage = melee_damage
	var sheet := StatSheet.new()
	sheet.set_base(block)
	return sheet


func _mod(kind: StatModifier.Kind, scope: StatModifier.Scope, stat: StatBlock.Stat, value: float) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.kind = kind
	modifier.scope = scope
	modifier.stat = stat
	modifier.value = value
	return modifier


func _near(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s (got %s, expected %s)" % [message, actual, expected])
		print("failed: %s" % _failures[_failures.size() - 1])
