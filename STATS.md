# Stats

## 1. Character Stats

Character stats define the numerical properties of a character, such as health, defense, movement speed, and damage.

### 1.1. Stat Calculation

Character stats can consist of three components:

- **Base Value:** The default value of the stat.
- **Flat Modifier:** A fixed amount added to or subtracted from the base value.
- **Percentage Modifier:** A percentage-based increase or decrease applied after flat modifiers.

The final value is calculated as:

```python
final_value = (base_value + flat_modifier) * (1 + percentage_modifier)
```

Percentage modifiers are represented as decimals. For example, `0.20` represents `+20%`.

#### Example

A character has the following melee damage values:

- `melee_damage.base_value = 10`
- `melee_damage.flat_modifier = 5`
- `melee_damage.percentage_modifier = 0.20`

The resulting damage is:

```text
(10 + 5) * (1 + 0.20) = 18
```

Modifiers from the same category are added together before the final value is calculated.

For example:

- Sword: `+5 melee damage`
- Berserker Perk: `+20% melee damage`
- Ring: `+10% all damage`

The flat modifier is `5`, while the combined percentage modifier is:

```text
0.20 + 0.10 = 0.30
```

The final melee damage is:

```text
(10 + 5) * (1 + 0.30) = 19.5
```

---

### 1.2. Resource and Survivability Stats

Resource and survivability stats define the character's durability and movement capabilities.

| Stat | Example Base Value | Description |
| --- | ---: | --- |
| `max_health` | 100 | Maximum amount of health |
| `health_regeneration` | 2/s | Health restored per second |
| `defense` | 20 | Reduces incoming damage |
| `movement_speed` | 5 m/s | Character movement speed |

These stats use the standard stat calculation:

```python
final_value = (base_value + flat_modifier) * (1 + percentage_modifier)
```

If a stat has no percentage-based modifiers, its `percentage_modifier` is `0`.

For example:

```text
(100 + 20) * (1 + 0) = 120
```

---

### 1.3. Damage Stats

Damage stats define the damage dealt by different attack types.

| Stat | Example Base Value | Description |
| --- | ---: | --- |
| `melee_damage` | 10 | Damage dealt by melee attacks |
| `ranged_damage` | 10 | Damage dealt by ranged attacks |
| `magic_damage` | 10 | Damage dealt by magical attacks |

Damage stats use the standard stat calculation.

This allows equipment, perks, buffs, and debuffs to modify damage through flat or percentage-based modifiers.

Examples:

- Sword: `+5 melee_damage`
- Berserker Perk: `+20% melee_damage`
- Ring: `+10% all damage`

The `all damage` modifier is applied to all supported damage stats:

- `melee_damage`
- `ranged_damage`
- `magic_damage`

---

## 2. Chance-Based Combat Mechanics

Chance-based combat mechanics use one or more character stats to determine whether an effect is triggered and how strong the resulting effect is.

Values such as `critical_chance`, `critical_damage_multiplier`, `lifesteal_chance`, and `lifesteal_amount` are character stats. They can use the regular stat calculation where applicable.

The combat mechanic consumes the final values of these stats during combat.

### 2.1. Critical Hits

Critical hits use two stats:

| Stat | Description |
| --- | --- |
| `critical_chance` | Probability that an attack becomes a critical hit |
| `critical_damage_multiplier` | Damage multiplier applied when a critical hit occurs |

Example values:

- `critical_chance = 0.20` represents a 20% chance.
- `critical_damage_multiplier = 1.50` represents 150% of the regular damage.

Conceptually, the mechanic works as follows:

```python
if random() < critical_chance:
    damage *= critical_damage_multiplier
```

For an attack that would normally deal `20` damage:

```text
20 * 1.5* = 30
```

The attack therefore deals `30` damage when the critical hit is triggered.

Chance values should normally be constrained to the range from `0.0` to `1.0`:

```python
critical_chance = clamp(critical*chance, 0.0, 1.0)
```

This corresponds to a probability between 0% and 100%.

> **Note:** `clamp()` represents a conceptual helper function. Its exact implementation depends on the programming language or game engine.

---

### 2.2. Lifesteal

Lifesteal uses two stats:

| Stat | Description |
| --- | --- |
| `lifesteal_chance` | Probability that lifesteal is triggered |
| `lifesteal_amount` | Amount of health restored when lifesteal is triggered |

*xample values:

- `lifesteal_chance = 0.10` represents a 10% chance.
* `lifesteal_amount = 5` restores 5 health.

Conceptually, the mechanic works as follows:

```python
if random() < lifesteal_chance:
    heal(lifesteal_amount)
```

When lifesteal is successfully triggered, the character restores health equal to the final value of `lifesteal_amount`.

Chance values should normally be constrained to the range from `0.0` to `1.0`:

```python
lifesteal_chance = clamp(lifesteal_chance, 0.0, 1.0)
```

This corresponds to a probability between 0% and 100%.

> **Note:** Lifesteal cannot restore health above the character's final `max_health` unless overhealing is explicitly supported.

---

## 3. Stat Categories

The initial character stat system consists of the following stats.

### 3.1. Resource and Survivability

- `max_health`
- `health_regeneration`
- `defense`
- `movement_speed`

### 3.2. Damage

- `melee_damage`
- `ranged_damage`
- `magic_damage`

### 3.3. Critical Hits

- `critical_chance`
- `critical_damage_multiplier`

### 3.4. Lifesteal

- `lifesteal_chance`
- `lifesteal_amount`

---

## 4. Character Stats and Combat Mechanics

Character stats and combat mechanics are separate concepts.

### 4.1. Character Stats

Character stats represent numerical values associated with the character. They can be modified by equipment, perks, buffs, and debuffs.

Examples include:

- `melee_damage`
- `critical_chance`
- `critical_damage_multiplier`
- `lifesteal_chance`
- `lifesteal_amount`

### 4.2. Combat Mechanics

Combat mechanics consume the final values of character stats to determine what happens during combat.

The critical hit mechanic uses:

- `critical_chance` to determine whether a critical hit occurs.
- `critical_damage_multiplier` to determine how much damage the critical hit deals.

The lifesteal mechanic uses:

- `lifesteal_chance` to determine whether lifesteal occurs.
- `lifesteal_amount` to determine how much health is restored.

The relationship can be summarized as follows:

```text
Character Stats
├── critical_chance
└── critical_damage_multiplier
    └── Critical Hit Mechanic
        ├── Determines whether a critical hit occurs
        └── Calculates the resulting critical damage

Character Stats
├── lifesteal_chance
└── lifesteal_amount
    └── Lifesteal Mechanic
        ├── Determines whether lifesteal occurs
        └── Calculates how much health is restored
```

This separation keeps the stat system consistent while allowing combat mechanics to combine multiple stats into more complex behavior.