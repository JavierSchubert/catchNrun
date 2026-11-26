class_name StatBlock
extends Resource
## Base value of each supported character stat.
## Defaults match the initial examples in docs/stats.README.md.
## A role resource replaces movement_speed with the speed that role actually uses.

enum Stat {
	MAX_HEALTH,
	HEALTH_REGENERATION,
	DEFENSE,
	MOVEMENT_SPEED,
	MELEE_DAMAGE,
	RANGED_DAMAGE,
	MAGIC_DAMAGE,
	CRITICAL_CHANCE,
	CRITICAL_DAMAGE_MULTIPLIER,
	LIFESTEAL_CHANCE,
	LIFESTEAL_AMOUNT,
	ATTACK_SPEED,
	# Append new stats at the end: the ordinals are serialized in .tres role configs.
	ATTACK_RANGE,
}

@export var max_health := 100.0
@export var health_regeneration := 2.0
@export var defense := 20.0
@export var movement_speed := 5.0
@export var melee_damage := 10.0
@export var ranged_damage := 10.0
@export var magic_damage := 10.0
@export var critical_chance := 0.20
@export var critical_damage_multiplier := 1.50
@export var lifesteal_chance := 0.10
@export var lifesteal_amount := 5.0
@export var attack_speed := 1.25 ## Attacks per second. Interval = 1 / attack_speed.
@export var attack_range := 0.0 ## Reach in pixels. Towers read it; units ignore it and use RoleConfig.attack_range.


func get_base(stat: Stat) -> float:
	match stat:
		Stat.MAX_HEALTH:
			return max_health
		Stat.HEALTH_REGENERATION:
			return health_regeneration
		Stat.DEFENSE:
			return defense
		Stat.MOVEMENT_SPEED:
			return movement_speed
		Stat.MELEE_DAMAGE:
			return melee_damage
		Stat.RANGED_DAMAGE:
			return ranged_damage
		Stat.MAGIC_DAMAGE:
			return magic_damage
		Stat.CRITICAL_CHANCE:
			return critical_chance
		Stat.CRITICAL_DAMAGE_MULTIPLIER:
			return critical_damage_multiplier
		Stat.LIFESTEAL_CHANCE:
			return lifesteal_chance
		Stat.LIFESTEAL_AMOUNT:
			return lifesteal_amount
		Stat.ATTACK_SPEED:
			return attack_speed
		Stat.ATTACK_RANGE:
			return attack_range
	return 0.0


static func damage_stats() -> Array[Stat]:
	return [Stat.MELEE_DAMAGE, Stat.RANGED_DAMAGE, Stat.MAGIC_DAMAGE]
