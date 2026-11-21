#!/usr/bin/env python3
"""
Build tiles/v3: opaque tiles sharing ONE floor texture.
- Borders/corners: floor fill + rock/lava on outer half (midline alignment)
- Plateau edges: floor + plateau cliff on midline
- Ramps: floor under + ramp art
v2 is left untouched.
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V2 = ROOT / "assets" / "sprites" / "maps" / "tiles" / "v2"
OUT = ROOT / "assets" / "sprites" / "maps" / "tiles" / "v3"
TILE = 128
MID = TILE // 2
ATLAS_COLS = 8


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
	path.write_bytes(
		b"\x89PNG\r\n\x1a\n"
		+ chunk(b"IHDR", ihdr)
		+ chunk(b"IDAT", zlib.compress(bytes(raw), 9))
		+ chunk(b"IEND", b"")
	)


def read_png(path: Path) -> bytes:
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
	assert width == TILE and height == TILE
	raw = zlib.decompress(bytes(idat))
	out = bytearray()
	stride = TILE * 4
	i = 0
	for _ in range(TILE):
		assert raw[i] == 0
		i += 1
		out.extend(raw[i : i + stride])
		i += stride
	return bytes(out)


def force_opaque(rgba: bytes) -> bytes:
	buf = bytearray(rgba)
	for i in range(3, len(buf), 4):
		if buf[i] < 255:
			# treat residual pink/transparent as needing floor later; keep alpha for overlays
			pass
	return bytes(buf)


def is_pink_or_clear(r: int, g: int, b: int, a: int) -> bool:
	if a < 16:
		return True
	if r > 170 and g < 90 and b > 70 and (r - g) > 80:
		return True
	if r > 160 and b > 160 and g < 140:
		return True
	return False


def copy_rgba(src: bytes) -> bytearray:
	return bytearray(src)


def blit_over(dst: bytearray, src: bytes, allow) -> None:
	"""Alpha-over src onto dst where allow(x,y) and src is not pink/clear."""
	for y in range(TILE):
		for x in range(TILE):
			if not allow(x, y):
				continue
			i = (y * TILE + x) * 4
			r, g, b, a = src[i], src[i + 1], src[i + 2], src[i + 3]
			if is_pink_or_clear(r, g, b, a):
				continue
			# over
			alpha = a / 255.0
			dst[i] = int(r * alpha + dst[i] * (1 - alpha))
			dst[i + 1] = int(g * alpha + dst[i + 1] * (1 - alpha))
			dst[i + 2] = int(b * alpha + dst[i + 2] * (1 - alpha))
			dst[i + 3] = 255


def make_opaque_floor_base(floor: bytes) -> bytearray:
	out = copy_rgba(floor)
	for i in range(3, len(out), 4):
		out[i] = 255
	return out


def border_bottom(floor: bytes, rocks: bytes) -> bytes:
	out = make_opaque_floor_base(floor)
	# Rocks/lava only in bottom half; floor occupies top half cleanly to midline.
	blit_over(out, rocks, lambda x, y: y >= MID)
	# Ensure full opacity
	for i in range(3, len(out), 4):
		out[i] = 255
	return bytes(out)


def border_top(floor: bytes, rocks: bytes) -> bytes:
	out = make_opaque_floor_base(floor)
	blit_over(out, rocks, lambda x, y: y < MID)
	for i in range(3, len(out), 4):
		out[i] = 255
	return bytes(out)


def border_left(floor: bytes, rocks: bytes) -> bytes:
	out = make_opaque_floor_base(floor)
	blit_over(out, rocks, lambda x, y: x < MID)
	for i in range(3, len(out), 4):
		out[i] = 255
	return bytes(out)


def border_right(floor: bytes, rocks: bytes) -> bytes:
	out = make_opaque_floor_base(floor)
	blit_over(out, rocks, lambda x, y: x >= MID)
	for i in range(3, len(out), 4):
		out[i] = 255
	return bytes(out)


def border_corner(floor: bytes, rocks: bytes, corner: str) -> bytes:
	"""
	Corner tiles: floor fills the inner quadrant; rocks occupy the outer L
	(outer halves of the two edges), meeting at the rectangle corner.
	"""
	out = make_opaque_floor_base(floor)

	def allow(x: int, y: int) -> bool:
		if corner == "se":
			return x >= MID or y >= MID
		if corner == "sw":
			return x < MID or y >= MID
		if corner == "ne":
			return x >= MID or y < MID
		if corner == "nw":
			return x < MID or y < MID
		return False

	blit_over(out, rocks, allow)
	for i in range(3, len(out), 4):
		out[i] = 255
	return bytes(out)


def rotate90(rgba: bytes) -> bytes:
	out = bytearray(TILE * TILE * 4)
	for y in range(TILE):
		for x in range(TILE):
			nx, ny = TILE - 1 - y, x  # CW
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


def plateau_edge(floor: bytes, edge_art: bytes, side: str) -> bytes:
	out = make_opaque_floor_base(floor)
	if side == "s":
		allow = lambda x, y: y >= MID - 8  # cliff band around midline+
	elif side == "n":
		allow = lambda x, y: y < MID + 8
	elif side == "e":
		allow = lambda x, y: x >= MID - 8
	else:
		allow = lambda x, y: x < MID + 8
	blit_over(out, edge_art, allow)
	for i in range(3, len(out), 4):
		out[i] = 255
	return bytes(out)


def plateau_corner(floor: bytes, art: bytes, corner: str) -> bytes:
	out = make_opaque_floor_base(floor)
	# Keep outer L + a bit of floor lip from art
	def allow(x, y):
		if corner == "se":
			return x >= MID - 8 or y >= MID - 8
		if corner == "sw":
			return x < MID + 8 or y >= MID - 8
		if corner == "ne":
			return x >= MID - 8 or y < MID + 8
		return x < MID + 8 or y < MID + 8

	blit_over(out, art, allow)
	for i in range(3, len(out), 4):
		out[i] = 255
	return bytes(out)


def ramp_tile(floor: bytes, ramp: bytes) -> bytes:
	out = make_opaque_floor_base(floor)
	blit_over(out, ramp, lambda x, y: True)
	for i in range(3, len(out), 4):
		out[i] = 255
	return bytes(out)


def save(name: str, rgba: bytes) -> None:
	write_png(OUT / f"{name}.png", TILE, TILE, rgba)


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	floor = read_png(V2 / "floor_a.png")

	# Universal floor (only one)
	save("floor", make_opaque_floor_base(floor))

	# --- Map borders (opaque, midline) ---
	bba = read_png(V2 / "border_bottom_a.png")
	bbb = read_png(V2 / "border_bottom_b.png")
	br = read_png(V2 / "border_right.png")
	bl = read_png(V2 / "border_left.png")
	bt = read_png(V2 / "border_top.png")
	bse = read_png(V2 / "border_corner_se.png")

	save("border_bottom_a", border_bottom(floor, bba))
	save("border_bottom_b", border_bottom(floor, bbb))
	save("border_top", border_top(floor, bt))
	save("border_left", border_left(floor, bl))
	save("border_right", border_right(floor, br))

	# Build corners from SE master + rotations, always on floor
	se = border_corner(floor, bse, "se")
	save("border_corner_se", se)
	sw = border_corner(floor, rotate90(bse), "sw")
	# Prefer derived from SE rock art rotated then remasked
	save("border_corner_sw", border_corner(floor, rotate90(bse), "sw"))
	save("border_corner_nw", border_corner(floor, rotate90(rotate90(bse)), "nw"))
	save("border_corner_ne", border_corner(floor, rotate90(rotate90(rotate90(bse))), "ne"))

	# --- Plateau (same floor) ---
	ps = read_png(V2 / "plateau_s.png")
	pe = read_png(V2 / "plateau_e.png")
	pose = read_png(V2 / "plateau_outer_se.png")
	save("plateau_s", plateau_edge(floor, ps, "s"))
	save("plateau_n", plateau_edge(floor, flip_v(ps), "n"))
	save("plateau_e", plateau_edge(floor, pe, "e"))
	save("plateau_w", plateau_edge(floor, flip_h(pe), "w"))
	save("plateau_outer_se", plateau_corner(floor, pose, "se"))
	save("plateau_outer_sw", plateau_corner(floor, rotate90(pose), "sw"))
	save("plateau_outer_nw", plateau_corner(floor, rotate90(rotate90(pose)), "nw"))
	save("plateau_outer_ne", plateau_corner(floor, rotate90(rotate90(rotate90(pose))), "ne"))

	# --- Ramps ---
	rs = read_png(V2 / "ramp_s.png")
	save("ramp_s", ramp_tile(floor, rs))
	save("ramp_n", ramp_tile(floor, flip_v(rs)))
	save("ramp_w", ramp_tile(floor, rotate90(rs)))
	save("ramp_e", ramp_tile(floor, rotate90(rotate90(rotate90(rs)))))

	names = [
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

	# Atlas
	rows = (len(names) + ATLAS_COLS - 1) // ATLAS_COLS
	atlas_w, atlas_h = ATLAS_COLS * TILE, rows * TILE
	atlas = bytearray(atlas_w * atlas_h * 4)
	mapping = {}
	for i, name in enumerate(names):
		ax, ay = i % ATLAS_COLS, i // ATLAS_COLS
		mapping[name] = (ax, ay)
		tile = read_png(OUT / f"{name}.png")
		for y in range(TILE):
			for x in range(TILE):
				si = (y * TILE + x) * 4
				di = ((ay * TILE + y) * atlas_w + ax * TILE + x) * 4
				atlas[di : di + 4] = tile[si : si + 4]
	write_png(OUT / "atlas.png", atlas_w, atlas_h, bytes(atlas))

	# TileSet (no physics needed for painting; void borders optional)
	lines = [
		'[gd_resource type="TileSet" load_steps=2 format=3 uid="uid://cv3plateautileset"]',
		"",
		'[ext_resource type="Texture2D" uid="uid://cv3plateauatlas01" path="res://assets/sprites/maps/tiles/v3/atlas.png" id="1_atlas"]',
		"",
		'[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_v3"]',
		'texture = ExtResource("1_atlas")',
		"texture_region_size = Vector2i(128, 128)",
	]
	for name in names:
		ax, ay = mapping[name]
		lines.append(f"{ax}:{ay}/0 = 0")
	lines += [
		"",
		"[resource]",
		"tile_size = Vector2i(128, 128)",
		'sources/0 = SubResource("TileSetAtlasSource_v3")',
		"",
	]
	(OUT / "tileset.tres").write_text("\n".join(lines), encoding="utf-8")

	# Import stub
	(OUT / "atlas.png.import").write_text(
		"""[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://cv3plateauatlas01"
path="res://.godot/imported/atlas.png-cv3plateauatlas01.ctex"
metadata={
"vram_texture": false
}

[deps]

source_file="res://assets/sprites/maps/tiles/v3/atlas.png"
dest_files=["res://.godot/imported/atlas.png-cv3plateauatlas01.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_fix=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
""",
		encoding="utf-8",
	)

	print("v3 tiles:", len(names))
	print("tileset:", OUT / "tileset.tres")
	print("v2 untouched")
	_verify()


def _verify() -> None:
	for name in ["border_bottom_a", "border_right", "border_corner_se", "floor"]:
		rgba = read_png(OUT / f"{name}.png")
		trans = sum(1 for i in range(3, len(rgba), 4) if rgba[i] < 255)
		pink = 0
		for i in range(0, len(rgba), 4):
			r, g, b, a = rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]
			if a == 255 and r > 170 and g < 90 and b > 70:
				pink += 1
		# sample top-center of bottom border should be floor-brown not pink
		cx = (16 * TILE + 64) * 4 if False else (16 * TILE + 64) * 4
		# y=16, x=64
		i = (16 * TILE + 64) * 4
		sample = list(rgba[i : i + 4])
		print(f"  {name}: nonopaque={trans} pink={pink} sample_top={sample}")


if __name__ == "__main__":
	main()
