# Vision and Fog of War

## 1. Overview

The map uses fog of war. Each team only knows what its own units and structures can currently see, plus what it has seen before.

The Vision system is the single authority on what the local player's team is allowed to know. The world fog overlay, minimap, selection panel, and any other presentation ask Vision; they never detect hidden entities on their own (`project_architecture.README.md` §5.4).

Implementation: `src/vision/` (`VisionSystem`, `VisionKnowledge`), instanced in `game/match/match.tscn` as the `VisionSystem` node (group `vision_system`).

## 2. Teams and Shared Vision

There are two teams.

```text
Runner team
-> Every Runner
-> Every structure (structures belong to the Runner team)

Hunter team
-> The Hunter
```

Vision is shared inside a team. A Runner sees through every Runner and every finished structure; the Hunter sees through the Hunter.

The viewing team is the role of the local player (`GameManager.local_peer_id()`). In the sandbox, switching the active character switches the viewing team and discards the previous team's knowledge.

## 3. Vision Sources and Range

A vision source reveals a circle around itself.

| Source | Config | Default |
| --- | --- | --- |
| Runner | `RoleConfig.vision_range` (`runner_config.tres`) | 450 px |
| Hunter | `RoleConfig.vision_range` (`hunter_config.tres`) | 500 px |
| Structure (wall / tower / crystal mine) | `BuildingDef.vision_range` (`*_def.tres`) | 320 px |

Rules:

- Dead or eliminated units are not sources.
- A structure becomes a source when its first construction finishes. It keeps vision while upgrading and stops when destroyed.
- Vision ignores walls and terrain: it is a plain circle. Line of sight is out of scope.
- Ranges are data, not code: change the resources, not the scripts.

Helpers: `Unit.get_vision_range()`, `Building.get_vision_range()`, `VisionSystem.get_vision_range(node)`.

## 4. Vision States

Every map cell is in exactly one state for the viewing team.

```text
Unexplored        never inside any vision circle
Previously Seen   was visible once, not visible now
Currently Visible inside a vision circle now
```

Explored cells never revert to Unexplored during a match. Terrain is stored as a grid (default 64 px cells over `PlateauMap.world_bounds()`) with two byte masks: `visible` (rebuilt every update) and `explored` (only ever grows). A cell is lit when its center is inside a source circle.

## 5. Entity Visibility

### 5.1. Own team

Own-team units and structures are always visible to their team, regardless of fog.

### 5.2. Enemy units

An enemy unit is visible only while its position is inside current vision.

```text
Enemy unit inside vision
-> Visible, live position

Enemy unit leaves vision
-> Hidden immediately
-> No last-known ghost, no stale marker, no live updates
```

There is intentionally no last-known memory for units. Moving entities never leak their hidden position.

### 5.3. Enemy structures

Structures are static, so they persist.

```text
Structure enters vision (any part of its footprint is lit)
-> Visible; a last-known snapshot is created / refreshed

Structure leaves vision
-> Hidden as a live object
-> Last-known snapshot stays (position, footprint, kind, level, construction flag)
-> Snapshot is not updated while hidden

Structure is destroyed or upgraded outside vision
-> Snapshot keeps showing the old state

Footprint becomes visible again
-> Snapshot refreshed from the live structure
-> Or removed if no structure exists there any more
```

In the shipped game all structures belong to the Runners, so only the Hunter team accumulates last-known structures. The rule is written generally (any structure not owned by the viewing team).

## 6. Honest Clients

Vision is computed locally on every peer from synced world state only: unit and structure positions, roles, owner, level, and state that already replicate. It does not read host-only data, and it grants no information beyond what the replicated nodes contain.

Consequences:

- Fog is a presentation / knowledge layer for the local player. The host remains authoritative for gameplay.
- Fog does not (yet) restrict server-side targeting, tower acquisition, or hunter bots. Gameplay-level fog rules are not part of this specification.

## 7. Fog Toggle

`VisionSystem.fog_enabled` (and `set_fog_enabled()`) turns fog off for debugging and the sandbox.

- Off: every query reports "visible", no knowledge is gathered (`update_vision()` is a no-op), `last_known_buildings()` is empty.
- Back on: masks refresh on the next physics tick. Previously gathered knowledge is kept.

## 8. Public API

All queries answer for the local player's team. Get the node with `VisionSystem.find_in(get_tree())` (returns `null` outside a match).

| Member | Purpose |
| --- | --- |
| `fog_enabled` / `set_fog_enabled(bool)` | Fog on/off; `fog_enabled_changed(bool)` signal |
| `is_world_visible(pos) -> bool` | Exact point-in-circle test against current sources |
| `terrain_state(pos) -> VisionKnowledge.State` | Cell state: `UNEXPLORED`, `PREVIOUSLY_SEEN`, `VISIBLE` |
| `can_see_unit(unit) -> bool` | Own team always; enemy only in current vision |
| `can_see_building(building) -> bool` | Own team always; enemy when any footprint cell is visible |
| `last_known_buildings()` | All remembered enemy structures (`VisionKnowledge.LastKnownBuilding`) |
| `hidden_last_known_buildings()` | Remembered structures not currently visible: what ghosts draw |
| `get_vision_range(node) -> float` | Range of a Unit or Building |
| `viewer_role() -> int` | `RoleConfig.Role` of the viewing team |
| `update_vision()` | Force an immediate refresh (tests / tools) |
| `visible_mask()`, `explored_mask()`, `grid_size()`, `cell_edge()`, `world_bounds()` | Raw grid for fog overlay and minimap |
| `knowledge` | The underlying `VisionKnowledge` (cell helpers: `world_to_cell`, `cell_rect`, ...) |
| signals `vision_updated`, `last_known_changed` | Redraw triggers for presentation |

`LastKnownBuilding` fields: `id`, `kind` (`BuildingDef.Kind`), `display_name`, `owner_peer_id`, `position` (footprint center), `footprint`, `pixel_size`, `level`, `under_construction`, `last_seen_msec`, `world_rect()`.

`is_world_visible` uses exact distances; `terrain_state` and structure checks use the 64 px cell grid. They can disagree by up to about one cell at a circle edge. Presentation should use `terrain_state` for terrain and the `can_see_*` helpers for entities.

## 9. Configurable Parameters

```text
RoleConfig.vision_range      Runner 450, Hunter 500
BuildingDef.vision_range     320 for all structures
VisionSystem.cell_size       64 px fog cell
VisionSystem.update_interval 0.1 s between refreshes
VisionSystem.fog_enabled     true
```

## 10. Responsibility Boundary

```text
Vision System
-> Owns sources, explored terrain, current visibility, last-known structures

World fog overlay (later phase)
-> Draws the three terrain states from Vision

Entity presentation (later phase)
-> Hides enemy units / structures that Vision says cannot be seen
-> Draws last-known structure ghosts

Minimap
-> See minimap.README.md; converts Vision knowledge into markers

Gameplay (combat, targeting, construction)
-> Unchanged by fog in this specification
```

## 11. Edge Cases

- Before the first update (first physics frames) nothing is visible except own-team entities.
- The Hunter spawns after the Runner preparation phase; until then the Hunter team has no sources.
- A last-known structure whose footprint is only partially lit counts as seen, and is refreshed or removed accordingly.
- A destroyed structure is purged the moment its footprint is visible; destroyed structures outside vision are remembered until revisited.
- Positions outside the map bounds are Unexplored and never visible.
