"""Python mirror of src/hud/hud_mode.gd for offline WP-17 verification (no Godot)."""

from __future__ import annotations

from enum import IntEnum


class Mode(IntEnum):
    NONE = 0
    UNIT_BUILD = 1
    BUILDING_MANAGE = 2


def resolve(
    *,
    is_active_runner: bool,
    selected_is_building: bool,
    building_owned: bool,
    building_has_def: bool,
    selected_is_controllable: bool,
) -> Mode:
    if not is_active_runner:
        return Mode.NONE
    if selected_is_building:
        if building_has_def and building_owned:
            return Mode.BUILDING_MANAGE
        return Mode.NONE
    if selected_is_controllable:
        return Mode.UNIT_BUILD
    return Mode.NONE


def can_build(mode: Mode) -> bool:
    return mode == Mode.UNIT_BUILD


def can_manage_building(mode: Mode) -> bool:
    return mode == Mode.BUILDING_MANAGE


def can_runner_a_destroy(
    *,
    is_active_runner: bool,
    selected_is_controllable: bool,
    selected_can_attack: bool,
    target_is_building: bool,
    building_owned: bool,
    building_has_def: bool,
) -> bool:
    if not is_active_runner:
        return False
    if not selected_is_controllable:
        return False
    if selected_can_attack:
        return False
    if not target_is_building or not building_has_def or not building_owned:
        return False
    return True
