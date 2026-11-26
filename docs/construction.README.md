# Construction

## 1. Overview

The Runner Team can construct and upgrade structures using Crystals.

Initial structure types are:

- Crystal Mine
- Wall
- Tower

Construction rules are separate from economy, combat, stats, and UI presentation.

## 2. Building Placement

Selecting a structure to build enters placement mode.

**Build UI gating (`HudMode`, WP-17):** placement buttons arm only while the local controllable unit is selected (`UNIT_BUILD`). Upgrade / Destroy / tower picks appear only while an owned structure is selected (`BUILDING_MANAGE`). The two modes are mutually exclusive — never both at once. Rules live in `src/hud/hud_mode.gd`; the bottom-right panel is `ui/hud/building_panel/` (`is_armed` + `"building_ui"` group).

Placement is **grid-based**. Footprint size in cells defines the structure hitbox. Collision layers, snap rules, and blocker checks are specified in `building.README.md`.

```text
Select Structure (UNIT_BUILD — local unit selected)
-> Enter Placement Mode
-> Show grid-snapped Placement Preview
-> Validate footprint (bounds + blocker layers)
-> Left Click Valid Position
-> Spend Required Crystals
-> Create Structure (hitbox = footprint cells)
-> Exit Placement Mode
```

Invalid placement must not spend resources or create the structure.

Placement validation must at least consider:

- Build-grid bounds.
- Footprint cell coverage (size of the entity in cells).
- Collisions with obstacles, units, buildings, and destructibles (`building.README.md` §4–§5).
- Other gameplay-specific restrictions (spacing, ownership) as the map design develops.

## 3. Crystal Mine

Crystal Mines are Runner economy structures.

They:

- Generate Crystals periodically.
- Have health.
- Can be attacked by the Hunter.
- Can be destroyed.
- Can be upgraded.

Crystal generation and upgrade economics are defined in `economy.README.md`.

## 4. Walls

Walls are defensive structures used to block or delay the Hunter.

Walls:

- Block movement.
- Have health.
- Can be attacked and destroyed by the Hunter.
- Can be upgraded.

Wall upgrades primarily increase survivability, such as maximum health.

```text
Wall Upgrade
-> Spend Crystals
-> Increase Wall Level
-> Apply Level Configuration
-> Increase Maximum Health
```

Exact costs and health values must be configurable.

From `shield_unlock_level` (15) a Wall also carries a **shield** in front of its health. The shield absorbs damage first; only the overflow reaches health. It waits `shield_recharge_delay` seconds after the last hit, then refills `shield_recharge_per_second` of its maximum per second. The shield grows by `shield_growth` per level above the unlock. Values live in `src/buildings/defs/wall_def.tres` (see `economy.README.md` §2.1).

Destroying a Wall must update navigation so that previously blocked paths can become available.

## 5. Towers

Towers provide offensive defense for the Runner Team.

Towers:

- Have health.
- Can be attacked and destroyed by the Hunter.
- Acquire valid Hunter targets according to their targeting rules.
- Attack according to their configured attack behavior.
- May be upgradeable.

A Tower fires a homing projectile at the nearest living Hunter in range. Damage is resolved when the shot is fired (`CombatDamage.resolve_ranged`), but applied only when the projectile lands; a target that dies or disappears in flight takes nothing. Its combat numbers come from a `StatSheet` seeded from `tower_base_stats` in `tower_def.tres` — never from a per-level damage curve. Its HP comes from `hp_for_level()` alone.

Every Tower upgrade requires one **stat pick**, chosen by the owner in the build panel:

| Path | Effect per pick |
| --- | --- |
| Damage | +`tower_damage_per_pick` of base ranged damage |
| Attack Speed | +`tower_attack_speed_per_pick` of base attack speed |
| Crit | +`tower_crit_chance_per_pick` crit chance and +`tower_crit_damage_per_pick` crit multiplier (flat) |
| Range | +`tower_range_per_pick` of base attack range |

Percentage picks on the same path sum rather than compound. The host validates the pick before spending anything, and the pick takes effect when the upgrade finishes — together with the new level and its HP — so a Tower never holds more picks than levels.

A common defensive pattern is:

```text
Runner Area
-> Tower
-> Wall
-> Hunter Approach
```

Walls delay access while Towers apply pressure to the Hunter.

## 6. Structure Health and Destruction

All destructible structures expose health to the combat system.

```text
Structure takes damage (Building.apply_damage — the only entry point)
-> Wall shield absorbs first, if any
-> Reduce current health by the rest

current_health <= 0
-> Destroy structure
-> Remove gameplay functionality
-> Update navigation / world state where required
```

`apply_damage()` returns the damage actually applied (shield + health); the Hunter's Crystal income is paid on that value (`economy.README.md` §3.1).

### 6.1. Voluntary destroy (Runner)

A Runner may destroy their own structures from:

- **BuildingPanel** Destroy (requires `HudMode.BUILDING_MANAGE` — owned building selected), or
- **`A` + left-click** on an own structure while their controllable unit is selected (`controls.README.md` §1.3).

Both paths call `ConstructionManager.request_destroy`. Host `_server_destroy` also runs `_can_build` (role / eliminated / phase), matching build and upgrade. When the building leaves the tree, `Building._exit_tree` notifies `SelectionManager.notify_entity_removed`, which clears the selection and auto-selects the local unit.

### 6.2. Repair

Runners can **repair** their own structures with the `repair` skill (`src/skills/defs/repair_def.tres`, rules in `src/skills/repair_skill.gd`). Right-clicking an own, damaged structure walks the Runner into reach and restores `value_per_second` HP per second until the structure is full (`controls.README.md` §1.2). Destroy is separate (§6.1).

The host validates every repair: Runner role, alive, owner of the structure, structure alive and damaged, and not under its first construction. Structures that are upgrading can be repaired. Repair restores health only; a wall's shield recharges on its own.

## 7. Structure Upgrades

Upgrade behavior should be driven by configuration rather than separate hard-coded logic for every upgrade level.

A structure upgrade can modify properties such as:

- Maximum health.
- Damage.
- Attack range.
- Generation output.
- Other structure-specific properties.

The relevant system owns the final behavior:

```text
Crystal Mine Upgrade -> Economy configuration
Wall Upgrade         -> Structure / health configuration (+ shield from level 15)
Tower Upgrade        -> Structure / combat configuration (+ one stat pick per level)
```

All of it lives in one `BuildingDef` per type (`src/buildings/defs/*.tres`); one `Building` script serves every type.
