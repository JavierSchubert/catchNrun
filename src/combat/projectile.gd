class_name Projectile
extends Node2D
## Short-lived homing shot fired by a Tower (docs/construction.README.md §5).
##
## The projectile owns travel and presentation only; it never computes damage. The host
## resolves the hit once with CombatDamage and hands the result over as `on_hit`, which the
## projectile invokes on impact so the HP drop happens when the sprite actually arrives.
## Clients spawn the very same scene with an empty callback (cosmetic only).
##
## Deliberately not replicated by a MultiplayerSpawner: shots are frequent, tiny and lossy
## by design, so the host broadcasts one unreliable RPC per shot instead (building.gd).

## Hard ceiling so a projectile can never leak if its target teleports or stalls.
const MAX_LIFETIME := 6.0
## Travel is resolved per frame, so a step shorter than this still counts as an arrival.
const HIT_RADIUS := 8.0

var speed := 650.0
var target: Node2D = null
var max_lifetime := MAX_LIFETIME

var _on_hit := Callable()
var _elapsed := 0.0
var _consumed := false

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	## Above the map and the units (Unit uses z_index 1).
	z_index = 6


## Call after add_child(): global_position needs the node to be inside the tree.
## `on_hit` is optional — leave it empty for the cosmetic client-side copy.
func setup(start: Vector2, p_target: Node2D, p_speed: float, on_hit := Callable()) -> void:
	target = p_target
	speed = maxf(p_speed, 1.0)
	_on_hit = on_hit
	global_position = start
	if _target_alive():
		rotation = (p_target.global_position - start).angle()


## One travel step. `_physics_process` forwards to it; headless tests drive it directly.
func advance(delta: float) -> void:
	if _consumed:
		return
	_elapsed += delta
	if _elapsed >= max_lifetime:
		_expire()
		return
	if not _target_alive():
		## Target died or was freed mid-flight: no damage, no leak.
		_expire()
		return
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	var step := speed * delta
	if distance <= maxf(step, HIT_RADIUS):
		global_position = target.global_position
		_impact()
		return
	var direction := to_target / distance
	global_position += direction * step
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	advance(delta)


func _target_alive() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.has_method("is_attackable"):
		return bool(target.call("is_attackable"))
	return true


func _impact() -> void:
	if _consumed:
		return
	_consumed = true
	set_physics_process(false)
	## is_valid() is false once the firing Tower has been freed, so a dead tower's shot
	## still disappears instead of calling into a freed object.
	if _on_hit.is_valid():
		_on_hit.call(target)
	queue_free()


func _expire() -> void:
	if _consumed:
		return
	_consumed = true
	set_physics_process(false)
	queue_free()
