class_name HealthComponent
extends Node
## Current health for a unit or structure. Max health comes from the Stats system.
## Combat applies damage here. When health reaches zero the owner is defeated.

signal health_changed(current: float, maximum: float)
signal died

var current := 0.0
var _alive := true


func is_alive() -> bool:
	return _alive


func setup(max_health: float) -> void:
	current = maxf(max_health, 0.0)
	_alive = current > 0.0
	health_changed.emit(current, current)


func set_from_sync(value: float, maximum: float) -> void:
	current = clampf(value, 0.0, maxf(maximum, 0.0))
	_alive = current > 0.0
	health_changed.emit(current, maximum)


func heal(amount: float, maximum: float) -> void:
	if not _alive or amount <= 0.0:
		return
	current = minf(current + amount, maximum)
	health_changed.emit(current, maximum)


func take_damage(amount: float, maximum: float) -> float:
	if not _alive or amount <= 0.0:
		return 0.0
	var applied := minf(amount, current)
	current = maxf(current - amount, 0.0)
	health_changed.emit(current, maximum)
	if current <= 0.0:
		_alive = false
		died.emit()
	return applied
