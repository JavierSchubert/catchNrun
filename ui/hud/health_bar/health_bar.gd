extends Control
class_name HealthBar


@onready var progress_bar: ProgressBar = $ProgressBar
@onready var health_label: Label = $health_amount


func update_for_health(current: float, maximum: float) -> void:
	progress_bar.value = current / maximum if maximum > 0.0 else 0.0
	health_label.text = str(roundi(current))
