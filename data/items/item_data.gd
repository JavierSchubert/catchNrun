class_name ItemData
extends Resource
## An item sold in the shop. Put .tres files in data/items/defs/ and ItemDatabase
## loads them automatically.

@export var id := "" ## Unique. This string is what RPCs send.
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D
@export var price := 50
@export_flags("Hunter", "Runner") var usable_by := 0b11 ## Bit index = RoleData.Role value.
@export var max_stack := 1
@export var modifiers: Array[StatModifier] = []


func usable_by_role(role: RoleData.Role) -> bool:
	return (usable_by & (1 << role)) != 0
