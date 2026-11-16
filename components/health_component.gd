class_name HealthComponent
extends Node
## Health for any role, Hunter included. Only the host changes it; the player's ServerSync
## (a MultiplayerSynchronizer owned by the host) sends `current` and `is_dead` to all peers.

signal health_changed(current: float, maximum: float)
signal died

@export var stats: StatsComponent

var current := 0.0:
	set(value):
		current = value
		health_changed.emit(current, get_max())

var is_dead := false:
	set(value):
		var just_died := value and not is_dead
		is_dead = value
		if just_died:
			died.emit()

var _last_max := 0.0


func _ready() -> void:
	if stats:
		stats.stats_changed.connect(_on_stats_changed)


func get_max() -> float:
	return stats.get_stat(StatBlock.Stat.MAX_HEALTH) if stats else 0.0


## Host only.
func reset() -> void:
	current = get_max()
	is_dead = false


## Host only. Armor reduces damage: 100 armor = half damage.
func apply_damage(amount: float) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	var armor := stats.get_stat(StatBlock.Stat.ARMOR)
	current = maxf(current - amount * 100.0 / (100.0 + armor), 0.0)
	if current <= 0.0:
		is_dead = true


## When max HP goes up (e.g. Armor Vest), current HP goes up by the same amount.
## When it goes down, current HP is clamped.
func _on_stats_changed() -> void:
	var new_max := get_max()
	if multiplayer.is_server() and not is_dead and _last_max > 0.0:
		current = minf(current + maxf(new_max - _last_max, 0.0), new_max)
	else:
		health_changed.emit(current, new_max) # Clients: refresh UI with the new max.
	_last_max = new_max


## Host only.
func heal(amount: float) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	current = minf(current + amount, get_max())
