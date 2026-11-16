class_name StatBlock
extends Resource
## Base stats of a role. Items add StatModifiers on top (see StatsComponent).
## To add a new stat: add it to the enum, add an @export, and handle it in get_base().

enum Stat { MAX_HEALTH, MOVE_SPEED, DAMAGE, ARMOR, ATTACK_COOLDOWN, ATTACK_RANGE }

@export var max_health := 100.0
@export var move_speed := 220.0
@export var damage := 0.0
@export var armor := 0.0
@export var attack_cooldown := 1.0 ## Seconds between attacks.
@export var attack_range := 0.0 ## Pixels. 0 = this role cannot attack.


func get_base(stat: Stat) -> float:
	match stat:
		Stat.MAX_HEALTH: return max_health
		Stat.MOVE_SPEED: return move_speed
		Stat.DAMAGE: return damage
		Stat.ARMOR: return armor
		Stat.ATTACK_COOLDOWN: return attack_cooldown
		Stat.ATTACK_RANGE: return attack_range
	return 0.0
