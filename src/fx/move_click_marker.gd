class_name MoveClickMarker
extends Node2D
## Brief local-only ring shown where the player right-clicked to move.
## Pops in with a short tween, then fades out and frees itself.

const RING_RADIUS := 20.0
const RING_WIDTH := 3.0
const DOT_RADIUS := 3.5
const RING_COLOR := Color(0.4, 0.78, 1.0, 1.0)

@export var pop_duration := 0.16
@export var fade_duration := 0.28
@export var fade_delay := 0.08

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
	draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, 48, RING_COLOR, RING_WIDTH, true)
	draw_circle(Vector2.ZERO, DOT_RADIUS, RING_COLOR)


static func spawn(parent: Node, world_position: Vector2) -> MoveClickMarker:
	if parent == null:
		return null
	var marker := MoveClickMarker.new()
	parent.add_child(marker)
	marker.global_position = world_position
	return marker
