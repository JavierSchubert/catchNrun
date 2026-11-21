#!/usr/bin/env python3
"""Extract central symbols from framed stat icons (remove gold border + plate)."""

from __future__ import annotations

import collections
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "sprites" / "stats"
OUT = SRC / "clean"
TARGET_SIZE = 512

# Panel icons we currently use (plus originals they map from).
FILES = [
	"health.png",
	"damage.png",
	"hp_regen.png",
	"attack_speed.png",
	"block_chance.png",
	"lifesteal_chance.png",
	"movement_speed.png",
	"crit_chance.png",
]


def _is_near_black(r: int, g: int, b: int) -> bool:
	return r < 28 and g < 28 and b < 28


def _is_gold_border(r: int, g: int, b: int) -> bool:
	# Thick yellow/gold beveled frame shared by these icons.
	return r > 140 and g > 90 and b < 120 and (r + g) > (b * 3) and (r - b) > 40


def _color_dist(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
	return abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])


def _sample_plate_color(px, w: int, h: int) -> tuple[int, int, int]:
	"""Sample dark plate color from points just inside the gold frame."""
	votes: list[tuple[int, int, int]] = []
	# Scan inward from center of each edge until past black+gold into plate.
	rays = [
		(w // 2, 0, 0, 1),
		(w // 2, h - 1, 0, -1),
		(0, h // 2, 1, 0),
		(w - 1, h // 2, -1, 0),
	]
	for x0, y0, dx, dy in rays:
		x, y = x0, y0
		seen_gold = False
		for _ in range(max(w, h)):
			r, g, b, a = px[x, y]
			if a < 10 or _is_near_black(r, g, b):
				x += dx
				y += dy
				continue
			if _is_gold_border(r, g, b):
				seen_gold = True
				x += dx
				y += dy
				continue
			if seen_gold:
				# Collect a short run of plate pixels.
				for _i in range(8):
					rr, gg, bb, aa = px[x, y]
					if aa >= 10 and not _is_gold_border(rr, gg, bb) and not _is_near_black(rr, gg, bb):
						votes.append((rr, gg, bb))
					x += dx
					y += dy
					if not (0 <= x < w and 0 <= y < h):
						break
				break
			x += dx
			y += dy
			if not (0 <= x < w and 0 <= y < h):
				break
	if not votes:
		# Fallback: most common dark-ish non-gold color.
		counts: collections.Counter[tuple[int, int, int]] = collections.Counter()
		for y in range(h):
			for x in range(w):
				r, g, b, a = px[x, y]
				if a < 10 or _is_near_black(r, g, b) or _is_gold_border(r, g, b):
					continue
				if max(r, g, b) < 120:
					counts[((r // 8) * 8, (g // 8) * 8, (b // 8) * 8)] += 1
		if counts:
			return counts.most_common(1)[0][0]
		return (60, 40, 50)
	# Median-ish: average of samples.
	n = len(votes)
	return (
		sum(c[0] for c in votes) // n,
		sum(c[1] for c in votes) // n,
		sum(c[2] for c in votes) // n,
	)


def extract(path: Path) -> Image.Image:
	src = Image.open(path).convert("RGBA")
	w, h = src.size
	px = src.load()
	plate = _sample_plate_color(px, w, h)
	# Plate threshold: generous so soft edges of the square disappear.
	plate_tol = 55

	out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	opx = out.load()
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if a < 10 or _is_near_black(r, g, b) or _is_gold_border(r, g, b):
				continue
			if _color_dist((r, g, b), plate) <= plate_tol:
				continue
			# Also drop near-plate muted fills that are clearly background (low saturation + dark).
			mx, mn = max(r, g, b), min(r, g, b)
			if mx < 95 and (mx - mn) < 35 and _color_dist((r, g, b), plate) <= plate_tol + 25:
				continue
			opx[x, y] = (r, g, b, a)

	bbox = out.getbbox()
	if bbox is None:
		raise RuntimeError(f"No foreground found in {path.name}")
	cropped = out.crop(bbox)

	# Pad to square with transparent margin, then upscale.
	cw, ch = cropped.size
	side = max(cw, ch)
	pad = max(8, side // 16)
	side_p = side + pad * 2
	square = Image.new("RGBA", (side_p, side_p), (0, 0, 0, 0))
	square.paste(cropped, ((side_p - cw) // 2, (side_p - ch) // 2), cropped)
	return square.resize((TARGET_SIZE, TARGET_SIZE), Image.Resampling.LANCZOS)


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	for name in FILES:
		src = SRC / name
		if not src.exists():
			print(f"skip missing {name}")
			continue
		result = extract(src)
		dest = OUT / name
		result.save(dest)
		print(f"wrote {dest.relative_to(ROOT)} ({result.size[0]}x{result.size[1]}) plate-extracted")


if __name__ == "__main__":
	main()
