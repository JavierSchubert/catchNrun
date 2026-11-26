"""Offline WP-14 checks — XP curve + portrait chrome wiring (no Godot).

Run:  python -m pytest tools/test/test_wp14_xp.py -q
  or: python tools/test/test_wp14_xp.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_xp_progress_curve_grows() -> None:
    src = _read("src/progression/xp_progress.gd")
    assert "class_name XpProgress" in src
    assert "BASE_XP" in src
    assert "GROWTH" in src
    assert "func xp_to_next" in src
    assert "func fill_ratio" in src
    assert "func apply_gain" in src


def test_unit_grants_xp_on_hunter_melee() -> None:
    unit = _read("src/units/unit/unit.gd")
    assert "var level := 1" in unit
    assert "var xp := 0.0" in unit
    assert "func grant_xp" in unit
    assert "func xp_fill_ratio" in unit
    assert unit.count("grant_xp(applied)") >= 2
    sync = _read("src/units/unit/unit.tscn")
    assert 'NodePath(".:level")' in sync
    assert 'NodePath(".:xp")' in sync


def test_portrait_xp_ring_draws_ccw_violet() -> None:
    ring = _read("ui/hud/selection_panel/portrait_xp_ring.gd")
    assert "class_name PortraitXpRing" in ring
    assert "-PI / 2.0" in ring or "-PI/2" in ring
    assert "VIOLET" in ring
    assert "BAND" in ring
    assert "draw_arc" in ring
    assert "counterclockwise" in ring.lower()


def test_selection_panel_binds_level_badge() -> None:
    panel = _read("ui/hud/selection_panel/selection_panel.gd")
    assert "PortraitXpRing" in panel
    assert "LevelBadge" in panel
    assert "_set_xp_chrome" in panel
    assert "xp_fill_ratio" in panel
    tscn = _read("ui/hud/selection_panel/selection_panel.tscn")
    assert "Vector2(96, 96)" in tscn


def test_sandbox_xp_button() -> None:
    sandbox = _read("game/sandbox/sandbox_panel.gd")
    assert "XP +50" in sandbox
    assert "_sandbox_add_xp" in sandbox


def test_docs_mention_xp_ring() -> None:
    docs = _read("docs/selection_panel.README.md")
    assert "violet" in docs.lower()
    assert "counterclockwise" in docs.lower() or "CCW" in docs
    stats = _read("docs/stats.README.md")
    assert "XpProgress" in stats


def main() -> int:
    tests = [
        test_xp_progress_curve_grows,
        test_unit_grants_xp_on_hunter_melee,
        test_portrait_xp_ring_draws_ccw_violet,
        test_selection_panel_binds_level_badge,
        test_sandbox_xp_button,
        test_docs_mention_xp_ring,
    ]
    failed = 0
    for test in tests:
        try:
            test()
            print(f"PASS {test.__name__}")
        except AssertionError as exc:
            failed += 1
            print(f"FAIL {test.__name__}: {exc}")
    if failed:
        print(f"{failed} failed")
        return 1
    print(f"All {len(tests)} passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
