extends Control
## Draws living unit markers and the local camera frustum on the minimap.

const DOT_SIZE := 4.0
const VIEW_RECT_COLOR := Color(1.0, 1.0, 1.0, 0.55)


func _draw() -> void:
	var minimap := get_parent() as MatchMinimap
	if minimap == null or Engine.is_editor_hint():
		return
	var tree := get_tree()
	if tree == null:
		return
	var draw_size := minimap.draw_area_size()
	if draw_size.x <= 1.0 or draw_size.y <= 1.0:
		return

	_draw_camera_view(minimap)

	var local_id := GameManager.local_peer_id()

	for node in tree.get_nodes_in_group("units"):
		if not node is Unit:
			continue
		var unit := node as Unit
		if not unit.is_alive():
			continue
		var point := minimap.world_to_minimap(unit.global_position)
		var color := unit.minimap_marker_color(local_id)
		var half := DOT_SIZE * 0.5
		draw_rect(Rect2(point - Vector2(half, half), Vector2(DOT_SIZE, DOT_SIZE)), color, true)


func _draw_camera_view(minimap: MatchMinimap) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null or not camera.is_current():
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var view_size := viewport.get_visible_rect().size
	var zoom := camera.zoom
	if zoom.x <= 0.001 or zoom.y <= 0.001:
		return
	var half_world := Vector2(view_size.x / zoom.x, view_size.y / zoom.y) * 0.5
	var top_left := minimap.world_to_minimap(camera.global_position - half_world)
	var bottom_right := minimap.world_to_minimap(camera.global_position + half_world)
	var rect := Rect2(top_left, bottom_right - top_left).abs()
	if rect.size.x < 2.0 or rect.size.y < 2.0:
		return
	draw_rect(rect, VIEW_RECT_COLOR, false, 1.0)
