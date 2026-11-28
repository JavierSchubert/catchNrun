"""Offline checks — Match HUD chrome layout avoids panel overlap (no Godot)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_hud_has_runtime_layout() -> None:
    hud = _read("game/match/hud.gd")
    assert "func _layout_chrome" in hud
    assert "SELECTION_SIZE" in hud
    assert "SEEK_SIZE" in hud
    assert "BUILDING_SIZE" in hud
    assert "UPGRADE_SIZE" in hud
    assert "notify_hud_layout" in hud
    ## Upgrade sits above the selection band.
    assert "SELECTION_SIZE.y + GAP" in hud or "SELECTION_SIZE.y + GAP" in hud.replace(" ", "")


def test_building_panel_keeps_minimize_after_layout() -> None:
    panel = _read("ui/hud/building_panel/building_panel.gd")
    assert "func notify_hud_layout" in panel
    assert "func _apply_minimize_layout" in panel


def test_upgrade_default_above_selection_band() -> None:
    tscn = _read("game/match/hud.tscn")
    assert "offset_bottom = -228.0" in tscn
    assert "offset_top = -478.0" in tscn


def test_layout_math_no_overlaps() -> None:
    margin = 16.0
    gap = 12.0
    minimap_w, minimap_h = 220.0, 146.0
    seek_w, seek_h = 136.0, 150.0
    sel_max_w, sel_h = 520.0, 200.0
    build_w, build_h = 420.0, 600.0
    up_w, up_h = 430.0, 250.0

    def layout(width: float, height: float, runner: bool, hunter: bool) -> dict[str, tuple[float, float, float, float]]:
        bottom = height - margin
        left_bound = margin + minimap_w + gap
        right_bound = width - margin
        if runner:
            right_bound -= build_w + gap
        middle = max(right_bound - left_bound, 0.0)
        seek_slot = seek_w + gap if hunter else 0.0
        sel_w = max(0.0, min(sel_max_w, middle - seek_slot))
        cluster = sel_w + seek_slot
        cluster_left = left_bound + max((middle - cluster) * 0.5, 0.0)
        rects = {
            "Minimap": (margin, bottom - minimap_h, margin + minimap_w, bottom),
            "Selection": (cluster_left, bottom - sel_h, cluster_left + sel_w, bottom),
        }
        if hunter:
            seek_left = cluster_left + sel_w + gap
            rects["Seek"] = (seek_left, bottom - seek_h, seek_left + seek_w, bottom)
            upgrade_bottom = bottom - sel_h - gap
            rects["Upgrade"] = (
                width - margin - up_w,
                upgrade_bottom - up_h,
                width - margin,
                upgrade_bottom,
            )
        if runner:
            rects["Building"] = (
                width - margin - build_w,
                bottom - build_h,
                width - margin,
                bottom,
            )
        return rects

    def overlaps(a: tuple[float, float, float, float], b: tuple[float, float, float, float]) -> bool:
        return not (a[2] <= b[0] or b[2] <= a[0] or a[3] <= b[1] or b[3] <= a[1])

    for width, height in ((1920, 1080), (1600, 900), (1366, 768), (1280, 720), (1024, 768)):
        for runner, hunter in ((False, True), (True, False)):
            rects = layout(width, height, runner, hunter)
            names = list(rects)
            for i, left_name in enumerate(names):
                for right_name in names[i + 1 :]:
                    assert not overlaps(rects[left_name], rects[right_name]), (
                        f"{width}x{height} {left_name} overlaps {right_name}"
                    )


def main() -> int:
    tests = [v for k, v in globals().items() if k.startswith("test_") and callable(v)]
    failed = 0
    for test in tests:
        try:
            test()
            print(f"PASS  {test.__name__}")
        except AssertionError as exc:
            failed += 1
            print(f"FAIL  {test.__name__}: {exc}")
        except Exception as exc:  # noqa: BLE001
            failed += 1
            print(f"ERROR {test.__name__}: {exc}")
    print(f"\n{len(tests) - failed}/{len(tests)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
