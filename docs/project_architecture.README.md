# CatchNRun Technical Architecture

## 1. Project Overview

CatchNRun is a 2D top-down asymmetric multiplayer game built with Godot.

The project consists of three primary modules:

1. **Godot Game**
2. **Test Pipeline**
3. **Build and Deployment Pipeline**

The technical design should prioritize:

- Modular gameplay systems
- Explicit dependencies
- Reusable scenes and components
- Configurable gameplay values
- Multiplayer testability
- Automated builds and exports
- Isolated test and sandbox environments

---

## 2. Technology

The game should use:

- Godot 4.7.2 stable
- GDScript
- Godot's high-level multiplayer API
- A server-authoritative multiplayer model
- Web export for browser-based testing and distribution

The exact approved stable Godot version should be pinned consistently in the repository and CI pipeline.

Before development starts, verify that the intended version is available as a stable Godot release.

---

## 3. Repository Structure

```text
catchNrun/
├── addons/
├── assets/
│   ├── audio/
│   │   ├── music/
│   │   └── sfx/
│   ├── fonts/
│   └── textures/
│
├── autoloads/
│
├── src/
│   ├── components/
│   │   ├── health/
│   │   ├── hitbox/
│   │   ├── hurtbox/
│   │   ├── selectable/
│   │   ├── vision/
│   │   └── targeting/
│   │
│   ├── units/
│   │   ├── hunter/
│   │   ├── runner/
│   │   └── npc/
│   │
│   ├── buildings/
│   │   ├── crystal_mine/
│   │   ├── wall/
│   │   ├── tower/
│   │   └── hunter_shop/
│   │
│   ├── combat/
│   ├── construction/
│   ├── economy/
│   ├── inventory/
│   ├── items/
│   ├── navigation/
│   ├── selection/
│   ├── stats/
│   └── vision/
│
├── game/
│   ├── arena/
│   ├── camera/
│   ├── match/
│   ├── multiplayer/
│   └── sandbox/
│
├── ui/
│   ├── hud/
│   │   ├── health_bar/
│   │   ├── minimap/
│   │   ├── resources/
│   │   ├── selection_panel/
│   │   └── stats/
│   │
│   ├── menus/
│   ├── overlays/
│   └── widgets/
│
├── tests/
│   ├── integration/
│   ├── multiplayer/
│   ├── scenes/
│   └── bots/
│
├── scripts/
│   ├── build/
│   ├── export/
│   └── test/
│
├── docs/
│   ├── gameplay.README.md
│   ├── controls.README.md
│   ├── stats.README.md
│   ├── economy.README.md
│   ├── construction.README.md
│   ├── selection_panel.README.md
│   └── minimap.README.md
│
├── styles/
├── shaders/
├── project.godot
└── README.md
```

---

## 4. Folder Responsibilities

### `addons/`

Contains third-party or custom Godot editor plugins. Gameplay code should not be placed in this directory.

### `assets/`

Contains source assets used by the game, organized by asset type.

### `autoloads/`

Contains globally available Godot services. Possible autoloads include match state, multiplayer session management, configuration access, the scene transition manager, and audio management.

Autoloads should only be used for systems that genuinely require global lifetime or global access. Gameplay entities should not be implemented as autoloads.

### `src/components/`

Contains focused, reusable gameplay capabilities such as Health, Hitbox, Hurtbox, Selection, Vision, and Targeting.

```text
Runner
├── Health Component
├── Hurtbox Component
├── Selectable Component
├── Vision Component
└── Targeting Component
```

### `src/units/`

Contains playable and non-playable units. Each unit folder should keep the primary scene, scripts, and unit-specific resources together.

```text
src/units/hunter/
├── hunter.tscn
├── hunter.gd
├── hunter_config.tres
└── README.md
```

### `src/buildings/`

Contains constructible and interactive structures such as Crystal Mines, Walls, Towers, and the Hunter Shop.

### `src/combat/`

Contains attack execution, damage events, projectile handling, melee collision resolution, and area-of-effect resolution. Combat consumes values from the Stats system.

### `src/construction/`

Contains placement mode, previews, build-position validation, construction transactions, structure creation, and navigation updates.

### `src/economy/`

Contains Runner Crystal income, Hunter damage-based income, passive income, upgrade costs, and resource transactions.

### `src/navigation/`

Contains movement commands, path creation, path following, moving-target pursuit, and path updates when structures change navigation.

### `src/selection/`

Contains entity selection and selection-state management. It determines what is selected but does not implement the Selection Panel UI.

### `src/stats/`

Contains stat definitions, modifiers, constraints, and final-value calculation.

### `src/vision/`

Contains vision range, team vision, fog-of-war state, explored areas, and last-known entity information.

### `game/`

Contains the scenes and coordinators that assemble gameplay systems into an actual match.

### `ui/`

Contains presentation logic. UI may display state and emit user intent, but it does not own gameplay rules.

```text
Selection Panel
-> Displays Crystal Mine upgrade cost

Economy System
-> Owns and validates Crystal Mine upgrade cost
```

### `tests/`

Contains integration scenes, multiplayer tests, automated test fixtures, and bot clients.

### `scripts/`

Contains shell scripts and automation used outside the game runtime, including test launchers and export scripts.

### `docs/`

Contains authoritative game and system specifications for developers and AI coding agents.

---

## 5. Architectural Principles

### 5.1. Keep Scenes and Scripts Together

A scene and its primary script should normally be stored in the same feature directory.

```text
wall/
├── wall.tscn
├── wall.gd
├── wall_config.tres
└── README.md
```

Small entity-specific assets may also be stored there. Reusable assets remain under `assets/`.

### 5.2. Connect Signals Explicitly in Code

Signals should be connected explicitly in code instead of relying on hidden editor connections.

```gdscript
func _ready() -> void:
    health_component.health_changed.connect(_on_health_changed)
    health_component.died.connect(_on_died)
```

Signal emitters should not directly update unrelated UI components.

```text
Health Component
-> Emits health_changed

Unit / Presenter
-> Receives health_changed

HUD
-> Updates displayed health
```

### 5.3. Configure Runtime UI Through Code and Data

Runtime values and dependencies should be assigned through code or data rather than existing only inside `.tscn` scenes.

Examples include selected entities, health, Crystals, costs, button states, and tooltip content.

Visual defaults, styles, anchors, and layout may still be configured in the editor.

### 5.4. Keep Gameplay Logic Out of UI

UI components may display state, emit user intent, and request gameplay actions.

UI components should not calculate income, apply damage, validate building placement, modify stats directly, or determine fog-of-war visibility.

```text
Upgrade Button Pressed
-> Emit upgrade request
-> Economy / Construction system validates request
-> Upgrade is applied
-> Entity state changes
-> Selection Panel refreshes
```

### 5.5. Prefer Composition Over Deep Inheritance

```text
Runner
├── Health
├── Stats
├── Movement
├── Selection
├── Vision
└── Construction

Hunter
├── Health
├── Stats
├── Movement
├── Selection
├── Vision
├── Inventory
└── Combat

Wall
├── Health
├── Hurtbox
├── Selection
└── Navigation Obstacle
```

### 5.6. Use Data-Driven Configuration

Balance values should be stored as configurable resources rather than scattered across scripts and scenes.

```text
runner_head_start_duration
crystal_generation_interval
hunter_crystals_per_damage
wall_health_per_level
tower_damage_per_level
vision_range
```

### 5.7. Separate Authoritative State From Presentation

Authoritative gameplay state must exist independently of UI components.

```text
Gameplay State
-> Exists independently

UI
-> Observes and displays gameplay state
```

---

## 6. Godot Game Application

### 6.1. Game Type

CatchNRun is a 2D, top-down, asymmetric, team-based multiplayer game with Runner and Hunter teams.

### 6.2. Session Scenes

The session is three separate scenes. Who may leave a scene, and how roles are resolved, is defined in `gameplay.README.md`.

```text
s0  Lobby            ui/lobby/lobby.tscn
s1  Role Selection   ui/role_selection/role_selection.tscn
s2  Game             game/match/match.tscn
```

```text
s0 Lobby
-> s1 Role Selection
-> s2 Game
```

The game scene assembles the match. It does not implement every gameplay rule itself.

```text
Game
├── Match
├── Arena
├── Camera
├── HUD
└── Debug Tools
```

### 6.3. Scene Transition Manager

`SceneTransitionManager` is an autoload. It is the only code that changes the current session scene.

The caller passes both scenes:

```text
transition(from, to)

from
-> The scene the players are leaving

to
-> The scene the players are opening
```

```text
Lobby continues
-> transition(lobby, role_selection)

Role selection is resolved
-> transition(role_selection, game)
```

The manager checks that `from` is the scene currently open, then opens `to` on every connected peer. It does not assign roles, start the preparation timer, or apply gameplay rules.

A scene may also be opened directly, with no previous scene, so it can be tested on its own. In that case `from` is empty.

### 6.4. Match System

Inside the game scene, match states include:

```text
Runner Preparation
-> Hunter Active
-> Match Finished
```

The match system owns the Runner head-start timer, Hunter spawn, elimination, and win/loss conditions. Role resolution happens on the role selection screen before the transition into this scene.

### 6.5. Scene Organization

Gameplay entities should have independently testable scenes where practical.

```text
lobby.tscn
role_selection.tscn
game / match.tscn
hunter.tscn
runner.tscn
wall.tscn
tower.tscn
crystal_mine.tscn
hunter_shop.tscn
arena.tscn
```

---

## 7. Multiplayer Architecture

### 7.1. Networking Model

Use Godot's high-level multiplayer API. The initial implementation supports one host, multiple clients, localhost testing, role assignment, state synchronization, player/structure interaction, and basic disconnect handling.

A complex public lobby is not required initially.

### 7.2. Server Authority

The host acts as the authoritative server and validates movement, attacks, damage, Crystal transactions, construction, upgrades, purchases, and match-state changes.

Clients send intent rather than directly assigning authoritative state.

```text
Client
-> Requests Wall Construction

Server
-> Validates position
-> Validates Crystal balance
-> Deducts Crystals
-> Creates Wall
-> Synchronizes result
```

### 7.3. Local Multiplayer Test

```text
Host
-> Creates local game

Client 1
-> Connects through localhost

Client 2
-> Connects through localhost

Bot Client
-> Connects through localhost
```

### 7.4. Initial Scope Exclusions

The initial implementation does not require public matchmaking, accounts, ranked play, persistent online profiles, a complex lobby browser, or dedicated public infrastructure.

---

## 8. Sandbox and Test Scenes

### 8.1. Development Sandbox

A sandbox or god-mode scene should allow developers to:

- Select Hunter or Runner
- Spawn units and structures
- Modify Crystals and stats
- Apply damage and healing
- Change structure levels
- Start or skip the preparation timer
- Toggle fog of war
- Reveal the map
- Test vision ranges
- Destroy selected entities
- Switch multiplayer roles where practical

The sandbox must not be available in production builds unless explicitly enabled.

### 8.2. Component Test Scenes

```text
health_component_test.tscn
hitbox_hurtbox_test.tscn
stats_test.tscn
selection_test.tscn
vision_test.tscn
construction_test.tscn
```

### 8.3. Multiplayer Test Scene

The multiplayer test scene should support creating a host, connecting local clients, assigning roles, spawning synchronized players, moving, attacking, building, and synchronizing health/resources.

### 8.4. Independent Scene Tests

Every session screen can be run and tested without playing through the screens before it.

```text
Lobby
-> Host, join, show the connected players, and continue

Role Selection
-> Show Runners on the left and the Hunter on the right
-> Accept a side from each player
-> Resolve several Hunter requests by random choice
-> Continue to the game

Game
-> Start from roles supplied by the test
-> Run preparation, the delayed Hunter spawn, and movement
```

Systems inside the game have their own test scenes as well. A test scene supplies only the state that system needs. It does not open the lobby or the role selection screen first.

```text
combat_test.tscn
item_shop_test.tscn
building_test.tscn
```

The same rule applies to the other gameplay systems: each one can be exercised on its own before it is wired into the full session.

---

## 9. Bot Clients

Bot clients provide repeatable multiplayer tests and initially require only simple deterministic behavior.

Capabilities may include:

- Connect to host
- Join match
- Accept assigned role
- Move to configured positions
- Attack configured targets
- Build configured structures
- Remain connected for a defined duration
- Disconnect cleanly

Bots help validate simultaneous connections, synchronization, RPC behavior, spawning, replication, disconnect handling, and basic server performance.

---

## 10. Test Pipeline

### 10.1. Project Validation

Validate that the project loads, scripts parse, required scenes import, expected autoloads exist, and configuration files are present.

### 10.2. Automated Tests

Critical tests include:

- Stat calculations
- Damage and health
- Crystal generation and spending
- Construction validation
- Structure upgrades
- Hunter damage-based income
- Match-state transitions
- Visibility-state transitions

### 10.3. Multiplayer Integration Tests

Start one host, one or more clients, and optional bot clients.

Verify connections, spawns, roles, server command handling, authoritative synchronization, consistent client outcomes, and clean disconnect behavior.

Use explicit timeouts so a failed process cannot block the pipeline indefinitely.

---

## 11. Build and Deployment Pipeline

### 11.1. Export Script

A Bash script should generate exports automatically.

```text
scripts/export/export.sh
```

The script should verify Godot availability, import the project if needed, run required tests, create exports, write to a predictable output directory, and return a non-zero exit code on failure.

### 11.2. Web Export

The game should support a browser-compatible Godot Web export.

```text
build/
└── web/
    ├── index.html
    ├── game.js
    ├── game.wasm
    └── game.pck
```

Exact filenames depend on the Godot export configuration. Store the Web export preset in `export_presets.cfg`.

### 11.3. Build Artifacts

Generated exports should normally be published as pipeline artifacts rather than committed to source control.

Artifacts may include the Web build, test reports, multiplayer logs, and import/export logs.

### 11.4. Pipeline Order

```text
Checkout Repository
-> Verify Godot Version
-> Import Project
-> Validate Scripts and Scenes
-> Run Automated Tests
-> Run Multiplayer Integration Tests
-> Generate Web Export
-> Publish Build Artifacts
```

---

## 12. Documentation Rules

Each major system should have one authoritative specification.

```text
docs/
├── gameplay.README.md
├── controls.README.md
├── stats.README.md
├── economy.README.md
├── construction.README.md
├── vision.README.md
├── selection-panel.README.md
└── minimap.README.md
```

Each specification should define responsibilities, rules, inputs, outputs, configurable parameters, interactions, and important edge cases.

Avoid defining the same rule differently in multiple files. Reference the authoritative specification instead of duplicating complete definitions.
