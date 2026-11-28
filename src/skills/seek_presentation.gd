class_name SeekPresentation
extends RefCounted
## Local-only Seek FX state for the casting Hunter. Host/client Unit RPCs write here;
## minimap_dots reads it each frame. No replication and no fog side effects.

static var active := false
static var origin := Vector2.ZERO
static var targets: Array[Vector2] = []
## Client-side timers so the skill button can show CD / active without waiting on sync.
static var cooldown_left := 0.0
static var active_left := 0.0


static func begin(duration: float, cooldown: float) -> void:
	active = true
	active_left = maxf(duration, 0.0)
	cooldown_left = maxf(cooldown, 0.0)
	targets.clear()


static func update_targets(from: Vector2, positions: Array) -> void:
	origin = from
	targets.clear()
	for entry in positions:
		targets.append(entry as Vector2)


static func end_active() -> void:
	active = false
	active_left = 0.0
	targets.clear()


static func tick(delta: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = maxf(cooldown_left - delta, 0.0)
	if active_left > 0.0:
		active_left = maxf(active_left - delta, 0.0)
		if active_left <= 0.0:
			end_active()


static func is_ready() -> bool:
	return cooldown_left <= 0.0
