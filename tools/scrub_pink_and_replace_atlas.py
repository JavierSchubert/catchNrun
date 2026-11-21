#!/usr/bin/env python3
"""Remove all pink/magenta anomalies from v3 tiles, rebuild atlas, replace active atlas."""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V3 = ROOT / "assets" / "sprites" / "maps" / "tiles" / "v3"
V2 = ROOT / "assets" / "sprites" / "maps" / "tiles" / "v2"
TILE = 128
ATLAS_COLS = 8

NAMES = [
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
	import time

	last_err: OSError | None = None
	for _ in range(12):
		try:
			path.write_bytes(data)
			return
		except OSError as err:
			last_err = err
			time.sleep(0.35)
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


def is_pink(r: int, g: int, b: int, a: int = 255) -> bool:
	"""Pink/magenta/purple fringe detector. Does NOT match orange lava."""
	if a < 250:
		return True
	# classic magenta (#FF00FF family)
	if r >= 150 and b >= 150 and g <= 140:
		return True
	# hot pink / rose: high R, low G, mid B — but not orange lava (lava has low B)
	if r >= 130 and g <= 115 and 70 <= b <= 200 and (r - g) >= 35 and b >= g - 5:
		return True
	# purple-pink fringe (R high, B≈G or B>G, not warm orange)
	if r >= 160 and b >= 100 and g <= 165 and (r - g) >= 20 and b >= int(g * 0.85):
		return True
	# light magenta haze
	if r >= 200 and 80 <= g <= 170 and 120 <= b <= 220 and (r - g) >= 40:
		return True
	# pastel pink bar (e.g. 252,191,230) — high R+B, G also high but pink cast
	if r >= 200 and b >= 170 and g >= 140 and (r + b) > (2 * g + 40) and b > 100:
		return True
	return False


def scrub(rgba: bytes, floor: bytes) -> tuple[bytes, int]:
	"""Replace pink pixels with floor (same coords) or nearest clean neighbor."""
	buf = bytearray(rgba)
	w = h = TILE
	changed = 0
	# pass 1: replace with floor at same index
	for i in range(0, len(buf), 4):
		r, g, b, a = buf[i], buf[i + 1], buf[i + 2], buf[i + 3]
		if is_pink(r, g, b, a):
			buf[i : i + 4] = floor[i : i + 4]
			buf[i + 3] = 255
			changed += 1
		else:
			buf[i + 3] = 255
	# pass 2: any residual pink -> average of non-pink neighbors, else floor
	for _ in range(3):
		nxt = bytearray(buf)
		more = 0
		for y in range(h):
			for x in range(w):
				i = (y * w + x) * 4
				if not is_pink(buf[i], buf[i + 1], buf[i + 2], buf[i + 3]):
					continue
				rs = gs = bs = n = 0
				for dy in (-1, 0, 1):
					for dx in (-1, 0, 1):
						nx, ny = x + dx, y + dy
						if nx < 0 or ny < 0 or nx >= w or ny >= h:
							continue
						j = (ny * w + nx) * 4
						if is_pink(buf[j], buf[j + 1], buf[j + 2], buf[j + 3]):
							continue
						rs += buf[j]
						gs += buf[j + 1]
						bs += buf[j + 2]
						n += 1
				if n:
					nxt[i] = rs // n
					nxt[i + 1] = gs // n
					nxt[i + 2] = bs // n
					nxt[i + 3] = 255
				else:
					nxt[i : i + 4] = floor[i : i + 4]
					nxt[i + 3] = 255
				more += 1
		buf = nxt
		changed += more
		if more == 0:
			break
	# final force opaque + last pink sweep
	for i in range(0, len(buf), 4):
		if is_pink(buf[i], buf[i + 1], buf[i + 2], buf[i + 3]):
			buf[i : i + 4] = floor[i : i + 4]
			changed += 1
		buf[i + 3] = 255
	return bytes(buf), changed


def build_atlas(mapping: dict[str, tuple[int, int]], fill: bytes) -> tuple[bytes, int, int]:
	rows = (len(NAMES) + ATLAS_COLS - 1) // ATLAS_COLS
	atlas_w, atlas_h = ATLAS_COLS * TILE, rows * TILE
	# Fill unused atlas cells with floor so nothing is transparent/pink.
	atlas = bytearray(atlas_w * atlas_h * 4)
	for y in range(atlas_h):
		for x in range(atlas_w):
			si = ((y % TILE) * TILE + (x % TILE)) * 4
			di = (y * atlas_w + x) * 4
			atlas[di : di + 4] = fill[si : si + 4]
	for name, (ax, ay) in mapping.items():
		_, _, tile = read_png(V3 / f"{name}.png")
		for y in range(TILE):
			for x in range(TILE):
				si = (y * TILE + x) * 4
				di = ((ay * TILE + y) * atlas_w + ax * TILE + x) * 4
				atlas[di : di + 4] = tile[si : si + 4]
	return bytes(atlas), atlas_w, atlas_h


def write_tileset(path: Path, atlas_res: str, atlas_uid: str, tileset_uid: str) -> None:
	mapping = {n: (i % ATLAS_COLS, i // ATLAS_COLS) for i, n in enumerate(NAMES)}
	lines = [
		f'[gd_resource type="TileSet" load_steps=2 format=3 uid="{tileset_uid}"]',
		"",
		f'[ext_resource type="Texture2D" uid="{atlas_uid}" path="{atlas_res}" id="1_atlas"]',
		"",
		'[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_main"]',
		'texture = ExtResource("1_atlas")',
		"texture_region_size = Vector2i(128, 128)",
	]
	for name in NAMES:
		ax, ay = mapping[name]
		lines.append(f"{ax}:{ay}/0 = 0")
	lines += [
		"",
		"[resource]",
		"tile_size = Vector2i(128, 128)",
		'sources/0 = SubResource("TileSetAtlasSource_main")',
		"",
	]
	path.write_text("\n".join(lines), encoding="utf-8")


def count_pink(rgba: bytes) -> int:
	n = 0
	for i in range(0, len(rgba), 4):
		if is_pink(rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]):
			n += 1
	return n


def main() -> None:
	_, _, floor = read_png(V3 / "floor.png")
	floor = bytearray(floor)
	for i in range(3, len(floor), 4):
		floor[i] = 255
	floor = bytes(floor)

	total = 0
	for name in NAMES:
		path = V3 / f"{name}.png"
		_, _, rgba = read_png(path)
		cleaned, n = scrub(rgba, floor if name != "floor" else rgba)
		# floor itself: only force opaque, scrub pink to average brown
		if name == "floor":
			cleaned, n = scrub(rgba, rgba)
		write_png(path, TILE, TILE, cleaned)
		left = count_pink(cleaned)
		print(f"{name}: scrubbed≈{n}, remaining_pink={left}")
		total += left

	mapping = {n: (i % ATLAS_COLS, i // ATLAS_COLS) for i, n in enumerate(NAMES)}
	_, _, floor_fill = read_png(V3 / "floor.png")
	atlas, aw, ah = build_atlas(mapping, floor_fill)
	write_png(V3 / "atlas.png", aw, ah, atlas)
	write_tileset(
		V3 / "tileset.tres",
		"res://assets/sprites/maps/tiles/v3/atlas.png",
		"uid://cv3plateauatlas01",
		"uid://cv3plateautileset",
	)

	# Replace the currently used (v2) atlas + tileset with cleaned v3 content
	write_png(V2 / "atlas.png", aw, ah, atlas)
	write_tileset(
		V2 / "tileset.tres",
		"res://assets/sprites/maps/tiles/v2/atlas.png",
		"uid://cv2plateauatlas01",
		"uid://cv2plateautileset",
	)

	# Repaint arena against the new atlas layout (coords changed vs old v2)
	write_arena(mapping)

	# Verify atlases
	for label, path in [("v3", V3 / "atlas.png"), ("v2", V2 / "atlas.png")]:
		_, _, rgba = read_png(path)
		print(f"{label} atlas pink remaining: {count_pink(rgba)}")
	print(f"tile pink remaining total: {total}")


def write_arena(mapping: dict[str, tuple[int, int]]) -> None:
	COLS, ROWS = 30, 20
	VOID, FLOOR, HIGH = 0, 1, 2
	grid = [[VOID] * COLS for _ in range(ROWS)]
	for y in range(1, ROWS - 1):
		for x in range(1, COLS - 1):
			grid[y][x] = FLOOR
	bases = [
		{"rect": (2, 2, 6, 5), "ramp": "s", "cols": [3, 4, 5]},
		{"rect": (22, 2, 6, 5), "ramp": "s", "cols": [24, 25, 26]},
		{"rect": (2, 13, 6, 5), "ramp": "n", "cols": [3, 4, 5]},
		{"rect": (22, 13, 6, 5), "ramp": "n", "cols": [24, 25, 26]},
	]
	ramps: dict[tuple[int, int], str] = {}
	for b in bases:
		x0, y0, w, h = b["rect"]
		for y in range(y0, y0 + h):
			for x in range(x0, x0 + w):
				grid[y][x] = HIGH
		ey = y0 + h - 1 if b["ramp"] == "s" else y0
		for x in b["cols"]:
			ramps[(x, ey)] = b["ramp"]

	def is_high(x: int, y: int) -> bool:
		return 0 <= x < COLS and 0 <= y < ROWS and grid[y][x] == HIGH

	floor_cells: list[tuple[int, int, int, int]] = []
	overlay_cells: list[tuple[int, int, int, int]] = []

	def add(cells: list, x: int, y: int, name: str) -> None:
		ax, ay = mapping[name]
		cells.append((x, y, ax, ay))

	for y in range(ROWS):
		for x in range(COLS):
			if grid[y][x] == HIGH:
				n, s = not is_high(x, y - 1), not is_high(x, y + 1)
				e, w = not is_high(x + 1, y), not is_high(x - 1, y)
				if (x, y) in ramps:
					add(floor_cells, x, y, "floor")
				elif n and e:
					add(floor_cells, x, y, "plateau_outer_ne")
				elif n and w:
					add(floor_cells, x, y, "plateau_outer_nw")
				elif s and e:
					add(floor_cells, x, y, "plateau_outer_se")
				elif s and w:
					add(floor_cells, x, y, "plateau_outer_sw")
				elif n:
					add(floor_cells, x, y, "plateau_n")
				elif s:
					add(floor_cells, x, y, "plateau_s")
				elif e:
					add(floor_cells, x, y, "plateau_e")
				elif w:
					add(floor_cells, x, y, "plateau_w")
				else:
					add(floor_cells, x, y, "floor")
			elif grid[y][x] == FLOOR:
				add(floor_cells, x, y, "floor")

			# borders on rim
			if y == ROWS - 1 and x == 0:
				add(overlay_cells, x, y, "border_corner_sw")
			elif y == ROWS - 1 and x == COLS - 1:
				add(overlay_cells, x, y, "border_corner_se")
			elif y == 0 and x == 0:
				add(overlay_cells, x, y, "border_corner_nw")
			elif y == 0 and x == COLS - 1:
				add(overlay_cells, x, y, "border_corner_ne")
			elif y == ROWS - 1:
				add(overlay_cells, x, y, "border_bottom_a" if x % 2 == 0 else "border_bottom_b")
			elif y == 0:
				add(overlay_cells, x, y, "border_top")
			elif x == 0:
				add(overlay_cells, x, y, "border_left")
			elif x == COLS - 1:
				add(overlay_cells, x, y, "border_right")
			if (x, y) in ramps:
				add(overlay_cells, x, y, f"ramp_{ramps[(x, y)]}")

	def encode(cells: list[tuple[int, int, int, int]]) -> bytes:
		out = bytearray()
		for x, y, ax, ay in cells:
			out += struct.pack("<hhHHHH", x, y, 0, ax, ay, 0)
		return bytes(out)

	floor_lit = ", ".join(str(b) for b in encode(floor_cells))
	overlay_lit = ", ".join(str(b) for b in encode(overlay_cells))
	path = ROOT / "game" / "maps" / "arena_plateau.tscn"
	path.write_text(
		f"""[gd_scene format=3 uid="uid://carenaplateau01"]

[ext_resource type="TileSet" uid="uid://cv2plateautileset" path="res://assets/sprites/maps/tiles/v2/tileset.tres" id="1_tileset"]

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
""",
		encoding="utf-8",
	)
	print("arena repainted ->", path)


if __name__ == "__main__":
	main()
