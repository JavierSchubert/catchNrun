# Selection Panel

## 1. Overview

The **Selection Panel** is the contextual HUD element for the currently selected entity.

It is displayed at the bottom of the screen when a selectable entity is selected.

The panel has two responsibilities:

1. Display information about the selected entity.
2. Display contextual actions that the local player is allowed to perform for that entity.

The Selection Panel does not own gameplay rules. It reads entity state, capabilities, team / ownership information, and available actions from the relevant gameplay systems.

## 2. Layout

The Selection Panel sits at the bottom of the screen while an entity is selected.

| Section | Position | Purpose |
| --- | --- | --- |
| Portrait | Left | Circular crop of the selected entity's image / sprite |
| Entity Info | Right of portrait | Name, type, health, and relevant stats |
| Context Action Panel | Further right (later) | Available contextual actions |

```text
Selection Panel (bottom of screen)
├── Circular Portrait
│   └── Selected entity sprite / icon
├── Entity Info
│   ├── Name
│   ├── Entity Type
│   ├── Health
│   └── Relevant Stats / Properties
│
└── Context Action Panel (optional / later)
    └── Actions available for the selected entity
```

Minimal visual-test layout: circular portrait + stats. Context actions can be added without changing the portrait / info strip.

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
Runner
Health          85 / 100
Movement Speed  5.0
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

- Hide the Selection Panel or show an empty state.
- Show no entity information.
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
