#!/usr/bin/env python3
"""Process v2 tiles: chroma-key magenta -> alpha, rotate variants, atlas + tileset + arena."""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = Path(r"C:\Users\GQCTY\.cursor\projects\c-Users-GQCTY-OneDrive-Bayer-Desktop-master-experimental-catchNrun\assets")
OUT = ROOT / "assets" / "sprites" / "maps" / "tiles" / "v2"
TILE = 128
COLS, ROWS = 30, 20
ATLAS_COLS = 8


def _paeth(a: int, b: int, c: int) -> int:
	p = a + b - c
	pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
	if pa <= pb and pa <= pc:
		return a
	if pb <= pc:
		return b
	return c


def write_png(path: Path, width: int, height: int, rgba: bytes) -> None:
	def chunk(tag: bytes, data: bytes) -> bytes:
		return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

	raw = bytearray()
	stride = width * 4
	for y in range(height):
		row = rgba[y * stride : (y + 1) * stride]
		raw.append(0)
		raw.extend(row)
	ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
	data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
	path.write_bytes(data)


def read_jpg_via_system(path: Path) -> tuple[int, int, bytes]:
	"""Load image via PowerShell System.Drawing, resize to TILE, export RGBA."""
	import subprocess
	import tempfile

	tmp = Path(tempfile.gettempdir()) / "catchnrun_tile_rgba.bin"
	ps = f"""
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile('{(path.as_posix())}')
$bmp = New-Object System.Drawing.Bitmap {TILE}, {TILE}
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($img, 0, 0, {TILE}, {TILE})
$g.Dispose(); $img.Dispose()
$bytes = New-Object byte[] ({TILE} * {TILE} * 4)
$i = 0
for ($y = 0; $y -lt {TILE}; $y++) {{
  for ($x = 0; $x -lt {TILE}; $x++) {{
    $c = $bmp.GetPixel($x, $y)
    $bytes[$i] = $c.R; $bytes[$i+1] = $c.G; $bytes[$i+2] = $c.B; $bytes[$i+3] = 255
    $i += 4
  }}
}}
$bmp.Dispose()
[IO.File]::WriteAllBytes('{(tmp.as_posix())}', $bytes)
Write-Output "{TILE} {TILE}"
"""
	out = subprocess.check_output(["powershell", "-NoProfile", "-Command", ps], text=True).strip()
	w, h = map(int, out.split())
	data = tmp.read_bytes()
	return w, h, data


def resize_nearest(src: bytes, sw: int, sh: int, dw: int, dh: int) -> bytes:
	out = bytearray(dw * dh * 4)
	for y in range(dh):
		sy = min(sh - 1, y * sh // dh)
		for x in range(dw):
			sx = min(sw - 1, x * sw // dw)
			si = (sy * sw + sx) * 4
			di = (y * dw + x) * 4
			out[di : di + 4] = src[si : si + 4]
	return bytes(out)


def chroma_key(rgba: bytes, w: int, h: int) -> bytes:
	out = bytearray(rgba)
	for i in range(0, len(out), 4):
		r, g, b = out[i], out[i + 1], out[i + 2]
		# Magenta (#FF00FF) and AI hot-pink leftovers (high R, low G, mid/high B)
		if r > 170 and g < 90 and b > 70 and (r - g) > 80:
			out[i + 3] = 0
			continue
		# Classic magenta
		if r > 160 and b > 160 and g < 140:
			out[i + 3] = 0
			continue
		# Near-white / light checker leftover
		if r > 230 and g > 230 and b > 230:
			out[i + 3] = 0
			continue
		# Light grey checker cells
		if r > 190 and g > 190 and b > 190 and abs(r - g) < 12 and abs(g - b) < 12:
			out[i + 3] = 0
	return bytes(out)


def rotate90(rgba: bytes, w: int, h: int) -> tuple[bytes, int, int]:
	out = bytearray(w * h * 4)
	for y in range(h):
		for x in range(w):
			# (x,y) -> (h-1-y, x) in new (h x w)? wait 90 CW: (x,y)->(h-1-y? no)
			# 90 CW: (x,y) -> (h-1-y, x) with new size (h, w) — standard: (x,y)->(y, w-1-x) for CCW
			# CW: nx, ny = h-1-y, x ; new_w=h, new_h=w
			nx, ny = h - 1 - y, x
			si = (y * w + x) * 4
			di = (ny * h + nx) * 4
			out[di : di + 4] = rgba[si : si + 4]
	return bytes(out), h, w


def flip_h(rgba: bytes, w: int, h: int) -> bytes:
	out = bytearray(len(rgba))
	for y in range(h):
		for x in range(w):
			si = (y * w + x) * 4
			di = (y * w + (w - 1 - x)) * 4
			out[di : di + 4] = rgba[si : si + 4]
	return bytes(out)


def flip_v(rgba: bytes, w: int, h: int) -> bytes:
	out = bytearray(len(rgba))
	for y in range(h):
		for x in range(w):
			si = (y * w + x) * 4
			di = ((h - 1 - y) * w + x) * 4
			out[di : di + 4] = rgba[si : si + 4]
	return bytes(out)


def load_tile(name: str, key: bool = True) -> bytes:
	path = SRC / f"{name}.jpg"
	if not path.exists():
		path = SRC / f"{name}.png"
	w, h, raw = read_jpg_via_system(path)
	rgba = raw if (w, h) == (TILE, TILE) else resize_nearest(raw, w, h, TILE, TILE)
	if key:
		rgba = chroma_key(rgba, TILE, TILE)
	else:
		# force opaque
		buf = bytearray(rgba)
		for i in range(3, len(buf), 4):
			buf[i] = 255
		rgba = bytes(buf)
	return rgba


def save(name: str, rgba: bytes) -> None:
	write_png(OUT / f"{name}.png", TILE, TILE, rgba)


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)

	# Opaque floors
	floor_a = load_tile("v2_floor", key=False)
	floor_b = load_tile("v2_floor_b", key=False)
	save("floor_a", floor_a)
	save("floor_b", floor_b)

	# Transparent borders
	border_bottom_a = load_tile("v2_border_bottom_a", key=True)
	border_bottom_b = load_tile("v2_border_bottom_b", key=True)
	border_right = load_tile("v2_border_right", key=True)
	border_left = load_tile("v2_border_left", key=True)
	border_top = load_tile("v2_border_top", key=True)
	save("border_bottom_a", border_bottom_a)
	save("border_bottom_b", border_bottom_b)
	save("border_right", border_right)
	save("border_left", border_left)
	save("border_top", border_top)

	corner = load_tile("v2_border_corner_se", key=True)
	save("border_corner_se", corner)
	c, w, h = rotate90(corner, TILE, TILE)
	save("border_corner_sw", c)  # may need adjust naming after visual
	c2, _, _ = rotate90(c, TILE, TILE)
	save("border_corner_nw", c2)
	c3, _, _ = rotate90(c2, TILE, TILE)
	save("border_corner_ne", c3)

	# Opaque plateau edges (floor colors baked in)
	plateau_s = load_tile("v2_plateau_s", key=False)
	plateau_e = load_tile("v2_plateau_e", key=False)
	save("plateau_s", plateau_s)
	save("plateau_e", plateau_e)
	pn, _, _ = rotate90(rotate90(plateau_s, TILE, TILE)[0], TILE, TILE)
	save("plateau_n", pn)
	# derive west from east by flip
	save("plateau_w", flip_h(plateau_e, TILE, TILE))

	outer = load_tile("v2_plateau_outer_se", key=False)
	save("plateau_outer_se", outer)
	o1, _, _ = rotate90(outer, TILE, TILE)
	save("plateau_outer_sw", o1)
	o2, _, _ = rotate90(o1, TILE, TILE)
	save("plateau_outer_nw", o2)
	o3, _, _ = rotate90(o2, TILE, TILE)
	save("plateau_outer_ne", o3)

	# Transparent ramps
	ramp_s = load_tile("v2_ramp_s", key=True)
	save("ramp_s", ramp_s)
	rn = flip_v(ramp_s, TILE, TILE)
	save("ramp_n", rn)
	re, _, _ = rotate90(rotate90(rotate90(ramp_s, TILE, TILE)[0], TILE, TILE)[0], TILE, TILE)
	# 270 CW from S -> E? S->W is 90 CW, S->N is 180, S->E is 270 CW
	r90, _, _ = rotate90(ramp_s, TILE, TILE)
	save("ramp_w", r90)
	r180, _, _ = rotate90(r90, TILE, TILE)
	save("ramp_n", r180)  # overwrite with rotation for consistency
	r270, _, _ = rotate90(r180, TILE, TILE)
	save("ramp_e", r270)

	names = [
		"floor_a",
		"floor_b",
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

	# Build atlas
	atlas_rows = (len(names) + ATLAS_COLS - 1) // ATLAS_COLS
	atlas_w, atlas_h = ATLAS_COLS * TILE, atlas_rows * TILE
	atlas = bytearray(atlas_w * atlas_h * 4)  # transparent
	mapping: dict[str, tuple[int, int]] = {}
	for i, name in enumerate(names):
		ax, ay = i % ATLAS_COLS, i // ATLAS_COLS
		mapping[name] = (ax, ay)
		tile = (OUT / f"{name}.png").read_bytes()
		# re-read via our png writer we know format - parse simple
		rgba = _read_png_rgba(OUT / f"{name}.png")
		for y in range(TILE):
			for x in range(TILE):
				si = (y * TILE + x) * 4
				di = ((ay * TILE + y) * atlas_w + (ax * TILE + x)) * 4
				atlas[di : di + 4] = rgba[si : si + 4]
	write_png(OUT / "atlas.png", atlas_w, atlas_h, bytes(atlas))

	# TileSet
	lines = [
		'[gd_resource type="TileSet" load_steps=2 format=3 uid="uid://cv2plateautileset"]',
		"",
		'[ext_resource type="Texture2D" path="res://assets/sprites/maps/tiles/v2/atlas.png" id="1_atlas"]',
		"",
		'[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_v2"]',
		'texture = ExtResource("1_atlas")',
		"texture_region_size = Vector2i(128, 128)",
	]
	solid = {"border_bottom_a", "border_bottom_b", "border_top", "border_left", "border_right",
			 "border_corner_nw", "border_corner_ne", "border_corner_sw", "border_corner_se"}
	for name in names:
		ax, ay = mapping[name]
		lines.append(f"{ax}:{ay}/0 = 0")
		if name in solid:
			lines.append(
				f"{ax}:{ay}/0/physics_layer_0/polygon_0/points = PackedVector2Array(-64, -64, 64, -64, 64, 64, -64, 64)"
			)
	lines += [
		"",
		"[resource]",
		"tile_size = Vector2i(128, 128)",
		"physics_layer_0/collision_layer = 2",
		'sources/0 = SubResource("TileSetAtlasSource_v2")',
		"",
	]
	(OUT / "tileset.tres").write_text("\n".join(lines), encoding="utf-8")

	# Paint arena
	floor_cells, overlay_cells = paint_arena(mapping)
	write_arena(floor_cells, overlay_cells)
	print("tiles:", len(names))
	print("atlas:", OUT / "atlas.png")
	print("tileset:", OUT / "tileset.tres")
	print("mapping:", mapping)


def _read_png_rgba(path: Path) -> bytes:
	data = path.read_bytes()
	assert data[:8] == b"\x89PNG\r\n\x1a\n"
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
	assert width and height
	raw = zlib.decompress(bytes(idat))
	# filter 0 only (we wrote filter 0)
	out = bytearray()
	stride = width * 4
	i = 0
	for _y in range(height):
		assert raw[i] == 0
		i += 1
		out.extend(raw[i : i + stride])
		i += stride
	return bytes(out)


def paint_arena(mapping: dict[str, tuple[int, int]]):
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
	ramps = {}
	for b in bases:
		x0, y0, w, h = b["rect"]
		for y in range(y0, y0 + h):
			for x in range(x0, x0 + w):
				grid[y][x] = HIGH
		ey = y0 + h - 1 if b["ramp"] == "s" else y0
		for x in b["cols"]:
			ramps[(x, ey)] = b["ramp"]

	def is_high(x, y):
		return 0 <= x < COLS and 0 <= y < ROWS and grid[y][x] == HIGH

	floor_cells = []
	overlay_cells = []

	def add(cells, x, y, name):
		ax, ay = mapping[name]
		cells.append((x, y, ax, ay))

	for y in range(ROWS):
		for x in range(COLS):
			# floor layer
			if grid[y][x] == VOID:
				# void cells: leave empty on floor; border overlay will show lava rocks
				pass
			elif grid[y][x] == HIGH:
				# plateau edge tiles replace floor on perimeter; interior floor
				n, s = not is_high(x, y - 1), not is_high(x, y + 1)
				e, w = not is_high(x + 1, y), not is_high(x - 1, y)
				if (x, y) in ramps:
					add(floor_cells, x, y, "floor_a")
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
					add(floor_cells, x, y, "floor_b")
			else:
				add(floor_cells, x, y, "floor_a" if (x + y) % 2 == 0 else "floor_b")

			# overlay: map borders + ramps
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

	return floor_cells, overlay_cells


def encode(cells):
	out = bytearray()
	for x, y, ax, ay in cells:
		out += struct.pack("<hhHHHH", x, y, 0, ax, ay, 0)
	return bytes(out)


def write_arena(floor_cells, overlay_cells):
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


if __name__ == "__main__":
	main()
