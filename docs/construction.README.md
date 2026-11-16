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

```text
Select Structure
-> Enter Placement Mode
-> Show Placement Preview
-> Validate Position
-> Left Click Valid Position
-> Spend Required Crystals
-> Create Structure
-> Exit Placement Mode
```

Invalid placement must not spend resources or create the structure.

Placement validation may consider:

- Map boundaries.
- Navigable / buildable terrain.
- Existing structures.
- Required spacing.
- Other gameplay-specific restrictions.

Exact placement rules can be extended as the map design develops.

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

Destroying a Wall must update navigation so that previously blocked paths can become available.

## 5. Towers

Towers provide offensive defense for the Runner Team.

Towers:

- Have health.
- Can be attacked and destroyed by the Hunter.
- Acquire valid Hunter targets according to their targeting rules.
- Attack according to their configured attack behavior.
- May be upgradeable.

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
Structure takes damage
-> Reduce current health

current_health <= 0
-> Destroy structure
-> Remove gameplay functionality
-> Update navigation / world state where required
```

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
Wall Upgrade         -> Structure / health configuration
Tower Upgrade        -> Structure / combat configuration
```
