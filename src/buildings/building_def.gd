class_name BuildingDef
extends Resource
## Data-driven per-level stats for one structure type.
## One Building script covers wall / tower / crystal mine; behavior differences come from
## `kind` + these formulas, not per-type subclasses (docs/construction.README.md §7).
##
## Balance baseline (docs/economy.README.md §2.1):
##   build cost  wall 8 / tower 24 / mine 16, all x1.8 per level
##   max level   wall 20 / tower 20 / mine 11
## Growth values were retuned for the 20-level ceilings: build_time_growth 1.08 (1.2^19
## would be a 93 s build) with max_build_seconds as a hard cap, hp_growth 1.18 wall /
## 1.15 tower (1.4^19 would be a 1100x HP swing) and 1.25 for the 11-level mine.

enum Kind { WALL, TOWER, CRYSTAL_MINE }

## Stat path the owner picks on each tower upgrade (docs/economy.README.md §2.1).
enum TowerPath { RANGED_DAMAGE, ATTACK_SPEED, CRIT, ATTACK_RANGE }

@export var kind: Kind = Kind.WALL
@export var id := ""
@export var display_name := ""
@export var footprint := Vector2i(1, 1)
@export var max_level := 5

## cost(level) = base_cost * cost_growth^(level - 1). Paid both to build level 1 and to
## upgrade into each later level (docs/economy.README.md §2.1, §5).
@export var base_cost := 50.0
@export var cost_growth := 1.5

## hp(level) = base_hp * hp_growth^(level - 1) (docs/construction.README.md §7).
@export var base_hp := 150.0
@export var hp_growth := 1.3

## build_seconds(level) = base_build_seconds * build_time_growth^(level - 1), capped at
## max_build_seconds so the late levels stay playable.
@export var base_build_seconds := 4.0
@export var build_time_growth := 1.15
@export var max_build_seconds := 20.0

## Crystal Mine only. Output doubles per level per docs/economy.README.md §2.1:
## 2 at level 1 up to the 2048 cap at level 11.
@export var mine_base_output := 2.0
@export var mine_interval := 2.0
@export var mine_max_output := 2048.0

## Wall only. The recharging shield unlocks part-way up the wall's level track; below the
## unlock level the wall has no shield at all (docs/economy.README.md §2.1).
@export var shield_unlock_level := 15
@export var shield_base := 0.0
@export var shield_growth := 1.18
@export var shield_recharge_delay := 6.0 ## Seconds without damage before the shield refills.
@export var shield_recharge_per_second := 0.05 ## Fraction of max shield restored per second.

## Tower only. Every tower combat number lives in this StatBlock; Building seeds its
## StatSheet from it (ranged damage, attack speed, attack range, crit). There is no passive
## per-level damage curve any more — a tower level only raises hp_for_level() and grants one
## upgrade pick, so the picks below are the sole source of damage growth.
## NOTE: tower_base_stats.max_health is a readable mirror of base_hp. hp_for_level() remains
## the only authority for structure HP; the stat is never fed into HealthComponent.
@export var tower_base_stats: StatBlock

## Tower stat-path upgrades. Each level the owner picks one TowerPath and the pick adds the
## matching increment. Damage / attack speed / range are percentages of the base value and
## they SUM (three damage picks are +90%, not 1.3^3); crit chance and crit damage are flat
## additions because their base crit chance is 0 and a percentage of zero grants nothing.
@export var tower_damage_per_pick := 0.30
@export var tower_attack_speed_per_pick := 0.20
@export var tower_crit_chance_per_pick := 0.08
@export var tower_crit_damage_per_pick := 0.15
@export var tower_range_per_pick := 0.15
@export var tower_projectile_speed := 650.0 ## Pixels per second of the fired projectile.


func cost_for_level(level: int) -> float:
	return base_cost * pow(cost_growth, maxi(level, 1) - 1)


func hp_for_level(level: int) -> float:
	return base_hp * pow(hp_growth, maxi(level, 1) - 1)


func build_seconds_for_level(level: int) -> float:
	return minf(base_build_seconds * pow(build_time_growth, maxi(level, 1) - 1), max_build_seconds)


func mine_output_for_level(level: int) -> float:
	return minf(mine_base_output * pow(2.0, maxi(level, 1) - 1), mine_max_output)


## 0.0 until the wall reaches shield_unlock_level, then shield_base at the unlock level
## and shield_growth per level above it.
func shield_for_level(level: int) -> float:
	var clamped := maxi(level, 1)
	if clamped < shield_unlock_level:
		return 0.0
	return shield_base * pow(shield_growth, clamped - shield_unlock_level)
