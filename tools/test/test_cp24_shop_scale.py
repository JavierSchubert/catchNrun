"""Offline CP-24 checks — map scale, HP bars, crystal icon, item shop (no Godot).

Run:  python -m pytest tools/test/test_cp24_shop_scale.py -q
  or: python tools/test/test_cp24_shop_scale.py
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_plateau_map_40x28() -> None:
    src = _read("src/maps/plateau_map.gd")
    assert "const COLS := 40" in src
    assert "const ROWS := 28" in src
    assert "SPAWN_RING_RADIUS := 220.0" in src
    assert "hunter_spawn_position" in src
    assert "SPAWN_RING_RADIUS" in src.split("func hunter_spawn_position")[1]


def test_unit_map_bounds_match_40x28() -> None:
    unit = _read("src/units/unit/unit.gd")
    # 40*128=5120, 28*128=3584; centered → origin -2560,-1792
    assert "MAP_BOUNDS := Rect2(-2560.0, -1792.0, 5120.0, 3584.0)" in unit


def test_cell_size_48() -> None:
    cm = _read("src/construction/construction_manager.gd")
    assert "const CELL_SIZE := 48.0" in cm


def test_unit_hp_bar_offsets() -> None:
    tscn = _read("src/units/unit/unit.tscn")
    assert "offset_top = -72.0" in tscn
    assert "offset_bottom = -44.0" in tscn
    assert "offset_top = -98.0" in tscn
    assert "offset_bottom = -74.0" in tscn


def test_building_hp_bar_raised() -> None:
    tscn = _read("src/buildings/building.tscn")
    assert "offset_top = -88.0" in tscn
    assert "offset_bottom = -62.0" in tscn


def test_crystal_icon_uses_asset() -> None:
    icons = _read("src/buildings/building_icons.gd")
    assert "crystal_currency_128.png" in icons
    assert "func crystal_icon" in icons
    asset = ROOT / "assets/sprites/buildings/crystal_assets_128/crystal_currency_128.png"
    assert asset.is_file(), f"missing currency asset: {asset}"


def test_shop_sprite_asset_exists() -> None:
    asset = ROOT / "assets/sprites/buildings/crystal_assets_128/shop_128.png"
    assert asset.is_file(), f"missing shop asset: {asset}"


def test_item_shop_entity() -> None:
    shop = _read("src/buildings/item_shop/item_shop.gd")
    assert "class_name ItemShop" in shop
    assert "FOOTPRINT := Vector2i(3, 3)" in shop
    assert "is_attackable" in shop
    assert "return false" in shop.split("func is_attackable")[1].split("func ")[0]
    assert "shop_128.png" in shop
    assert "item_shop" in shop
    tscn = _read("src/buildings/item_shop/item_shop.tscn")
    assert "item_shop.gd" in tscn


def test_match_spawns_item_shop() -> None:
    match_gd = _read("game/match/match.gd")
    assert "_spawn_item_shop" in match_gd
    assert "item_shop.tscn" in match_gd
    assert "PlateauMap.spawn_center" in match_gd


def test_shop_catalog_hunter_items() -> None:
    catalog = _read("src/shop/shop_catalog.gd")
    assert "class_name ShopCatalog" in catalog
    for item_id in (
        "shop_max_health",
        "shop_hp_regen",
        "shop_defense",
        "shop_move",
        "shop_melee",
        "shop_attack_speed",
        "shop_crit",
        "shop_lifesteal",
    ):
        assert item_id in catalog
    assert "make_modifier" in catalog
    assert 'shop:%s' in catalog or 'shop:"' in catalog or "shop:%s" in catalog
    assert "items_for_role" in catalog


def test_unit_shop_buy_sell_rpc() -> None:
    unit = _read("src/units/unit/unit.gd")
    assert "shop_inventory" in unit
    assert "func request_shop_buy" in unit
    assert "func request_shop_sell" in unit
    assert "_server_shop_buy" in unit
    assert "_server_shop_sell" in unit
    assert "try_spend_crystals" in unit
    assert "grant_crystals" in unit
    assert "_open_item_shop" in unit
    assert "_item_shop_at" in unit
    tscn = _read("src/units/unit/unit.tscn")
    assert "shop_inventory" in tscn


def test_item_shop_panel_wiring() -> None:
    panel = _read("ui/hud/item_shop_panel/item_shop_panel.gd")
    assert "class_name ItemShopPanel" in panel
    assert "open_shop" in panel
    assert "close_shop" in panel
    assert "KEY_ESCAPE" in panel
    assert "MOUSE_BUTTON_RIGHT" in panel
    assert "AFFORD_COLOR" in panel
    assert "UNAFFORD_COLOR" in panel
    assert "request_shop_buy" in panel
    assert "request_shop_sell" in panel
    assert "Hunter upgrades only" in panel
    hud = _read("game/match/hud.tscn")
    assert "item_shop_panel.tscn" in hud
    assert "ItemShopPanel" in hud


def test_lava_scale_for_new_bounds() -> None:
    for rel in ("game/maps/arena_plateau.tscn", "game/maps/arena_plateau2.tscn"):
        tscn = _read(rel)
        assert "scale = Vector2(3.33333, 3.5)" in tscn


def test_stat_modifier_has_source() -> None:
    mod = _read("src/stats/stat_modifier.gd")
    assert "var source" in mod


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
