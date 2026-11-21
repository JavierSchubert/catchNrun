#!/usr/bin/env python3
"""Paint 60x40 space arena TileMap from heightmap (void / mid / high)."""

from __future__ import annotations

import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_SCENE = ROOT / "game" / "maps" / "arena_space.tscn"
TILESET = "res://assets/sprites/maps/tiles/space/tileset.tres"

TILE = 128
COLS, ROWS = 60, 40
ATLAS_COLS = 8
VOID, MID, HIGH = 0, 1, 2

NAMES = [
	"floor",
	"void",
	"border_n",
	"border_s",
	"border_e",
	"border_w",
	"border_l_nw",
	"border_l_ne",
	"border_l_sw",
	"border_l_se",
	"border_l_nw_fog_primary",
	"border_l_nw_fog_secondary",
	"border_l_ne_fog_primary",
	"border_l_ne_fog_secondary",
	"border_l_sw_fog_primary",
	"border_l_sw_fog_secondary",
	"border_l_se_fog_primary",
	"border_l_se_fog_secondary",
	"plateau_n_mid",
	"plateau_n_edge",
	"plateau_s_mid",
	"plateau_s_edge",
	"plateau_e_mid",
	"plateau_e_edge",
	"plateau_w_mid",
	"plateau_w_edge",
	"plateau_l_nw_mid",
	"plateau_l_nw_edge",
	"plateau_l_ne_mid",
	"plateau_l_ne_edge",
	"plateau_l_sw_mid",
	"plateau_l_sw_edge",
	"plateau_l_se_mid",
	"plateau_l_se_edge",
]
ATLAS = {name: (i % ATLAS_COLS, i // ATLAS_COLS) for i, name in enumerate(NAMES)}


def fill_rect(grid: list[list[int]], x0: int, y0: int, w: int, h: int, val: int) -> None:
	for y in range(y0, min(y0 + h, ROWS)):
		for x in range(x0, min(x0 + w, COLS)):
			if 0 <= x < COLS and 0 <= y < ROWS:
				grid[y][x] = val


def in_octagon(x: int, y: int, margin: int = 3) -> bool:
	"""Rough playable footprint inset from edges (octagon-ish)."""
	if x < margin or y < margin or x >= COLS - margin or y >= ROWS - margin:
		return False
	# cut corners
	cx, cy = COLS / 2.0, ROWS / 2.0
	nx = abs(x + 0.5 - cx) / (COLS / 2.0 - margin)
	ny = abs(y + 0.5 - cy) / (ROWS / 2.0 - margin)
	return (nx + ny) <= 1.55


def build_grid() -> list[list[int]]:
	grid = [[VOID for _ in range(COLS)] for _ in range(ROWS)]
	for y in range(ROWS):
		for x in range(COLS):
			if in_octagon(x, y):
				grid[y][x] = MID

	# Ring of high plateaus (SC2-like bases) — openings toward center stay MID for access.
	plateaus = [
		# NW, N, NE, E, SE, SW, W
		(4, 3, 10, 8),
		(22, 2, 16, 7),
		(46, 3, 10, 8),
		(50, 13, 7, 12),
		(46, 29, 10, 8),
		(4, 29, 10, 8),
		(3, 13, 7, 12),
	]
	for x0, y0, w, h in plateaus:
		fill_rect(grid, x0, y0, w, h, HIGH)

	# Access corridors into each plateau (walkable mid gaps)
	corridors = [
		(8, 11, 3, 2),   # NW south opening
		(28, 9, 4, 2),   # N south opening
		(49, 11, 3, 2),  # NE south opening
		(48, 18, 2, 3),  # E west opening
		(49, 27, 3, 2),  # SE north opening
		(8, 27, 3, 2),   # SW north opening
		(10, 18, 2, 3),  # W east opening
	]
	for x0, y0, w, h in corridors:
		fill_rect(grid, x0, y0, w, h, MID)

	return grid


def kind(grid: list[list[int]], x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= COLS or y >= ROWS:
		return VOID
	return grid[y][x]


def is_void(grid: list[list[int]], x: int, y: int) -> bool:
	return kind(grid, x, y) == VOID


def is_high(grid: list[list[int]], x: int, y: int) -> bool:
	return kind(grid, x, y) == HIGH


def is_walkable(grid: list[list[int]], x: int, y: int) -> bool:
	return kind(grid, x, y) != VOID


def pick_border(grid: list[list[int]], x: int, y: int) -> str | None:
	"""MID cell adjacent to VOID → border tile."""
	if grid[y][x] != MID:
		return None
	n = is_void(grid, x, y - 1)
	s = is_void(grid, x, y + 1)
	e = is_void(grid, x + 1, y)
	w = is_void(grid, x - 1, y)
	if not (n or s or e or w):
		return None
	# outer L corners (void on two adjacent sides)
	if n and w and not s and not e:
		return "border_l_nw"
	if n and e and not s and not w:
		return "border_l_ne"
	if s and w and not n and not e:
		return "border_l_sw"
	if s and e and not n and not w:
		return "border_l_se"
	if n and not s and not e and not w:
		return "border_n"
	if s and not n and not e and not w:
		return "border_s"
	if e and not n and not s and not w:
		return "border_e"
	if w and not n and not s and not e:
		return "border_w"
	# multi-side fallbacks
	if s and e:
		return "border_l_se"
	if s and w:
		return "border_l_sw"
	if n and e:
		return "border_l_ne"
	if n and w:
		return "border_l_nw"
	if s:
		return "border_s"
	if n:
		return "border_n"
	if e:
		return "border_e"
	return "border_w"


def pick_plateau(grid: list[list[int]], x: int, y: int) -> str | None:
	"""HIGH cell adjacent to non-HIGH walkable → plateau cliff (prefer mid)."""
	if grid[y][x] != HIGH:
		return None
	n = not is_high(grid, x, y - 1) and is_walkable(grid, x, y - 1)
	s = not is_high(grid, x, y + 1) and is_walkable(grid, x, y + 1)
	e = not is_high(grid, x + 1, y) and is_walkable(grid, x + 1, y)
	w = not is_high(grid, x - 1, y) and is_walkable(grid, x - 1, y)
	# also cliff against void at outer rim of plateau
	n = n or (not is_high(grid, x, y - 1) and is_void(grid, x, y - 1))
	s = s or (not is_high(grid, x, y + 1) and is_void(grid, x, y + 1))
	e = e or (not is_high(grid, x + 1, y) and is_void(grid, x + 1, y))
	w = w or (not is_high(grid, x - 1, y) and is_void(grid, x - 1, y))
	if not (n or s or e or w):
		return None

	# edge vs mid: if the drop is toward map border (near void beyond), use edge
	def toward_edge(dx: int, dy: int) -> bool:
		return is_void(grid, x + dx * 2, y + dy * 2) or is_void(grid, x + dx, y + dy)

	use_edge = False
	if n and toward_edge(0, -1):
		use_edge = True
	if s and toward_edge(0, 1):
		use_edge = True
	if e and toward_edge(1, 0):
		use_edge = True
	if w and toward_edge(-1, 0):
		use_edge = True
	suffix = "edge" if use_edge else "mid"

	if n and w and not s and not e:
		return f"plateau_l_nw_{suffix}"
	if n and e and not s and not w:
		return f"plateau_l_ne_{suffix}"
	if s and w and not n and not e:
		return f"plateau_l_sw_{suffix}"
	if s and e and not n and not w:
		return f"plateau_l_se_{suffix}"
	if n and not s and not e and not w:
		return f"plateau_n_{suffix}"
	if s and not n and not e and not w:
		return f"plateau_s_{suffix}"
	if e and not n and not s and not w:
		return f"plateau_e_{suffix}"
	if w and not n and not s and not e:
		return f"plateau_w_{suffix}"
	if s and e:
		return f"plateau_l_se_{suffix}"
	if s and w:
		return f"plateau_l_sw_{suffix}"
	if n and e:
		return f"plateau_l_ne_{suffix}"
	if n and w:
		return f"plateau_l_nw_{suffix}"
	if s:
		return f"plateau_s_{suffix}"
	if n:
		return f"plateau_n_{suffix}"
	if e:
		return f"plateau_e_{suffix}"
	return f"plateau_w_{suffix}"


def floor_tile_name(grid: list[list[int]], x: int, y: int) -> str:
	k = grid[y][x]
	if k == VOID:
		return "void"
	border = pick_border(grid, x, y)
	if border:
		return border
	plateau = pick_plateau(grid, x, y)
	if plateau:
		return plateau
	return "floor"


def encode_cells(cells: list[tuple[int, int, int, int]]) -> bytes:
	out = bytearray()
	for x, y, ax, ay in cells:
		out += struct.pack("<hhHHHH", x, y, 0, ax, ay, 0)
	return bytes(out)


def packed_literal(data: bytes) -> str:
	return ", ".join(str(b) for b in data)


def main() -> None:
	grid = build_grid()
	floor_cells: list[tuple[int, int, int, int]] = []
	for y in range(ROWS):
		for x in range(COLS):
			name = floor_tile_name(grid, x, y)
			ax, ay = ATLAS[name]
			floor_cells.append((x, y, ax, ay))

	floor_data = encode_cells(floor_cells)
	# Overlay empty for now (props later)
	overlay_data = encode_cells([])

	ox = -COLS * TILE // 2
	oy = -ROWS * TILE // 2
	content = f"""[gd_scene format=3 uid="uid://carenaspace0001"]

[ext_resource type="TileSet" uid="uid://cspacemaptiles01" path="{TILESET}" id="1_tileset"]

[node name="ArenaSpace" type="Node2D"]

[node name="FloorLayer" type="TileMapLayer" parent="."]
position = Vector2({ox}, {oy})
tile_set = ExtResource("1_tileset")
tile_map_data = PackedByteArray({packed_literal(floor_data)})

[node name="OverlayLayer" type="TileMapLayer" parent="."]
z_index = 1
position = Vector2({ox}, {oy})
tile_set = ExtResource("1_tileset")
tile_map_data = PackedByteArray({packed_literal(overlay_data)})
"""
	OUT_SCENE.parent.mkdir(parents=True, exist_ok=True)
	OUT_SCENE.write_text(content, encoding="utf-8")

	# ASCII preview
	ch = {VOID: ".", MID: "#", HIGH: "H"}
	print(f"arena {COLS}x{ROWS} -> {OUT_SCENE}")
	print(f"floor cells={len(floor_cells)}")
	for y in range(0, ROWS, 2):
		row = ""
		for x in range(0, COLS, 2):
			row += ch[grid[y][x]]
		print(row)


if __name__ == "__main__":
	main()
