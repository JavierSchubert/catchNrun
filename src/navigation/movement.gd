class_name UnitMovement
extends Node
## Applies either a direct direction or a path order. The match host is the only peer that calls apply().
## A new move order replaces the current path.

var speed := 220.0
var intent := Vector2.ZERO

var _follow := PathFollow.new()
var _has_order := false


func has_order() -> bool:
	return _has_order


func order_move(from: Vector2, to: Vector2) -> void:
	_follow.set_path(NavigationPaths.to_point(from, to))
	_has_order = true
	intent = Vector2.ZERO


func clear_order() -> void:
	_follow.set_path(PackedVector2Array())
	_has_order = false
	intent = Vector2.ZERO


func apply(body: CharacterBody2D) -> void:
	if _has_order:
		intent = _follow.direction(body.global_position)
		if _follow.finished():
			_has_order = false
			intent = Vector2.ZERO
	body.velocity = intent.limit_length(1.0) * speed
	body.move_and_slide()
