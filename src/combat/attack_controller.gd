class_name AttackController
extends Node
## Host-only attack and chase helper for a unit.
## Direct attack targets win over automatic acquisition.

var attack_range := 64.0
var acquisition_range := 900.0
var attack_interval := 0.8

var explicit_target: Node2D = null
var _cooldown := 0.0


func clear_target() -> void:
	explicit_target = null


func set_explicit_target(target: Node2D) -> void:
	explicit_target = target


func tick(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func can_swing() -> bool:
	return _cooldown <= 0.0


func mark_swung() -> void:
	_cooldown = attack_interval


func in_attack_range(from: Vector2, target: Node2D) -> bool:
	return from.distance_to(target.global_position) <= attack_range


func pick_target(from: Vector2, candidates: Array[Node2D]) -> Node2D:
	if explicit_target != null and is_instance_valid(explicit_target):
		if _is_valid_candidate(explicit_target):
			return explicit_target
		explicit_target = null

	var best: Node2D = null
	var best_distance := INF
	for candidate in candidates:
		if not _is_valid_candidate(candidate):
			continue
		var distance := from.distance_to(candidate.global_position)
		if distance > acquisition_range:
			continue
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _is_valid_candidate(node: Node2D) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.has_method("is_attackable"):
		return false
	return bool(node.call("is_attackable"))
