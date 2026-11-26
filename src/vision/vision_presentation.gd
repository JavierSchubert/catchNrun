class_name VisionPresentation
extends RefCounted
## Shared "may the local player see this entity right now?" helper for world presentation
## and input (docs/vision.README.md §10). Everything here asks VisionSystem; nothing detects
## hidden entities on its own.
##
## Without a VisionSystem (isolated tests, entities outside the tree) every entity counts as
## visible, so code paths that have no match around them behave exactly as before fog.


## True when the local team may see `entity` this frame. Only Units and finished-def
## Buildings are fogged; any other node is always visible.
static func can_local_see(entity: Node) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	var vision := _vision_for(entity)
	if vision == null:
		return true
	return can_see_with(vision, entity)


## Same decision against an explicit VisionSystem (used by per-frame presenters so they
## resolve the system once, not per entity).
static func can_see_with(vision: VisionSystem, entity: Node) -> bool:
	if vision == null:
		return true
	if entity is Unit:
		return vision.can_see_unit(entity as Unit)
	if entity is Building:
		var building := entity as Building
		## Legacy footprint-only buildings (def == null) are test fixtures, never fogged.
		if building.def == null:
			return true
		return vision.can_see_building(building)
	return true


static func _vision_for(entity: Node) -> VisionSystem:
	if not entity.is_inside_tree():
		return null
	return VisionSystem.find_in(entity.get_tree())
