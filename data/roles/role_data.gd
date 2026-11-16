class_name RoleData
extends Resource
## Defines a role (Hunter / Runner): its base stats and starting gold.

enum Role { HUNTER, RUNNER }

@export var role: Role = Role.RUNNER
@export var display_name := ""
@export var color := Color.WHITE
@export var base_stats: StatBlock
@export var starting_gold := 0
@export var gold_per_second := 2 ## Paid by the host while this player is alive.
