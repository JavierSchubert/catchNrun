extends Node2D

const TILE_SIZE := 128
const COLS := 60
const ROWS := 40

@onready var floor_layer: TileMapLayer = $FloorLayer
@onready var overlay_layer: TileMapLayer = $OverlayLayer


func _ready() -> void:
	floor_layer.clear()
	overlay_layer.clear()
