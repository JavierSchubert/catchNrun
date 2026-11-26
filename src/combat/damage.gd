class_name CombatDamage
extends RefCounted
## Applies one attack from attacker to target using final stat values.
## Combat consumes stats; it does not recalculate them.


static func resolve_melee(attacker_stats: StatSheet, target_stats: StatSheet) -> Dictionary:
	return _resolve(attacker_stats, target_stats, StatBlock.Stat.MELEE_DAMAGE)


## Same rules as melee, but the attack reads RANGED_DAMAGE. Used by tower projectiles.
static func resolve_ranged(attacker_stats: StatSheet, target_stats: StatSheet) -> Dictionary:
	return _resolve(attacker_stats, target_stats, StatBlock.Stat.RANGED_DAMAGE)


static func _resolve(
	attacker_stats: StatSheet, target_stats: StatSheet, damage_stat: StatBlock.Stat
) -> Dictionary:
	var raw := attacker_stats.final_value(damage_stat)
	if raw <= 0.0:
		return {"damage": 0.0, "critical": false, "lifesteal": 0.0}

	var critical := false
	if randf() < attacker_stats.final_value(StatBlock.Stat.CRITICAL_CHANCE):
		raw *= attacker_stats.final_value(StatBlock.Stat.CRITICAL_DAMAGE_MULTIPLIER)
		critical = true

	var defense := target_stats.final_value(StatBlock.Stat.DEFENSE)
	var damage := maxf(0.0, raw - defense * 0.25)

	var lifesteal := 0.0
	if damage > 0.0 and randf() < attacker_stats.final_value(StatBlock.Stat.LIFESTEAL_CHANCE):
		lifesteal = attacker_stats.final_value(StatBlock.Stat.LIFESTEAL_AMOUNT)

	return {"damage": damage, "critical": critical, "lifesteal": lifesteal}
