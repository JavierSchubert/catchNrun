class_name MoveClickMarker
extends Node2D
## Brief local-only ring shown for click commands.
## Blue = move. Red = attack / attack-move.

const RING_RADIUS := 20.0
const RING_WIDTH := 3.0
const DOT_RADIUS := 3.5
const MOVE_COLOR := Color(0.4, 0.78, 1.0, 1.0)
const ATTACK_COLOR := Color(0.95, 0.28, 0.28, 0.95)

@export var pop_duration := 0.16
@export var fade_duration := 0.28
@export var fade_delay := 0.08

var ring_color := MOVE_COLOR
var _playing := false


func _ready() -> void:
	z_index = 5
	scale = Vector2(0.25, 0.25)
	modulate.a = 0.95
	queue_redraw()
	# Spawn sets global_position after add_child; start the tween on the next idle frame.
	call_deferred("_play")


func lifetime_seconds() -> float:
	## Longest parallel track, then the free callback.
	return maxf(pop_duration, fade_delay + fade_duration)


func _play() -> void:
	if _playing or not is_inside_tree():
		return
	_playing = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, pop_duration) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration) \
		.set_delay(fade_delay) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, 48, ring_color, RING_WIDTH, true)
	draw_circle(Vector2.ZERO, DOT_RADIUS, ring_color)


static func spawn(parent: Node, world_position: Vector2, color: Color = MOVE_COLOR) -> MoveClickMarker:
	if parent == null:
		return null
	var marker := MoveClickMarker.new()
	marker.ring_color = color
	parent.add_child(marker)
	marker.global_position = world_position
	return marker


static func spawn_on(target: Node2D, color: Color = ATTACK_COLOR) -> MoveClickMarker:
	if target == null or not is_instance_valid(target):
		return null
	var marker := MoveClickMarker.new()
	marker.ring_color = color
	target.add_child(marker)
	marker.position = Vector2.ZERO
	return marker
