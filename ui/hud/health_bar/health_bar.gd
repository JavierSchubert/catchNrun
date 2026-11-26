extends Control
class_name HealthBar
## World-space HP strip. Players keep the bar always on; structures hide it at full HP.

const FULL_EPSILON := 0.01

## When true the bar stays visible at full health (player units). Buildings leave this false.
@export var show_when_full := false

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var health_label: Label = $health_amount


func update_for_health(current: float, maximum: float) -> void:
	progress_bar.value = current / maximum if maximum > 0.0 else 0.0
	health_label.text = str(roundi(current))
	_refresh_visibility(current, maximum)


func _refresh_visibility(current: float, maximum: float) -> void:
	if show_when_full:
		visible = true
		return
	if maximum <= 0.0:
		visible = false
		return
	visible = current < maximum - FULL_EPSILON
