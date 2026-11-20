extends Node
## Checks selection priority from controls.README.md §1.1.
##   godot --headless --path . res://tests/selection/selection_priority_test.tscn

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_test_own_unit_wins()
	_test_player_over_npc()
	_test_random_among_players()
	_test_empty_candidates()
	if _failures.is_empty():
		print("PASS: selection priority")
		get_tree().quit(0)
	else:
		print("FAIL: %d check(s)" % _failures.size())
		for failure in _failures:
			print(" - %s" % failure)
		get_tree().quit(1)


func _test_own_unit_wins() -> void:
	var own := _stub(true, true, 1)
	var other := _stub(false, true, 2)
	var npc := _stub(false, false, 0)
	var picked := SelectionResolver.pick([other, npc, own], 1)
	_check(picked == own, "own unit is selected when present among candidates")


func _test_player_over_npc() -> void:
	var runner := _stub(false, true, 2)
	var npc_a := _stub(false, false, 0)
	var npc_b := _stub(false, false, 0)
	var picked := SelectionResolver.pick([npc_a, runner, npc_b], 1)
	_check(picked == runner, "player figures outrank NPCs when own unit is absent")


func _test_random_among_players() -> void:
	var a := _stub(false, true, 2)
	var b := _stub(false, true, 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for _i in 40:
		var picked := SelectionResolver.pick([a, b], 1, rng)
		seen[picked] = true
	_check(seen.has(a) and seen.has(b), "non-owned player candidates are picked at random")


func _test_empty_candidates() -> void:
	var picked := SelectionResolver.pick([], 1)
	_check(picked == null, "empty candidate list yields no selection")


func _stub(own: bool, player: bool, peer_id: int) -> StubClickable:
	var node := StubClickable.new()
	node.own = own
	node.player = player
	node.peer_id = peer_id
	add_child(node)
	return node


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class StubClickable extends Node:
	var own := false
	var player := false
	var peer_id := 0

	func is_local_controllable(_local_peer_id: int) -> bool:
		return own

	func is_player_character() -> bool:
		return player
