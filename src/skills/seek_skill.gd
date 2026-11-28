class_name SeekSkill
extends RefCounted
## Hunter `seek`: self-cast ability that reveals the direction of other living player units
## on the minimap for `duration` seconds, then sits on `cooldown`. Cast validation lives
## here so the UI button, the Q hotkey, the RPC, and tests agree.

const DEF: SkillDef = preload("res://src/skills/defs/seek_def.tres")


static func can_cast(caster: Unit) -> bool:
	if caster == null or not is_instance_valid(caster) or not caster.is_alive():
		return false
	if caster.role() != DEF.role:
		return false
	return GameManager.phase == GameManager.Phase.HUNTER_ACTIVE


## World positions of every other living player unit. Fog is intentionally bypassed —
## Seek is the Hunter's short window of directional knowledge.
static func gather_target_positions(caster: Unit) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if caster == null or not is_instance_valid(caster):
		return positions
	var tree := caster.get_tree()
	if tree == null:
		return positions
	for node in tree.get_nodes_in_group("units"):
		if not node is Unit:
			continue
		var unit := node as Unit
		if unit == caster or not unit.is_alive():
			continue
		if unit.peer_id == caster.peer_id:
			continue
		positions.append(unit.global_position)
	return positions
