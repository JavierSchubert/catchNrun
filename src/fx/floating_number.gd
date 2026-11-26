class_name FloatingNumber
extends Node2D
## Local combat / regen feedback: a rising, fading number near the affected entity.
## Spawn from combat resolve sites only (not bare health_changed). Pattern matches MoveClickMarker.

enum Kind { DAMAGE, CRIT, LIFESTEAL, REGEN }

const COLOR_DAMAGE := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_CRIT := Color(1.0, 0.92, 0.25, 1.0)
const COLOR_HEAL := Color(0.36, 0.92, 0.45, 1.0)

const RISE_PX := 42.0
const OFFSET_RADIUS := 18.0
const POP_DURATION := 0.12
const RISE_DURATION := 0.75
const FADE_DURATION := 0.55
const FADE_DELAY := 0.2


var _label: Label
var _playing := false


func _ready() -> void:
	z_index = 20
	modulate.a = 0.95
	scale = Vector2(0.65, 0.65)
	call_deferred("_play")


func _play() -> void:
	if _playing or not is_inside_tree():
		return
	_playing = true
	var rise_to := position + Vector2(0.0, -RISE_PX)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, POP_DURATION) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", rise_to, RISE_DURATION) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION) \
		.set_delay(FADE_DELAY) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


static func color_for(kind: Kind) -> Color:
	match kind:
		Kind.CRIT:
			return COLOR_CRIT
		Kind.LIFESTEAL, Kind.REGEN:
			return COLOR_HEAL
		_:
			return COLOR_DAMAGE


static func format_value(value: float, kind: Kind) -> String:
	var rounded := value
	var text := str(int(roundf(rounded))) if is_equal_approx(rounded, roundf(rounded)) else "%.1f" % rounded
	match kind:
		Kind.LIFESTEAL, Kind.REGEN:
			return "+%s" % text
		_:
			return text


## World-space spawn with a small random offset around `world_position`.
static func spawn(
	parent: Node,
	world_position: Vector2,
	value: float,
	kind: Kind = Kind.DAMAGE,
) -> FloatingNumber:
	if parent == null or value <= 0.0:
		return null
	var fx := FloatingNumber.new()
	var label := Label.new()
	label.text = format_value(value, kind)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18 if kind != Kind.CRIT else 22)
	label.add_theme_color_override("font_color", color_for(kind))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("outline_size", 4)
	label.position = Vector2(-28, -12)
	label.size = Vector2(56, 24)
	fx._label = label
	fx.add_child(label)
	parent.add_child(fx)
	var offset := Vector2(
		randf_range(-OFFSET_RADIUS, OFFSET_RADIUS),
		randf_range(-OFFSET_RADIUS * 0.5, OFFSET_RADIUS * 0.35),
	)
	fx.global_position = world_position + offset
	return fx


## Convenience: spawn above a Node2D (unit / building).
static func spawn_on(target: Node2D, value: float, kind: Kind = Kind.DAMAGE) -> FloatingNumber:
	if target == null or not is_instance_valid(target):
		return null
	var host := target.get_tree().current_scene if target.get_tree() != null else null
	if host == null:
		host = target.get_parent()
	if host == null:
		return null
	var anchor := target.global_position + Vector2(0.0, -28.0)
	return spawn(host, anchor, value, kind)


## Host combat sites: local spawn, then authority unreliable RPC (no `call_local` — host
## must not double-draw). `authority` must expose `_rpc_floating_number` (Unit / Building).
static func spawn_replicated(authority: Node, target: Node2D, value: float, kind: Kind) -> void:
	if value <= 0.0 or target == null or not is_instance_valid(target):
		return
	if authority == null or not is_instance_valid(authority):
		return
	spawn_on(target, value, kind)
	if not authority.is_inside_tree():
		return
	var mp := authority.multiplayer
	if mp == null or not mp.is_server() or mp.get_peers().is_empty():
		return
	authority.rpc("_rpc_floating_number", target.get_path(), value, int(kind))


## Shared body for Unit/Building `@rpc("authority", "unreliable")` floating-number handlers.
## Skips the host so a mis-delivered local call cannot double-spawn.
static func receive_rpc(from: Node, target_path: NodePath, value: float, kind: int) -> void:
	if from == null or not from.is_inside_tree():
		return
	var mp := from.multiplayer
	if mp != null and mp.is_server():
		return
	var target := from.get_node_or_null(target_path) as Node2D
	if target == null:
		return
	spawn_on(target, value, kind as Kind)
