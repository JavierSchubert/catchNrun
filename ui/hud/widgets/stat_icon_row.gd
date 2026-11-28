@tool
class_name StatIconRow
extends HBoxContainer
## Compact icon + value row shared by the selection strip and building manage UI.
## Bind via `bind_stat` (StatSheet) or `bind_text` (manual label for structure HP etc.).

const ICON_PX := 36

@onready var _icon: TextureRect = %Icon
@onready var _value: RichTextLabel = %Value


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _icon != null:
		_icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _value != null:
		_value.bbcode_enabled = true
		_value.fit_content = true
		_value.scroll_active = false
		_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func bind_stat(sheet: StatSheet, stat: StatBlock.Stat) -> void:
	_ensure_nodes()
	_icon.texture = StatIcons.icon(stat)
	_icon.tooltip_text = StatIcons.display_name(stat)
	_value.text = StatIcons.format_value(sheet, stat)


func bind_text(texture: Texture2D, text: String, tooltip := "") -> void:
	_ensure_nodes()
	_icon.texture = texture
	_icon.tooltip_text = tooltip
	_value.text = text


func clear_row() -> void:
	_ensure_nodes()
	_icon.texture = null
	_icon.tooltip_text = ""
	_value.text = ""


func _ensure_nodes() -> void:
	if _icon == null:
		_icon = get_node_or_null("%Icon") as TextureRect
	if _value == null:
		_value = get_node_or_null("%Value") as RichTextLabel
