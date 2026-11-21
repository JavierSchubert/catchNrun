#!/usr/bin/env python3
"""Convert generated jpg/png stat icons to transparent PNGs under assets/sprites/stats/clean."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "sprites" / "stats" / "clean"
TARGET = 512

# Cursor image tool writes into the project assets mirror under .cursor/projects/...
CANDIDATE_DIRS = [
	Path(r"C:\Users\GQCTY\.cursor\projects\c-Users-GQCTY-OneDrive-Bayer-Desktop-master-experimental-catchNrun\assets"),
	ROOT / "assets",
]

NAMES = [
	"health",
	"damage",
	"hp_regen",
	"attack_speed",
	"block_chance",
	"lifesteal_chance",
	"movement_speed",
	"crit_chance",
]


def find_source(stem: str) -> Path | None:
	for folder in CANDIDATE_DIRS:
		for ext in (".png", ".jpg", ".jpeg", ".webp"):
			path = folder / f"{stem}{ext}"
			if path.exists():
				return path
	return None


def whiten_to_alpha(im: Image.Image, threshold: int = 245, soft: int = 25) -> Image.Image:
	"""Make near-white background transparent with a soft edge."""
	rgba = im.convert("RGBA")
	pixels = rgba.load()
	w, h = rgba.size
	for y in range(h):
		for x in range(w):
			r, g, b, a = pixels[x, y]
			brightness = (r + g + b) / 3.0
			# Near-white and low-saturation -> background.
			sat = max(r, g, b) - min(r, g, b)
			if brightness >= threshold and sat < 18:
				pixels[x, y] = (r, g, b, 0)
			elif brightness >= threshold - soft and sat < 30:
				fade = int(a * (threshold - brightness) / soft)
				pixels[x, y] = (r, g, b, max(0, min(a, fade)))
	return rgba


def finalize(im: Image.Image) -> Image.Image:
	bbox = im.getbbox()
	if bbox is None:
		raise RuntimeError("empty image after chroma key")
	cropped = im.crop(bbox)
	cw, ch = cropped.size
	side = max(cw, ch)
	pad = max(8, side // 20)
	side_p = side + pad * 2
	square = Image.new("RGBA", (side_p, side_p), (0, 0, 0, 0))
	square.paste(cropped, ((side_p - cw) // 2, (side_p - ch) // 2), cropped)
	return square.resize((TARGET, TARGET), Image.Resampling.LANCZOS)


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	for stem in NAMES:
		src = find_source(stem)
		if src is None:
			print(f"missing {stem}")
			continue
		raw = Image.open(src)
		cleaned = finalize(whiten_to_alpha(raw))
		dest = OUT / f"{stem}.png"
		cleaned.save(dest)
		print(f"{src.name} -> {dest.relative_to(ROOT)} ({cleaned.size[0]}x{cleaned.size[1]})")


if __name__ == "__main__":
	main()
