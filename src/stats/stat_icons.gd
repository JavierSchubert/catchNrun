class_name StatIcons
extends RefCounted
## Maps character stats to HUD icons and display labels.
## Icon file names under assets/sprites/stats/ drive the mapping.
##
## Clean borderless icons live under assets/sprites/stats/clean/ (512px).
## They are Lanczos-resized once to HUD_ICON_PX for the selection panel.

const POSITIVE_COLOR := "#6fdf8a"
const NEGATIVE_COLOR := "#f07178"
## Pixel size baked for the selection-panel TextureRects (keep in sync with scene).
const HUD_ICON_PX := 34

static var _texture_cache: Dictionary = {}

## Defense uses the clean block_chance shield until a dedicated defense icon exists.
const ICON_PATHS := {
	StatBlock.Stat.MAX_HEALTH: "res://assets/sprites/stats/clean/health.png",
	StatBlock.Stat.MELEE_DAMAGE: "res://assets/sprites/stats/clean/damage.png",
	StatBlock.Stat.HEALTH_REGENERATION: "res://assets/sprites/stats/clean/hp_regen.png",
	StatBlock.Stat.ATTACK_SPEED: "res://assets/sprites/stats/clean/attack_speed.png",
	StatBlock.Stat.DEFENSE: "res://assets/sprites/stats/clean/block_chance.png",
	StatBlock.Stat.LIFESTEAL_CHANCE: "res://assets/sprites/stats/clean/lifesteal_chance.png",
	StatBlock.Stat.MOVEMENT_SPEED: "res://assets/sprites/stats/clean/movement_speed.png",
	StatBlock.Stat.CRITICAL_CHANCE: "res://assets/sprites/stats/clean/crit_chance.png",
	StatBlock.Stat.RANGED_DAMAGE: "res://assets/sprites/stats/attack_range.png",
	StatBlock.Stat.MAGIC_DAMAGE: "res://assets/sprites/stats/magic.png",
}

const DISPLAY_NAMES := {
	StatBlock.Stat.MAX_HEALTH: "Health",
	StatBlock.Stat.MELEE_DAMAGE: "Damage",
	StatBlock.Stat.HEALTH_REGENERATION: "HP Regen",
	StatBlock.Stat.ATTACK_SPEED: "Attack Speed",
	StatBlock.Stat.DEFENSE: "Defense",
	StatBlock.Stat.LIFESTEAL_CHANCE: "Lifesteal Chance",
	StatBlock.Stat.MOVEMENT_SPEED: "Movement Speed",
	StatBlock.Stat.CRITICAL_CHANCE: "Crit Chance",
	StatBlock.Stat.RANGED_DAMAGE: "Ranged Damage",
	StatBlock.Stat.MAGIC_DAMAGE: "Magic Damage",
	StatBlock.Stat.CRITICAL_DAMAGE_MULTIPLIER: "Crit Damage",
	StatBlock.Stat.LIFESTEAL_AMOUNT: "Lifesteal Amount",
}

const _CHANCE_STATS := {
	StatBlock.Stat.CRITICAL_CHANCE: true,
	StatBlock.Stat.LIFESTEAL_CHANCE: true,
}


static func icon(stat: StatBlock.Stat) -> Texture2D:
	if _texture_cache.has(stat):
		return _texture_cache[stat] as Texture2D
	var path: String = ICON_PATHS.get(stat, "")
	if path.is_empty():
		return null
	var source := load(path) as Texture2D
	if source == null:
		return null
	var image := source.get_image()
	if image == null:
		return source
	if image.get_width() != HUD_ICON_PX or image.get_height() != HUD_ICON_PX:
		image.resize(HUD_ICON_PX, HUD_ICON_PX, Image.INTERPOLATE_LANCZOS)
	var baked := ImageTexture.create_from_image(image)
	_texture_cache[stat] = baked
	return baked


static func display_name(stat: StatBlock.Stat) -> String:
	return DISPLAY_NAMES.get(stat, str(stat))


static func format_value(sheet: StatSheet, stat: StatBlock.Stat) -> String:
	var base := sheet.base_value(stat)
	var delta := sheet.modifier_delta(stat)
	var base_text := _format_number(stat, base)
	if is_zero_approx(delta):
		return base_text
	var color := POSITIVE_COLOR if delta > 0.0 else NEGATIVE_COLOR
	var sign := "+" if delta > 0.0 else "-"
	var delta_text := _format_number(stat, absf(delta))
	return "%s ([color=%s]%s%s[/color])" % [base_text, color, sign, delta_text]


static func _format_number(stat: StatBlock.Stat, value: float) -> String:
	if _CHANCE_STATS.has(stat):
		var percent := value * 100.0
		if is_equal_approx(percent, roundf(percent)):
			return "%d%%" % int(roundf(percent))
		return "%.1f%%" % percent
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value
