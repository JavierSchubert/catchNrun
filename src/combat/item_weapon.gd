""" Base class for weapons extending ItemBase-class containing specific weapon variables """
extends ItemBase
class_name ItemWeapon


enum WeaponType {
	MELEE,
	RANGE
}

# variables for the weapon ressource
@export var type: WeaponType
@export var scene: PackedScene # scene for the weapon
@export var stats: WeaponStats
@export var upgrade_to: ItemWeapon


func get_description() -> String:
	return (
		"[code]"
		+ "Damage: [color=green]%s[/color]\n"
		+ "Cooldown: [color=green]%s[/color]\n"
		+ "Range: [color=green]%s[/color]\n"
		+ "Critical: [color=green]%s%%[/color]"
		+ "[/code]"
	) % [stats.damage, stats.cooldown, stats.max_range, stats.crit_chance * 100]
