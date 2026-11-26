class_name RepairSkill
extends RefCounted
## Runner `repair`: RMB on an own, finished, damaged structure walks into range and restores
## HP at the def's value_per_second. Unit drives the channel on the host; every rule about
## *whether* a repair is allowed lives here so the click, the RPC, and the tests agree.

const DEF: SkillDef = preload("res://src/skills/defs/repair_def.tres")


## Host validation (also used client-side to decide whether RMB means repair or move):
## Runner role, alive, owns the structure, structure alive + damaged + past its first build.
static func can_repair(caster: Unit, structure: Building) -> bool:
	if caster == null or not is_instance_valid(caster) or not caster.is_alive():
		return false
	if caster.role() != DEF.role:
		return false
	if structure == null or not is_instance_valid(structure) or structure.def == null:
		return false
	if structure.owner_peer_id != caster.peer_id:
		return false
	if structure.state == Building.State.UNDER_CONSTRUCTION:
		return false
	return structure.is_damaged()


static func reach(structure: Building) -> float:
	return structure.selection_hit_radius() + DEF.cast_range


static func in_range(caster: Unit, structure: Building) -> bool:
	return caster.global_position.distance_to(structure.global_position) <= reach(structure)


## Where to walk: the structure's center is inside its own collision box, so aim for a point
## on the caster's side, comfortably inside the repair reach.
static func approach_point(caster: Unit, structure: Building) -> Vector2:
	var away := caster.global_position - structure.global_position
	if away.is_zero_approx():
		away = Vector2.RIGHT
	var stand_off := structure.selection_hit_radius() + DEF.cast_range * 0.5
	return structure.global_position + away.normalized() * stand_off
