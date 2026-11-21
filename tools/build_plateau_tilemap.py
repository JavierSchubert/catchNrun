#!/usr/bin/env python3
"""Build plateau TileSet + encoded TileMapLayer data for the match arena."""

from __future__ import annotations

import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "sprites" / "maps" / "tiles" / "plateau"

TILE = 128
COLS, ROWS = 30, 20
ATLAS_COLS = 8

NAMES = [
	"floor_low",
	"floor_high",
	"void_lava",
	"cliff_n",
	"cliff_s",
	"cliff_e",
	"cliff_w",
	"cliff_outer_ne",
	"cliff_outer_nw",
	"cliff_outer_se",
	"cliff_outer_sw",
	"cliff_inner_ne",
	"cliff_inner_nw",
	"cliff_inner_se",
	"cliff_inner_sw",
	"ramp_n",
	"ramp_s",
	"ramp_e",
	"ramp_w",
	"ramp_s_left",
	"ramp_s_mid",
	"ramp_s_right",
	"ramp_n_left",
	"ramp_n_mid",
	"ramp_n_right",
	"ramp_e_top",
	"ramp_e_mid",
	"ramp_e_bottom",
	"ramp_w_top",
	"ramp_w_mid",
	"ramp_w_bottom",
]

ATLAS = {name: (i % ATLAS_COLS, i // ATLAS_COLS) for i, name in enumerate(NAMES)}
# Only lava void blocks by default. Cliff collision can be painted/tuned in the TileSet editor.
SOLID = {
	"void_lava",
}

VOID, LOW, HIGH = 0, 1, 2


def build_grid() -> tuple[list[list[int]], dict[tuple[int, int], tuple[str, str]]]:
	grid = [[VOID for _ in range(COLS)] for _ in range(ROWS)]
	for y in range(1, ROWS - 1):
		for x in range(1, COLS - 1):
			grid[y][x] = LOW

	bases = [
		{"rect": (2, 2, 6, 5), "ramp_dir": "s", "ramp_cols": [3, 4, 5]},
		{"rect": (22, 2, 6, 5), "ramp_dir": "s", "ramp_cols": [24, 25, 26]},
		{"rect": (2, 13, 6, 5), "ramp_dir": "n", "ramp_cols": [3, 4, 5]},
		{"rect": (22, 13, 6, 5), "ramp_dir": "n", "ramp_cols": [24, 25, 26]},
	]
	ramp_cells: dict[tuple[int, int], tuple[str, str]] = {}
	for base in bases:
		x0, y0, w, h = base["rect"]
		for y in range(y0, y0 + h):
			for x in range(x0, x0 + w):
				grid[y][x] = HIGH
		edge_y = y0 + h - 1 if base["ramp_dir"] == "s" else y0
		slots = ["left", "mid", "right"]
		for i, x in enumerate(base["ramp_cols"]):
			ramp_cells[(x, edge_y)] = (base["ramp_dir"], slots[i])
	return grid, ramp_cells


def is_high(grid: list[list[int]], x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= COLS or y >= ROWS:
		return False
	return grid[y][x] == HIGH


def floor_tile(grid: list[list[int]], x: int, y: int) -> str:
	kind = grid[y][x]
	if kind == VOID:
		return "void_lava"
	if kind == HIGH:
		return "floor_high"
	return "floor_low"


def overlay_tile(
	grid: list[list[int]],
	ramp_cells: dict[tuple[int, int], tuple[str, str]],
	x: int,
	y: int,
) -> str | None:
	if (x, y) in ramp_cells:
		direction, slot = ramp_cells[(x, y)]
		return f"ramp_{direction}_{slot}"
	if grid[y][x] != HIGH:
		return None
	n = not is_high(grid, x, y - 1)
	s = not is_high(grid, x, y + 1)
	e = not is_high(grid, x + 1, y)
	w = not is_high(grid, x - 1, y)
	if n and e and not s and not w:
		return "cliff_outer_ne"
	if n and w and not s and not e:
		return "cliff_outer_nw"
	if s and e and not n and not w:
		return "cliff_outer_se"
	if s and w and not n and not e:
		return "cliff_outer_sw"
	if n and not s and not e and not w:
		return "cliff_n"
	if s and not n and not e and not w:
		return "cliff_s"
	if e and not n and not s and not w:
		return "cliff_e"
	if w and not n and not s and not e:
		return "cliff_w"
	if n and e:
		return "cliff_outer_ne"
	if n and w:
		return "cliff_outer_nw"
	if s and e:
		return "cliff_outer_se"
	if s and w:
		return "cliff_outer_sw"
	return None


def encode_cells(cells: list[tuple[int, int, int, int]]) -> bytes:
	out = bytearray()
	for x, y, ax, ay in cells:
		# Godot 4 TileMapLayer cell: x,y int16; source_id, atlas_x, atlas_y, alternative uint16
		out += struct.pack("<hhHHHH", x, y, 0, ax, ay, 0)
	return bytes(out)


def packed_byte_array_literal(data: bytes) -> str:
	return ", ".join(str(b) for b in data)


def write_tileset() -> None:
	lines = [
		'[gd_resource type="TileSet" load_steps=2 format=3 uid="uid://cplateautileset1"]',
		"",
		'[ext_resource type="Texture2D" path="res://assets/sprites/maps/tiles/plateau/plateau_atlas.png" id="1_atlas"]',
		"",
		'[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_plateau"]',
		"texture = ExtResource(\"1_atlas\")",
		"texture_region_size = Vector2i(128, 128)",
	]
	for name in NAMES:
		ax, ay = ATLAS[name]
		lines.append(f"{ax}:{ay}/0 = 0")
		if name in SOLID:
			lines.append(
				f"{ax}:{ay}/0/physics_layer_0/polygon_0/points = PackedVector2Array(-64, -64, 64, -64, 64, 64, -64, 64)"
			)
	lines.extend(
		[
			"",
			"[resource]",
			"tile_size = Vector2i(128, 128)",
			"physics_layer_0/collision_layer = 2",
			"sources/0 = SubResource(\"TileSetAtlasSource_plateau\")",
			"",
		]
	)
	(OUT_DIR / "plateau_tileset.tres").write_text("\n".join(lines), encoding="utf-8")


def write_arena_scene(floor_data: bytes, overlay_data: bytes) -> None:
	scene_path = ROOT / "game" / "maps" / "arena_plateau.tscn"
	scene_path.parent.mkdir(parents=True, exist_ok=True)
	floor_lit = packed_byte_array_literal(floor_data)
	overlay_lit = packed_byte_array_literal(overlay_data)
	content = f"""[gd_scene format=3 uid="uid://carenaplateau01"]

[ext_resource type="TileSet" uid="uid://cplateautileset1" path="res://assets/sprites/maps/tiles/plateau/plateau_tileset.tres" id="1_tileset"]

[node name="ArenaPlateau" type="Node2D"]

[node name="FloorLayer" type="TileMapLayer" parent="."]
position = Vector2(-1920, -1280)
tile_set = ExtResource("1_tileset")
tile_map_data = PackedByteArray({floor_lit})

[node name="OverlayLayer" type="TileMapLayer" parent="."]
z_index = 1
position = Vector2(-1920, -1280)
tile_set = ExtResource("1_tileset")
tile_map_data = PackedByteArray({overlay_lit})
"""
	scene_path.write_text(content, encoding="utf-8")


def main() -> None:
	grid, ramp_cells = build_grid()
	floor_cells: list[tuple[int, int, int, int]] = []
	overlay_cells: list[tuple[int, int, int, int]] = []
	for y in range(ROWS):
		for x in range(COLS):
			ax, ay = ATLAS[floor_tile(grid, x, y)]
			floor_cells.append((x, y, ax, ay))
			overlay = overlay_tile(grid, ramp_cells, x, y)
			if overlay is not None:
				ox, oy = ATLAS[overlay]
				overlay_cells.append((x, y, ox, oy))

	floor_data = encode_cells(floor_cells)
	overlay_data = encode_cells(overlay_cells)
	write_tileset()
	write_arena_scene(floor_data, overlay_data)
	print(f"tileset -> {OUT_DIR / 'plateau_tileset.tres'}")
	print(f"arena   -> {ROOT / 'game' / 'maps' / 'arena_plateau.tscn'}")
	print(f"floor cells={len(floor_cells)} overlay cells={len(overlay_cells)}")


if __name__ == "__main__":
	main()
