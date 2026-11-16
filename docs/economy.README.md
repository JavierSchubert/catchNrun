# Economy

## 1. Overview

Crystals are the primary resource for both teams, but each team generates and spends them differently.

```text
Runner Economy
-> Crystal Mines
-> Economy / Structure Upgrades
-> Defensive Construction

Hunter Economy
-> Damage Dealt
-> Lower Passive Income
-> Hunter Stat / Item Upgrades
```

## 2. Runner Crystal Economy

### 2.1. Crystal Mines

Crystal Mines periodically generate Crystals for the Runner Team.

The generation interval is configurable.

```text
crystal_generation_interval = 2.0
```

A level 1 mine starts with:

```text
1 Crystal / tick
```

Mine output doubles with each level:

| Mine Level | Crystals / Tick |
| ---: | ---: |
| 1 | 1 |
| 2 | 2 |
| 3 | 4 |
| 4 | 8 |
| 5 | 16 |
| 6 | 32 |
| 7 | 64 |
| 8 | 128 |
| 9 | 256 |
| 10 | 512 |
| 11 | 1024 |
| 12 | 2048 |

Conceptually:

```text
crystals_per_tick = 2^(mine_level - 1)
```

Upgrade costs must be configurable. An early upgrade may initially cost `16` Crystals, but balance values should not be embedded into UI logic.

### 2.2. Runner Spending

Runner Crystals can be spent on:

- Crystal Mine upgrades.
- Walls.
- Wall upgrades.
- Towers.
- Tower upgrades.
- Future Runner structures or improvements.

This creates a trade-off between economy and immediate defense.

## 3. Hunter Crystal Economy

### 3.1. Damage-Based Income

The Hunter earns Crystals by dealing damage to valid Runner targets.

Initial balancing may use:

```text
hunter_crystals_per_damage = 1.0
```

Conceptually:

```text
crystals_earned = damage_dealt * hunter_crystals_per_damage
```

Valid damage targets include:

- Runners.
- Walls.
- Towers.
- Crystal Mines.
- Other valid Runner structures.

The conversion factor must remain configurable because damage-based progression can create a strong snowball effect.

### 3.2. Passive Hunter Income

The Hunter additionally receives passive Crystal income associated with the central Hunter Shop / base.

This income must be lower than a developed Runner Crystal Mine economy so that active combat remains the Hunter's primary progression source.

Both values are configurable:

```text
hunter_passive_crystal_income
hunter_passive_income_interval
```

## 4. Hunter Shop and Spending

The Hunter spends Crystals on items or upgrades that modify existing character stats.

Potential upgrades include:

- Maximum Health.
- Health Regeneration.
- Defense.
- Movement Speed.
- Melee Damage.
- Ranged Damage.
- Magic Damage.
- Critical Chance.
- Critical Damage Multiplier.
- Lifesteal Chance.
- Lifesteal Amount.

Conceptually:

```text
Hunter earns Crystals
-> Hunter Shop
-> Purchase Item / Upgrade# Economy

## 1. Overview

Crystals are the primary resource for both teams, but each team generates and spends them differently.

```text
Runner Economy
-> Crystal Mines
-> Economy / Structure Upgrades
-> Defensive Construction

Hunter Economy
-> Damage Dealt
-> Lower Passive Income
-> Hunter Stat / Item Upgrades
```

## 2. Runner Crystal Economy

### 2.1. Crystal Mines

Crystal Mines periodically generate Crystals for the Runner Team.

The generation interval is configurable.

```text
crystal_generation_interval = 2.0
```

A level 1 mine starts with:

```text
1 Crystal / tick
```

Mine output doubles with each level:

| Mine Level | Crystals / Tick |
| ---: | ---: |
| 1 | 1 |
| 2 | 2 |
| 3 | 4 |
| 4 | 8 |
| 5 | 16 |
| 6 | 32 |
| 7 | 64 |
| 8 | 128 |
| 9 | 256 |
| 10 | 512 |
| 11 | 1024 |
| 12 | 2048 |

Conceptually:

```text
crystals_per_tick = 2^(mine_level - 1)
```

Upgrade costs must be configurable. An early upgrade may initially cost `16` Crystals, but balance values should not be embedded into UI logic.

### 2.2. Runner Spending

Runner Crystals can be spent on:

- Crystal Mine upgrades.
- Walls.
- Wall upgrades.
- Towers.
- Tower upgrades.
- Future Runner structures or improvements.

This creates a trade-off between economy and immediate defense.

## 3. Hunter Crystal Economy

### 3.1. Damage-Based Income

The Hunter earns Crystals by dealing damage to valid Runner targets.

Initial balancing may use:

```text
hunter_crystals_per_damage = 1.0
```

Conceptually:

```text
crystals_earned = damage_dealt * hunter_crystals_per_damage
```

Valid damage targets include:

- Runners.
- Walls.
- Towers.
- Crystal Mines.
- Other valid Runner structures.

The conversion factor must remain configurable because damage-based progression can create a strong snowball effect.

### 3.2. Passive Hunter Income

The Hunter additionally receives passive Crystal income associated with the central Hunter Shop / base.

This income must be lower than a developed Runner Crystal Mine economy so that active combat remains the Hunter's primary progression source.

Both values are configurable:

```text
hunter_passive_crystal_income
hunter_passive_income_interval
```

## 4. Hunter Shop and Spending

The Hunter spends Crystals on items or upgrades that modify existing character stats.

Potential upgrades include:

- Maximum Health.
- Health Regeneration.
- Defense.
- Movement Speed.
- Melee Damage.
- Ranged Damage.
- Magic Damage.
- Critical Chance.
- Critical Damage Multiplier.
- Lifesteal Chance.
- Lifesteal Amount.

Conceptually:

```text
Hunter earns Crystals
-> Hunter Shop
-> Purchase Item / Upgrade
-> Apply Stat Modifier
-> Hunter becomes stronger
```

The shop must use the Stats system instead of implementing separate stat calculations.

## 5. Economy Configuration

Economy balance data should be configurable and centralized.

Examples:

```text
crystal_generation_interval
crystals_per_mine_level
crystal_mine_upgrade_costs
wall_costs
wall_upgrade_costs
tower_costs
tower_upgrade_costs
hunter_crystals_per_damage
hunter_passive_crystal_income
hunter_passive_income_interval
hunter_shop_item_costs
```

UI components display economy values but do not own or calculate the economy rules.

-> Apply Stat Modifier
-> Hunter becomes stronger
```

The shop must use the Stats system instead of implementing separate stat calculations.

## 5. Economy Configuration

Economy balance data should be configurable and centralized.

Examples:

```text
crystal_generation_interval
crystals_per_mine_level
crystal_mine_upgrade_costs
wall_costs
wall_upgrade_costs
tower_costs
tower_upgrade_costs
hunter_crystals_per_damage
hunter_passive_crystal_income
hunter_passive_income_interval
hunter_shop_item_costs
```

UI components display economy values but do not own or calculate the economy rules.
