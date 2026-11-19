class_name PathFollow
extends RefCounted
## Walks a path one point at a time and stops at the destination.
## Direction is normalized, so a diagonal step is not faster than a straight one.

const ARRIVE_DISTANCE := 12.0

var points: PackedVector2Array = PackedVector2Array()
var index := 0


func set_path(path: PackedVector2Array) -> void:
	points = path
	index = 0


func finished() -> bool:
	return index >= points.size()


func direction(from: Vector2) -> Vector2:
	while index < points.size() and from.distance_to(points[index]) <= ARRIVE_DISTANCE:
		index += 1
	if finished():
		return Vector2.ZERO
	return (points[index] - from).normalized()
