extends Node
## Checks right-click movement orders from docs/controls.README.md.
##   godot --headless --path . res://tests/navigation/move_command_test.tscn

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_test_straight_path()
	_test_follow_and_stop()
	_test_replace_order()
	if _failures.is_empty():
		print("PASS: move command")
		get_tree().quit(0)
	else:
		print("FAIL: %d check(s)" % _failures.size())
		for failure in _failures:
			print(" - %s" % failure)
		get_tree().quit(1)


func _test_straight_path() -> void:
	var path := NavigationPaths.to_point(Vector2.ZERO, Vector2(300, 0))
	_equal(path.size(), 1, "a click builds one waypoint when nothing blocks the ground")
	_near(path[0], Vector2(300, 0), "the waypoint is the clicked world position")
	var same := NavigationPaths.to_point(Vector2(4, 4), Vector2(4, 4))
	_equal(same.size(), 0, "clicking the current position clears the path")


func _test_follow_and_stop() -> void:
	var follow := PathFollow.new()
	follow.set_path(PackedVector2Array([Vector2(100, 0), Vector2(100, 80)]))
	var first := follow.direction(Vector2.ZERO)
	_near(first, Vector2.RIGHT, "the unit walks toward the first path point")
	_near_length(first.length(), 1.0, "the movement direction is normalized")
	var diagonal := PathFollow.new()
	diagonal.set_path(PackedVector2Array([Vector2(80, 80)]))
	_near_length(diagonal.direction(Vector2.ZERO).length(), 1.0, "a diagonal step stays at length 1")
	var toward_second := follow.direction(Vector2(100, 0))
	_near(toward_second, Vector2.DOWN, "passing a point advances to the next one")
	var stopped := follow.direction(Vector2(100, 80))
	_near(stopped, Vector2.ZERO, "the unit stops when it reaches the destination")
	if not follow.finished():
		_fail("the path is finished at the destination")


func _test_replace_order() -> void:
	var follow := PathFollow.new()
	follow.set_path(PackedVector2Array([Vector2(200, 0)]))
	follow.set_path(NavigationPaths.to_point(Vector2.ZERO, Vector2(0, 150)))
	_near(follow.direction(Vector2.ZERO), Vector2.DOWN, "a new move order replaces the current path")


func _equal(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_fail("%s (got %d, expected %d)" % [message, actual, expected])


func _near(actual: Vector2, expected: Vector2, message: String) -> void:
	if not actual.is_equal_approx(expected):
		_fail("%s (got %s, expected %s)" % [message, actual, expected])


func _near_length(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_fail("%s (got %s, expected %s)" % [message, actual, expected])


func _fail(message: String) -> void:
	_failures.append(message)
	print("failed: %s" % message)
