class_name SkillIcons
extends RefCounted
## Runtime-drawn skill icons (no art dependency, headless-safe) — same idea as
## BuildingIcons.crystal_icon(). Add new skill ids here as actives land.

const SIZE := 64
const SEEK_COLOR := Color(0.35, 0.7, 1.0, 1.0)
const SEEK_ACCENT := Color(0.85, 0.95, 1.0, 1.0)
const REPAIR_COLOR := Color(0.35, 0.9, 0.65, 1.0)
const REPAIR_ACCENT := Color(0.85, 1.0, 0.9, 1.0)

static var _cache: Dictionary = {}


static func icon_for(skill_id: String) -> Texture2D:
	if _cache.has(skill_id):
		return _cache[skill_id] as Texture2D
	var texture: Texture2D
	match skill_id:
		"seek":
			texture = seek_icon()
		"repair":
			texture = repair_icon()
		_:
			texture = _fallback_icon()
	_cache[skill_id] = texture
	return texture


static func seek_icon() -> ImageTexture:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(SIZE * 0.5, SIZE * 0.5)
	_draw_ring(image, center, 22, SEEK_COLOR, 2)
	_draw_ring(image, center, 12, SEEK_COLOR, 1)
	## Three direction wedges — matches the minimap Seek arrows fantasy.
	_draw_arrow(image, center, Vector2(0, -1), SEEK_ACCENT)
	_draw_arrow(image, center, Vector2(0.87, 0.5), SEEK_COLOR)
	_draw_arrow(image, center, Vector2(-0.87, 0.5), SEEK_COLOR)
	## Center pip.
	image.fill_rect(Rect2i(int(center.x) - 2, int(center.y) - 2, 4, 4), SEEK_ACCENT)
	return ImageTexture.create_from_image(image)


static func repair_icon() -> ImageTexture:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(SIZE * 0.5, SIZE * 0.5)
	_draw_ring(image, center, 22, REPAIR_COLOR, 2)
	image.fill_rect(Rect2i(int(center.x) - 2, int(center.y) - 10, 4, 20), REPAIR_ACCENT)
	image.fill_rect(Rect2i(int(center.x) - 10, int(center.y) - 2, 20, 4), REPAIR_ACCENT)
	return ImageTexture.create_from_image(image)


static func _draw_ring(image: Image, center: Vector2, radius: int, color: Color, thickness: int) -> void:
	for y in range(SIZE):
		for x in range(SIZE):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if absf(d - float(radius)) <= float(thickness) * 0.5 + 0.25:
				image.set_pixel(x, y, color)


static func _draw_arrow(image: Image, center: Vector2, direction: Vector2, color: Color) -> void:
	var dir := direction.normalized()
	var tip := center + dir * 26.0
	var base := center + dir * 14.0
	var side := dir.orthogonal() * 5.0
	_fill_triangle(image, tip, base + side, base - side, color)


static func _fill_triangle(image: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var min_x := int(floorf(mini(a.x, mini(b.x, c.x))))
	var max_x := int(ceilf(maxi(a.x, maxi(b.x, c.x))))
	var min_y := int(floorf(mini(a.y, mini(b.y, c.y))))
	var max_y := int(ceilf(maxi(a.y, maxi(b.y, c.y))))
	min_x = clampi(min_x, 0, SIZE - 1)
	max_x = clampi(max_x, 0, SIZE - 1)
	min_y = clampi(min_y, 0, SIZE - 1)
	max_y = clampi(max_y, 0, SIZE - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			if _point_in_triangle(p, a, b, c):
				image.set_pixel(x, y, color)


static func _point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var v0 := c - a
	var v1 := b - a
	var v2 := p - a
	var dot00 := v0.dot(v0)
	var dot01 := v0.dot(v1)
	var dot02 := v0.dot(v2)
	var dot11 := v1.dot(v1)
	var dot12 := v1.dot(v2)
	var denom := dot00 * dot11 - dot01 * dot01
	if absf(denom) < 0.0001:
		return false
	var inv := 1.0 / denom
	var u := (dot11 * dot02 - dot01 * dot12) * inv
	var v := (dot00 * dot12 - dot01 * dot02) * inv
	return u >= 0.0 and v >= 0.0 and (u + v) <= 1.0


static func _fallback_icon() -> Texture2D:
	const FALLBACK_ID := "_fallback"
	if _cache.has(FALLBACK_ID):
		return _cache[FALLBACK_ID] as Texture2D
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.fill_rect(Rect2i(8, 8, SIZE - 16, SIZE - 16), Color(0.55, 0.55, 0.6, 1.0))
	var texture := ImageTexture.create_from_image(image)
	_cache[FALLBACK_ID] = texture
	return texture
