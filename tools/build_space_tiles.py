#!/usr/bin/env python3
"""Build space tileset from gen_space_* masters (rotate/flip for full set)."""

from __future__ import annotations

import struct
import subprocess
import tempfile
import time
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sprites" / "maps" / "tiles" / "space"
SRC = Path(
	r"C:\Users\GQCTY\.cursor\projects\c-Users-GQCTY-OneDrive-Bayer-Desktop-master-experimental-catchNrun\assets"
)
TILE = 128
ATLAS_COLS = 8

# Atlas order (paint script depends on these names/indices).
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
	payload = (
		b"\x89PNG\r\n\x1a\n"
		+ chunk(b"IHDR", ihdr)
		+ chunk(b"IDAT", zlib.compress(bytes(raw), 9))
		+ chunk(b"IEND", b"")
	)
	last: OSError | None = None
	for _ in range(12):
		try:
			path.write_bytes(payload)
			return
		except OSError as err:
			last = err
			time.sleep(0.3)
	if last:
		raise last


def read_png(path: Path) -> bytes:
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
	assert width == TILE and height == TILE
	return bytes(out)


def is_pink(r: int, g: int, b: int, a: int = 255) -> bool:
	if a < 250:
		return True
	if r >= 150 and b >= 150 and g <= 140:
		return True
	if r >= 130 and g <= 115 and 70 <= b <= 200 and (r - g) >= 35 and b >= g - 5:
		return True
	if r >= 200 and 80 <= g <= 170 and 120 <= b <= 220 and (r - g) >= 40:
		return True
	return False


def scrub_pink(rgba: bytes, floor: bytes) -> bytes:
	buf = bytearray(rgba)
	for i in range(0, len(buf), 4):
		if is_pink(buf[i], buf[i + 1], buf[i + 2], buf[i + 3]):
			buf[i : i + 4] = floor[i : i + 4]
		buf[i + 3] = 255
	return bytes(buf)


def load_gen(name: str) -> bytes:
	path = SRC / f"{name}.jpg"
	if not path.exists():
		path = SRC / f"{name}.png"
	if not path.exists():
		raise FileNotFoundError(name)
	tmp = Path(tempfile.gettempdir()) / f"cnr_{name}_rgba.bin"
	ps = f"""
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile('{(path.as_posix())}')
$bmp = New-Object System.Drawing.Bitmap {TILE}, {TILE}
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($img, 0, 0, {TILE}, {TILE})
$g.Dispose(); $img.Dispose()
$bytes = New-Object byte[] ({TILE}*{TILE}*4)
$i = 0
for ($y=0; $y -lt {TILE}; $y++) {{
  for ($x=0; $x -lt {TILE}; $x++) {{
    $c = $bmp.GetPixel($x,$y)
    $bytes[$i]=$c.R; $bytes[$i+1]=$c.G; $bytes[$i+2]=$c.B; $bytes[$i+3]=255
    $i += 4
  }}
}}
$bmp.Dispose()
[IO.File]::WriteAllBytes('{(tmp.as_posix())}', $bytes)
"""
	subprocess.check_call(["powershell", "-NoProfile", "-Command", ps])
	return tmp.read_bytes()


def rot90(rgba: bytes) -> bytes:
	out = bytearray(TILE * TILE * 4)
	for y in range(TILE):
		for x in range(TILE):
			nx, ny = TILE - 1 - y, x
			si = (y * TILE + x) * 4
			di = (ny * TILE + nx) * 4
			out[di : di + 4] = rgba[si : si + 4]
	return bytes(out)


def flip_h(rgba: bytes) -> bytes:
	out = bytearray(len(rgba))
	for y in range(TILE):
		for x in range(TILE):
			si = (y * TILE + x) * 4
			di = (y * TILE + (TILE - 1 - x)) * 4
			out[di : di + 4] = rgba[si : si + 4]
	return bytes(out)


def flip_v(rgba: bytes) -> bytes:
	out = bytearray(len(rgba))
	for y in range(TILE):
		for x in range(TILE):
			si = (y * TILE + x) * 4
			di = ((TILE - 1 - y) * TILE + x) * 4
			out[di : di + 4] = rgba[si : si + 4]
	return bytes(out)


def save(name: str, rgba: bytes) -> None:
	write_png(OUT / f"{name}.png", TILE, TILE, rgba)


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)

	floor_raw = load_gen("gen_space_floor")
	# provisional scrub target = raw floor
	floor = scrub_pink(floor_raw, floor_raw)
	# scrub again against itself after forcing opaque
	floor = scrub_pink(floor, floor)
	save("floor", floor)

	void = scrub_pink(load_gen("gen_space_void"), floor)
	save("void", void)

	border_s = scrub_pink(load_gen("gen_space_border_s"), floor)
	border_w = rot90(border_s)
	border_n = rot90(border_w)
	border_e = rot90(border_n)
	save("border_s", border_s)
	save("border_w", border_w)
	save("border_n", border_n)
	save("border_e", border_e)

	se_both = scrub_pink(load_gen("gen_space_border_se_both"), floor)
	se_pri = scrub_pink(load_gen("gen_space_border_se_fog_s"), floor)
	se_sec = scrub_pink(load_gen("gen_space_border_se_fog_e"), floor)

	# SE -> SW -> NW -> NE via CW rot90
	sw_both, nw_both, ne_both = rot90(se_both), rot90(rot90(se_both)), rot90(rot90(rot90(se_both)))
	sw_pri, nw_pri, ne_pri = rot90(se_pri), rot90(rot90(se_pri)), rot90(rot90(rot90(se_pri)))
	sw_sec, nw_sec, ne_sec = rot90(se_sec), rot90(rot90(se_sec)), rot90(rot90(rot90(se_sec)))

	save("border_l_se", se_both)
	save("border_l_sw", sw_both)
	save("border_l_nw", nw_both)
	save("border_l_ne", ne_both)
	save("border_l_se_fog_primary", se_pri)
	save("border_l_se_fog_secondary", se_sec)
	save("border_l_sw_fog_primary", sw_pri)
	save("border_l_sw_fog_secondary", sw_sec)
	save("border_l_nw_fog_primary", nw_pri)
	save("border_l_nw_fog_secondary", nw_sec)
	save("border_l_ne_fog_primary", ne_pri)
	save("border_l_ne_fog_secondary", ne_sec)

	s_mid = scrub_pink(load_gen("gen_space_plateau_s_mid"), floor)
	s_edge = scrub_pink(load_gen("gen_space_plateau_s_edge"), floor)
	e_mid = scrub_pink(load_gen("gen_space_plateau_e_mid"), floor)
	e_edge = scrub_pink(load_gen("gen_space_plateau_e_edge"), floor)
	save("plateau_s_mid", s_mid)
	save("plateau_s_edge", s_edge)
	save("plateau_n_mid", flip_v(s_mid))
	save("plateau_n_edge", flip_v(s_edge))
	save("plateau_e_mid", e_mid)
	save("plateau_e_edge", e_edge)
	save("plateau_w_mid", flip_h(e_mid))
	save("plateau_w_edge", flip_h(e_edge))

	se_mid = scrub_pink(load_gen("gen_space_plateau_se_mid"), floor)
	se_edge = scrub_pink(load_gen("gen_space_plateau_se_edge"), floor)
	sw_mid = rot90(se_mid)
	nw_mid = rot90(sw_mid)
	ne_mid = rot90(nw_mid)
	sw_edge = rot90(se_edge)
	nw_edge = rot90(sw_edge)
	ne_edge = rot90(nw_edge)
	save("plateau_l_se_mid", se_mid)
	save("plateau_l_se_edge", se_edge)
	save("plateau_l_sw_mid", sw_mid)
	save("plateau_l_sw_edge", sw_edge)
	save("plateau_l_nw_mid", nw_mid)
	save("plateau_l_nw_edge", nw_edge)
	save("plateau_l_ne_mid", ne_mid)
	save("plateau_l_ne_edge", ne_edge)

	# Atlas
	rows = (len(NAMES) + ATLAS_COLS - 1) // ATLAS_COLS
	atlas_w, atlas_h = ATLAS_COLS * TILE, rows * TILE
	atlas = bytearray(atlas_w * atlas_h * 4)
	for y in range(atlas_h):
		for x in range(atlas_w):
			si = ((y % TILE) * TILE + (x % TILE)) * 4
			di = (y * atlas_w + x) * 4
			atlas[di : di + 4] = floor[si : si + 4]

	for i, name in enumerate(NAMES):
		ax, ay = i % ATLAS_COLS, i // ATLAS_COLS
		tile = read_png(OUT / f"{name}.png")
		for y in range(TILE):
			for x in range(TILE):
				si = (y * TILE + x) * 4
				di = ((ay * TILE + y) * atlas_w + ax * TILE + x) * 4
				atlas[di : di + 4] = tile[si : si + 4]
		print(f"{ax},{ay} {name}")

	write_png(OUT / "atlas.png", atlas_w, atlas_h, bytes(atlas))

	lines = [
		'[gd_resource type="TileSet" load_steps=2 format=3 uid="uid://cspacemaptiles01"]',
		"",
		'[ext_resource type="Texture2D" path="res://assets/sprites/maps/tiles/space/atlas.png" id="1_atlas"]',
		"",
		'[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_space"]',
		'texture = ExtResource("1_atlas")',
		"texture_region_size = Vector2i(128, 128)",
	]
	for i, name in enumerate(NAMES):
		ax, ay = i % ATLAS_COLS, i // ATLAS_COLS
		lines.append(f"{ax}:{ay}/0 = 0")
		if name == "void":
			lines.append(
				f"{ax}:{ay}/0/physics_layer_0/polygon_0/points = PackedVector2Array(-64, -64, 64, -64, 64, 64, -64, 64)"
			)
	lines += [
		"",
		"[resource]",
		"tile_size = Vector2i(128, 128)",
		"physics_layer_0/collision_layer = 2",
		'sources/0 = SubResource("TileSetAtlasSource_space")',
		"",
	]
	(OUT / "tileset.tres").write_text("\n".join(lines), encoding="utf-8")

	legend = ["# space tile legend (atlas col,row)", ""]
	for i, name in enumerate(NAMES):
		ax, ay = i % ATLAS_COLS, i // ATLAS_COLS
		legend.append(f"{ax},{ay}\t{name}")
	(OUT / "TILE_LEGEND.txt").write_text("\n".join(legend) + "\n", encoding="utf-8")
	print(f"space tileset: {len(NAMES)} tiles, atlas {atlas_w}x{atlas_h}")


if __name__ == "__main__":
	main()
