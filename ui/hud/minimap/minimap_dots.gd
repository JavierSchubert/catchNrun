extends Control
## Draws the minimap overlay: fog of war, structure markers (live + last-known ghosts), living
## unit markers and the local camera frustum.
##
## Presentation only. What is known comes from VisionSystem (docs/vision.README.md); this node
## never detects hidden entities on its own. Without a VisionSystem (isolated tests) or with fog
## disabled, everything is drawn live and no fog is shown.
##
## Draw order (bottom to top): fog, structures, last-known structure ghosts, units, camera frustum.

const DOT_SIZE := 4.0
const VIEW_RECT_COLOR := Color(1.0, 1.0, 1.0, 0.55)

## Fog overlay alpha per vision state (black overlay): unexplored dark, seen dimmed, visible clear.
const FOG_UNEXPLORED_ALPHA := 0.9
const FOG_SEEN_ALPHA := 0.45
const FOG_VISIBLE_ALPHA := 0.0

## Structure markers are rects of the footprint, never smaller than this many minimap pixels.
const STRUCTURE_MIN_SIZE := 5.0
const STRUCTURE_OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.7)
## Last-known (hidden) structures are drawn faded so they read as remembered, not live.
const GHOST_ALPHA := 0.6

var _vision: VisionSystem
var _fog_image: Image
var _fog_texture: ImageTexture
var _fog_dirty := true


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _exit_tree() -> void:
	_disconnect_vision()


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

	var vision := _resolve_vision(tree)
	var local_id := GameManager.local_peer_id()
	_draw_fog(minimap, vision)
	_draw_structures(minimap, tree, vision, local_id)
	_draw_last_known_structures(minimap, vision)
	_draw_units(minimap, tree, vision, local_id)
	_draw_camera_view(minimap)


# --- Vision binding ---------------------------------------------------------------------------


func _resolve_vision(tree: SceneTree) -> VisionSystem:
	if _vision != null and is_instance_valid(_vision) and _vision.is_inside_tree():
		return _vision
	_disconnect_vision()
	var found := VisionSystem.find_in(tree)
	if found == null:
		return null
	_vision = found
	_vision.vision_updated.connect(_on_vision_changed)
	_vision.fog_enabled_changed.connect(_on_fog_enabled_changed)
	_fog_dirty = true
	return _vision


func _disconnect_vision() -> void:
	if _vision != null and is_instance_valid(_vision):
		if _vision.vision_updated.is_connected(_on_vision_changed):
			_vision.vision_updated.disconnect(_on_vision_changed)
		if _vision.fog_enabled_changed.is_connected(_on_fog_enabled_changed):
			_vision.fog_enabled_changed.disconnect(_on_fog_enabled_changed)
	_vision = null


func _on_vision_changed() -> void:
	_fog_dirty = true


func _on_fog_enabled_changed(_enabled: bool) -> void:
	_fog_dirty = true


# --- Fog --------------------------------------------------------------------------------------


func _draw_fog(minimap: MatchMinimap, vision: VisionSystem) -> void:
	if vision == null or not vision.fog_enabled or vision.knowledge == null:
		return
	var grid := vision.grid_size()
	if grid.x <= 0 or grid.y <= 0:
		return
	if _fog_dirty or _fog_texture == null or _fog_image == null \
			or _fog_image.get_size() != grid:
		_rebuild_fog_texture(vision, grid)
	if _fog_texture == null:
		return
	## Same world -> minimap mapping as the markers, so fog cells line up with the map image.
	var bounds := vision.world_bounds()
	var top_left := minimap.world_to_minimap(bounds.position)
	var bottom_right := minimap.world_to_minimap(bounds.end)
	var rect := Rect2(top_left, bottom_right - top_left).abs()
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	draw_texture_rect(_fog_texture, rect, false)


func _rebuild_fog_texture(vision: VisionSystem, grid: Vector2i) -> void:
	var visible_cells := vision.visible_mask()
	var explored_cells := vision.explored_mask()
	var count := grid.x * grid.y
	if visible_cells.size() < count or explored_cells.size() < count:
		return
	## RGBA8, black with a per-cell alpha derived from the same mask terrain_state() reads.
	var data := PackedByteArray()
	data.resize(count * 4)
	var unexplored_a := roundi(FOG_UNEXPLORED_ALPHA * 255.0)
	var seen_a := roundi(FOG_SEEN_ALPHA * 255.0)
	var visible_a := roundi(FOG_VISIBLE_ALPHA * 255.0)
	for i in count:
		var alpha := unexplored_a
		if visible_cells[i] != 0:
			alpha = visible_a
		elif explored_cells[i] != 0:
			alpha = seen_a
		data[i * 4 + 3] = alpha
	_fog_image = Image.create_from_data(grid.x, grid.y, false, Image.FORMAT_RGBA8, data)
	if _fog_texture == null or _fog_texture.get_size() != Vector2(grid):
		_fog_texture = ImageTexture.create_from_image(_fog_image)
	else:
		_fog_texture.update(_fog_image)
	_fog_dirty = false


# --- Structures -------------------------------------------------------------------------------


func _draw_structures(
	minimap: MatchMinimap, tree: SceneTree, vision: VisionSystem, local_id: int
) -> void:
	var viewer_role := _viewer_role(vision, local_id)
	for node in tree.get_nodes_in_group("buildings"):
		var building := node as Building
		if building == null or building.def == null or building.is_queued_for_deletion():
			continue
		if not building.is_attackable():
			continue
		if vision != null and not vision.can_see_building(building):
			continue
		var color := _structure_color(building, local_id, viewer_role)
		_draw_structure_rect(minimap, building.world_rect(), color)


func _draw_last_known_structures(minimap: MatchMinimap, vision: VisionSystem) -> void:
	if vision == null or not vision.fog_enabled:
		return
	## Remembered structures are always enemy structures (red), frozen at the last observed
	## footprint, and only listed while their footprint is outside current vision.
	var color := SelectionCircle.COLOR_HUNTER
	color.a *= GHOST_ALPHA
	for entry in vision.hidden_last_known_buildings():
		_draw_structure_rect(minimap, entry.world_rect(), color)


func _draw_structure_rect(minimap: MatchMinimap, world_rect: Rect2, color: Color) -> void:
	var top_left := minimap.world_to_minimap(world_rect.position)
	var bottom_right := minimap.world_to_minimap(world_rect.end)
	var rect := Rect2(top_left, bottom_right - top_left).abs()
	if rect.size.x < STRUCTURE_MIN_SIZE or rect.size.y < STRUCTURE_MIN_SIZE:
		var center := rect.get_center()
		var marker_size := Vector2(
			maxf(rect.size.x, STRUCTURE_MIN_SIZE), maxf(rect.size.y, STRUCTURE_MIN_SIZE)
		)
		rect = Rect2(center - marker_size * 0.5, marker_size)
	draw_rect(rect, color, true)
	var outline := STRUCTURE_OUTLINE_COLOR
	outline.a = minf(outline.a, color.a)
	draw_rect(rect, outline, false, 1.0)


## Viewer-relative like Unit.minimap_marker_color: own = green, allied Runner team = blue,
## enemy = red.
func _structure_color(building: Building, local_id: int, viewer_role: int) -> Color:
	if building.owner_peer_id == local_id:
		return SelectionCircle.COLOR_OWN
	if building.team_role() == viewer_role:
		return SelectionCircle.COLOR_RUNNER_TEAM
	return SelectionCircle.COLOR_HUNTER


func _viewer_role(vision: VisionSystem, local_id: int) -> int:
	if vision != null:
		return vision.viewer_role()
	var entry: Variant = GameManager.players.get(local_id)
	if entry is Dictionary:
		return int((entry as Dictionary).get("role", RoleConfig.Role.RUNNER))
	return RoleConfig.Role.RUNNER


# --- Units ------------------------------------------------------------------------------------


func _draw_units(
	minimap: MatchMinimap, tree: SceneTree, vision: VisionSystem, local_id: int
) -> void:
	var half := DOT_SIZE * 0.5
	for node in tree.get_nodes_in_group("units"):
		if not node is Unit:
			continue
		var unit := node as Unit
		if not unit.is_alive():
			continue
		## Own team always passes; enemies only while currently visible. Units never leave a
		## last-known ghost, so a hidden enemy is simply not drawn.
		if vision != null and not vision.can_see_unit(unit):
			continue
		var point := minimap.world_to_minimap(unit.global_position)
		var color := unit.minimap_marker_color(local_id)
		draw_rect(Rect2(point - Vector2(half, half), Vector2(DOT_SIZE, DOT_SIZE)), color, true)


# --- Camera -----------------------------------------------------------------------------------


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
