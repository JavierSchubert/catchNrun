extends Node
## Looks up every ItemData in ITEM_DIR by id. RPCs send item ids (strings), never
## Resources, and each peer gets the matching ItemData from here.
##
## To add an item: create a new ItemData resource (.tres) in data/items/defs/. No code needed.

const ITEM_DIR := "res://data/items/defs/"

var _items: Dictionary = {} # String id -> ItemData


func _ready() -> void:
	if not DirAccess.dir_exists_absolute(ITEM_DIR):
		return
	for file in ResourceLoader.list_directory(ITEM_DIR):
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var item := load(ITEM_DIR + file) as ItemData
		if item == null or item.id.is_empty():
			push_warning("ItemDatabase: skipping invalid item %s" % file)
			continue
		_items[item.id] = item


func get_item(id: String) -> ItemData:
	return _items.get(id)


func all_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	result.assign(_items.values())
	result.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.price < b.price)
	return result
