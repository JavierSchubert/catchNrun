#!/usr/bin/env python3
"""Append rocks + lava veins to v3 atlas/tileset and fix arena_plateau.tscn TileSet refs."""

from __future__ import annotations

import re
import struct
import time
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V3 = ROOT / "assets" / "sprites" / "maps" / "tiles" / "v3"
ARENA = ROOT / "game" / "maps" / "arena_plateau.tscn"
TILE = 128
ATLAS_COLS = 8

# Keep existing atlas order so painted cells stay valid, then append props.
BASE_NAMES = [
	"floor",
	"border_bottom_a",
	"border_bottom_b",
	"border_top",
	"border_left",
	"border_right",
	"border_corner_nw",
	"border_corner_ne",
	"border_corner_sw",
	"border_corner_se",
	"plateau_n",
	"plateau_s",
	"plateau_e",
	"plateau_w",
	"plateau_outer_nw",
	"plateau_outer_ne",
	"plateau_outer_sw",
	"plateau_outer_se",
	"ramp_n",
	"ramp_s",
	"ramp_e",
	"ramp_w",
]
NEW_NAMES = [
	"prop_rocks",
	"tile_lava_vein_mid",
	"tile_lava_vein_end",
	"tile_lava_vein_source",
	"tile_border_rock",
	"tile_ground_center",
	"tile_ground_high",
]


def write_png(path: Path, width: int, height: int, rgba: bytes) -> None:
	def chunk(tag: bytes, data: bytes) -> bytes:
		return (
			struct.pack(">I", len(data))
			+ tag
			+ data
			+ struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
		)

	raw = bytearray()
	stride = width * 4
	for y in range(height):
		raw.append(0)
		raw.extend(rgba[y * stride : (y + 1) * stride])
	ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
	data = (
		b"\x89PNG\r\n\x1a\n"
		+ chunk(b"IHDR", ihdr)
		+ chunk(b"IDAT", zlib.compress(bytes(raw), 9))
		+ chunk(b"IEND", b"")
	)
	last_err: OSError | None = None
	for _ in range(12):
		try:
			path.write_bytes(data)
			return
		except OSError as err:
			last_err = err
			time.sleep(0.3)
	if last_err:
		raise last_err


def read_png(path: Path) -> tuple[int, int, bytes]:
	data = path.read_bytes()
	pos = 8
	width = height = None
	idat = bytearray()
	while pos < len(data):
		length = struct.unpack(">I", data[pos : pos + 4])[0]
		tag = data[pos + 4 : pos + 8]
		chunk = data[pos + 8 : pos + 8 + length]
		pos += 12 + length
		if tag == b"IHDR":
			width, height = struct.unpack(">II", chunk[:8])
		elif tag == b"IDAT":
			idat.extend(chunk)
		elif tag == b"IEND":
			break
	raw = zlib.decompress(bytes(idat))
	out = bytearray()
	stride = width * 4
	i = 0
	for _ in range(height):
		i += 1
		out.extend(raw[i : i + stride])
		i += stride
	return width, height, bytes(out)


def force_opaque(rgba: bytes) -> bytes:
	buf = bytearray(rgba)
	for i in range(3, len(buf), 4):
		buf[i] = 255
	return bytes(buf)


def main() -> None:
	names = BASE_NAMES + [n for n in NEW_NAMES if (V3 / f"{n}.png").exists()]
	_, _, floor = read_png(V3 / "floor.png")
	floor = force_opaque(floor)

	rows = (len(names) + ATLAS_COLS - 1) // ATLAS_COLS
	atlas_w, atlas_h = ATLAS_COLS * TILE, rows * TILE
	atlas = bytearray(atlas_w * atlas_h * 4)
	# fill unused with floor
	for y in range(atlas_h):
		for x in range(atlas_w):
			si = ((y % TILE) * TILE + (x % TILE)) * 4
			di = (y * atlas_w + x) * 4
			atlas[di : di + 4] = floor[si : si + 4]

	for i, name in enumerate(names):
		ax, ay = i % ATLAS_COLS, i // ATLAS_COLS
		_, _, tile = read_png(V3 / f"{name}.png")
		tile = force_opaque(tile)
		for y in range(TILE):
			for x in range(TILE):
				si = (y * TILE + x) * 4
				di = ((ay * TILE + y) * atlas_w + ax * TILE + x) * 4
				atlas[di : di + 4] = tile[si : si + 4]
		print(f"  {ax},{ay} <- {name}")

	write_png(V3 / "atlas.png", atlas_w, atlas_h, bytes(atlas))

	# tileset.tres
	lines = [
		'[gd_resource type="TileSet" load_steps=2 format=3 uid="uid://cv3plateautileset"]',
		"",
		'[ext_resource type="Texture2D" uid="uid://cv3plateauatlas01" path="res://assets/sprites/maps/tiles/v3/atlas.png" id="1_atlas"]',
		"",
		'[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_main"]',
		'texture = ExtResource("1_atlas")',
		"texture_region_size = Vector2i(128, 128)",
	]
	for i, _name in enumerate(names):
		ax, ay = i % ATLAS_COLS, i // ATLAS_COLS
		lines.append(f"{ax}:{ay}/0 = 0")
	lines += [
		"",
		"[resource]",
		"tile_size = Vector2i(128, 128)",
		'sources/0 = SubResource("TileSetAtlasSource_main")',
		"",
	]
	(V3 / "tileset.tres").write_text("\n".join(lines), encoding="utf-8")
	print("updated", V3 / "tileset.tres", "tiles=", len(names))

	fix_arena()


def fix_arena() -> None:
	text = ARENA.read_text(encoding="utf-8")
	# Keep the painted PackedByteArrays from the user's prototype.
	floor_m = re.search(
		r'\[node name="FloorLayer"[^\]]*\]\s*tile_map_data = PackedByteArray\("([^"]*)"\)',
		text,
		re.S,
	)
	overlay_m = re.search(
		r'\[node name="OverlayLayer"[^\]]*\].*?tile_map_data = PackedByteArray\("([^"]*)"\)',
		text,
		re.S,
	)
	if floor_m is None or overlay_m is None:
		# Godot 4 format sometimes has props between name and tile_map_data
		floor_m = re.search(
			r'\[node name="FloorLayer".*?tile_map_data = PackedByteArray\("([^"]*)"\)',
			text,
			re.S,
		)
		overlay_m = re.search(
			r'\[node name="OverlayLayer".*?tile_map_data = PackedByteArray\("([^"]*)"\)',
			text,
			re.S,
		)
	if floor_m is None or overlay_m is None:
		raise RuntimeError("Could not extract painted tile_map_data from arena_plateau.tscn")

	floor_data = floor_m.group(1)
	overlay_data = overlay_m.group(1)

	ARENA.write_text(
		f"""[gd_scene format=3 uid="uid://co2dllw6ejyto"]

[ext_resource type="TileSet" uid="uid://cv3plateautileset" path="res://assets/sprites/maps/tiles/v3/tileset.tres" id="1_tileset"]

[node name="ArenaPlateau" type="Node2D"]

[node name="FloorLayer" type="TileMapLayer" parent="."]
tile_map_data = PackedByteArray("{floor_data}")
tile_set = ExtResource("1_tileset")

[node name="OverlayLayer" type="TileMapLayer" parent="."]
z_index = 1
tile_map_data = PackedByteArray("{overlay_data}")
tile_set = ExtResource("1_tileset")
""",
		encoding="utf-8",
	)
	print("fixed arena_plateau.tscn -> uses v3/tileset.tres")


if __name__ == "__main__":
	main()
