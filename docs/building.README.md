# Building

## 1. Overview

Building is **grid-based**, in the style of StarCraft 2 or Age of Empires.

A structure does not float freely on the map. It occupies a rectangular footprint of one or more grid cells. That footprint **is** the structure's solid hitbox for placement and blocking.

Construction flow, Crystal costs, upgrades, and structure roles (Crystal Mine, Wall, Tower) are defined in `construction.README.md`. This document owns the **grid**, **footprint / hitbox**, **collision layers**, and **placement validity** rules.

```text
Select structure
-> Enter placement mode
-> Snap ghost to build grid
-> Validate footprint cells + physics blockers
-> Left click when valid
-> Spawn building whose hitbox matches the footprint
```

## 2. Build Grid

The playable map is overlaid with a uniform axis-aligned grid.

| Property | Meaning |
| --- | --- |
| `cell_size` | Edge length of one cell in world pixels (configurable) |
| `origin` | World position of the top-left corner of cell `(0, 0)` |
| Cell coordinate | Integer `Vector2i(x, y)` |

```text
world position
-> convert to cell
-> snap footprint anchor to that cell
-> footprint covers [anchor .. anchor + size - 1]
```

The ghost preview and the final building share the same snap rules so what you see is what you place.

## 3. Footprint Equals Hitbox

Every placeable building declares a footprint in **cells**, not only in pixels.

Examples:

| Structure | Footprint (cells) | Hitbox (world) |
| --- | --- | --- |
| Small prop / 1×1 pad | `1 × 1` | `cell_size × cell_size` |
| Crystal Mine | e.g. `2 × 2` | `2·cell_size × 2·cell_size` |
| Wall segment | e.g. `1 × 1` or `2 × 1` | matches cells |
| Tower | e.g. `2 × 2` | matches cells |

Rules:

1. Footprint width / height are positive integers.
2. The solid collision shape is an axis-aligned rectangle covering exactly those cells.
3. Visual art may extend slightly for presentation, but **placement and blocking** use the cell footprint only.
4. Units and other blockers that overlap any covered cell make the placement invalid.

```text
footprint (cells) = hitbox (world rectangle of those cells)
```

## 4. Placement Validation

A placement is valid only when **all** of the following hold:

1. Every cell of the footprint lies on buildable grid space (inside the configured build bounds).
2. The footprint rectangle does **not** overlap a blocking collider (see §5).
3. Gameplay rules from `construction.README.md` pass (resources, ownership, etc. — when those systems are active).

```text
Candidate anchor cell + footprint
    |
    +-- Outside build bounds?        -> Invalid
    +-- Overlaps Obstacle?           -> Invalid
    +-- Overlaps Unit?               -> Invalid
    +-- Overlaps Building?           -> Invalid
    +-- Overlaps Destructible?       -> Invalid
    +-- Otherwise                    -> Valid
```

Invalid placement must not spend resources or spawn a structure.

While placing, the preview shows:

| State | Feedback |
| --- | --- |
| Valid | Green footprint / ghost |
| Invalid | Red footprint / ghost |

## 5. Collision Layers

Physics layers separate what kinds of bodies exist in the world. Layer names in the project:

| Layer | Name | Used by |
| --- | --- | --- |
| 1 | `world` | Shared world / ground context all gameplay bodies live in |
| 2 | `obstacle` | Static blockers such as map borders and non-buildable terrain colliders |
| 3 | `unit` | Player units (Hunter, Runners) and NPCs |
| 4 | `building` | Constructed building objects |
| 5 | `destructible` | Destructible world / “NPC objects” that can be damaged or cleared |
| 6 | `item` | Collectible pickups |

Conceptual stack:

```text
World (layer world)
├── Obstacles          (map rim, blocked terrain)
├── Units              (Hunter, Runners, NPCs)
├── Buildings          (Crystal Mine, Wall, Tower, …)
├── Destructibles      (breakable props / NPC objects)
└── Items              (pickups)
```

### 5.1. What blocks building

Placement queries treat these layers as **blockers**:

- `obstacle`
- `unit`
- `building`
- `destructible`

If the footprint rectangle intersects any collider on those layers, placement is invalid.

### 5.2. Items

`item` pickups use their own layer so collection can use overlap queries without being treated as solid world geometry by default.

Items **do not** block building unless a specific item is explicitly configured as a blocker. Collecting an item removes it from the world; it should not permanently reserve build cells.

### 5.3. World layer

`world` is the shared membership / ground context. It does not by itself mean “blocked”. Map borders and non-buildable volumes are authored as `obstacle` (or another blocker layer), not merely as `world`.

## 6. Runtime Responsibilities

```text
BuildGrid
-> Cell size, origin, world ↔ cell conversion, footprint rectangles

PlacementValidator
-> Bounds + physics overlap tests against blocker layers

Placement / Construction controller
-> Ghost preview, input, commit place when valid

Building instance
-> Footprint metadata + matching rectangular hitbox on layer `building`
-> Health, Shield (wall), Attack (tower) child components; health / shield / build-progress bars
-> Building.apply_damage() / repair() as the only ways structure HP changes
```

Two runtime notes that touch the scene tree rather than the grid:

- **Shield** — `building.tscn` carries a `Shield` (`ShieldComponent`) node and a `ShieldBar` above the health bar. The bar stays hidden while the structure has no shield (every non-wall, and walls below level 15). `sync_current_shield` and `max_shield` replicate like `sync_current_health`.
- **Projectiles** — tower shots (`src/combat/projectile.tscn`) are added to the current scene, not to the Building, so they do not collide with or move with the structure. They are not on any physics layer and never block placement. Clients get a cosmetic copy over an unreliable RPC; only the host's copy applies damage.

Economy spend and structure-type rules stay outside this document (`economy.README.md`, `construction.README.md`).

## 7. Test Scene

Grid placement must be testable without the full lobby → role selection → match flow.

```text
tests/construction/building_grid_test.tscn
```

The scene should let a developer:

1. See the build grid drawn on the map.
2. Move a footprint ghost snapped to cells.
3. Toggle or cycle footprint sizes (for example `1×1`, `2×2`, `3×2`).
4. Attempt placement only when the footprint is free of blockers.
5. Observe pre-placed obstacles, units, buildings, destructibles, and items on the correct layers.

A headless logic test covers cell math and “blocked vs free” decisions without requiring the editor viewport.

## 8. Relation to Other Docs

| Topic | Doc |
| --- | --- |
| Placement mode flow, structure types, upgrades | `construction.README.md` |
| Crystal costs / spend | `economy.README.md` |
| Selecting constructed buildings in the HUD | `selection_panel.README.md` / `controls.README.md` |
| Folder layout (`src/buildings/`, `src/construction/`) | `project_architecture.README.md` |
