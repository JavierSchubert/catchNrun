class_name BuildingIcons
extends RefCounted
## Small placeholder icons for the building UI buttons, drawn at runtime so the build
## panel has clickable images without depending on imported art assets.

const SIZE := 48


static func icon_for(building_key: String) -> ImageTexture:
	match building_key:
		"wall":
			return _wall_icon()
		"tower":
			return _tower_icon()
		"crystal_mine":
			return _mine_icon()
	return _fallback_icon()


static func _wall_icon() -> ImageTexture:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var mortar := Color(0.55, 0.52, 0.48, 1.0)
	var brick := Color(0.74, 0.44, 0.3, 1.0)
	image.fill_rect(Rect2i(4, 4, 40, 40), mortar)
	var row := 0
	var y := 7
	while y < 40:
		var offset := 0 if row % 2 == 0 else 9
		var x := 6 + offset
		while x < 40:
			image.fill_rect(Rect2i(x, y, 7, 5), brick)
			x += 9
		y += 7
		row += 1
	return ImageTexture.create_from_image(image)


static func _tower_icon() -> ImageTexture:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var stone := Color(0.58, 0.58, 0.63, 1.0)
	var banner := Color(0.75, 0.18, 0.18, 1.0)
	image.fill_rect(Rect2i(16, 20, 16, 24), stone)
	image.fill_rect(Rect2i(10, 10, 28, 10), stone)
	for i in range(4):
		image.fill_rect(Rect2i(10 + i * 7, 4, 5, 7), stone)
	image.fill_rect(Rect2i(21, 22, 6, 14), banner)
	return ImageTexture.create_from_image(image)


static func _mine_icon() -> ImageTexture:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var base := Color(0.4, 0.32, 0.26, 1.0)
	var crystal := Color(0.3, 0.85, 0.95, 1.0)
	image.fill_rect(Rect2i(8, 34, 32, 8), base)
	var center := SIZE / 2
	var radius := 16
	for y in range(center - radius, center + radius):
		var dy := absi(y - center)
		var half_width := radius - int(dy * 1.4)
		if half_width <= 0:
			continue
		image.fill_rect(Rect2i(center - half_width, y, half_width * 2, 1), crystal)
	return ImageTexture.create_from_image(image)


static func _fallback_icon() -> ImageTexture:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.fill_rect(Rect2i(4, 4, 40, 40), Color(0.6, 0.6, 0.6, 1.0))
	return ImageTexture.create_from_image(image)
