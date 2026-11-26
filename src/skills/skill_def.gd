class_name SkillDef
extends Resource
## Data for one role skill. Balance lives in the matching defs/*.tres; the behavior that
## reads it lives next to the skill (RepairSkill for `repair`).

enum Target { OWN_STRUCTURE }

@export var id := ""
@export var display_name := ""
@export var role: RoleConfig.Role = RoleConfig.Role.RUNNER
@export var target: Target = Target.OWN_STRUCTURE
## Gap in pixels between the caster's position and the edge of the target structure
## (its selection_hit_radius) at which the skill takes effect.
@export var cast_range := 48.0
## Effect applied per second while channelling (repair: HP restored per second).
@export var value_per_second := 20.0
