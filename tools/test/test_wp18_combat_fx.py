"""Offline WP-18 / WP-09 checks — no Godot required.

Run:  python tools/test/test_wp18_combat_fx.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_structure_melee_helper_exists() -> None:
    text = _read("src/combat/structure_melee.gd")
    assert "class_name StructureMelee" in text
    assert "func approach_point" in text
    assert "func in_range" in text
    assert "func reach" in text


def test_attack_controller_uses_structure_melee() -> None:
    text = _read("src/combat/attack_controller.gd")
    assert "StructureMelee.in_range" in text
    assert "target is Building" in text


def test_hunter_building_click_and_approach() -> None:
    text = _read("src/units/unit/unit.gd")
    assert "hit_radius = maxf(hit_radius, 56.0)" in text
    assert "StructureMelee.approach_point" in text
    assert "_nearest_hunter_target" in text
    assert "_combat_approach_point" in text
    assert "flash_attack_target_circle" in _read("src/buildings/building.gd")


def test_floating_number_api() -> None:
    text = _read("src/fx/floating_number.gd")
    assert "class_name FloatingNumber" in text
    assert "enum Kind" in text
    assert "DAMAGE" in text and "CRIT" in text
    assert "LIFESTEAL" in text and "REGEN" in text
    assert "static func spawn" in text
    assert "static func spawn_replicated" in text
    assert "static func receive_rpc" in text
    assert "RISE_PX" in text
    assert "COLOR_DAMAGE" in text
    assert "COLOR_CRIT" in text
    assert "COLOR_HEAL" in text


def test_floating_number_wired() -> None:
    unit = _read("src/units/unit/unit.gd")
    assert "FloatingNumber.Kind.DAMAGE" in unit
    assert "FloatingNumber.Kind.CRIT" in unit
    assert "FloatingNumber.Kind.LIFESTEAL" in unit
    assert "FloatingNumber.Kind.REGEN" in unit
    assert "_spawn_floating_number_on" in unit
    assert "FloatingNumber.spawn_replicated" in unit
    building = _read("src/buildings/building.gd")
    assert "_spawn_floating_number_on" in building
    assert "FloatingNumber.spawn_replicated" in building
    fx = _read("src/fx/floating_number.gd")
    assert "static func spawn_replicated" in fx
    assert "static func receive_rpc" in fx


def test_docs_mention_wp09_or_cp18() -> None:
    wp = _read("tasks/working_packages.README.md")
    cp = _read("tasks/checkpoints.README.md")
    assert "FloatingNumber" in wp or "floating" in wp.lower()
    assert "CP-18" in cp or "WP-09" in cp


def main() -> int:
    tests = [v for k, v in globals().items() if k.startswith("test_") and callable(v)]
    failed = 0
    for fn in tests:
        try:
            fn()
            print(f"PASS: {fn.__name__}")
        except Exception as exc:  # noqa: BLE001
            failed += 1
            print(f"FAIL: {fn.__name__}: {exc}")
    if failed:
        print(f"{failed} failed")
        return 1
    print(f"PASS: all {len(tests)} WP-18 offline checks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
