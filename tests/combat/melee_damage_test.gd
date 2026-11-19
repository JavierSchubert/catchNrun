extends Node
## Checks hunter melee damage and zero runner damage.
##   godot --headless --path . res://tests/combat/melee_damage_test.tscn

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_test_hunter_damages_runner()
	_test_runner_deals_zero()
	_test_health_reaches_zero()
	if _failures.is_empty():
		print("PASS: melee damage")
		get_tree().quit(0)
	else:
		print("FAIL: %d check(s)" % _failures.size())
		for failure in _failures:
			print(" - %s" % failure)
		get_tree().quit(1)


func _test_hunter_damages_runner() -> void:
	var hunter := _sheet(25.0, 0.0)
	var runner := _sheet(0.0, 0.0)
	var result := CombatDamage.resolve_melee(hunter, runner)
	_near(float(result.damage), 25.0, "hunter melee damage passes through with zero defense")


func _test_runner_deals_zero() -> void:
	var runner := _sheet(0.0, 0.0)
	var hunter := _sheet(25.0, 0.0)
	var result := CombatDamage.resolve_melee(runner, hunter)
	_near(float(result.damage), 0.0, "runner melee damage is zero")


func _test_health_reaches_zero() -> void:
	var health := HealthComponent.new()
	add_child(health)
	var died := false
	health.died.connect(func() -> void: died = true)
	health.setup(50.0)
	health.take_damage(25.0, 50.0)
	_near(health.current, 25.0, "partial damage reduces current health")
	health.take_damage(25.0, 50.0)
	_near(health.current, 0.0, "lethal damage empties health")
	if not died:
		_fail("health emits died at zero")
	if health.is_alive():
		_fail("health is not alive after lethal damage")


func _sheet(melee_damage: float, defense: float) -> StatSheet:
	var block := StatBlock.new()
	block.melee_damage = melee_damage
	block.defense = defense
	block.critical_chance = 0.0
	block.lifesteal_chance = 0.0
	var sheet := StatSheet.new()
	sheet.set_base(block)
	return sheet


func _near(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) > 0.001:
		_fail("%s (got %s, expected %s)" % [label, actual, expected])


func _fail(message: String) -> void:
	_failures.append(message)
