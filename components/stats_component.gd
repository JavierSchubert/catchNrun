class_name StatsComponent
extends Node
## Final stat = (base + sum of FLAT) * (1 + sum of PERCENT).
##
## Every peer computes stats itself from the replicated item list, so all peers get the
## same numbers. The owning client needs its own speed for movement, and the host needs
## damage and armor to run combat.

signal stats_changed

var base: StatBlock
var _final: Dictionary = {} # StatBlock.Stat -> float


func setup(base_stats: StatBlock) -> void:
	base = base_stats
	recalculate([])


func recalculate(items: Array[ItemData]) -> void:
	if base == null:
		return
	var flat: Dictionary = {}
	var percent: Dictionary = {}
	for item in items:
		for mod in item.modifiers:
			var target := flat if mod.kind == StatModifier.Kind.FLAT else percent
			target[mod.stat] = target.get(mod.stat, 0.0) + mod.value
	for stat: StatBlock.Stat in StatBlock.Stat.values():
		_final[stat] = (base.get_base(stat) + flat.get(stat, 0.0)) * (1.0 + percent.get(stat, 0.0))
	stats_changed.emit()


func get_stat(stat: StatBlock.Stat) -> float:
	return _final.get(stat, 0.0)
