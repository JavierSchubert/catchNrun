# Stats

## 1. Character Stats

Character stats define the numerical properties of a character, such as health, defense, movement speed, damage, critical hit chance, and lifesteal.

Stats may be modified by equipment, perks, buffs, and debuffs.

---

### 1.1. Stat Model

A character stat consists of the following components:

- **Base Value:** The default value of the stat.
- **Flat Modifier:** A fixed amount added to or subtracted from the base value.
- **Percentage Modifier:** A percentage-based increase or decrease applied after flat modifiers.
- **Final Value:** The resulting value after all modifiers have been applied.

The final value is calculated as:

```text
final_value = (base_value + flat_modifier) * (1 + percentage_modifier)
```

Percentage modifiers are represented as decimals:

```text
0.20 = +20%
-0.20 = -20%
0.50 = +50%
```

If a stat has no flat or percentage modifiers, those modifiers are `0`.

---

### 1.2. Modifier Calculation

Modifiers of the same type are added together before the final value is calculated.

For example, a character has:

```text
melee_damage.base_value = 10
```

The character receives the following modifiers:

- Sword: `+5 melee damage`
- Berserker Perk: `+20% melee damage`
- Ring: `+10% all damage`

The resulting modifiers are:

```text
flat_modifier = 5
percentage_modifier = 0.20 + 0.10
percentage_modifier = 0.30
```

The final melee damage is:

```text
(10 + 5) * (1 + 0.30) = 19.5
```

Modifiers that affect multiple stats, such as `all damage`, contribute to the modifier calculation of every supported target stat.

For example:

```text
+10% all damage
```

affects:

- `melee_damage`
- `ranged_damage`
- `magic_damage`

---

### 1.3. Supported Stats

The initial character stat system supports the following stats.

| Stat | Category | Example Base Value | Description |
| --- | --- | ---: | --- |
| `max_health` | Resource | 100 | Maximum amount of health |
| `health_regeneration` | Resource | 2.0 | Health restored per second (Hunter: only after `RoleConfig.regen_delay_after_damage` with no HP loss) |
| `defense` | Survivability | 20 | Used to reduce incoming damage |
| `movement_speed` | Movement | 5.0 | Character movement speed |
| `melee_damage` | Damage | 10 | Damage dealt by melee attacks |
| `ranged_damage` | Damage | 10 | Damage dealt by ranged attacks |
| `magic_damage` | Damage | 10 | Damage dealt by magical attacks |
| `critical_chance` | Critical Hit | 0.20 | Probability that an attack becomes a critical hit |
| `critical_damage_multiplier` | Critical Hit | 1.50 | Damage multiplier applied to critical hits |
| `lifesteal_chance` | Lifesteal | 0.10 | Probability that lifesteal is triggered |
| `lifesteal_amount` | Lifesteal | 5 | Health restored when lifesteal is triggered |
| `attack_speed` | Attack | 1.25 | Attacks per second; the attack interval is `1 / attack_speed` |
| `attack_range` | Attack | 0 | Reach of an attack in pixels; read by Towers. Units ignore it and use `RoleConfig.attack_range` |
| `luck` | Progression | 0.10 for the Hunter | Improves the rarity odds of Hunter level-up rewards; clamped to `0.0`–`1.0` |

All supported stats use the standard stat calculation unless explicitly documented otherwise.

`StatBlock.Stat` is **append-only**: its ordinals are serialized in `.tres` files, so a new stat goes at the end of the enum, never in between.

Towers use the same system: each Tower owns a `StatSheet` seeded from `tower_base_stats` in `tower_def.tres`, and its upgrade picks are ordinary `StatModifier`s (`construction.README.md` §5). Only `RANGED_DAMAGE`, `ATTACK_SPEED`, `ATTACK_RANGE`, and the two crit stats affect a Tower; structure HP is not taken from `max_health` but from `BuildingDef.hp_for_level()`.

Units currently read their real reach from `RoleConfig.attack_range` and report `attack_range = 0` through their sheet.

### 1.3.1. Player XP and levels (WP-14)

Units carry host-owned `level` and `xp` (replicated). Curve math lives in `XpProgress` (`src/progression/xp_progress.gd`):

```text
xp_to_next(level) = 100 * 1.35^(level - 1)
```

- **Hunter:** gains **1 XP per point of applied melee damage** (units and buildings). Filling the portrait XP ring levels up; overflow XP carries into the next level.
- **Starting Hunter balance (CP-22 / follow-up):** `22.5` melee damage at `1.25` attacks/sec (`0.8s` interval), down from `25` at `1.333` attacks/sec. This reduces opening sustained damage by about `16%`. For survivability, Hunter regeneration is `3.0` HP/s after **`regen_delay_after_damage = 3.0` seconds** without taking damage (`hunter_config.tres`) — same idea as wall shield recharge, in real seconds (not ticks). Movement is unchanged. The level-1 Tower deals `12` ranged damage at `1` attack/sec; its upgrades grant 10% damage/speed/range increments and smaller flat crit bonuses.
- **Hunter rewards:** each gained level queues three different stat choices. The host rolls each choice's stat, rarity, and bonus; the Hunter chooses one in the bottom-right HUD panel. Overflow levels remain queued and show one offer at a time.
- **Rarity:** Basic (blue), Advanced (green), Rare (violet), and Legendary (gold) scale the base stat ranges by `1.0×`, `1.5×`, `2.25×`, and `3.5×`. Luck shifts the default rarity weights from `60/27/10/3` toward `43/27/20/10` at maximum Luck.
- **Luck:** starts at `0.10` for Hunters, is displayed in the upgrade prompt, and can itself be upgraded. It affects future offers only.
- Max-health choices raise current health by the same amount, up to the new maximum. Movement speed, melee damage, and attack speed rewards are percentage modifiers; chance and other numeric rewards are flat additions.
- **Runner:** stays at **level 1**; the selection-panel XP band is always fully violet (no XP gain).
- HUD: violet fill is counterclockwise from 12 o'clock on the dark band between the grey portrait rings (`PortraitXpRing`).

---

### 1.4. Value Semantics and Constraints

Different types of values use different numerical representations.

#### Percentage Modifiers

Percentage modifiers represent relative increases or decreases.

```text
0.20 = +20%
-0.20 = -20%
```

For example:

```text
base_value = 100
percentage_modifier = 0.20

final_value = 100 * 1.20
final_value = 120
```

#### Chances

Chance values represent probabilities between `0.0` and `1.0`.

```text
0.00 = 0%
0.10 = 10%
0.50 = 50%
1.00 = 100%
```

Chance-based stats should be clamped to this range:

```text
chance = clamp(chance, 0.0, 1.0)
```

This applies to stats such as:

- `critical_chance`
- `lifesteal_chance`

#### Multipliers

Multipliers represent a factor applied directly to another value.

```text
1.00 = 100%
1.50 = 150%
2.00 = 200%
```

For example:

```text
damage = 20
critical_damage_multiplier = 1.50

critical_damage = 20 * 1.50
critical_damage = 30
```

#### General Constraints

Unless explicitly supported by a mechanic:

```text
critical_chance >= 0.0 and <= 1.0
lifesteal_chance >= 0.0 and <= 1.0

max_health >= 0.0
health_regeneration >= 0.0
movement_speed >= 0.0

critical_damage_multiplier >= 0.0
lifesteal_amount >= 0.0
```

---

## 2. Combat Mechanics

Character stats and combat mechanics are separate concepts.

**Character stats** store and calculate numerical values.

**Combat mechanics** consume the final values of those stats to implement gameplay behavior.

Combat mechanics do not own or independently calculate character stat values. They use the final values provided by the character stat system.

Conceptually:

```text
Character Stats
│
├── melee_damage
├── ranged_damage
├── magic_damage
├── critical_chance
├── critical_damage_multiplier
├── lifesteal_chance
└── lifesteal_amount

Combat Mechanics
│
├── Critical Hit
│   ├── consumes critical_chance
│   └── consumes critical_damage_multiplier
│
└── Lifesteal
    ├── consumes lifesteal_chance
    └── consumes lifesteal_amount
```

This separation keeps stat calculation consistent while allowing combat mechanics to combine multiple stats into more complex gameplay behavior.

---

### 2.1. Critical Hits

Critical hits use two character stats:

| Stat | Description |
| --- | --- |
| `critical_chance` | Probability that an attack becomes a critical hit |
| `critical_damage_multiplier` | Damage multiplier applied when a critical hit occurs |

Example values:

```text
critical_chance = 0.20
critical_damage_multiplier = 1.50
```

This represents:

- `20%` chance to trigger a critical hit.
- `150%` damage when the critical hit occurs.

Conceptually, the mechanic works as follows:

```text
if random() < critical_chance:
    damage *= critical_damage_multiplier
```

For an attack that would normally deal `20` damage:

```text
20 * 1.50 = 30
```

The attack therefore deals `30` damage when the critical hit is triggered.

The mechanic always uses the **final calculated values** of `critical_chance` and `critical_damage_multiplier`.

For example:

```text
critical_chance.final_value
critical_damage_multiplier.final_value
```

`critical_chance` must be constrained to the range `0.0` to `1.0`.

---

### 2.2. Lifesteal

Lifesteal uses two character stats:

| Stat | Description |
| --- | --- |
| `lifesteal_chance` | Probability that lifesteal is triggered |
| `lifesteal_amount` | Amount of health restored when lifesteal is triggered |

Example values:

```text
lifesteal_chance = 0.10
lifesteal_amount = 5
```

This represents:

- `10%` chance to trigger lifesteal.
- `5` health restored when lifesteal triggers.

Conceptually, the mechanic works as follows:

```text
if random() < lifesteal_chance:
    heal(lifesteal_amount)
```

The mechanic always uses the **final calculated values** of `lifesteal_chance` and `lifesteal_amount`.

For example:

```text
lifesteal_chance.final_value
lifesteal_amount.final_value
```

`lifesteal_chance` must be constrained to the range `0.0` to `1.0`.

Lifesteal cannot restore health above the character's final `max_health` unless an explicit overhealing mechanic is implemented.

Conceptually:

```text
current_health = min(
    current_health + lifesteal_amount,
    max_health
)
```

---

## 3. Design Principles

The stat system should follow these principles.

### Single Stat Calculation

All character stats use the same calculation model:

```text
final_value = (base_value + flat_modifier) * (1 + percentage_modifier)
```

Individual gameplay systems should not implement their own alternative stat calculation logic.

### Stats Store Values

Character stats represent numerical properties of the character.

Examples:

```text
melee_damage
critical_chance
critical_damage_multiplier
lifesteal_amount
```

### Mechanics Consume Stats

Gameplay mechanics use the final calculated values of character stats.

Examples:

```text
Critical Hit
    -> critical_chance
    -> critical_damage_multiplier

Lifesteal
    -> lifesteal_chance
    -> lifesteal_amount
```

### Modifiers Change Stats, Not Mechanics

Equipment, perks, buffs, and debuffs modify character stats.

They should generally not modify the internal logic of a combat mechanic directly.

For example:

```text
Sword
    -> +5 melee_damage

Berserker Perk
    -> +20% melee_damage

Critical Ring
    -> +10% critical_chance
```

The combat mechanic then consumes the resulting final stat value.

### Final Values Are the Gameplay Interface

Gameplay systems should consume the final calculated value of a stat rather than manually accessing and combining its internal modifiers.

Conceptually:

```text
damage = melee_damage.final_value
```

rather than:

```text
damage = (
    melee_damage.base_value
    + melee_damage.flat_modifier
) * (
    1 + melee_damage.percentage_modifier
)
```

The stat system is responsible for calculating the value. Gameplay systems are responsible for using it.
