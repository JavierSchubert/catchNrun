class_name VisionKnowledge
extends RefCounted
## What one team knows about the map: a grid of currently visible / ever explored cells and a
## memory of enemy structures that were seen (docs/vision.README.md).
##
## Pure data + grid math, no scene-tree access, so it can be unit tested on its own.
## VisionSystem feeds it from synced world state every update.
##
## Enemy *units* are deliberately not remembered: only structures persist.

enum State { UNEXPLORED, PREVIOUSLY_SEEN, VISIBLE }

const DEFAULT_CELL_SIZE := 64.0

var bounds := Rect2()
var cell_size := DEFAULT_CELL_SIZE
var cols := 0
var rows := 0
## One byte per cell, row-major (index = y * cols + x). 1 = currently visible.
var visible_cells := PackedByteArray()
## One byte per cell. 1 = seen at least once; never cleared except by reset().
var explored_cells := PackedByteArray()

var _last_known: Dictionary = {} ## String id -> LastKnownBuilding


## Snapshot of an enemy structure as it was when last seen. Presentation draws these as
## ghosts while the footprint is outside current vision.
class LastKnownBuilding extends RefCounted:
	var id := ""
	var kind := 0 ## BuildingDef.Kind
	var display_name := ""
	var owner_peer_id := 0
	var position := Vector2.ZERO ## Footprint center, world space.
	var footprint := Vector2i(1, 1)
	var pixel_size := Vector2.ZERO
	var level := 1
	var under_construction := false
	var last_seen_msec := 0

	func world_rect() -> Rect2:
		return Rect2(position - pixel_size * 0.5, pixel_size)

	## Same remembered facts (ignores last_seen_msec).
	func same_as(other: LastKnownBuilding) -> bool:
		return other != null and id == other.id and kind == other.kind \
			and display_name == other.display_name and owner_peer_id == other.owner_peer_id \
			and position.is_equal_approx(other.position) and footprint == other.footprint \
			and pixel_size.is_equal_approx(other.pixel_size) and level == other.level \
			and under_construction == other.under_construction


func _init(p_bounds := Rect2(), p_cell_size := DEFAULT_CELL_SIZE) -> void:
	bounds = p_bounds if p_bounds.size.x > 0.0 and p_bounds.size.y > 0.0 else PlateauMap.world_bounds()
	cell_size = maxf(p_cell_size, 1.0)
	cols = maxi(ceili(bounds.size.x / cell_size), 1)
	rows = maxi(ceili(bounds.size.y / cell_size), 1)
	visible_cells.resize(cols * rows)
	explored_cells.resize(cols * rows)
	reset()


## Forget everything: no explored cells, no remembered structures.
func reset() -> void:
	visible_cells.fill(0)
	explored_cells.fill(0)
	_last_known.clear()


func cell_count() -> int:
	return cols * rows


func grid_size() -> Vector2i:
	return Vector2i(cols, rows)


## Cell containing `world_pos`, or (-1, -1) outside the map bounds.
func world_to_cell(world_pos: Vector2) -> Vector2i:
	if not bounds.has_point(world_pos):
		return Vector2i(-1, -1)
	var local := world_pos - bounds.position
	return Vector2i(
		clampi(floori(local.x / cell_size), 0, cols - 1),
		clampi(floori(local.y / cell_size), 0, rows - 1)
	)


func is_cell_valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


func cell_index(cell: Vector2i) -> int:
	return cell.y * cols + cell.x


func cell_center(cell: Vector2i) -> Vector2:
	return bounds.position + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(bounds.position + Vector2(cell) * cell_size, Vector2(cell_size, cell_size))


# --- Per-update visibility ----------------------------------------------------------------


## Start a new update: nothing is visible until reveal_circle() runs again.
## Explored cells and remembered structures are kept.
func begin_update() -> void:
	visible_cells.fill(0)


## Marks every cell whose center lies within `radius` of `center` as visible + explored.
func reveal_circle(center: Vector2, radius: float) -> void:
	if radius <= 0.0:
		return
	var min_cell := _clamped_cell(center - Vector2(radius, radius))
	var max_cell := _clamped_cell(center + Vector2(radius, radius))
	var radius_sq := radius * radius
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			if cell_center(cell).distance_squared_to(center) > radius_sq:
				continue
			var index := y * cols + x
			visible_cells[index] = 1
			explored_cells[index] = 1


func state_at_cell(cell: Vector2i) -> State:
	if not is_cell_valid(cell):
		return State.UNEXPLORED
	var index := cell_index(cell)
	if visible_cells[index] != 0:
		return State.VISIBLE
	if explored_cells[index] != 0:
		return State.PREVIOUSLY_SEEN
	return State.UNEXPLORED


func state_at(world_pos: Vector2) -> State:
	return state_at_cell(world_to_cell(world_pos))


func is_visible_at(world_pos: Vector2) -> bool:
	return state_at(world_pos) == State.VISIBLE


func is_explored_at(world_pos: Vector2) -> bool:
	return state_at(world_pos) != State.UNEXPLORED


## True when any cell touched by `rect` is currently visible. Used for structure footprints:
## a structure is seen as soon as any part of its footprint is lit.
func rect_has_visible(rect: Rect2) -> bool:
	if not rect.intersects(bounds):
		return false
	var min_cell := _clamped_cell(rect.position)
	## Shave a hair so a rect ending exactly on a cell edge does not touch the next cell.
	var max_cell := _clamped_cell(rect.end - Vector2(0.01, 0.01))
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			if visible_cells[y * cols + x] != 0:
				return true
	return false


func visible_cell_count() -> int:
	return _count(visible_cells)


func explored_cell_count() -> int:
	return _count(explored_cells)


# --- Last-known structures ----------------------------------------------------------------


## Stores or refreshes a remembered structure. Returns true when the memory changed.
func remember_building(entry: LastKnownBuilding) -> bool:
	if entry == null or entry.id.is_empty():
		return false
	var existing: LastKnownBuilding = _last_known.get(entry.id)
	if existing != null and existing.same_as(entry):
		existing.last_seen_msec = entry.last_seen_msec
		return false
	_last_known[entry.id] = entry
	return true


func forget_building(id: String) -> bool:
	return _last_known.erase(id)


func has_last_known_building(id: String) -> bool:
	return _last_known.has(id)


func last_known_building(id: String) -> LastKnownBuilding:
	return _last_known.get(id)


func last_known_buildings() -> Array[LastKnownBuilding]:
	var result: Array[LastKnownBuilding] = []
	for entry in _last_known.values():
		result.append(entry as LastKnownBuilding)
	return result


## Remembered structures whose footprint is not currently visible: what the ghost layer draws.
func hidden_last_known_buildings() -> Array[LastKnownBuilding]:
	var result: Array[LastKnownBuilding] = []
	for entry in _last_known.values():
		var building := entry as LastKnownBuilding
		if not rect_has_visible(building.world_rect()):
			result.append(building)
	return result


## Drops remembered structures that are gone: their footprint is visible right now but no live
## structure with that id exists any more. `live_ids` is a Dictionary used as a set.
## Returns how many entries were removed.
func purge_unseen(live_ids: Dictionary) -> int:
	var stale: Array[String] = []
	for id in _last_known.keys():
		if live_ids.has(id):
			continue
		var entry := _last_known[id] as LastKnownBuilding
		if rect_has_visible(entry.world_rect()):
			stale.append(String(id))
	for id in stale:
		_last_known.erase(id)
	return stale.size()


func _clamped_cell(world_pos: Vector2) -> Vector2i:
	var local := world_pos - bounds.position
	return Vector2i(
		clampi(floori(local.x / cell_size), 0, cols - 1),
		clampi(floori(local.y / cell_size), 0, rows - 1)
	)


static func _count(mask: PackedByteArray) -> int:
	var total := 0
	for value in mask:
		if value != 0:
			total += 1
	return total
