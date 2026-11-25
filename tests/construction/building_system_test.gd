extends Node2D
## Interactive building-system sandbox: the real ConstructionManager + build UI + grid,
## without needing the lobby -> role selection -> match flow.
##   godot --path . res://tests/construction/building_system_test.tscn
##
## Controls:
##   Click a build button (bottom-right panel) to arm a structure, move the mouse to
##   preview it snapped to the grid, LMB to place (spends Crystals and starts the few
##   seconds construction progress bar). RMB or Esc cancels placement.
##   Click a placed structure to Upgrade or Destroy it from the same panel.

@onready var camera: Camera2D = %Camera2D


func _ready() -> void:
	GameManager.prepare_game_test()
	camera.position = Unit.MAP_BOUNDS.get_center()
	camera.enabled = DisplayServer.get_name() != "headless"
	if camera.enabled:
		camera.make_current()
	_spawn_blockers()


func _spawn_blockers() -> void:
	## A couple of pre-placed obstacles so placement validation has something to reject.
	_add_blocker(PhysicsLayers.WORLD | PhysicsLayers.OBSTACLE, Color(0.45, 0.35, 0.25, 0.95), Vector2(96, 96), Vector2(-200, -120))
	_add_blocker(PhysicsLayers.WORLD | PhysicsLayers.DESTRUCTIBLE, Color(0.85, 0.55, 0.2, 0.95), Vector2(48, 48), Vector2(180, 100))


func _add_blocker(layer: int, color: Color, size: Vector2, pos: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var visual := Polygon2D.new()
	var half := size * 0.5
	visual.color = color
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	body.add_child(visual)
	add_child(body)
