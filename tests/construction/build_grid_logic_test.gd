extends Node
## Headless build-grid / footprint checks from building.README.md.
##   godot --headless --path . res://tests/construction/build_grid_logic_test.tscn

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_test_world_cell_roundtrip()
	_test_footprint_rect_matches_cells()
	_test_bounds_enclose_footprint()
	_test_validator_rejects_out_of_bounds()
	_test_item_layer_not_in_blockers()
	if _failures.is_empty():
		print("PASS: build grid logic")
		get_tree().quit(0)
	else:
		print("FAIL: %d check(s)" % _failures.size())
		for failure in _failures:
			print(" - %s" % failure)
		get_tree().quit(1)


func _test_world_cell_roundtrip() -> void:
	var grid := BuildGrid.new(32.0, Vector2(-64, -64), Rect2i(0, 0, 10, 10))
	var cell := Vector2i(3, 4)
	var top_left := grid.cell_to_world_top_left(cell)
	_check(grid.world_to_cell(top_left + Vector2(1, 1)) == cell, "world_to_cell maps interior points back to the cell")
	_check(grid.world_to_cell(top_left + Vector2(31.9, 31.9)) == cell, "cell covers a full cell_size square")


func _test_footprint_rect_matches_cells() -> void:
	var grid := BuildGrid.new(32.0, Vector2.ZERO, Rect2i(0, 0, 20, 20))
	var rect := grid.footprint_world_rect(Vector2i(1, 2), Vector2i(3, 2))
	_near(rect.position.x, 32.0, "footprint x originates at anchor cell")
	_near(rect.position.y, 64.0, "footprint y originates at anchor cell")
	_near(rect.size.x, 96.0, "3 cells wide => 3 * cell_size hitbox width")
	_near(rect.size.y, 64.0, "2 cells tall => 2 * cell_size hitbox height")
	_check(grid.cells_in_footprint(Vector2i(1, 2), Vector2i(3, 2)).size() == 6, "3x2 footprint lists six cells")


func _test_bounds_enclose_footprint() -> void:
	var grid := BuildGrid.new(32.0, Vector2.ZERO, Rect2i(0, 0, 5, 5))
	_check(grid.contains_footprint(Vector2i(0, 0), Vector2i(2, 2)), "2x2 fits in the top-left of a 5x5 grid")
	_check(not grid.contains_footprint(Vector2i(4, 4), Vector2i(2, 2)), "2x2 at the last cell overflows bounds")


func _test_validator_rejects_out_of_bounds() -> void:
	var grid := BuildGrid.new(32.0, Vector2.ZERO, Rect2i(0, 0, 4, 4))
	var validator := PlacementValidator.new(grid)
	_check(not validator.can_place(Vector2i(3, 3), Vector2i(2, 2), null), "validator rejects out-of-bounds without physics")
	_check(validator.can_place(Vector2i(1, 1), Vector2i(2, 2), null), "validator accepts in-bounds when space is null")


func _test_item_layer_not_in_blockers() -> void:
	_check((PhysicsLayers.BUILD_BLOCKERS & PhysicsLayers.ITEM) == 0, "item layer does not block building by default")
	_check((PhysicsLayers.BUILD_BLOCKERS & PhysicsLayers.OBSTACLE) != 0, "obstacle blocks building")
	_check((PhysicsLayers.BUILD_BLOCKERS & PhysicsLayers.UNIT) != 0, "unit blocks building")
	_check((PhysicsLayers.BUILD_BLOCKERS & PhysicsLayers.BUILDING) != 0, "building blocks building")
	_check((PhysicsLayers.BUILD_BLOCKERS & PhysicsLayers.DESTRUCTIBLE) != 0, "destructible blocks building")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _near(actual: float, expected: float, message: String, eps := 0.001) -> void:
	if absf(actual - expected) > eps:
		_failures.append("%s (got %s expected %s)" % [message, actual, expected])
