extends Node
class_name TooltipController


const TOOLTIP_DELAY := 0.3


@onready var popup_panel: Panel = %popup_panel
@onready var popup_timer: Timer = %popup_timer

@onready var label: Label = %Label
@onready var value_label_text: Label = %value_label_text
@onready var value_label_value: Label = %value_label_value
@onready var description: RichTextLabel = %RichTextLabel

var hovered_item: ItemBase = null


func _ready() -> void:
	popup_panel.hide()
	popup_timer.wait_time = TOOLTIP_DELAY
	popup_timer.timeout.connect(_on_tooltip_timer_timeout)


func show_tooltip_for(item: ItemBase) -> void:
	hovered_item = item
	popup_timer.start()


func hide_tooltip() -> void:
	""" Hide popup when cursor leaves and reset timer. """
	hovered_item = null
	popup_timer.stop()
	popup_panel.hide()


func _on_tooltip_timer_timeout() -> void:
	if hovered_item:
		_show_popup(hovered_item)


func _show_popup(item: ItemBase) -> void:
	update_with_item(item)
	popup_panel.show()

	var mouse_pos = get_viewport().get_mouse_position()
	var offset = Vector2(16, 8)
	var tooltip_pos = mouse_pos + offset

	var screen_size = get_viewport().get_visible_rect().size
	var tooltip_size = popup_panel.size
	tooltip_pos.x = clamp(tooltip_pos.x, 0, screen_size.x - tooltip_size.x)
	tooltip_pos.y = clamp(tooltip_pos.y, 0, screen_size.y - tooltip_size.y)

	popup_panel.position = tooltip_pos


func update_with_item(item: ItemBase) -> void:
	label.text = item.name
	value_label_text.text = "Value: "
	value_label_value.text = str(int(item.item_cost * 0.75))
	description.text = item.get_description()
