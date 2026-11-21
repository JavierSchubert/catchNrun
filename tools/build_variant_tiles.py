#!/usr/bin/env python3
"""
Build plateau mid/edge + L variants and floor border L lava variants into v3 tileset.
Existing atlas tile order is preserved; new tiles are appended.
"""

from __future__ import annotations

import struct
import subprocess
import tempfile
import time
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V3 = ROOT / "assets" / "sprites" / "maps" / "tiles" / "v3"
SRC = Path(
	r"C:\Users\GQCTY\.cursor\projects\c-Users-GQCTY-OneDrive-Bayer-Desktop-master-experimental-catchNrun\assets"
)
TILE = 128
ATLAS_COLS = 8

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
	"prop_rocks",
	"tile_lava_vein_mid",
	"tile_lava_vein_end",
	"tile_lava_vein_source",
	"tile_border_rock",
	"tile_ground_center",
	"tile_ground_high",
]

# gen filename -> output tile name
GEN_MAP = {
	"gen_plateau_n_mid": "plateau_n_mid",
	"gen_plateau_n_edge": "plateau_n_edge",
	"gen_plateau_s_mid": "plateau_s_mid",
	"gen_plateau_s_edge": "plateau_s_edge",
	"gen_plateau_e_mid": "plateau_e_mid",
	"gen_plateau_e_edge": "plateau_e_edge",
	"gen_plateau_w_mid": "plateau_w_mid",
	"gen_plateau_w_edge": "plateau_w_edge",
	"gen_plateau_nw_mid": "plateau_l_nw_mid",
	"gen_plateau_nw_edge": "plateau_l_nw_edge",
	"gen_plateau_ne_mid": "plateau_l_ne_mid",
	"gen_plateau_ne_edge": "plateau_l_ne_edge",
	"gen_plateau_sw_mid": "plateau_l_sw_mid",
	"gen_plateau_sw_edge": "plateau_l_sw_edge",
	"gen_plateau_se_mid": "plateau_l_se_mid",
	"gen_plateau_se_edge": "plateau_l_se_edge",
	"gen_border_nw_lava_both": "border_l_nw_lava_both",
	"gen_border_nw_lava_north": "border_l_nw_lava_primary",
	"gen_border_nw_lava_west": "border_l_nw_lava_secondary",
	"gen_border_ne_lava_both": "border_l_ne_lava_both",
	"gen_border_ne_lava_north": "border_l_ne_lava_primary",
	"gen_border_ne_lava_east": "border_l_ne_lava_secondary",
	"gen_border_sw_lava_both": "border_l_sw_lava_both",
	"gen_border_sw_lava_south": "border_l_sw_lava_primary",
	"gen_border_sw_lava_west": "border_l_sw_lava_secondary",
	"gen_border_se_lava_both": "border_l_se_lava_both",
	"gen_border_se_lava_south": "border_l_se_lava_primary",
	"gen_border_se_lava_east": "border_l_se_lava_secondary",
}

NEW_NAMES = [
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
	"border_l_nw_lava_both",
	"border_l_nw_lava_primary",
	"border_l_nw_lava_secondary",
	"border_l_ne_lava_both",
	"border_l_ne_lava_primary",
	"border_l_ne_lava_secondary",
	"border_l_sw_lava_both",
	"border_l_sw_lava_primary",
	"border_l_sw_lava_secondary",
	"border_l_se_lava_both",
	"border_l_se_lava_primary",
	"border_l_se_lava_secondary",
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
	if r >= 160 and b >= 100 and g <= 165 and (r - g) >= 20 and b >= int(g * 0.85):
		return True
	if r >= 200 and 80 <= g <= 170 and 120 <= b <= 220 and (r - g) >= 40:
		return True
	if r >= 200 and b >= 170 and g >= 140 and (r + b) > (2 * g + 40) and b > 100:
		return True
	return False


def scrub_pink(rgba: bytes, floor: bytes) -> bytes:
	buf = bytearray(rgba)
	for i in range(0, len(buf), 4):
		if is_pink(buf[i], buf[i + 1], buf[i + 2], buf[i + 3]):
			buf[i : i + 4] = floor[i : i + 4]
		buf[i + 3] = 255
	return bytes(buf)


def load_gen(name: str, floor: bytes) -> bytes:
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
	return scrub_pink(tmp.read_bytes(), floor)


def main() -> None:
	floor = read_png(V3 / "floor.png")

	for gen_name, out_name in GEN_MAP.items():
		rgba = load_gen(gen_name, floor)
		write_png(V3 / f"{out_name}.png", TILE, TILE, rgba)
		print(f"wrote {out_name}")

	all_names = [n for n in BASE_NAMES if (V3 / f"{n}.png").exists()] + NEW_NAMES
	rows = (len(all_names) + ATLAS_COLS - 1) // ATLAS_COLS
	atlas_w, atlas_h = ATLAS_COLS * TILE, rows * TILE
	atlas = bytearray(atlas_w * atlas_h * 4)
	for y in range(atlas_h):
		for x in range(atlas_w):
			si = ((y % TILE) * TILE + (x % TILE)) * 4
			di = (y * atlas_w + x) * 4
			atlas[di : di + 4] = floor[si : si + 4]

	for i, name in enumerate(all_names):
		ax, ay = i % ATLAS_COLS, i // ATLAS_COLS
		tile = read_png(V3 / f"{name}.png")
		for y in range(TILE):
			for x in range(TILE):
				si = (y * TILE + x) * 4
				di = ((ay * TILE + y) * atlas_w + ax * TILE + x) * 4
				atlas[di : di + 4] = tile[si : si + 4]
		print(f"{ax},{ay} {name}")

	write_png(V3 / "atlas.png", atlas_w, atlas_h, bytes(atlas))

	atlas_uid = "uid://b2vashtogah3q"
	imp = V3 / "atlas.png.import"
	if imp.exists():
		for line in imp.read_text(encoding="utf-8").splitlines():
			if line.startswith("uid="):
				atlas_uid = line.split("=", 1)[1].strip().strip('"')
				break

	lines = [
		'[gd_resource type="TileSet" load_steps=2 format=3 uid="uid://cv3plateautileset"]',
		"",
		f'[ext_resource type="Texture2D" uid="{atlas_uid}" path="res://assets/sprites/maps/tiles/v3/atlas.png" id="1_atlas"]',
		"",
		'[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_main"]',
		'texture = ExtResource("1_atlas")',
		"texture_region_size = Vector2i(128, 128)",
	]
	for i, _n in enumerate(all_names):
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

	legend = ["# v3 tile legend (atlas col,row)", ""]
	for i, name in enumerate(all_names):
		ax, ay = i % ATLAS_COLS, i // ATLAS_COLS
		legend.append(f"{ax},{ay}\t{name}")
	(V3 / "TILE_LEGEND.txt").write_text("\n".join(legend) + "\n", encoding="utf-8")
	print(f"tileset updated: {len(all_names)} tiles, atlas {atlas_w}x{atlas_h}")


if __name__ == "__main__":
	main()
