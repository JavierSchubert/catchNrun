class_name ItemShop
extends StaticBody2D
## Neutral central shop. Clickable for both roles; not attackable / not Runner-built.
## Footprint is 3x3 build cells (ConstructionManager.CELL_SIZE).

const SHOP_TEXTURE := preload("res://assets/sprites/buildings/crystal_assets_128/shop_128.png")
const FOOTPRINT := Vector2i(3, 3)
const CAST_RANGE := 48.0

var grid: BuildGrid
var anchor_cell := Vector2i.ZERO

var _selection_circle: SelectionCircle
var _selection_hovered := false
var _selection_selected := false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var art: Sprite2D = $Art


func _ready() -> void:
	collision_layer = PhysicsLayers.WORLD | PhysicsLayers.BUILDING
	collision_mask = 0
	add_to_group("item_shop")
	add_to_group("clickable")
	if grid != null:
		global_position = grid.footprint_center(anchor_cell, FOOTPRINT)
	_apply_visual()
	_ensure_selection_circle()
	refresh_selection_visual()


func is_alive() -> bool:
	return true


func is_attackable() -> bool:
	return false


func is_clickable() -> bool:
	return true


func is_player_character() -> bool:
	return false


func selection_hit_radius() -> float:
	var cell := ConstructionManager.CELL_SIZE
	return maxf(FOOTPRINT.x, FOOTPRINT.y) * cell * 0.5


func set_selection_hover(active: bool) -> void:
	_selection_hovered = active
	refresh_selection_visual()


func set_selection_selected(active: bool) -> void:
	_selection_selected = active
	refresh_selection_visual()


func refresh_selection_visual() -> void:
	_ensure_selection_circle()
	if _selection_circle == null:
		return
	_selection_circle.configure(selection_hit_radius(), SelectionCircle.COLOR_RUNNER_TEAM)
	_selection_circle.set_hover(_selection_hovered and not _selection_selected)
	_selection_circle.set_selected(_selection_selected)


func world_rect() -> Rect2:
	var cell := ConstructionManager.CELL_SIZE
	var size := Vector2(FOOTPRINT) * cell
	return Rect2(global_position - size * 0.5, size)


static func interaction_reach() -> float:
	var cell := ConstructionManager.CELL_SIZE
	var half := maxf(FOOTPRINT.x, FOOTPRINT.y) * cell * 0.5
	return half + CAST_RANGE


func _apply_visual() -> void:
	var cell := ConstructionManager.CELL_SIZE
	var pixel_size := Vector2(FOOTPRINT) * cell
	if collision_shape != null:
		var rect := RectangleShape2D.new()
		rect.size = pixel_size
		collision_shape.shape = rect
	if art != null and SHOP_TEXTURE != null:
		art.texture = SHOP_TEXTURE
		var tex_size := SHOP_TEXTURE.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			art.scale = pixel_size / tex_size


func _ensure_selection_circle() -> void:
	if _selection_circle != null and is_instance_valid(_selection_circle):
		return
	_selection_circle = SelectionCircle.new()
	_selection_circle.name = "SelectionCircle"
	add_child(_selection_circle)
