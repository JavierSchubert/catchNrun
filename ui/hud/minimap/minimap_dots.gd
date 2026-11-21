extends Control
## Draws living unit pixels on the minimap. Bounds come from the MatchMinimap parent.

const DOT_SIZE := 4.0


func _draw() -> void:
	var minimap := get_parent() as MatchMinimap
	if minimap == null or Engine.is_editor_hint():
		return
	var map_bounds: Rect2 = minimap.map_bounds
	var local_id := 1
	var tree := get_tree()
	if tree != null and multiplayer.has_multiplayer_peer():
		local_id = multiplayer.get_unique_id()
	var inset := 3.0
	var draw_size := size - Vector2(inset * 2.0, inset * 2.0)
	if draw_size.x <= 1.0 or draw_size.y <= 1.0 or tree == null:
		return
	for node in tree.get_nodes_in_group("units"):
		if not node is Unit:
			continue
		var unit := node as Unit
		if not unit.is_alive():
			continue
		var point := _world_to_minimap(unit.global_position, map_bounds, inset, draw_size)
		var color := unit.selection_affinity_color(local_id)
		var half := DOT_SIZE * 0.5
		draw_rect(Rect2(point - Vector2(half, half), Vector2(DOT_SIZE, DOT_SIZE)), color, true)


func _world_to_minimap(world_pos: Vector2, map_bounds: Rect2, inset: float, draw_size: Vector2) -> Vector2:
	var u := 0.5
	var v := 0.5
	if map_bounds.size.x > 0.0:
		u = (world_pos.x - map_bounds.position.x) / map_bounds.size.x
	if map_bounds.size.y > 0.0:
		v = (world_pos.y - map_bounds.position.y) / map_bounds.size.y
	u = clampf(u, 0.0, 1.0)
	v = clampf(v, 0.0, 1.0)
	return Vector2(inset + u * draw_size.x, inset + v * draw_size.y)
