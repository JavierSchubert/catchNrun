class_name RoleConfig
extends Resource
## Placeholder configuration for one role. Lives next to the unit it configures.

enum Role { HUNTER, RUNNER }

@export var role: Role = Role.RUNNER
@export var display_name := ""
@export var color := Color.WHITE ## Tint of the placeholder icon.
@export var base_stats: StatBlock
@export var move_speed := 220.0 ## Used only when base_stats is empty. Pixels per second.
