extends Control
class_name ButtonUpDown

@onready var button_up: TextureButton = $VBoxContainer/button_up
@onready var button_down: TextureButton = $VBoxContainer/button_down


signal button_up_pressed
signal button_down_pressed


func _ready() -> void:
	button_up.pressed.connect(_on_button_up_pressed)
	button_down.pressed.connect(_on_button_down_pressed)


func _on_button_up_pressed() -> void:
	button_up_pressed.emit()
	button_up.release_focus()


func _on_button_down_pressed() -> void:
	button_down_pressed.emit()
	button_down.release_focus()
