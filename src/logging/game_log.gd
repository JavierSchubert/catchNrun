class_name GameLog
extends RefCounted
## Tagged console log for networking and match transitions, e.g.
## "[  12.40] [host] [MATCH] phase -> HUNTER_ACTIVE". Keep messages greppable.


static func info(tag: String, message: String) -> void:
	print("[%8.2f] [%s] [%s] %s" % [Time.get_ticks_msec() / 1000.0, _who(), tag, message])


static func _who() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return "?"
	var mp := tree.root.multiplayer
	if mp.multiplayer_peer == null or mp.multiplayer_peer is OfflineMultiplayerPeer:
		return "offline"
	return "host" if mp.is_server() else "peer %d" % mp.get_unique_id()
