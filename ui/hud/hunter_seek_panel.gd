class_name HunterSeekPanel
extends Control
## Hunter Seek skill button nested in SelectionPanel SkillSlot (LoL-style).
## Visible only while the local controllable Hunter is selected.

@onready var _button: Button = %SeekButton

var _display_signature := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.pressed.connect(_on_seek_pressed)
	_button.icon = SkillIcons.icon_for(SeekSkill.DEF.id)
	visible = false
	set_process(true)


func _process(_delta: float) -> void:
	if not _local_is_hunter():
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_display_signature = ""
		return
	var hunter := _local_hunter_if_selected()
	visible = hunter != null
	if hunter == null:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_display_signature = ""
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ready := hunter.seek_is_ready()
	var active_left := hunter.seek_active_left()
	var cd := hunter.seek_cooldown_left()
	var signature := "%s:%.0f:%.0f" % [str(ready), ceilf(active_left), ceilf(cd)]
	if signature == _display_signature:
		return
	_display_signature = signature
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


func _local_is_hunter() -> bool:
	var local_id := GameManager.local_peer_id()
	return int(GameManager.players.get(local_id, {}).get("role", GameManager.ANY_ROLE)) \
			== RoleConfig.Role.HUNTER


func _local_hunter_if_selected() -> Unit:
	var unit := SelectionQueries.selected_controllable(get_tree())
	if unit == null or unit.role() != RoleConfig.Role.HUNTER:
		return null
	return unit
