"""Offline WP-17 checks — no Godot required.

Run:  python -m pytest tools/test/test_hud_wp17.py -q
  or: python tools/test/test_hud_wp17.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from hud_mode_rules import Mode, can_build, can_manage_building, can_runner_a_destroy, resolve  # noqa: E402


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_hud_mode_unit_build_only_when_controllable() -> None:
    mode = resolve(
        is_active_runner=True,
        selected_is_building=False,
        building_owned=False,
        building_has_def=False,
        selected_is_controllable=True,
    )
    assert mode == Mode.UNIT_BUILD
    assert can_build(mode)
    assert not can_manage_building(mode)


def test_hud_mode_building_manage_only_when_owned() -> None:
    mode = resolve(
        is_active_runner=True,
        selected_is_building=True,
        building_owned=True,
        building_has_def=True,
        selected_is_controllable=False,
    )
    assert mode == Mode.BUILDING_MANAGE
    assert can_manage_building(mode)
    assert not can_build(mode)


def test_hud_mode_mutual_exclusion() -> None:
    """Build and manage never true together for any resolve outcome."""
    cases = [
        dict(is_active_runner=True, selected_is_building=False, building_owned=False, building_has_def=False, selected_is_controllable=True),
        dict(is_active_runner=True, selected_is_building=True, building_owned=True, building_has_def=True, selected_is_controllable=False),
        dict(is_active_runner=True, selected_is_building=True, building_owned=False, building_has_def=True, selected_is_controllable=False),
        dict(is_active_runner=False, selected_is_building=False, building_owned=False, building_has_def=False, selected_is_controllable=True),
        dict(is_active_runner=True, selected_is_building=False, building_owned=False, building_has_def=False, selected_is_controllable=False),
    ]
    for kwargs in cases:
        mode = resolve(**kwargs)
        assert not (can_build(mode) and can_manage_building(mode))


def test_runner_a_destroy_own_only() -> None:
    assert can_runner_a_destroy(
        is_active_runner=True,
        selected_is_controllable=True,
        selected_can_attack=False,
        target_is_building=True,
        building_owned=True,
        building_has_def=True,
    )
    assert not can_runner_a_destroy(
        is_active_runner=True,
        selected_is_controllable=True,
        selected_can_attack=True,  # Hunter
        target_is_building=True,
        building_owned=True,
        building_has_def=True,
    )
    assert not can_runner_a_destroy(
        is_active_runner=True,
        selected_is_controllable=True,
        selected_can_attack=False,
        target_is_building=True,
        building_owned=False,
        building_has_def=True,
    )


def test_hud_tscn_corner_anchors() -> None:
    text = _read("game/match/hud.tscn")
    # Minimap bottom-left: preset 2
    assert re.search(r'\[node name="Minimap".*?anchors_preset = 2', text, re.S)
    # Selection bottom-center: preset 7
    assert re.search(r'\[node name="SelectionPanel".*?anchors_preset = 7', text, re.S)
    # Building bottom-right: preset 3
    assert re.search(r'\[node name="BuildingPanel".*?anchors_preset = 3', text, re.S)
    assert "offset_left = -316.0" in text
    assert "offset_top = -376.0" in text


def test_building_panel_has_stat_rows_and_sections() -> None:
    text = _read("ui/hud/building_panel/building_panel.tscn")
    for name in (
        "BuildSection",
        "SelectedSection",
        "StatHp",
        "DestroyButton",
        "UpgradeButton",
        "PickGrid",
    ):
        assert name in text
    assert 'path="res://ui/hud/widgets/stat_icon_row.tscn"' in text


def test_gdscript_wires_hud_mode_and_destroy() -> None:
    panel = _read("ui/hud/building_panel/building_panel.gd")
    assert "HudMode.resolve" in panel
    assert "HudMode.can_build" in panel
    assert "HudMode.can_manage_building" in panel
    assert "request_destroy" in panel
    assert "StatIcons.short_number" in panel
    assert "BuildingIcons.icon_for_def" in panel

    mode = _read("src/hud/hud_mode.gd")
    assert "UNIT_BUILD" in mode
    assert "BUILDING_MANAGE" in mode
    assert "can_runner_a_destroy" in mode

    selection = _read("src/selection/selection_manager.gd")
    assert "HudMode.can_runner_a_destroy" in selection
    assert "notify_entity_removed" in selection
    assert "_request_destroy_building" in selection

    building = _read("src/buildings/building.gd")
    assert "set_selection_hover" in building
    assert "set_selection_selected" in building
    assert "notify_entity_removed" in building

    construction = _read("src/construction/construction_manager.gd")
    assert "HudMode.is_active_runner" in construction

    resolver = _read("src/selection/selection_resolver.gd")
    assert 'has_method("is_own")' in resolver

    sel_panel = _read("ui/hud/selection_panel/selection_panel.gd")
    assert "_show_building" in sel_panel
    assert "_apply_stat_icons()" in sel_panel
    assert "BuildingIcons.icon_for_def" in sel_panel
    assert "StatIcons.short_number" in sel_panel


def test_stat_icon_assets_exist() -> None:
    for name in (
        "health.png",
        "damage.png",
        "attack_speed.png",
        "block_chance.png",
        "crit_chance.png",
    ):
        path = ROOT / "assets" / "sprites" / "stats" / "clean" / name
        assert path.is_file(), f"missing {path}"


def test_helper_scenes_exist() -> None:
    assert (ROOT / "tests" / "hud" / "hud_layout_preview.tscn").is_file()
    assert (ROOT / "ui" / "hud" / "widgets" / "stat_icon_row.tscn").is_file()
    kit = _read("ui/widgets/ui_kit/ui_kit.tscn")
    assert "building_panel.tscn" in kit
    assert "stat_icon_row.tscn" in kit


def test_scene_unique_names_in_building_panel() -> None:
    text = _read("ui/hud/building_panel/building_panel.tscn")
    script = _read("ui/hud/building_panel/building_panel.gd")
    for match in re.finditer(r"@onready\s+var\s+\w+[^=]*=\s*%([A-Za-z0-9_]+)", script):
        name = match.group(1)
        assert f'name="{name}"' in text, f"%{name} missing in tscn"
    assert "unique_name_in_owner = true" in text


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
    print(f"PASS: all {len(tests)} WP-17 offline checks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
