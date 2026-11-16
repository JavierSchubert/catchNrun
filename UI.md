# Selection Panel

## Overview

The **Selection Panel** is the main contextual HUD element for the currently selected entity.

It is displayed at the **bottom of the screen** whenever the player selects an entity such as:

- a character
- a unit
- a building
- an interactive object

The panel provides two main types of information:

1. **Entity Information**

Displays information about the currently selected entity.

1. **Contextual Actions**

Displays commands and actions that are available for the selected entity.

The Selection Panel must dynamically update whenever the player's selection changes.

---

## Layout

The Selection Panel is divided into two main sections:

| Section | Position | Purpose |
| --- | --- | --- |
| Entity Info Panel | Left | Displays information about the selected entity |
| Command Panel | Right | Displays available contextual actions |

Conceptually:

```text
┌─────────────────────────────────────────────────────────────┐

│                     SELECTION PANEL                         │

│                                                             │

│  ENTITY INFO                         COMMAND PANEL           │

│                                                             │

│  [Portrait]                          [Action] [Action]       │

│  Entity Name                         [Action] [Action]       │

│                                                             │

│  Health                                                     │

│  Damage                                                     │

│  Defense                                                    │

│  Movement Speed                                             │

│                                                             │

└─────────────────────────────────────────────────────────────┘
```

---

# Entity Info Panel

The **Entity Info Panel** is located on the left side of the Selection Panel.

It displays the identity and important gameplay information of the currently selected entity.

## General Information

The panel should display:

- Entity portrait or icon
- Entity name
- Entity type
- Current health
- Maximum health

Example:

```text
[Portrait]
Swordsman
Health
85 / 100
```

---

## Stats

The Entity Info Panel displays the most important stats relevant to the selected entity.

Possible stats include:

- Health
- Damage
- Defense
- Movement Speed
- Attack Speed
- Attack Range

Not every entity must display every stat.

Only stats that are meaningful for the selected entity should be displayed.

### Example: Character

```text
Knight

Health          120 / 150
Damage          24
Defense         12
Movement Speed  5.0
Attack Speed    1.2
```

### Example: Building

```text
Barracks
Health          800 / 1000
Defense         25
```

A building does not display Movement Speed because the stat is not relevant.

---

# Command Panel

The **Command Panel** is located on the right side of the Selection Panel.

It contains contextual actions available for the currently selected entity.

The available actions depend on:

- entity type
- entity capabilities
- ownership
- current entity state
- player resources
- game state

Actions should be represented as buttons with recognizable icons.

Where useful, buttons should display additional information such as:

- resource cost
- cooldown
- hotkey
- remaining charges
- production time

---

# Ownership Rules

The Selection Panel distinguishes between **player-owned** and **non-player-owned** entities.

## Player-Owned Entity

If the selected entity belongs to the player:

- Display Entity Info.
- Display available commands.
- Display abilities.
- Display production or construction actions where applicable.

## Non-Player Entity

If the selected entity does not belong to the player:

- Display Entity Info.
- Do not display commands that would allow the player to control the entity.
- Do not display production or construction controls.

The player may still see information about the entity if that information is intended to be visible by the game rules.

---

# Contextual Actions

Actions should be determined by entity capabilities rather than hard-coded only by entity type.

Examples:

## Character / Unit

Possible commands:

- Move
- Attack
- Stop
- Hold Position
- Patrol

Possible abilities:

- Active abilities
- Spells
- Special attacks

Example:

```text
Swordsman

[Move] [Attack] [Stop]

[Ability 1] [Ability 2]
```

---

## Worker / Builder

A worker may additionally expose a **Build Menu**.

Example:

```text
Worker

[Move] [Attack] [Stop]

[Build]
```

Selecting Build opens the available construction options:

```text
BUILD

[Barracks]

[Tower]

[House]

[Workshop]
```

Each construction option should show its resource cost.

Unavailable buildings remain visible but disabled if the player does not fulfill their requirements.

---

## Production Building

Production buildings expose a **Production Menu** or **Training Menu**.

Example:

```text
Barracks
    |
[Train Swordsman]
    |
[Train Archer]
    |
[Train Pikeman]
```

Each unit button should display:

- unit icon
- resource cost
- production time

Selecting a unit adds it to the building's production queue.

---

# Production Queue

Buildings capable of producing units should display their current production queue.

Example:

```text
Barracks
    |
Production
    |
[Swordsman]  70%
    |
[Archer]
    |
[Archer]
```

The currently produced unit should display production progress.

Queued units should display their order in the queue.

If supported by the game rules, the player should be able to cancel queued production.

---

# Button States

Every command button can have one of the following states:

## Available

The action can currently be performed.

## Hovered

The cursor is currently over the action.

A tooltip should explain the action and relevant information.

Example:

```text
Train Swordsman
Cost: 100 Gold
Training Time: 15 s
```

## Disabled

The action exists but cannot currently be performed.

Possible reasons include:

- insufficient resources
- missing prerequisite
- ability on cooldown
- invalid entity state
- production queue full

Disabled actions should remain visible when useful for communicating progression or requirements.

## Active

Used for commands or abilities that are currently active or toggled.

Examples:

- Hold Position
- Auto Cast
- Build Mode

---

# Selection Behavior

## No Selection

If no entity is selected:

- Hide the Selection Panel or display its empty state.
- Do not display Entity Info.
- Do not display contextual commands.

## Single Selection

If exactly one entity is selected:

- Display its Entity Info.
- Display its available contextual actions.

## Selection Changed

When another entity is selected:

1. Clear the previous entity information.
2. Load the newly selected entity.
3. Update the Entity Info Panel.
4. Determine available commands.
5. Update the Command Panel.

The UI should update immediately.

---

# Design Principle

The Selection Panel should be **data-driven and capability-driven**.

The UI should not contain separate hard-coded implementations for every individual entity.

Instead, entities expose:

- their display information
- their relevant stats
- their available commands
- their abilities
- their production capabilities
- their construction capabilities

The Selection Panel reads these capabilities and dynamically builds the appropriate interface.

For example:

```text
Swordsman
├── Selectable
├── Movable
├── Attackable
└── AbilityUser

Worker
├── Selectable
├── Movable
├── Attackable
└── Builder

Barracks
├── Selectable
└── UnitProducer
```

This allows new entity types to integrate into the Selection Panel without requiring a completely new UI implementation.

---

# UI Hierarchy

The intended conceptual hierarchy is:

```text
HUD
│
└── Selection Panel
    │
    ├── Entity Info Panel
    │   ├── Portrait
    │   ├── Entity Name
    │   ├── Health
    │   └── Stats
    │
    └── Command Panel
        ├── Core Commands
        ├── Abilities
        ├── Build Menu
        ├── Production Menu
        └── Production Queue
```

Only components supported by the currently selected entity should be displayed.

---

# Implementation Requirement

The Selection Panel must be designed as a reusable HUD system.

Adding a new entity should generally require defining the entity's data and capabilities rather than modifying the Selection Panel itself.

Avoid entity\-specific UI logic such as:

if selected\_entity == barracks

if selected\_entity == worker

if selected\_entity == swordsman

Prefer capability\-based behavior such as:

if entity is movable

    show movement commands

if entity has abilities

    show ability commands

if entity can build

    show build menu

if entity can produce units

    show production menu

    show production queue

This separation should be preserved as the number of units, buildings, abilities, and production options increases.

