class_name HunterSeekPanel
extends Control
## Bottom-right skill slot for the local Hunter's Seek ability (Q / click).
## Visible only while the local controllable Hunter is selected.

@onready var _button: Button = %SeekButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.pressed.connect(_on_seek_pressed)
	_button.icon = SkillIcons.icon_for(SeekSkill.DEF.id)
	visible = false
	set_process(true)


func _process(_delta: float) -> void:
	var hunter := _local_hunter_if_selected()
	visible = hunter != null
	if hunter == null:
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ready := hunter.seek_is_ready()
	var active_left := hunter.seek_active_left()
	var cd := hunter.seek_cooldown_left()
	_button.disabled = not ready
	_button.icon = SkillIcons.icon_for(SeekSkill.DEF.id)
	if active_left > 0.0:
		_button.text = "Seek\n%.0fs" % ceilf(active_left)
		_button.tooltip_text = "Seek active — directions on minimap (%.0fs left)" % active_left
	elif cd > 0.0:
		_button.text = "Seek [Q]\n%.0fs" % ceilf(cd)
		_button.tooltip_text = "Seek cooling down — %.0fs remaining" % cd
	else:
		_button.text = "Seek [Q]\nReady"
		_button.tooltip_text = "Reveal other players' directions on the minimap for 10s (30s cooldown)"


func _on_seek_pressed() -> void:
	var hunter := _local_hunter_if_selected()
	if hunter == null or not hunter.seek_is_ready():
		return
	hunter.request_seek()


func _local_hunter_if_selected() -> Unit:
	var tree := get_tree()
	if tree == null:
		return null
	var manager := tree.get_first_node_in_group("selection_manager") as SelectionManager
	if manager == null or not manager.is_controllable_selected():
		return null
	var unit := manager.selected as Unit
	if unit == null or unit.role() != RoleConfig.Role.HUNTER:
		return null
	return unit
