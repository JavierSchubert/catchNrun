# Selection Panel

## 1. Overview

The **Selection Panel** is the contextual HUD element for the currently selected entity.

It is displayed at the bottom of the screen when a selectable entity is selected.

The panel has two responsibilities:

1. Display information about the selected entity.
2. Display contextual actions that the local player is allowed to perform for that entity.

The Selection Panel does not own gameplay rules. It reads entity state, capabilities, team / ownership information, and available actions from the relevant gameplay systems.

## 2. Layout

The Selection Panel is a **fixed-size** bottom HUD strip (`520×148`). Selection vs empty must not change the panel size.

| Section | Position | Purpose |
| --- | --- | --- |
| Portrait ring | Left | Circular crop of the selected unit sprite; empty ring when nothing is selected |
| Combat stats | Right of portrait | Two columns of icon + value rows |
| Health bar | Under stats | Fill = current / max health; `+regen` only when not full |

```text
Selection Panel (fixed size)
├── Portrait ring (always; sprite only when a unit is selected)
└── Right column (only when a unit is selected)
    ├── Stats grid (2 columns)
    │   ├── Damage          Crit Chance
    │   ├── Defense         Lifesteal Chance
    │   └── Attack Speed    Movement Speed
    └── Health bar [////////////] +regen
```

Stat values use `base (+delta)` with green / red BBCode for the modifier. Icons come from `assets/sprites/stats/clean/` via `StatIcons`.

Empty selection: grey panel + empty portrait ring only (no stats, no health bar).

### 2.1. Scene / style resources

```text
ui/hud/selection_panel/selection_panel.tscn
ui/hud/selection_panel/selection_panel_style.tres
ui/hud/selection_panel/selection_ring_style.tres
src/stats/stat_icons.gd
assets/sprites/stats/clean/
```

Instanced by `game/match/hud.tscn`. The panel script is `@tool` so StyleBox `@export` changes refresh in the editor.

## 3. Selectable Entities

Selectable entities may include:

- Runners.
- Hunter.
- NPCs.
- Crystal Mines.
- Walls.
- Towers.
- Other future selectable structures or objects.

Selection and click handling are defined by the Controls system.

## 4. Entity Information

The panel should show information relevant to the selected entity.

Common information includes:

- Portrait or icon.
- Entity name.
- Entity type.
- Current health.
- Maximum health.

Additional values depend on the entity.

### Character Example

```text
[portrait]  Damage 10          Crit 0%
            Defense 0          Lifesteal 0%
            Atk Spd 1.3        Move 220
            [======== HP bar ========] +2
```

### Wall Example

```text
Wall
Health          850 / 1000
Level           3
```

### Crystal Mine Example

```text
Crystal Mine
Health          450 / 500
Level           4
Generation      8 Crystals / tick
```

Only meaningful information should be displayed. A Wall, for example, does not need Movement Speed.

## 5. Team and Control Rules

The panel distinguishes between entities the local player can control and entities that are only observable.

For entities controlled by the local player or team:

- Display permitted entity information.
- Display available contextual actions.
- Display upgrades or abilities where applicable.

For opposing entities:

- Display only information permitted by game and vision rules.
- Do not display commands that would control the opposing entity.
- Do not expose hidden information that the player's team is not allowed to know.

## 6. Context Actions

Actions are based on capabilities and current game state.

Examples include:

### Runner

Possible actions may include:

- Build.
- Runner-specific abilities added later.

### Runner Structure

Possible actions may include:

- Upgrade Crystal Mine.
- Upgrade Wall.
- Upgrade Tower.
- Other structure-specific actions.

### Hunter

Hunter progression actions are primarily handled through the Hunter Shop interface. If Hunter-specific contextual actions are added later, they can be exposed through the same capability-driven action model.

## 7. Button States

Context action buttons may have the following states:

### Available

The action can currently be performed.

### Hovered

The cursor is over the action. A tooltip may display relevant details such as cost, effect, or requirements.

### Disabled

The action exists but cannot currently be performed.

Reasons may include:

- Insufficient Crystals.
- Missing prerequisite.
- Invalid entity state.
- Maximum upgrade level reached.
- Other gameplay restrictions.

Disabled actions may remain visible when useful for communicating requirements.

### Active

Used for actions or modes that are currently active or toggled.

## 8. Selection Behavior

### No Selection

If no entity is selected:

- Keep the fixed-size grey panel visible.
- Show the empty portrait ring (no sprite).
- Hide stats and the health bar.
- Show no contextual actions.

### Single Selection

If one entity is selected:

- Display permitted Entity Info.
- Determine currently available contextual actions.
- Update the Context Action Panel.

### Selection Changed

```text
New Entity Selected
-> Clear previous presentation state
-> Load selected entity information
-> Apply visibility / team rules
-> Determine available capabilities and actions
-> Update Entity Info Panel
-> Update Context Action Panel
```

The UI should update immediately.

## 9. Data- and Capability-Driven Design

The Selection Panel should not contain separate hard-coded UI implementations for individual entity instances.

Conceptually:

```text
Runner
├── Selectable
├── Movable
├── Attack Capabilities
└── Builder

Hunter
├── Selectable
├── Movable
└── Attack Capabilities

Crystal Mine
├── Selectable
├── Destructible
├── Crystal Generator
└── Upgradeable

Wall
├── Selectable
├── Destructible
└── Upgradeable

Tower
├── Selectable
├── Destructible
├── Attack Capabilities
└── Upgradeable
```

These are conceptual capabilities, not mandatory Godot class or group names.

The Selection Panel reads the relevant capabilities and state and builds the appropriate interface.

## 10. Responsibility Boundary

The Selection Panel presents data but does not own it.

```text
Stats System
-> Provides character stat values

Economy System
-> Provides Crystal costs and generation values

Construction System
-> Provides structure and upgrade actions

Vision System
-> Determines which information is known / visible

Controls / Selection
-> Determines the currently selected entity

Selection Panel
-> Presents permitted information and contextual actions
```

Adding a new entity should generally require exposing the entity's data and capabilities rather than adding a completely new Selection Panel implementation.
