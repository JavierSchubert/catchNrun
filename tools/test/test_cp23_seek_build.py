"""Offline CP-23 checks — Seek skill, build hotkeys, multi-select, mine cap (no Godot).

Run:  python -m pytest tools/test/test_cp23_seek_build.py -q
  or: python tools/test/test_cp23_seek_build.py
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_skill_def_has_self_cooldown_duration() -> None:
    src = _read("src/skills/skill_def.gd")
    assert "SELF" in src
    assert "cooldown" in src
    assert "duration" in src


def test_seek_def_balance() -> None:
    tres = _read("src/skills/defs/seek_def.tres")
    assert 'id = "seek"' in tres
    assert "cooldown = 30.0" in tres
    assert "duration = 10.0" in tres
    assert "role = 0" in tres  # HUNTER
    skill = _read("src/skills/seek_skill.gd")
    assert "class_name SeekSkill" in skill
    assert "can_cast" in skill
    assert "gather_target_positions" in skill


def test_unit_seek_rpc_and_hotkey() -> None:
    unit = _read("src/units/unit/unit.gd")
    assert "func request_seek" in unit
    assert "_server_cast_seek" in unit
    assert "_rpc_seek_started" in unit
    assert "_rpc_seek_targets" in unit
    assert "KEY_Q" in unit
    assert "SeekPresentation" in unit


def test_seek_presentation_and_minimap_arrows() -> None:
    pres = _read("src/skills/seek_presentation.gd")
    assert "class_name SeekPresentation" in pres
    assert "func begin" in pres
    dots = _read("ui/hud/minimap/minimap_dots.gd")
    assert "_draw_seek_arrows" in dots
    assert "SeekPresentation" in dots


def test_hunter_seek_panel_wired() -> None:
    panel = _read("ui/hud/hunter_seek_panel.gd")
    assert "class_name HunterSeekPanel" in panel
    assert "request_seek" in panel
    assert "SkillIcons" in panel
    icons = _read("src/skills/skill_icons.gd")
    assert "class_name SkillIcons" in icons
    assert "seek_icon" in icons
    hud = _read("game/match/hud.tscn")
    assert "hunter_seek_panel.tscn" in hud
    assert "HunterSeekPanel" in hud


def test_hunter_standard_regen() -> None:
    tres = _read("src/units/hunter/hunter_config.tres")
    assert "health_regeneration = 2.0" in tres
    assert "regen_delay_after_damage = 5.0" in tres
    role = _read("src/units/role_config.gd")
    assert "regen_delay_after_damage" in role
    unit = _read("src/units/unit/unit.gd")
    assert "_since_damage" in unit
    assert "_on_health_changed_for_regen" in unit


def test_build_hotkeys_and_destroy_d() -> None:
    panel = _read("ui/hud/building_panel/building_panel.gd")
    assert "KEY_W" in panel
    assert "KEY_T" in panel
    assert "KEY_C" in panel
    assert "KEY_D" in panel
    assert "_handle_build_hotkey" in panel
    assert "_managed_buildings" in panel
    cam = _read("game/camera/match_camera.gd")
    assert "_runner_build_mode_active" in cam


def test_multi_select_double_click() -> None:
    sel = _read("src/selection/selection_manager.gd")
    assert "selected_group" in sel
    assert "_own_buildings_of_kind" in sel
    assert "double_click" in sel
    assert "selected_buildings" in sel


def test_one_crystal_mine_cap() -> None:
    cm = _read("src/construction/construction_manager.gd")
    assert "owns_crystal_mine" in cm
    assert 'building_key == "crystal_mine"' in cm
    panel = _read("ui/hud/building_panel/building_panel.gd")
    assert "owns_crystal_mine" in panel


def test_hunter_damage_crystals_wired() -> None:
    unit = _read("src/units/unit/unit.gd")
    assert unit.count("award_damage_crystals") >= 2
    gm = _read("autoloads/game_manager.gd")
    assert "func award_damage_crystals" in gm
    econ = _read("src/economy/economy_config.tres")
    assert "hunter_crystals_per_damage = 0.2" in econ


def test_docs_and_checkpoint() -> None:
    controls = _read("docs/controls.README.md")
    assert "Hunter Seek" in controls
    assert "W` | Arm" in controls or "W`" in controls
    construction = _read("docs/construction.README.md")
    assert "one Crystal Mine" in construction or "One Crystal Mine" in construction
    minimap = _read("docs/minimap.README.md")
    assert "Seek" in minimap
    cp = _read("tasks/checkpoints.README.md")
    assert "CP-23" in cp


def main() -> int:
    tests = [
        test_skill_def_has_self_cooldown_duration,
        test_seek_def_balance,
        test_unit_seek_rpc_and_hotkey,
        test_seek_presentation_and_minimap_arrows,
        test_hunter_seek_panel_wired,
        test_hunter_standard_regen,
        test_build_hotkeys_and_destroy_d,
        test_multi_select_double_click,
        test_one_crystal_mine_cap,
        test_hunter_damage_crystals_wired,
        test_docs_and_checkpoint,
    ]
    failed = 0
    for test in tests:
        try:
            test()
            print(f"PASS: {test.__name__}")
        except AssertionError as exc:
            failed += 1
            print(f"FAIL: {test.__name__}: {exc}")
        except Exception as exc:  # noqa: BLE001
            failed += 1
            print(f"ERROR: {test.__name__}: {exc}")
    if failed:
        print(f"{failed} failed")
        return 1
    print(f"All {len(tests)} passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
