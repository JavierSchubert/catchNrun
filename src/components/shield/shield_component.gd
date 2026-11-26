class_name ShieldComponent
extends Node
## Recharging damage buffer in front of a HealthComponent (Wall from shield_unlock_level).
## Same shape as HealthComponent, but a shield never "dies": a maximum of 0.0 is the normal
## "no shield" state, so unlike HealthComponent.setup(0.0) it is always safe to set.
## Recharge waits `recharge_delay` seconds after the last hit, then restores
## `recharge_per_second` (a fraction of the maximum) every second.

signal shield_changed(current: float, maximum: float)

var current := 0.0
var maximum := 0.0
var recharge_delay := 6.0
var recharge_per_second := 0.05

var _since_damage := 0.0


func has_shield() -> bool:
	return maximum > 0.0


func setup(p_maximum: float, p_recharge_delay: float, p_recharge_per_second: float) -> void:
	maximum = maxf(p_maximum, 0.0)
	current = maximum
	recharge_delay = maxf(p_recharge_delay, 0.0)
	recharge_per_second = maxf(p_recharge_per_second, 0.0)
	_since_damage = recharge_delay
	shield_changed.emit(current, maximum)


## A larger maximum (level-up) grants the difference immediately, mirroring how
## Building._complete_construction() heals the HP delta. A smaller one clamps.
func set_maximum(new_maximum: float) -> void:
	var clamped := maxf(new_maximum, 0.0)
	var delta := clamped - maximum
	maximum = clamped
	current = clampf(current + maxf(delta, 0.0), 0.0, maximum)
	shield_changed.emit(current, maximum)


func set_from_sync(value: float, p_maximum: float) -> void:
	maximum = maxf(p_maximum, 0.0)
	current = clampf(value, 0.0, maximum)
	shield_changed.emit(current, maximum)


## Soaks up to `amount` and returns what it absorbed; the caller passes the rest on to
## health. Every hit restarts the recharge delay, even one that finds the shield empty.
func absorb(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	_since_damage = 0.0
	if current <= 0.0:
		return 0.0
	var absorbed := minf(amount, current)
	current -= absorbed
	shield_changed.emit(current, maximum)
	return absorbed


func tick(delta: float) -> void:
	if maximum <= 0.0 or delta <= 0.0:
		return
	if _since_damage < recharge_delay:
		_since_damage += delta
		return
	if current >= maximum:
		return
	current = minf(current + maximum * recharge_per_second * delta, maximum)
	shield_changed.emit(current, maximum)
