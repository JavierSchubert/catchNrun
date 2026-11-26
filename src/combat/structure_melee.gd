class_name StructureMelee
extends RefCounted
## Footprint-aware melee reach and approach against buildings.
## Mirrors RepairSkill.approach_point so Hunter chase does not aim at the solid center.

static func reach(attack_range: float, structure: Building) -> float:
	if structure == null:
		return attack_range
	return attack_range + structure.selection_hit_radius()


static func in_range(from: Vector2, attack_range: float, structure: Building) -> bool:
	if structure == null or not is_instance_valid(structure):
		return false
	return from.distance_to(structure.global_position) <= reach(attack_range, structure)


## Stand just outside the footprint, comfortably inside attack reach.
static func approach_point(from: Vector2, attack_range: float, structure: Building) -> Vector2:
	if structure == null or not is_instance_valid(structure):
		return from
	var away := from - structure.global_position
	if away.is_zero_approx():
		away = Vector2.RIGHT
	var stand_off := structure.selection_hit_radius() + attack_range * 0.5
	return structure.global_position + away.normalized() * stand_off
