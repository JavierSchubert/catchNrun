class_name StatModifier
extends Resource
## One flat or percentage change contributed by equipment, a perk, a buff, or a debuff.
## Percentage values are decimals: 0.20 is +20%. An all-damage modifier applies to
## melee, ranged, and magic damage.

enum Kind { FLAT, PERCENT }
enum Scope { ONE_STAT, ALL_DAMAGE }

@export var kind: Kind = Kind.FLAT
@export var scope: Scope = Scope.ONE_STAT
@export var stat: StatBlock.Stat = StatBlock.Stat.MELEE_DAMAGE
@export var value := 0.0
## Optional origin tag (e.g. `shop:shop_max_health`) for debugging / inventory rebuild.
@export var source := ""


func applies_to(target: StatBlock.Stat) -> bool:
	if scope == Scope.ALL_DAMAGE:
		return target in StatBlock.damage_stats()
	return stat == target
