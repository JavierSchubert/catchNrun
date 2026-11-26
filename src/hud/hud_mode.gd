class_name HudMode
extends RefCounted
## Pure selection→HUD mode rules. BuildingPanel / SelectionPanel / tests share this so
## build vs manage never drifts between UI sites (WP-17).

enum Mode {
	NONE,
	## Local controllable unit selected: Runner may arm placement.
	UNIT_BUILD,
	## Owned structure selected: Upgrade / Destroy / tower picks only.
	BUILDING_MANAGE,
}


## Active Runner in prep or hunter-active who is not eliminated.
static func is_active_runner(peer_id: int) -> bool:
	if not GameManager.players.has(peer_id):
		return false
	if GameManager.phase != GameManager.Phase.RUNNER_PREPARATION \
			and GameManager.phase != GameManager.Phase.HUNTER_ACTIVE:
		return false
	if GameManager.is_eliminated(peer_id):
		return false
	var entry: Dictionary = GameManager.players[peer_id]
	return int(entry.get("role", RoleConfig.Role.RUNNER)) == RoleConfig.Role.RUNNER


static func resolve(selected: Node, local_peer_id: int, is_active_runner: bool) -> Mode:
	if not is_active_runner:
		return Mode.NONE
	if selected == null or not is_instance_valid(selected):
		return Mode.NONE
	if selected is Building:
		var building := selected as Building
		if building.def != null and building.owner_peer_id == local_peer_id:
			return Mode.BUILDING_MANAGE
		return Mode.NONE
	if selected.has_method("is_local_controllable") \
			and bool(selected.call("is_local_controllable", local_peer_id)):
		return Mode.UNIT_BUILD
	return Mode.NONE


static func can_build(mode: Mode) -> bool:
	return mode == Mode.UNIT_BUILD


static func can_manage_building(mode: Mode) -> bool:
	return mode == Mode.BUILDING_MANAGE


## Runner A-click destroy: own finished structure under the cursor (not combat).
static func can_runner_a_destroy(
	selected: Node,
	target: Node,
	local_peer_id: int,
	is_active_runner: bool,
) -> bool:
	if not is_active_runner:
		return false
	if selected == null or not is_instance_valid(selected):
		return false
	if not selected.has_method("is_local_controllable"):
		return false
	if not bool(selected.call("is_local_controllable", local_peer_id)):
		return false
	if selected.has_method("can_attack") and bool(selected.call("can_attack")):
		## Hunters use combat A-move; never the voluntary destroy path.
		return false
	if target == null or not is_instance_valid(target):
		return false
	if not target is Building:
		return false
	var building := target as Building
	return building.def != null and building.owner_peer_id == local_peer_id
