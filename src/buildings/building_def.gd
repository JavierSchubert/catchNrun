class_name BuildingDef
extends Resource
## Data-driven per-level stats for one structure type.
## One Building script covers wall / tower / crystal mine; behavior differences come from
## `kind` + these formulas, not per-type subclasses (docs/construction.README.md §7).

enum Kind { WALL, TOWER, CRYSTAL_MINE }

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

## build_seconds(level) = base_build_seconds * build_time_growth^(level - 1).
@export var base_build_seconds := 4.0
@export var build_time_growth := 1.15

## Crystal Mine only. Output doubles per level per docs/economy.README.md §2.1.
@export var mine_base_output := 1.0
@export var mine_interval := 2.0

## Tower only.
@export var tower_base_damage := 15.0
@export var tower_damage_growth := 1.25
@export var tower_range := 260.0
@export var tower_attack_interval := 1.0


func cost_for_level(level: int) -> float:
	return base_cost * pow(cost_growth, maxi(level, 1) - 1)


func hp_for_level(level: int) -> float:
	return base_hp * pow(hp_growth, maxi(level, 1) - 1)


func build_seconds_for_level(level: int) -> float:
	return base_build_seconds * pow(build_time_growth, maxi(level, 1) - 1)


func mine_output_for_level(level: int) -> float:
	return mine_base_output * pow(2.0, maxi(level, 1) - 1)


func tower_damage_for_level(level: int) -> float:
	return tower_base_damage * pow(tower_damage_growth, maxi(level, 1) - 1)
