extends Control
class_name SettingsMenu


#signal button_pressed(button_name: String, pressed: bool)


# --- Buttons ---
@onready var home: AnimatedButton = %home
@onready var pause: AnimatedButton = %pause
@onready var stats: AnimatedButton = %stats
@onready var settings: AnimatedButton = %settings


# --- Overlays ---
@onready var stats_overlay: StatsContainer = %stats_overlay
@onready var dynamic_stats_overlay: DynamicStatsContainer = %dynamic_stats_overlay
@onready var audio_overlay: Control = %audio_overlay
@onready var game_paused_overlay: Label = %game_paused_overlay


# --- Pause icons ---
const ICON_START = preload("res://assets/sprites/icons/icon_start.tres")
const ICON_PAUSE = preload("res://assets/sprites/icons/icon_pause.tres")


# --- Button configuration dictionary ---
@export var dynamic_overlay: bool = false
var buttons_config := {}
var button_callbacks: Dictionary = {}

# --- State capture ---
var overlay_active_cfg := {}  # empty dictionary initially


func _ready() -> void:
	# Configure buttons
	buttons_config = {
		"home": {
			"node": home,
			"pressed": false,
		},
		"settings": {
			"node": settings,
			"pressed": false,
			"overlay_static": audio_overlay,
			"overlay_offset_x": -250  # Audio overlay offset
		},
		"stats": {
			"node": stats,
			"pressed": false,
			"overlay_static": stats_overlay,
			"overlay_dynamic": dynamic_stats_overlay,
			"overlay_offset_x": -230  # Stats overlay offset
		},
		"pause": {
			"node": pause,
			"pressed": false,
			"icons": {"on": ICON_START, "off": ICON_PAUSE},
			"overlay_static": game_paused_overlay,
			"overlay_offset_x": -850
		}
	}

	# Connect signals and initialize
	for btn_name in buttons_config.keys():
		var cfg = buttons_config[btn_name]
		var btn_node: AnimatedButton = cfg["node"]

		# Connect the activated signal
		btn_node.activated.connect(
			# Alt 1: Use lamda function
			#func(_sender, button_name_local=btn_name):
				#_on_button_activated(button_name_local)
			
			# Alt 2: Bind the btn_name since the activated functions only emits 
			# the MenuIcon instance which is not aware of the btn_name
			_on_button_activated.bind(btn_name)
		)

		# Apply initial state
		_set_overlay_visibility(cfg)
		_set_button_icon(cfg)


# -----------------------------
# Generic button pressed handler
# -----------------------------
func _on_button_activated(_sender: AnimatedButton, btn_name: String) -> void:
	var cfg = buttons_config[btn_name]

	# Toggle pressed state for all buttons
	cfg["pressed"] = !cfg["pressed"]

	# Update overlay visibility only if overlay exists
	_set_overlay_visibility(cfg)

	# Update the button icon after toggling the pressed state
	_set_button_icon(cfg)
	#button_pressed.emit(btn_name, cfg["pressed"]) => Update: using callback below now
	
	# Call scene-specific callback
	if btn_name in button_callbacks:
		var cb: Callable = button_callbacks[btn_name]
		cb.call(cfg["pressed"])  # always pass pressed


# -----------------------------
# Helpers
# -----------------------------
func _set_overlay_visibility(cfg: Dictionary) -> void:
	""" Toggle overlay visibility """
	# Hide the previously active overlay if it's not the current one
	if overlay_active_cfg != cfg and overlay_active_cfg != {}:
		if "overlay_static" in overlay_active_cfg:
			overlay_active_cfg["overlay_static"].visible = false
		if "overlay_dynamic" in overlay_active_cfg:
			overlay_active_cfg["overlay_dynamic"].visible = false
		# Reset its pressed state so it can toggle properly next time
		overlay_active_cfg["pressed"] = false
	# Show current overlay if the button is pressed
	if "overlay_static" in cfg:
		cfg["overlay_static"].visible = cfg["pressed"] and not dynamic_overlay
	if "overlay_dynamic" in cfg:
		cfg["overlay_dynamic"].visible = cfg["pressed"] and dynamic_overlay
	# Update which overlay is currently active
	overlay_active_cfg = cfg if cfg["pressed"] else {}
	# Update overlay position if needed
	if cfg["pressed"]:
		call_deferred("_update_overlay_position", cfg)


func _set_button_icon(cfg: Dictionary) -> void:
	""" Toggle icon on button press """
	if "icons" in cfg:
		# Switch between "on" and "off" icons based on the pressed state
		var icon = cfg["icons"]["on"] if cfg["pressed"] else cfg["icons"]["off"]
		var btn_node: AnimatedButton = cfg["node"]
		for prop in ["texture_normal", "texture_hover", "texture_pressed", "texture_disabled"]:
			btn_node.btn.set(prop, icon)


func _update_overlay_position(cfg: Dictionary) -> void:
	var settings_menu: AnimatedButton = cfg["node"]
	var overlay: Control = _get_overlay(cfg)
	if settings_menu == null or overlay == null:
		return

	var animated_btn: AnimatedButton = cfg["node"]
	var btn_node: TextureButton = animated_btn.btn

	# Wait if button or overlay sizes are not ready yet
	var btn_rect = btn_node.get_global_rect()
	var overlay_size = overlay.get_combined_minimum_size()
	# Defer if sizes not ready
	if btn_rect.size == Vector2.ZERO or overlay_size == Vector2.ZERO:
		call_deferred("_update_overlay_position", cfg)
		return

	# --- Horizontal positioning: fixed distance from the right screen edge ---
	var screen_width = get_viewport_rect().size.x
	var right_margin = abs(cfg.get("overlay_offset_x", -250)) # treat offset as margin
	var overlay_x = screen_width - right_margin - overlay_size.x

	# --- Vertical positioning: center relative to button ---
	var overlay_y = btn_rect.position.y + btn_rect.size.y / 2 - overlay_size.y / 2

	overlay.global_position = Vector2(overlay_x, overlay_y)


func _get_overlay(cfg: Dictionary) -> Control:
	if dynamic_overlay and "overlay_dynamic" in cfg:
		return cfg["overlay_dynamic"]
	return cfg.get("overlay_static")
