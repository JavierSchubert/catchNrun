extends Node
## Checks the right-click move marker FX.
##   godot --headless --path . res://tests/fx/move_click_marker_test.tscn
##
## Or from PowerShell on a machine that has Godot:
##   powershell -File scripts/test/move_click_marker_test.ps1 -Godot "C:\Path\To\Godot.exe"

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	await _run()


func _run() -> void:
	_test_null_parent_is_safe()
	await _test_spawns_at_world_position()
	await _test_attack_color_and_spawn_on()
	await _test_pops_then_frees()
	await _test_second_click_spawns_another_marker()
	if _failures.is_empty():
		print("PASS: move click marker")
		get_tree().quit(0)
	else:
		print("FAIL: %d check(s)" % _failures.size())
		for failure in _failures:
			print(" - %s" % failure)
		get_tree().quit(1)


func _test_null_parent_is_safe() -> void:
	var marker := MoveClickMarker.spawn(null, Vector2(10, 20))
	if marker != null:
		_fail("spawn with a null parent must return null")


func _test_spawns_at_world_position() -> void:
	var host := Node2D.new()
	add_child(host)
	host.global_position = Vector2(100, 50)
	var at := Vector2(320, -140)
	var marker := MoveClickMarker.spawn(host, at)
	if marker == null:
		_fail("spawn must return a marker")
		host.queue_free()
		return
	await get_tree().process_frame
	_near(marker.global_position, at, "marker sits on the clicked world position")
	if marker.get_parent() != host:
		_fail("marker must be parented under the given host")
	if marker.scale != Vector2(0.25, 0.25):
		_fail("marker should start at the pop-in scale (got %s)" % marker.scale)
	if marker.ring_color != MoveClickMarker.MOVE_COLOR:
		_fail("default spawn color must be move blue")
	marker.queue_free()
	host.queue_free()
	await get_tree().process_frame


func _test_attack_color_and_spawn_on() -> void:
	var host := Node2D.new()
	add_child(host)
	var ground := MoveClickMarker.spawn(host, Vector2(50, 60), MoveClickMarker.ATTACK_COLOR)
	if ground == null:
		_fail("attack-colored ground spawn must return a marker")
		host.queue_free()
		return
	if ground.ring_color != MoveClickMarker.ATTACK_COLOR:
		_fail("attack-move ground marker must use attack red")
	ground.queue_free()
	var target := Node2D.new()
	host.add_child(target)
	target.global_position = Vector2(200, 100)
	var on_target := MoveClickMarker.spawn_on(target, MoveClickMarker.ATTACK_COLOR)
	if on_target == null:
		_fail("spawn_on must return a marker")
		host.queue_free()
		return
	await get_tree().process_frame
	if on_target.get_parent() != target:
		_fail("spawn_on must parent the marker under the target")
	_near(on_target.global_position, target.global_position, "spawn_on sits on the target")
	if on_target.ring_color != MoveClickMarker.ATTACK_COLOR:
		_fail("entity attack marker must use attack red")
	on_target.queue_free()
	target.queue_free()
	host.queue_free()
	await get_tree().process_frame


func _test_pops_then_frees() -> void:
	var host := Node2D.new()
	add_child(host)
	var marker := MoveClickMarker.spawn(host, Vector2(12, 34))
	if marker == null:
		_fail("spawn must return a marker for the lifetime check")
		host.queue_free()
		return
	var lifetime := marker.lifetime_seconds()
	# Allow the deferred _play() to start, then sample mid-pop.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.06).timeout
	if not is_instance_valid(marker):
		_fail("marker must still exist shortly after spawn")
		host.queue_free()
		return
	# Mid-pop: scale should have grown past the start value.
	if marker.scale.x <= 0.25 + 0.001:
		_fail("marker scale should grow during the pop tween (got %s)" % marker.scale)
	await get_tree().create_timer(lifetime + 0.15).timeout
	if is_instance_valid(marker):
		_fail("marker must free itself after the tween finishes")
	if host.get_child_count() != 0:
		_fail("host should have no marker children after free")
	host.queue_free()
	await get_tree().process_frame


func _test_second_click_spawns_another_marker() -> void:
	var host := Node2D.new()
	add_child(host)
	var first := MoveClickMarker.spawn(host, Vector2(1, 1))
	var second := MoveClickMarker.spawn(host, Vector2(2, 2))
	if first == null or second == null:
		_fail("each spawn must return its own marker")
		host.queue_free()
		return
	if first == second:
		_fail("repeated clicks must create distinct marker instances")
	_equal(host.get_child_count(), 2, "two clicks leave two markers until they fade")
	_near(first.global_position, Vector2(1, 1), "first marker keeps its click position")
	_near(second.global_position, Vector2(2, 2), "second marker keeps its click position")
	first.queue_free()
	second.queue_free()
	host.queue_free()
	await get_tree().process_frame


func _equal(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_fail("%s (got %d, expected %d)" % [message, actual, expected])


func _near(actual: Vector2, expected: Vector2, message: String) -> void:
	if not actual.is_equal_approx(expected):
		_fail("%s (got %s, expected %s)" % [message, actual, expected])


func _fail(message: String) -> void:
	_failures.append(message)
	print("failed: %s" % message)
