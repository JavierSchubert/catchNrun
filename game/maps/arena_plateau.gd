extends Node2D

const TILE_SIZE := 128
const COLS := 60
const ROWS := 40

@onready var floor_layer: TileMapLayer = $FloorLayer
@onready var overlay_layer: TileMapLayer = $OverlayLayer


func _ready() -> void:
	floor_layer.clear()
	overlay_layer.clear()
	_paint_floor()


func _paint_floor() -> void:
	var left := -COLS / 2
	var top := -ROWS / 2

	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(left + x, top + y)
			var atlas := Vector2i((x + y * 3) % 8, (x * 2 + y) % 8)
			floor_layer.set_cell(cell, 0, atlas)

	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(left + x, top + y)
			var on_border := x == 0 or y == 0 or x == COLS - 1 or y == ROWS - 1
			if on_border:
				overlay_layer.set_cell(cell, 0, Vector2i(7, 7))
