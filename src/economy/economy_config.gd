class_name EconomyConfig
extends Resource
## Match-wide Crystal economy balance. Edit economy_config.tres to change values.
## Per-building cost/HP/build-time scaling lives in BuildingDef instead (docs/economy.README.md §5).

@export var starting_crystals := 20.0 ## Crystals every player starts a match with.

## Crystals the Hunter earns per point of damage actually applied to a target.
## 0.2 means a 25-damage swing pays 5 Crystals (docs/economy.README.md §3.1).
## The conversion lives in GameManager.award_damage_crystals(), never at the combat call site.
@export var hunter_crystals_per_damage := 0.2
