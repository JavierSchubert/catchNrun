class_name BuildingIcons
extends RefCounted

const SIZE := 128
const CRYSTAL_ICON_SIZE := 48
const CRYSTAL_COLOR := Color(0.3, 0.85, 0.95, 1.0)

const BUILDING_TEXTURES := {
	"wall": [
		preload("res://assets/sprites/buildings/crystal_assets_128/wall_blue_01.png"),
		preload("res://assets/sprites/buildings/crystal_assets_128/wall_blue_02.png"),
		preload("res://assets/sprites/buildings/crystal_assets_128/wall_blue_03.png"),
		preload("res://assets/sprites/buildings/crystal_assets_128/wall_blue_04.png"),
	],
	"tower": [
		preload("res://assets/sprites/buildings/crystal_assets_128/tower_blue_01.png"),
		preload("res://assets/sprites/buildings/crystal_assets_128/tower_blue_02.png"),
		preload("res://assets/sprites/buildings/crystal_assets_128/tower_blue_03.png"),
		preload("res://assets/sprites/buildings/crystal_assets_128/tower_blue_04.png"),
	],
	"crystal_mine": [
		preload("res://assets/sprites/buildings/crystal_assets_128/mine_blue_01.png"),
		preload("res://assets/sprites/buildings/crystal_assets_128/mine_blue_02.png"),
		preload("res://assets/sprites/buildings/crystal_assets_128/mine_blue_03.png"),
	],
}


static func key_for_kind(kind: BuildingDef.Kind) -> String:
	match kind:
		BuildingDef.Kind.WALL:
			return "wall"
		BuildingDef.Kind.TOWER:
			return "tower"
		BuildingDef.Kind.CRYSTAL_MINE:
			return "crystal_mine"
	return "wall"


static func icon_for_kind(kind: BuildingDef.Kind) -> Texture2D:
	return icon_for(key_for_kind(kind))


static func icon_for_def(def: BuildingDef, level: int = 1) -> Texture2D:
	if def == null:
		return _fallback_icon()
	return texture_for_level(key_for_kind(def.kind), level, def.max_level)


static func icon_for(building_key: String) -> Texture2D:
	return texture_for_level(building_key, 1, 20)


static func texture_for_level(building_key: String, level: int, max_level: int) -> Texture2D:
	var textures: Array = BUILDING_TEXTURES.get(building_key, [])
	if textures.is_empty():
		return _fallback_icon()
	var levels_per_texture := maxi(ceili(float(maxi(max_level, 1)) / textures.size()), 1)
	var texture_index := mini((maxi(level, 1) - 1) / levels_per_texture, textures.size() - 1)
	return textures[texture_index]


## Bare Crystal diamond for the resource bar, separate from the building sprites.
static func crystal_icon() -> ImageTexture:
	var image := Image.create(CRYSTAL_ICON_SIZE, CRYSTAL_ICON_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_draw_crystal(image)
	return ImageTexture.create_from_image(image)


static func _draw_crystal(image: Image) -> void:
	var center := CRYSTAL_ICON_SIZE / 2
	var radius := 16
	for y in range(center - radius, center + radius):
		var dy := absi(y - center)
		var half_width := radius - int(dy * 1.4)
		if half_width <= 0:
			continue
		image.fill_rect(Rect2i(center - half_width, y, half_width * 2, 1), CRYSTAL_COLOR)


static func _fallback_icon() -> ImageTexture:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.fill_rect(Rect2i(4, 4, SIZE - 8, SIZE - 8), Color(0.6, 0.6, 0.6, 1.0))
	return ImageTexture.create_from_image(image)
