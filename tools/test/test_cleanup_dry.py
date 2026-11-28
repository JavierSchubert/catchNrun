"""Offline safe-cleanup checks — leftovers, SelectionQueries, process gating (no Godot)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_legacy_dirs_removed() -> None:
    for rel in (
        "addons",
        "components",
        "common",
        "data",
        "entities",
        "game/arena",
        "game/player",
        "tests/harness",
        "tests/multiplayer",
        "assets/sprites/maps/tiles/plateau",
        "assets/sprites/maps/tiles/space",
        "assets/sprites/maps/tiles/v4",
    ):
        assert not (ROOT / rel).exists(), f"legacy path still present: {rel}"


def test_dead_script_and_arena_removed() -> None:
    assert not (ROOT / "src/combat/item_weapon.gd").exists()
    assert not (ROOT / "game/maps/arena_plateau2.tscn").exists()
    assert (ROOT / "game/maps/arena_plateau.tscn").is_file()


def test_project_godot_cleaned() -> None:
    text = _read("project.godot")
    assert "res://common/" not in text
    assert "res://entities/" not in text
    assert "res://config/" not in text
    assert "res://objects/" not in text
    assert "[input]" not in text
    assert "\nleft=" not in text
    assert "\nattack=" not in text


def test_selection_queries_exists_and_wired() -> None:
    queries = _read("src/selection/selection_queries.gd")
    assert "class_name SelectionQueries" in queries
    assert "func manager" in queries
    assert "func selected_controllable" in queries
    assert "func unit_for_peer" in queries
    assert "func issue_move" in queries
    assert "func issue_attack_move" in queries
    minimap = _read("ui/hud/minimap/minimap.gd")
    assert "SelectionQueries.issue_move" in minimap
    assert "SelectionQueries.issue_attack_move" in minimap
    assert "_issue_move_to" not in minimap
    sel = _read("src/selection/selection_manager.gd")
    assert "SelectionQueries.issue_attack_move" in sel
    shop = _read("ui/hud/item_shop_panel/item_shop_panel.gd")
    assert "SelectionQueries.unit_for_peer" in shop
    hud = _read("game/match/hud.gd")
    assert "SelectionQueries.manager" in hud
    assert "SelectionQueries.unit_for_peer" in hud


def test_shop_process_gated() -> None:
    shop = _read("ui/hud/item_shop_panel/item_shop_panel.gd")
    assert "set_process(false)" in shop
    assert "set_process(true)" in shop
    assert "func open_shop" in shop
    open_body = shop.split("func open_shop")[1].split("func ")[0]
    assert "set_process(true)" in open_body
    close_body = shop.split("func close_shop")[1].split("func ")[0]
    assert "set_process(false)" in close_body


def test_icon_fallback_caches() -> None:
    buildings = _read("src/buildings/building_icons.gd")
    assert "_fallback_cache" in buildings
    assert "_fallback_crystal_cache" in buildings
    skills = _read("src/skills/skill_icons.gd")
    assert 'FALLBACK_ID := "_fallback"' in skills or '"_fallback"' in skills


def test_xp_progress_comment_updated() -> None:
    xp = _read("src/progression/xp_progress.gd")
    assert "HunterUpgradeProgression" in xp
    assert "intentionally empty" not in xp


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
