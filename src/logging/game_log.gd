class_name GameLog
extends RefCounted
## Tagged console log for networking and match transitions, e.g.
## "[  12.40] [host] [MATCH] phase -> HUNTER_ACTIVE". Keep messages greppable.
## Also keeps a ring buffer for the sandbox status / log panel.

const MAX_HISTORY := 200

static var history: PackedStringArray = PackedStringArray()
static var _listeners: Array[Callable] = []


static func info(tag: String, message: String) -> void:
	var line := "[%8.2f] [%s] [%s] %s" % [Time.get_ticks_msec() / 1000.0, _who(), tag, message]
	print(line)
	history.append(line)
	while history.size() > MAX_HISTORY:
		history.remove_at(0)
	for listener in _listeners:
		if listener.is_valid():
			listener.call(line)


static func clear_history() -> void:
	history.clear()


static func add_listener(callback: Callable) -> void:
	if not _listeners.has(callback):
		_listeners.append(callback)


static func remove_listener(callback: Callable) -> void:
	_listeners.erase(callback)


static func _who() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return "?"
	var mp := tree.root.multiplayer
	if mp.multiplayer_peer == null or mp.multiplayer_peer is OfflineMultiplayerPeer:
		return "offline"
	return "host" if mp.is_server() else "peer %d" % mp.get_unique_id()
