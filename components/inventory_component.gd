class_name InventoryComponent
extends Node
## Gold and owned items. This is also where shop purchases happen.
##
## The client only *asks* to buy (buy() sends an RPC to the host). The host checks the
## price, the role restriction and the stack limit, then updates gold/item_ids. The new
## values reach every peer through the player's ServerSync.

signal changed

@export var stats: StatsComponent

var gold := 0:
	set(value):
		gold = value
		changed.emit()

var item_ids := PackedStringArray():
	set(value):
		item_ids = value
		refresh()


func refresh() -> void:
	var items: Array[ItemData] = []
	for id in item_ids:
		var item := ItemDatabase.get_item(id)
		if item:
			items.append(item)
	if stats:
		stats.recalculate(items)
	changed.emit()


func count(item_id: String) -> int:
	return item_ids.count(item_id)


func can_buy(item: ItemData) -> bool:
	var player := get_parent() as Player
	return item.usable_by_role(player.role) and gold >= item.price and count(item.id) < item.max_stack


## Called by the UI on the owning client.
func buy(item_id: String) -> void:
	_request_purchase.rpc_id(1, item_id)


@rpc("any_peer", "call_local", "reliable")
func _request_purchase(item_id: String) -> void:
	if not multiplayer.is_server():
		return
	var player := get_parent() as Player
	if GameManager.sender_id(multiplayer) != player.peer_id:
		return # Only the owner of this inventory can buy for it.
	var item := ItemDatabase.get_item(item_id)
	if item == null or player.health.is_dead or not can_buy(item):
		return
	gold -= item.price
	var new_ids := item_ids.duplicate()
	new_ids.append(item_id)
	item_ids = new_ids # Assign a new array so the setter runs and the synchronizer sees the change.
