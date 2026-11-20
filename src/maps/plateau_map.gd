class_name PlateauMap
extends Node2D
## Builds a StarCraft-style two-height arena from modular plateau tiles.
## Four elevated corner bases open toward the center via ramps; low ground fills the middle.

const TILE := 128.0
const COLS := 30
const ROWS := 20

const TEX_FLOOR_LOW := preload("res://assets/sprites/maps/tiles/plateau/floor_low.png")
const TEX_FLOOR_HIGH := preload("res://assets/sprites/maps/tiles/plateau/floor_high.png")
const TEX_VOID := preload("res://assets/sprites/maps/tiles/plateau/void_lava.png")
const TEX_CLIFF := {
	"n": preload("res://assets/sprites/maps/tiles/plateau/cliff_n.png"),
	"s": preload("res://assets/sprites/maps/tiles/plateau/cliff_s.png"),
	"e": preload("res://assets/sprites/maps/tiles/plateau/cliff_e.png"),
	"w": preload("res://assets/sprites/maps/tiles/plateau/cliff_w.png"),
}
const TEX_OUTER := {
	"ne": preload("res://assets/sprites/maps/tiles/plateau/cliff_outer_ne.png"),
	"nw": preload("res://assets/sprites/maps/tiles/plateau/cliff_outer_nw.png"),
	"se": preload("res://assets/sprites/maps/tiles/plateau/cliff_outer_se.png"),
	"sw": preload("res://assets/sprites/maps/tiles/plateau/cliff_outer_sw.png"),
}
const TEX_RAMP := {
	"n": preload("res://assets/sprites/maps/tiles/plateau/ramp_n.png"),
	"s": preload("res://assets/sprites/maps/tiles/plateau/ramp_s.png"),
	"e": preload("res://assets/sprites/maps/tiles/plateau/ramp_e.png"),
	"w": preload("res://assets/sprites/maps/tiles/plateau/ramp_w.png"),
}
const TEX_RAMP_WIDE_S := {
	"left": preload("res://assets/sprites/maps/tiles/plateau/ramp_s_left.png"),
	"mid": preload("res://assets/sprites/maps/tiles/plateau/ramp_s_mid.png"),
	"right": preload("res://assets/sprites/maps/tiles/plateau/ramp_s_right.png"),
}
const TEX_RAMP_WIDE_N := {
	"left": preload("res://assets/sprites/maps/tiles/plateau/ramp_n_left.png"),
	"mid": preload("res://assets/sprites/maps/tiles/plateau/ramp_n_mid.png"),
	"right": preload("res://assets/sprites/maps/tiles/plateau/ramp_n_right.png"),
}

enum Cell { VOID, LOW, HIGH }

## World rect covering every tile. Kept in sync with Unit.MAP_BOUNDS via world_bounds().
static func world_bounds() -> Rect2:
	var size := Vector2(COLS, ROWS) * TILE
	return Rect2(-size * 0.5, size)


static func cell_to_world(cell: Vector2i) -> Vector2:
	return world_bounds().position + (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


## Runner spawn centers on the four elevated bases (NW, NE, SW, SE).
static func runner_spawn_positions() -> Array[Vector2]:
	return [
		cell_to_world(Vector2i(4, 4)),
		cell_to_world(Vector2i(24, 4)),
		cell_to_world(Vector2i(4, 15)),
		cell_to_world(Vector2i(24, 15)),
	]


static func hunter_spawn_position() -> Vector2:
	return Vector2.ZERO


## Center of a cell in world space.
func cell_center(cell: Vector2i) -> Vector2:
	return cell_to_world(cell)


func _ready() -> void:
	_build()


func _build() -> void:
	var grid: Array = []
	grid.resize(ROWS)
	for y in ROWS:
		var row: Array = []
		row.resize(COLS)
		row.fill(Cell.VOID)
		grid[y] = row

	_fill_low(grid, Rect2i(1, 1, COLS - 2, ROWS - 2))

	# Four elevated spawn bases (high) with ramps facing the center.
	var bases: Array[Dictionary] = [
		{"rect": Rect2i(2, 2, 6, 5), "ramp_dir": "s", "ramp_cols": [3, 4, 5]},
		{"rect": Rect2i(22, 2, 6, 5), "ramp_dir": "s", "ramp_cols": [24, 25, 26]},
		{"rect": Rect2i(2, 13, 6, 5), "ramp_dir": "n", "ramp_cols": [3, 4, 5]},
		{"rect": Rect2i(22, 13, 6, 5), "ramp_dir": "n", "ramp_cols": [24, 25, 26]},
	]

	var ramp_cells: Dictionary = {} # Vector2i -> {dir, slot}
	for base in bases:
		_fill_high(grid, base.rect)
		_mark_ramp_opening(grid, base, ramp_cells)

	var floors := Node2D.new()
	floors.name = "Floors"
	add_child(floors)
	var cliffs := Node2D.new()
	cliffs.name = "Cliffs"
	add_child(cliffs)
	var ramps := Node2D.new()
	ramps.name = "Ramps"
	add_child(ramps)
	var blockers := Node2D.new()
	blockers.name = "Blockers"
	add_child(blockers)

	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			var kind: int = grid[y][x]
			var pos := cell_center(cell)
			match kind:
				Cell.VOID:
					_sprite(floors, TEX_VOID, pos, 0)
					_blocker(blockers, pos)
				Cell.LOW:
					_sprite(floors, TEX_FLOOR_LOW, pos, 0)
				Cell.HIGH:
					_sprite(floors, TEX_FLOOR_HIGH, pos, 0)
					if ramp_cells.has(cell):
						_place_ramp(ramps, cell, ramp_cells[cell])
					else:
						_place_cliff_overlay(cliffs, blockers, grid, cell)


func _fill_low(grid: Array, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			grid[y][x] = Cell.LOW


func _fill_high(grid: Array, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			grid[y][x] = Cell.HIGH


func _mark_ramp_opening(grid: Array, base: Dictionary, ramp_cells: Dictionary) -> void:
	var rect: Rect2i = base.rect
	var dir: String = base.ramp_dir
	var cols: Array = base.ramp_cols
	var edge_y := rect.end.y - 1 if dir == "s" else rect.position.y
	var slots := ["left", "mid", "right"]
	var i := 0
	for x in cols:
		var cell := Vector2i(int(x), edge_y)
		if grid[cell.y][cell.x] != Cell.HIGH:
			continue
		ramp_cells[cell] = {"dir": dir, "slot": slots[mini(i, slots.size() - 1)]}
		i += 1


func _is_high(grid: Array, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= COLS or cell.y >= ROWS:
		return false
	return grid[cell.y][cell.x] == Cell.HIGH


func _place_cliff_overlay(
	cliffs: Node2D,
	blockers: Node2D,
	grid: Array,
	cell: Vector2i
) -> void:
	var n := not _is_high(grid, cell + Vector2i(0, -1))
	var s := not _is_high(grid, cell + Vector2i(0, 1))
	var e := not _is_high(grid, cell + Vector2i(1, 0))
	var w := not _is_high(grid, cell + Vector2i(-1, 0))

	var tex: Texture2D = null
	if n and e and not s and not w:
		tex = TEX_OUTER["ne"]
	elif n and w and not s and not e:
		tex = TEX_OUTER["nw"]
	elif s and e and not n and not w:
		tex = TEX_OUTER["se"]
	elif s and w and not n and not e:
		tex = TEX_OUTER["sw"]
	elif n and not s and not e and not w:
		tex = TEX_CLIFF["n"]
	elif s and not n and not e and not w:
		tex = TEX_CLIFF["s"]
	elif e and not n and not s and not w:
		tex = TEX_CLIFF["e"]
	elif w and not n and not s and not e:
		tex = TEX_CLIFF["w"]
	elif n and e:
		tex = TEX_OUTER["ne"]
	elif n and w:
		tex = TEX_OUTER["nw"]
	elif s and e:
		tex = TEX_OUTER["se"]
	elif s and w:
		tex = TEX_OUTER["sw"]

	if tex == null:
		return
	var pos := cell_center(cell)
	_sprite(cliffs, tex, pos, 1)
	# Thin walls on the low side so high ground stays walkable; ramps stay open.
	if n:
		_edge_blocker(blockers, pos + Vector2(0, -TILE * 0.5), Vector2(TILE * 0.9, TILE * 0.22))
	if s:
		_edge_blocker(blockers, pos + Vector2(0, TILE * 0.5), Vector2(TILE * 0.9, TILE * 0.22))
	if e:
		_edge_blocker(blockers, pos + Vector2(TILE * 0.5, 0), Vector2(TILE * 0.22, TILE * 0.9))
	if w:
		_edge_blocker(blockers, pos + Vector2(-TILE * 0.5, 0), Vector2(TILE * 0.22, TILE * 0.9))


func _place_ramp(ramps: Node2D, cell: Vector2i, info: Dictionary) -> void:
	var dir: String = info.dir
	var slot: String = info.slot
	var tex: Texture2D = TEX_RAMP[dir]
	if dir == "s":
		tex = TEX_RAMP_WIDE_S.get(slot, TEX_RAMP["s"])
	elif dir == "n":
		tex = TEX_RAMP_WIDE_N.get(slot, TEX_RAMP["n"])
	_sprite(ramps, tex, cell_center(cell), 1)


func _sprite(parent: Node2D, texture: Texture2D, pos: Vector2, z: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = pos
	sprite.z_index = z
	parent.add_child(sprite)


func _blocker(parent: Node2D, pos: Vector2) -> void:
	_edge_blocker(parent, pos, Vector2(TILE, TILE) * 0.92)


func _edge_blocker(parent: Node2D, pos: Vector2, size: Vector2) -> void:
	## Lava void and cliff faces block movement. Units need obstacle on their collision_mask.
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = PhysicsLayers.OBSTACLE
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	parent.add_child(body)
