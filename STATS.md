# Stats

## 1. Character Stats

Character stats define the numerical properties of a character, such as health, defense, movement speed, and damage.

### 1.1. Stat Calculation

Regular stats consist of three components:

- **Base Value:** The default value of the stat.
- **Flat Modifier:** A fixed amount added to or subtracted from the base value.
- **Percentage Modifier:** A percentage-based increase or decrease applied after flat modifiers.

The final value is calculated as:

```python
final_value = (base_value + flat_modifier) × (1 + percentage_modifier)
```

Percentage modifiers are represented as decimals. For example, 0.20 represents +20%.

#### Example

A character has:

- melee_damage.base_value = 10
- melee_damage.flat_modifier = 5
- melee_damage.percentage_modifier = 0.20

The resulting damage is:

```python
(10 + 5) × (1 + 0.20) = 18
```

Modifiers from the same category are added together before calculating the final value.

For example:

- Sword: +5 melee damage
- Berserker Perk: +20% melee damage
- Ring: +10% all damage

This results in:

```python
(10 + 5) × (1 + 0.20 + 0.10) = 19.5 melee damage
```

---

### 1.2. Resource and Survivability Stats

Resource and survivability stats define the character's durability and movement capabilities.

| Stat | Example Base Value | Description |
| --- | --- | --- |
| max_health | 100 | Maximum amount of health |
| health_regeneration | 2/s | Health restored per second |
| defense | 20 | Reduces incoming damage |
| movement_speed | 5 m/s | Character movement speed |

These stats use the standard stat calculation:

```python
final_value = (base_value + flat_modifier) × (1 + percentage_modifier)
```

If no percentage modifiers exist, percentage_modifier is 0.

---

### 1.3. Damage Stats

Damage stats define the base damage dealt by different attack types.

| Stat | Example Base Value | Description |
| --- | --- | --- |
| melee_damage | 10 | Damage dealt by melee attacks |
| ranged_damage | 10 | Damage dealt by ranged attacks |
| magic_damage | 10 | Damage dealt by magical attacks |

Damage stats use the same standard stat calculation.

This allows equipment, perks, buffs, and debuffs to modify damage through either flat or percentage-based bonuses.

---

## 2. Chance-Based Combat Mechanics

Some combat effects consist of a **chance of activation** and an **effect value**.

Unlike percentage modifiers, the chance does not directly modify another stat. Instead, it determines whether the corresponding combat effect is triggered.

### 2.1. Critical Hits

Critical hits are controlled by two values:

| Stat | Description |
| --- | --- |
| critical_chance | Probability that an attack becomes a critical hit |
| critical_damage | Damage multiplier applied when a critical hit occurs |

Example:

- critical_chance = 0.20 → 20% chance
- critical_damage = 1.50 → 150% damage

Conceptually:

```python
if random() < critical_chance:
    damage = damage × critical_damage

# For an attack dealing 20 damage:
# 20 × 1.50 = 30 damage, when the critical hit triggers
```

---

### 2.2. Lifesteal

Lifesteal is controlled by two values:

| Stat | Description |
| --- | --- |
| lifesteal_chance | Probability that lifesteal triggers |
| lifesteal_amount | Health restored when lifesteal triggers |

Example:

- lifesteal_chance = 0.10 → 10% chance
- lifesteal_amount = 5 → restores 5 health

Conceptually:

```python
if random() < lifesteal_chance:
    heal(lifesteal_amount)
```

Therefore, lifesteal restores a fixed amount of health when successfully triggered.

---

## 3. Stat Categories

The initial character stat system consists of:

### Resource and Survivability

- max_health
- health_regeneration
- defense
- movement_speed

### Damage

- melee_damage
- ranged_damage
- magic_damage

### Critical Hits

- critical_chance
- critical_damage

### Lifesteal

- lifesteal_chance
- lifesteal_amount

The important distinction is that **regular stats describe character values**, while **chance-based mechanics describe how certain combat effects are triggered and applied**.

---
