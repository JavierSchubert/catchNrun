# Gameplay

## 1. Game Overview

The game is an asymmetric team-based strategy and survival game with two opposing teams:

- **Runner Team**
- **Hunter Team**

Runners receive a preparation head start. During this time they build an economy and defenses before the Hunter enters the map.

The Hunter must break through those defenses and eliminate the Runners.

```text
Runner Team
-> Generate Crystals
-> Build and upgrade defenses
-> Protect territory and survive

Hunter Team
-> Spawn after the head start
-> Hunt and deal damage
-> Earn Crystals
-> Buy stat upgrades
-> Break defenses
-> Eliminate Runners
```

## 2. Teams and Match Flow

### 2.1. Runner Team

Runners can:

- Move and explore.
- Generate Crystals through Crystal Mines.
- Construct Walls, Towers, and Crystal Mines.
- Upgrade structures.
- Reposition when defenses are breached.

### 2.2. Hunter Team

The Hunter can:

- Move and explore.
- Attack Runners and Runner structures.
- Destroy Walls, Towers, and Crystal Mines.
- Earn Crystals by dealing damage.
- Receive lower passive Crystal income from the central Hunter Shop / base.
- Spend Crystals on items and stat improvements.

### 2.3. Runner Head Start

The initial preparation duration is configurable.

```text
runner_head_start_duration = 60.0
```

During this period the Runners can establish their economy and defenses. The Hunter has not yet spawned and therefore cannot attack them.

When the timer expires:

```text
Runner Head Start Ends
-> Hunter Spawns
-> Hunter Gameplay Begins
```

## 3. Runner Gameplay Loop

```text
Generate Crystals
-> Invest in Economy or Defenses
-> Build / Upgrade Structures
-> Delay the Hunter
-> Generate More Crystals
-> Strengthen Defenses
```

Runners must balance long-term economy against immediate defensive strength.

Initial Runner structures are:

| Structure | Primary Purpose |
| --- | --- |
| Crystal Mine | Crystal generation |
| Wall | Path blocking and defense |
| Tower | Defensive offense |

Structures have health and can be attacked and destroyed by the Hunter.

## 4. Hunter Gameplay Loop

```text
Find Runner Defenses
-> Deal Damage
-> Earn Crystals
-> Purchase Upgrades
-> Increase Hunter Power
-> Break Stronger Defenses
-> Reach and Eliminate Runners
```

The Hunter becomes stronger through active combat and purchases made with earned Crystals.

## 5. Health and Destruction

Runners and destructible structures have health.

```text
current_health -= damage
```

When health reaches zero:

```text
current_health <= 0
-> Runner is eliminated
-> Structure is destroyed
```

Detailed stat and damage calculation belongs to the Stats and Combat systems.

## 6. Vision and Information

The map uses fog of war. Hunter and Runner teams can only observe the world within their available vision.

Information can exist in three states:

```text
Unexplored
Currently Visible
Previously Seen
```

Previously seen information is not updated again until the relevant area or entity becomes visible.

Detailed visibility rules belong to `vision.README.md`.

## 7. Configurable Gameplay Parameters

Values expected to require balancing must be configurable instead of hard-coded into unrelated gameplay or UI logic.

Examples include:

```text
runner_head_start_duration
crystal_generation_interval
crystal_mine_upgrade_costs
wall_health_per_level
wall_upgrade_costs
tower_health_per_level
tower_upgrade_costs
hunter_crystals_per_damage
hunter_passive_crystal_income
hunter_passive_income_interval
vision_range
```

## 8. System Boundaries

This document defines the high-level game rules. Detailed behavior belongs to dedicated specifications.

```text
Gameplay
├── Teams
├── Match Flow
├── Objectives
├── Runner Gameplay Loop
└── Hunter Gameplay Loop

Stats
├── Character Stats
└── Stat Modifiers

Controls
├── Selection
├── Movement / Attack Commands
├── Camera
└── Cursor Feedback

Economy
├── Crystals
├── Crystal Mine Progression
├── Hunter Damage Income
└── Passive Income

Construction
├── Placement
├── Walls
├── Towers
├── Crystal Mines
└── Structure Upgrades

Vision
├── Team Vision
├── Fog of War
└── Last-Known Information

UI
├── Selection Panel
├── Build UI
├── Hunter Shop
└── Minimap
```

# TODO: add that only one crystal mine can be build. Runners can upgrade their walls and towers. Hunter can also die through the damage of towers