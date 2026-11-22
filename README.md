# CatchNRun

## Project Overview

CatchNRun is a 2D top-down asymmetric multiplayer game with two opposing teams:

- **Runner Team**
- **Hunter Team**

The Runner Team receives a configurable head start of initially `60 seconds`. During this preparation phase, the Runners must escape, generate Crystals, and construct defenses before the Hunter spawns on the map.

The Runners can build Crystal Mines, Walls, and Towers. Walls are used to block or delay the Hunter, while Towers can attack the Hunter from behind the defensive line. All structures have health and can be attacked and destroyed.

Crystal Mines generate Crystals at a configurable interval, initially every `2 seconds`. A level 1 Crystal Mine generates `1 Crystal` per tick. Upgrading the mine increases its output by powers of two until it reaches `2048 Crystals` per tick.

```text
Level 1  -> 1 Crystal / tick
Level 2  -> 2 Crystals / tick
Level 3  -> 4 Crystals / tick
...
Level 12 -> 2048 Crystals / tick
```

The first upgrade may initially cost `16 Crystals`. Generation intervals, upgrade costs, health values, and other balance parameters must remain configurable for playtesting.

The Hunter earns Crystals based on damage dealt to Runners and their structures. The Hunter also receives a smaller amount of passive Crystal income from the central Hunter Shop so that active combat remains the primary source of progression.

At the Hunter Shop, the Hunter can purchase items and upgrades that modify character stats, including:

- Health
- Health regeneration
- Defense
- Movement speed
- Damage
- Critical chance
- Critical damage
- Lifesteal

The map uses fog of war. Hunter and Runner teams can only see entities within their team's current vision area. The minimap displays discovered structures using configured pixel colors or icons. When a structure leaves vision, its last-known information remains until that location becomes visible again and the information can be refreshed.

## Documentation

The authoritative instructions for building the game are stored as separate Markdown files under the `docs/` directory.

```text
docs/
├── building.README.md
├── construction.README.md
├── controls.README.md
├── economy.README.md
├── gameplay.README.md
├── minimap.README.md
├── project_architecture.README.md
├── selection_panel.README.md
├── stats.README.md
└── ui_audio.README.md
```

Implementation progress vs these docs is tracked in `tasks/checkpoints.README.md` (done) and `tasks/working_packages.README.md` (open).

Each document owns a specific part of the game design and implementation.

| Document | Responsibility |
| --- | --- |
| `building.README.md` | Build grid, footprints, placement validation, physics layers for structures |
| `construction.README.md` | Building placement, Crystal Mines, Walls, Towers, structure health, destruction, and upgrades |
| `controls.README.md` | Selection, movement, attack commands, attack-move behavior, camera controls, and cursor feedback |
| `economy.README.md` | Crystals, Crystal Mine progression, Hunter damage income, passive income, costs, and spending |
| `gameplay.README.md` | High-level game rules, session screens, role selection, teams, match flow, objectives, Runner preparation phase, and win/loss behavior |
| `minimap.README.md` | Minimap presentation, team knowledge, visible entities, and last-known information |
| `project_architecture.README.md` | Repository structure, technical architecture, Godot conventions, multiplayer, testing, and deployment |
| `selection_panel.README.md` | Selected-entity information and contextual actions shown in the bottom HUD |
| `stats.README.md` | Character stats, modifiers, constraints, stat calculation, critical hits, and lifesteal |
| `ui_audio.README.md` | Settings dock, audio buses / playlist, lobby presentation, sandbox chrome layout |

## Documentation Rules

The documentation files are the source of truth for implementing the game.

When building or modifying a feature:

1. Read `gameplay.README.md` to understand the high-level rule or objective.
2. Read `project_architecture.README.md` to understand where the implementation belongs and which architectural principles apply.
3. Read the system-specific document for detailed behavior.
4. Preserve the separation of responsibilities between gameplay, UI, economy, construction, controls, stats, and minimap presentation.
5. Do not implement conflicting rules in different systems.

If the same topic appears in multiple documents, the document that owns the system is authoritative.

Examples:

```text
Session screens and Hunter selection
-> gameplay.README.md

Scene transitions and per-scene tests
-> project_architecture.README.md

Crystal generation and costs
-> economy.README.md

Wall placement and destruction
-> construction.README.md

Left-click selection and right-click commands
-> controls.README.md

Displayed selection information
-> selection_panel.README.md

Stat calculation
-> stats.README.md

Fog-of-war minimap presentation
-> minimap.README.md

Settings dock, music playlist, lobby UX, sandbox chrome
-> ui_audio.README.md

Camera edge scroll / overscroll padding / UI hover / minimap click
-> controls.README.md §2

Editor-preview HUD shells and StyleBoxes
-> project_architecture.README.md §5.3
```

Gameplay values that are expected to change during balancing must remain configurable and must not be hard-coded into UI components.

## Current runtime configuration (UI / audio / camera)

Snapshot of what is wired today (CP-12). Full detail: `docs/ui_audio.README.md` and `docs/controls.README.md` §2.

### Autoloads

```text
… → SettingsManager → SoundManager → BotClient → Sandbox
```

Settings load `user://settings.cfg`, push volumes onto SoundManager, then call `ensure_music()`.

### Audio

| Piece | Configuration |
| --- | --- |
| Bus layout | `default_bus_layout.tres` → Master → Music / SFX (`project.godot` `[audio]`) |
| Defaults | Music `0.75`, SFX `0.85`, both unmuted |
| Playlist | `osrs_bh1` → `osrs_bh2` → `osrs_bh3` → loop; continues across scene changes |
| Scene rule | Call `SoundManager.ensure_music()` — do not restart music per scene |
| MP3 load | Raw file bytes into `AudioStreamMP3` when Godot imports are invalid |
| Persist | `[audio]` + optional `[video] fullscreen` in `user://settings.cfg` |

### UI

| Piece | Configuration |
| --- | --- |
| Settings gear | Right edge on lobby, role selection, and match (`SettingsMenu.attach`) |
| Lobby | Wallpaper + card; **ENet only** Host/Join |
| Match map | `game/maps/arena_plateau.tscn` (lava / tiles v3), not space |
| Sandbox | Action bar top-left; Tests top-right; status bottom-right; headless default **on** |
| Match HUD status | Top-center, under the sandbox action bar |

### Camera (`MatchCamera`)

| Export | Default | Notes |
| --- | --- | --- |
| `edge_margin` | `48` | Screen px trigger zone for edge scroll (nearer the edge) |
| `camera_speed` | `1600` | World units / second (edge-scroll velocity) |
| Middle-mouse drag | hold MMB | Pan camera until release |
| `zoom_factor` | `1.0` | Sets `Camera2D.zoom` |
| `bound_padding` | `360` | Screen px overscroll so map corners stay inset; converted with `/ zoom` |

Also: no edge scroll over blocking UI; no auto-recenter on eliminations; minimap LMB → `center_on`; `C` still centers on own unit.

### Match HUD / styles (CP-13)

| Piece | Location |
| --- | --- |
| Match HUD scene | `game/match/hud.tscn` |
| Selection panel / minimap | `ui/hud/selection_panel/`, `ui/hud/minimap/` (+ StyleBox `.tres`) |
| Shared menu styles | `ui/styles/` |
| UI kit gallery | `ui/widgets/ui_kit/ui_kit.tscn` |
| Spawn ring | `Match.spawn_ring_radius` (default `160`) around map center |

## Implementation Principle

The game should be built as modular, data-driven systems.

```text
Gameplay Rules
-> Define what should happen

System Specifications
-> Define which system owns the behavior

Godot Implementation
-> Implements the behavior using scenes, scripts, components, and resources

UI
-> Presents state and emits player intent without owning gameplay rules
```

Before implementing a feature, use the relevant file under `docs/` as the primary instruction set.
