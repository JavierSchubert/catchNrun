class_name StatModifier
extends Resource
## One change to one stat, e.g. "+15% MOVE_SPEED" or "+10 ARMOR".

enum Kind { FLAT, PERCENT }

@export var stat: StatBlock.Stat = StatBlock.Stat.MOVE_SPEED
@export var kind: Kind = Kind.FLAT
@export var value := 0.0 ## FLAT: added to the base value. PERCENT: 0.15 means +15%.
