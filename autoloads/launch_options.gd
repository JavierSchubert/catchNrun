extends Node
## Command-line options, parsed once at startup. Pass them after `--`:
##   godot --path . -- --sandbox
##   godot --headless --path . -- --bot=hunter --bot-name=Hunter
## Without options the game starts normally. Used by the sandbox and the test harness.

var sandbox_enabled := false ## Debug sandbox panel: debug builds or --sandbox. Never headless or bots.
var player_name := "" ## --player-name=NAME. Empty keeps the default name.
var host_on_start := false ## --host: host a local game immediately.
var auto_start_players := 0 ## --auto-start=N: the host starts the match once N players are in the lobby.
var head_start := -1.0 ## --head-start=SECONDS: overrides the Runner preparation time when >= 0.
var host_lifetime := 0.0 ## --host-lifetime=SECONDS: the host quits after this long (0 = never).
var bot_role := "" ## --bot=runner|hunter: run as a bot client. Empty = normal player.
var bot_name := "Bot" ## --bot-name=NAME
var bot_lifetime := 0.0 ## --bot-lifetime=SECONDS: the bot leaves after this long (0 = never).
var report_path := "" ## --report=PATH: write a JSON report of what this process observed.


func _ready() -> void:
	var options := _parse(OS.get_cmdline_user_args())
	player_name = str(options.get("player-name", ""))
	host_on_start = options.has("host")
	auto_start_players = int(options.get("auto-start", 0))
	head_start = float(options.get("head-start", -1.0))
	host_lifetime = float(options.get("host-lifetime", 0.0))
	bot_role = str(options.get("bot", ""))
	bot_name = str(options.get("bot-name", "Bot"))
	bot_lifetime = float(options.get("bot-lifetime", 0.0))
	report_path = str(options.get("report", ""))
	if not bot_role.is_empty() and bot_role not in ["runner", "hunter"]:
		push_error("Unknown --bot role '%s' (use runner or hunter)." % bot_role)
		bot_role = ""
	var headless := DisplayServer.get_name() == "headless"
	sandbox_enabled = (OS.is_debug_build() or options.has("sandbox")) and bot_role.is_empty() and not headless


static func _parse(args: PackedStringArray) -> Dictionary:
	var result := {}
	for arg in args:
		var parts := arg.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else true
	return result
