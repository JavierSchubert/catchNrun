class_name SkillDef
extends Resource
## Data for one role skill. Balance lives in the matching defs/*.tres; the behavior that
## reads it lives next to the skill (RepairSkill for `repair`, SeekSkill for `seek`).

enum Target {
	OWN_STRUCTURE,
	SELF,
}

@export var id := ""
@export var display_name := ""
@export var role: RoleConfig.Role = RoleConfig.Role.RUNNER
@export var target: Target = Target.OWN_STRUCTURE
## Gap in pixels between the caster's position and the edge of the target structure
## (its selection_hit_radius) at which the skill takes effect. Unused for SELF skills.
@export var cast_range := 48.0
## Effect applied per second while channelling (repair: HP restored per second).
@export var value_per_second := 20.0
## Seconds before the skill can be cast again after a successful cast. 0 = no cooldown.
@export var cooldown := 0.0
## Seconds the skill effect stays active after cast (seek: minimap arrows). 0 = instant.
@export var duration := 0.0
