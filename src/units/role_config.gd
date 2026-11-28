class_name RoleConfig
extends Resource
## Placeholder configuration for one role. Lives next to the unit it configures.

enum Role { HUNTER, RUNNER }

@export var role: Role = Role.RUNNER
@export var display_name := ""
@export var color := Color.WHITE ## Tint of the placeholder icon.
@export var base_stats: StatBlock
@export var move_speed := 220.0 ## Used only when base_stats is empty. Pixels per second.
@export var attack_range := 64.0 ## Distance at which a melee swing can start.
@export var acquisition_range := 900.0 ## Distance for automatic target acquisition.
@export var attack_interval := 0.8 ## Seconds between melee swings.
## Radius (pixels) of the circle this unit reveals for its team (docs/vision.README.md).
## Runner 450, Hunter 500 in the shipped configs.
@export var vision_range := 450.0
## Seconds without taking damage before HEALTH_REGENERATION ticks. 0 = regenerate always
## (while the regen stat is > 0). Uses real seconds, not physics ticks — same as wall
## shield_recharge_delay. Hunter default 3s: longer than a Tower shot (~1/s) so regen
## never ticks under fire, short enough to recover after disengaging.
@export var regen_delay_after_damage := 0.0
