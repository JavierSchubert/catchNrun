class_name StatSheet
extends RefCounted
## Final character stats for one unit.
##
## final_value = (base_value + flat_modifier) * (1 + percentage_modifier)
##
## Flat modifiers are summed. Percentage modifiers are summed. Gameplay reads
## final_value() and does not repeat this formula.

signal stats_changed

var _base := StatBlock.new()
var _modifiers: Array[StatModifier] = []


func set_base(block: StatBlock) -> void:
	_base = block if block != null else StatBlock.new()
	stats_changed.emit()


func add_modifier(modifier: StatModifier) -> void:
	_modifiers.append(modifier)
	stats_changed.emit()


func remove_modifier(modifier: StatModifier) -> void:
	_modifiers.erase(modifier)
	stats_changed.emit()


func clear_modifiers() -> void:
	_modifiers.clear()
	stats_changed.emit()


func base_value(stat: StatBlock.Stat) -> float:
	return _base.get_base(stat)


func final_value(stat: StatBlock.Stat) -> float:
	var flat := 0.0
	var percent := 0.0
	for modifier in _modifiers:
		if not modifier.applies_to(stat):
			continue
		if modifier.kind == StatModifier.Kind.FLAT:
			flat += modifier.value
		else:
			percent += modifier.value
	return constrain(stat, (_base.get_base(stat) + flat) * (1.0 + percent))


## Difference between final and base after constraints. Used by HUD as `(+delta)`.
func modifier_delta(stat: StatBlock.Stat) -> float:
	return final_value(stat) - base_value(stat)


static func constrain(stat: StatBlock.Stat, value: float) -> float:
	match stat:
		StatBlock.Stat.CRITICAL_CHANCE, StatBlock.Stat.LIFESTEAL_CHANCE, StatBlock.Stat.LUCK:
			return clampf(value, 0.0, 1.0)
		StatBlock.Stat.MAX_HEALTH, StatBlock.Stat.HEALTH_REGENERATION, StatBlock.Stat.MOVEMENT_SPEED, \
				StatBlock.Stat.CRITICAL_DAMAGE_MULTIPLIER, StatBlock.Stat.LIFESTEAL_AMOUNT, \
				StatBlock.Stat.ATTACK_SPEED, StatBlock.Stat.ATTACK_RANGE:
			return maxf(value, 0.0)
		_:
			return value
