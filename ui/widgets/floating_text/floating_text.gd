extends Node2D
class_name FloatingText


@onready var value_label: Label = $value_label

# --- Configurable parameters ---
var dy: float = 15.0
var animation_duration: float = 0.4
var spawn_offset_radius: float = 35.0
var rotation_range: float = 10.0
var scale_range := Vector2(0.8, 1.6)


func setup_for_unit(unit: Node2D, value: String, color: Color) -> void:
	"""
	Spawns the floating text around the unit, sets value/color, and animates it.
	"""
	_spawn_at_unit(unit)
	setup(value, color)


func setup(value: String, color: Color) -> void:
	value_label.text = value
	modulate = color
	# on instanciation put scale to 0, so that floating text is not visible
	scale = Vector2.ZERO

	# Random rotation
	rotation = deg_to_rad(randf_range(-rotation_range, rotation_range))
	# Random scale
	var random_scale := randf_range(scale_range.x, scale_range.y)
	
	# animate properties (change properties over time)
	# different scale of floating text and move up
	var tween := create_tween()
	tween.parallel().tween_property(self, "scale", random_scale * Vector2.ONE, animation_duration)
	tween.parallel().tween_property(self, "global_position", global_position + Vector2.UP * dy, animation_duration)
	
	# wait 0.5 seconds before next animation
	tween.tween_interval(0.5)
	
	# fade out
	tween.parallel().tween_property(self, "scale", Vector2.ZERO, animation_duration)
	tween.parallel().tween_property(self, "modulate:a", 0.0, animation_duration)
	
	await tween.finished
	queue_free()


func _spawn_at_unit(unit: Node2D) -> void:
	var random_angle := randf_range(0, TAU)
	global_position = unit.global_position + Vector2.RIGHT.rotated(random_angle) * spawn_offset_radius
