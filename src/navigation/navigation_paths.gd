class_name NavigationPaths
extends RefCounted
## Builds a path to a world position.
##
## The map has no navigation obstacles yet, so the shortest valid path is the
## straight line to the clicked point. A later obstacle map can replace this
## without changing the move command.


static func to_point(from: Vector2, to: Vector2) -> PackedVector2Array:
	if from.is_equal_approx(to):
		return PackedVector2Array()
	return PackedVector2Array([to])
