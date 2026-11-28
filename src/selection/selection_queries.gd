class_name SelectionQueries
extends RefCounted
## Shared selection lookups and controllable command issuance (minimap / HUD / A-click).


static func manager(tree: SceneTree) -> SelectionManager:
	if tree == null:
		return null
	return tree.get_first_node_in_group("selection_manager") as SelectionManager


static func selected_controllable(tree: SceneTree) -> Unit:
	var selection := manager(tree)
	if selection == null or not selection.is_controllable_selected():
		return null
	return selection.selected as Unit


static func unit_for_peer(tree: SceneTree, peer_id: int, alive_only: bool = true) -> Unit:
	if tree == null:
		return null
	for node in tree.get_nodes_in_group("units"):
		if not node is Unit:
			continue
		var unit := node as Unit
		if unit.peer_id != peer_id:
			continue
		if alive_only and not unit.is_alive():
			continue
		return unit
	return null


static func issue_move(tree: SceneTree, world: Vector2) -> void:
	_issue(tree, &"issue_move", world, true)


static func issue_chain_append(tree: SceneTree, world: Vector2) -> void:
	_issue(tree, &"issue_chain_append", world, true)


static func issue_attack_move(tree: SceneTree, world: Vector2) -> void:
	_issue(tree, &"issue_attack_move", world, true)


static func issue_attack_chain_append(tree: SceneTree, world: Vector2) -> void:
	## Keep attack-move armed so more Shift+A clicks can append.
	_issue(tree, &"issue_attack_chain_append", world, false)


static func _issue(tree: SceneTree, method: StringName, world: Vector2, disarm: bool) -> void:
	var selection := manager(tree)
	if disarm and selection != null and selection.attack_move_armed:
		selection.attack_move_armed = false
	var unit := selected_controllable(tree)
	if unit == null:
		return
	if unit.has_method(method):
		unit.call(method, world)
