class_name EntityVisionPresenter
extends Node
## Hides world units and structures the local team cannot currently see (docs/vision.README.md
## §5, §10). One node per match; it toggles `visible` on the live entities, so their health
## bars, name labels and selection circles disappear with them.
##
## - Own team: always shown while alive (VisionSystem.can_see_unit / can_see_building).
## - Enemy units: shown only while inside current vision; no memory.
## - Enemy structures: shown only while any footprint cell is lit. Remembered structures are
##   drawn by LastKnownBuildingLayer as ghosts instead.
## - Dead / eliminated units keep the `visible = false` Unit sets itself; this node never
##   re-shows them.
##
## Entities are checked every frame because enemy units move between 0.1 s vision refreshes.
## Nothing here changes gameplay: hidden entities still tick, replicate and collide.

var _vision: VisionSystem


func _process(_delta: float) -> void:
	var vision := _resolve_vision()
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("units"):
		var unit := node as Unit
		if unit == null or not unit.is_alive():
			continue
		_apply(unit, VisionPresentation.can_see_with(vision, unit))
	for node in tree.get_nodes_in_group("buildings"):
		var building := node as Building
		if building == null or building.def == null:
			continue
		_apply(building, VisionPresentation.can_see_with(vision, building))


func _apply(entity: CanvasItem, show_entity: bool) -> void:
	if entity.visible != show_entity:
		entity.visible = show_entity


func _resolve_vision() -> VisionSystem:
	if _vision != null and is_instance_valid(_vision) and _vision.is_inside_tree():
		return _vision
	_vision = VisionSystem.find_in(get_tree())
	return _vision
