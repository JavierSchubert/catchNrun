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

Every player starts a match with:

```text
starting_crystals = 20
```

The numbers in this document mirror the balance resources; when they disagree, the resources win:

- `src/economy/economy_config.tres` — match-wide values (starting Crystals, Hunter damage income).
- `src/buildings/defs/crystal_mine_def.tres`, `wall_def.tres`, `tower_def.tres` — per-structure cost, HP, build time, and level data.

## 2. Runner Crystal Economy

### 2.1. Crystal Mines and Structure Baseline

Crystal Mines periodically generate Crystals for the owning Runner.

The generation interval is configurable (`mine_interval` in `crystal_mine_def.tres`):

```text
mine_interval = 2.0 seconds
```

A level 1 mine produces 2 Crystals per tick. Output doubles with each level and stops at level 11, the mine's maximum level:

| Mine Level | Crystals / Tick |
| ---: | ---: |
| 1 | 2 |
| 2 | 4 |
| 3 | 8 |
| 4 | 16 |
| 5 | 32 |
| 6 | 64 |
| 7 | 128 |
| 8 | 256 |
| 9 | 512 |
| 10 | 1024 |
| 11 | 2048 |

Conceptually:

```text
crystals_per_tick = min(mine_base_output * 2^(mine_level - 1), mine_max_output)
                  = min(2 * 2^(mine_level - 1), 2048)
```

A mine keeps producing while it is being upgraded.

Structure costs grow by the same factor for every type. The cost of a level is paid both to build level 1 and to upgrade into each later level:

```text
cost(level) = base_cost * cost_growth^(level - 1)
```

| Structure | Level 1 cost | `cost_growth` | Max level |
| --- | ---: | ---: | ---: |
| Crystal Mine | 16 | ×1.8 | 11 |
| Wall | 8 | ×1.8 | 20 |
| Tower | 24 | ×1.8 | 20 |

Upgrade-specific rules:

- **Wall** — from level 15 (`shield_unlock_level`) the wall carries a recharging shield in front of its HP: 900 at level 15, ×1.18 per level above it. The shield absorbs damage first, waits 6 s after the last hit, then refills 5 % of its maximum per second. Repair (Runner skill) restores HP only.
- **Tower** — every upgrade grants one stat pick out of four paths: Damage (+10 % ranged damage), Attack Speed (+10 %), Crit (+5 percentage points chance and +0.10 multiplier, flat), Range (+10 %). Percentage picks on the same path sum rather than compound.

Balance values must not be embedded into UI logic.

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

Current balance (`economy_config.tres`):

```text
hunter_crystals_per_damage = 0.2
```

Conceptually:

```text
crystals_earned = damage_applied * hunter_crystals_per_damage
```

`damage_applied` is what the hit actually removed (overkill does not pay). Against a shielded wall, damage absorbed by the shield counts as applied. The conversion lives in `GameManager.award_damage_crystals()`, never at the combat call site.

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

Not implemented yet.

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

Where each value lives:

```text
economy_config.tres     starting_crystals, hunter_crystals_per_damage
<structure>_def.tres    base_cost, cost_growth, max_level, base_hp, hp_growth,
                        base_build_seconds, build_time_growth, max_build_seconds,
                        mine_base_output, mine_interval, mine_max_output (mine),
                        shield_* (wall), tower_* + tower_base_stats (tower)
not implemented yet     hunter_passive_crystal_income, hunter_passive_income_interval,
                        hunter_shop_item_costs
```

UI components display economy values but do not own or calculate the economy rules.
