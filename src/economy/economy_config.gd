class_name EconomyConfig
extends Resource
## Match-wide Crystal economy balance. Edit economy_config.tres to change values.
## Per-building cost/HP/build-time scaling lives in BuildingDef instead (docs/economy.README.md §5).

@export var starting_crystals := 1000000.0 ## Crystals every player starts a match with.
