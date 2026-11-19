extends Control
class_name HealthBar


@export var back_color: Color
@export var fill_color: Color

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var health_label: Label = $health_amount


func _ready() -> void:
	# duplicate and save style
	var back_style := progress_bar.get_theme_stylebox("background").duplicate()
	back_style.bg_color = back_color
	
	var fill_style := progress_bar.get_theme_stylebox("fill").duplicate()
	fill_style.bg_color = fill_color
	
	# apply to progress_bar
	progress_bar.add_theme_stylebox_override("background", back_style)
	progress_bar.add_theme_stylebox_override("fill", fill_style)


func _on_health_component_on_health_changed(current_value: float, max_value: float) -> void:
	var value := current_value / max_value
	update_bar(value, current_value)


func update_bar(value: float, health: float) -> void:
	# change progress bar
	progress_bar.value = value
	# change label
	health_label.text = str(health)
