class_name AttackController
extends Node
## Host-only attack and chase helper for a unit.
## Direct attack targets win over automatic acquisition.

var attack_range := 64.0
var acquisition_range := 900.0
var attack_interval := 0.8

var explicit_target: Node2D = null
## When set, the unit resumes this destination after finishing opportunistic attacks.
var attack_move_destination := Vector2.ZERO
var attack_move_active := false
## True after diverting from the attack-move path to chase an acquired target.
var attack_move_chasing := false
var _cooldown := 0.0


func clear_target() -> void:
	explicit_target = null


func clear_attack_move() -> void:
	attack_move_active = false
	attack_move_destination = Vector2.ZERO
	attack_move_chasing = false


func set_explicit_target(target: Node2D) -> void:
	explicit_target = target
	clear_attack_move()


func begin_attack_move(destination: Vector2) -> void:
	explicit_target = null
	attack_move_active = true
	attack_move_chasing = false
	attack_move_destination = destination


func tick(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func can_swing() -> bool:
	return _cooldown <= 0.0


func mark_swung() -> void:
	_cooldown = attack_interval


func in_attack_range(from: Vector2, target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	## Buildings: reach extends to the footprint edge (StructureMelee), not the solid center.
	if target is Building:
		return StructureMelee.in_range(from, attack_range, target as Building)
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
