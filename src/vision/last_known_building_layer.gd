class_name LastKnownBuildingLayer
extends Node2D
## Draws last-known stand-ins ("ghosts") for enemy structures the local team saw earlier and
## cannot see right now (docs/vision.README.md §5.3). Ghosts show the position, footprint,
## kind, level and construction flag recorded when the structure was last in view; they do
## not update while hidden and vanish once the spot is seen empty (VisionSystem purges them).
##
## Ghosts are plain drawing, not nodes: they are not in the "clickable" / "buildings"
## groups, have no collision and no health bar, so selection, targeting and RMB commands
## ignore them. The layer sits at Building depth under the world fog, so ghosts are dimmed
## by the fog like the ground around them. Structures never discovered are not drawn at all.

## Fill colors mirror the structure scenes (wall.tscn / tower.tscn / crystal_mine.tscn).
const KIND_COLORS := {
	BuildingDef.Kind.WALL: Color(0.55, 0.52, 0.48),
	BuildingDef.Kind.TOWER: Color(0.5, 0.22, 0.2),
	BuildingDef.Kind.CRYSTAL_MINE: Color(0.25, 0.7, 0.8),
}
const FALLBACK_COLOR := Color(0.35, 0.7, 0.95)
## Ghosts look washed out so they read as "remembered", not live.
const DESATURATE := 0.45
const GHOST_ALPHA := 0.8
const CONSTRUCTION_ALPHA := 0.5
const OUTLINE_COLOR := Color(0.85, 0.9, 1.0, 0.55)
const LEVEL_FONT_SIZE := 14

var _vision: VisionSystem
var _ghosts: Array[VisionKnowledge.LastKnownBuilding] = []


func _ready() -> void:
	_vision = VisionSystem.find_in(get_tree())
	if _vision == null:
		return
	_vision.vision_updated.connect(_refresh)
	_vision.last_known_changed.connect(_refresh)
	_vision.fog_enabled_changed.connect(_on_fog_enabled_changed)
	_refresh()


func _exit_tree() -> void:
	if _vision != null and is_instance_valid(_vision):
		if _vision.vision_updated.is_connected(_refresh):
			_vision.vision_updated.disconnect(_refresh)
		if _vision.last_known_changed.is_connected(_refresh):
			_vision.last_known_changed.disconnect(_refresh)
		if _vision.fog_enabled_changed.is_connected(_on_fog_enabled_changed):
			_vision.fog_enabled_changed.disconnect(_on_fog_enabled_changed)
	_vision = null


## Ghosts drawn right now (remembered structures outside current vision). Read only.
func ghosts() -> Array[VisionKnowledge.LastKnownBuilding]:
	return _ghosts


func ghost_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for entry in _ghosts:
		ids.append(entry.id)
	return ids


func _on_fog_enabled_changed(_enabled: bool) -> void:
	_refresh()


func _refresh() -> void:
	var next: Array[VisionKnowledge.LastKnownBuilding] = []
	if _vision != null and is_instance_valid(_vision) and _vision.fog_enabled:
		next = _vision.hidden_last_known_buildings()
	if _same_ghosts(next):
		return
	_ghosts = next
	queue_redraw()


## Redraw only when the visible set or a remembered entry changed.
func _same_ghosts(next: Array[VisionKnowledge.LastKnownBuilding]) -> bool:
	if next.size() != _ghosts.size():
		return false
	for entry in next:
		var found := false
		for current in _ghosts:
			if current == entry:
				found = true
				break
		if not found:
			return false
	return true


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for entry in _ghosts:
		var rect := Rect2(to_local(entry.position) - entry.pixel_size * 0.5, entry.pixel_size)
		var base: Color = KIND_COLORS.get(entry.kind, FALLBACK_COLOR)
		var fill := base.lerp(Color(base.get_luminance(), base.get_luminance(), base.get_luminance()), DESATURATE)
		fill.a = CONSTRUCTION_ALPHA if entry.under_construction else GHOST_ALPHA
		draw_rect(rect, fill, true)
		draw_rect(rect, OUTLINE_COLOR, false, 2.0)
		if font != null and entry.level > 1:
			var text := "Lv %d" % entry.level
			var at := rect.get_center() + Vector2(-rect.size.x * 0.5, LEVEL_FONT_SIZE * 0.35)
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, LEVEL_FONT_SIZE, Color(1, 1, 1, 0.85))
