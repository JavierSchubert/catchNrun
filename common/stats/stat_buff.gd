extends Resource
class_name StatBuff


enum Modifier {
	MULTIPLY,
	ADD,
}


@export var stat: Stats.BuffableStats
@export var amount: float
@export var modifier: Modifier


func _init(_stat: Stats.BuffableStats = Stats.BuffableStats.MAX_HEALTH, 
			_amount: float = 1.0,
			_modifier: StatBuff.Modifier = Modifier.MULTIPLY) -> void:
	stat = _stat
	amount = _amount
	modifier = _modifier
