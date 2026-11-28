"""Offline checks for building/manage UI polish (no Godot)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_menu_scenes_exist() -> None:
    for rel in (
        "ui/hud/menus/build_menu.tscn",
        "ui/hud/menus/manage_menu.tscn",
        "ui/hud/menus/selection_menu.tscn",
    ):
        assert (ROOT / rel).is_file(), rel


def test_building_panel_layout_polish() -> None:
    tscn = _read("ui/hud/building_panel/building_panel.tscn")
    assert 'name="StatsGrid"' in tscn
    assert "columns = 2" in tscn
    assert 'name="ActionsFooter"' in tscn
    assert 'name="FooterSpacer"' in tscn
    assert "DestroyButton" in tscn and "ActionsFooter" in tscn
    info = tscn.split('name="InfoLabel"')[1].split("[node")[0]
    assert "visible = false" in info
    gd = _read("ui/hud/building_panel/building_panel.gd")
    assert "_upgrade_delta_text" in gd
    assert 'Manage selected' not in gd
    assert "Select a structure to build" not in gd
    assert '"%s [%d]"' in gd or "%s [%d]" in gd
    assert "_upgrade_cost_row.visible = true" in gd


def test_seek_nested_in_selection() -> None:
    hud = _read("game/match/hud.gd")
    assert "_nest_seek_into_selection" in hud
    sel = _read("ui/hud/selection_panel/selection_panel.tscn")
    assert 'name="SkillSlot"' in sel


def test_settings_dock_top() -> None:
    settings = _read("ui/widgets/settings_menu/settings_menu.tscn")
    assert "offset_top = 12.0" in settings
    assert "offset_bottom = 92.0" in settings


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
