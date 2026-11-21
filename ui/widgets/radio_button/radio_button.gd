extends Control
class_name RadioButton

@onready var button: Button = $VBoxContainer/button


func _ready() -> void:
	button.pressed.connect(_on_pressed)


func _on_pressed() -> void:
	button.release_focus()
