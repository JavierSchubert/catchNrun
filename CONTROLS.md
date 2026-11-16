# Controls

## 1. Input and Commands

The game uses mouse-based unit controls similar to League of Legends.

The same basic control system applies to all player-controlled characters, including Hunters and Runners.

### 1.1. Left Click: Selection

Left-clicking a clickable entity selects that entity.

Clickable entities include:

- Players
- Hunters
- NPCs
- Towers
- Destructible objects
- Walls

The selected entity is displayed in the selection panel at the bottom of the screen.

The information shown in the selection panel depends on the groups or entity types assigned to the selected entity.

Conceptually:

```text
Left Click
    |
    +-- Clickable Entity
    |       -> Select entity
    |       -> Determine entity groups / type
    |       -> Update selection panel
    |
    +-- Non-clickable World
            -> Clear selection if applicable
```

Examples:

```text
Player
-> Show player information

Hunter
-> Show hunter information

NPC
-> Show NPC information

Tower
-> Show tower information

Destructible Object
-> Show object information
```

The exact information displayed for each entity type is defined by the UI / selection panel system.

### 1.2. Right Click: Context Command

Right click issues a context-sensitive command.

```text
Right Click
    |
    +-- Navigable Ground
    |       -> Movement Command
    |
    +-- Valid Attackable Entity
    |       -> Attack Command
    |
    +-- Invalid Target
            -> Next moveable position
```

#### Movement Command

Right-clicking navigable ground moves the controlled character toward the clicked world position.

Right Click Ground
-> Determine clicked world position
-> Calculate shortest valid path
-> Move along path

A newly issued movement command replaces the current movement or attack command.

#### Attack Command

Right-clicking a valid attackable entity sets that entity as the current attack target.

```text
Right Click Attackable Entity
    |
    +-- Target within attack range
    |       -> Stop movement if necessary
    |       -> Attack target
    |
    +-- Target outside attack range
            -> Pathfind toward target
            -> Follow target if it moves
            -> Stop when target enters attack range
            -> Attack target
```

### 1.3. Attack Move

Pressing `A` followed by a left click issues an attack-move command.

```text
A
-> Left Click Position
-> Attack Move
```

During attack move:

```text
Attack Move
    |
    +-- Valid target detected
    |       -> Acquire target
    |       -> Move into attack range if necessary
    |       -> Attack target
    |
    +-- No target detected
            -> Continue toward attack-move destination
```

After the target is no longer valid, the character continues toward the original attack-move destination unless another valid target is acquired.

### 1.4. Camera Center

Pressing `C` centers the camera on the controlled character.

---

## 2. Camera

The camera can move independently from the controlled character.

### 2.1. Edge Scrolling

Moving the mouse cursor to the edges or corners of the screen moves the camera in the corresponding direction.

```text
Top edge          -> Move camera up
Bottom edge       -> Move camera down
Left edge         -> Move camera left
Right edge        -> Move camera right

Top-left corner     -> Move camera up-left
Top-right corner    -> Move camera up-right
Bottom-left corner  -> Move camera down-left
Bottom-right corner -> Move camera down-right
```

The movement vector must be normalized so diagonal movement is not faster than horizontal or vertical movement.

```python
direction = normalized(direction)
movement = direction * camera_speed
```

Camera movement does not affect the controlled character.

---

## 3. Entity Interaction

Entities may expose different interaction capabilities.

### 3.1. Clickable Entities

Clickable entities can be selected with left click.

Examples:

- Players
- Hunters
- NPCs
- Towers
- Walls
- Destructible objects
- Buildings

A clickable entity provides information that can be displayed in the selection panel.

### 3.2. Attackable Entities

Attackable entities can be targeted by attacks.

Examples may include:

- Enemy Players
- Enemy Hunters
- Hostile NPCs
- Towers
- Destructible objects
- Walls
- Buildings

Whether an entity is attackable depends on gameplay rules such as:

- Team
- Entity type
- Current state
- Invulnerability
- Destruction state

Clickable and attackable are separate properties.

For example:

```text
Friendly Player
-> Clickable
-> Not Attackable

Enemy Hunter
-> Clickable
-> Attackable

Destructible Wall
-> Clickable
-> Attackable

Non-interactive Environment
-> Not Clickable
-> Not Attackable
```

This distinction should be reflected by Godot groups, components, or other entity capabilities rather than relying on a single entity type.

---

## 4. Movement and Target Acquisition

Movement uses pathfinding to reach world positions or attack targets.

### 4.1. Pathfinding

Movement commands should attempt to find the shortest valid path while respecting navigation obstacles.

When moving toward a fixed position:

```text
Movement Command
-> Calculate path
-> Follow path
-> Reach destination
-> Stop
```

When moving toward an attack target:

```text
Attack Command
-> Track target position
-> Recalculate movement as necessary
-> Enter attack range
-> Stop
-> Attack
```

### 4.2. Acquisition Range

Automatic targeting uses `acquisition_range`.

The nearest valid attackable entity within acquisition_range becomes the current target, unless a target has been explicitly specified by a direct attack command or acquired through an attack-move command.

Target priority is:

1. **Direct Attack Command:** The explicitly clicked attackable target has the highest priority.
2. **Attack Move:** A valid target acquired while executing an attack-move command has the second-highest priority.
3. **Automatic Acquisition:** If no target has been specified or acquired, the nearest valid attackable entity within `acquisition_range` becomes the current target.

Once a target has been acquired, the character should keep that target instead of continuously switching to another, closer target.

The current target is released when:

- The target is defeated or destroyed.
- The target becomes invalid or non-attackable.
- The target leaves the allowed acquisition or chase range.
- The player issues a new command that replaces the current target.

After the current target is released, automatic target acquisition may select the nearest valid attackable entity within `acquisition_range`.

Attack execution uses `attack_range`.

```text
Acquisition Range
-> Determines whether a valid target can be automatically acquired.

Attack Range
-> Determines whether an attack can be initiated.
```

For example:

```text
acquisition_range = 10
attack_range = 2
```

An enemy at distance `7` can be acquired, but the Hunter must move closer before attacking.

### 4.3. Hunter Automatic Targeting

Hunters may automatically acquire valid targets when the current command allows automatic target acquisition.

```text
Enemy enters acquisition range
    |
    -> Validate target
    -> Acquire target
    |
    +-- Outside attack range
    |       -> Move toward target
    |       -> Enter attack range
    |       -> Attack
    |
    +-- Inside attack range
            -> Attack immediately
```

Explicit player commands take priority when the current command does not allow automatic target acquisition.

---

## 5. Combat

### 5.1. Attack Range

`attack_range` determines the maximum distance from which an attack can be initiated.

Attack range and hit detection are separate concepts.

```text
attack_range
-> Can the attack be initiated?

hitbox / hurtbox
-> Does the executed attack hit an entity?
```

### 5.2. Attack Types

The combat system supports:

- Melee
- Ranged
- Magic

#### Melee

Melee attacks operate at close range.

They may be:

- Single-target
- Splash
- Area-based

```text
Target within melee attack range
-> Start attack
-> Activate attack hitbox
-> Detect valid hurtboxes
-> Apply damage
```

#### Ranged

```text
Ranged attacks are primarily projectile-based.

Target within ranged attack range
-> Start attack
-> Spawn projectile
-> Projectile travels through world
-> Projectile collides with valid hurtbox
-> Apply damage
```

#### Magic

```text
Magic attacks may use:

- Projectiles
- Direct targeted effects
- Area-of-effect attacks

Examples:

Fireball
-> Projectile

Lightning Strike
-> Direct target

Meteor
-> Area of effect

Individual attacks define their exact targeting and hit-resolution behavior.
```

---

## 6. Cursor Feedback

The cursor provides visual feedback about the command that will be issued.

| State | Visual | Context |
| --- | --- | --- |
| Movement | Blue movement cursor | Navigable ground |
| Attack | Red attack cursor | Valid attackable entity |
| Invalid | Gray blocked cursor | Invalid interaction |
| Attack Move | Red attack cursor | Attack-move mode |

Color should not be the only distinction. Different cursor symbols should also be used.

### 6.1. Context-Sensitive Cursor

```text
Mouse Hover
    |
    +-- Navigable Ground
    |       -> Movement Cursor
    |
    +-- Valid Attackable Entity
    |       -> Attack Cursor
    |
    +-- Invalid Interaction
            -> Invalid Cursor
```

The cursor only communicates the result of interaction detection.

It does not determine whether an entity is attackable or whether a location is navigable.

### 6.2. Attack-Move Cursor

```text
Press A
-> Enter attack-move mode
-> Show attack-move cursor

Left Click Position
-> Issue attack-move command
-> Exit attack-move mode
-> Restore context-sensitive cursor

Cancel
-> Exit attack-move mode (e.g. by pressing Escape or right click)
-> Restore context-sensitive cursor
```

---

## 7. Responsibility Summary

The systems should remain separated by responsibility.

```text
Input
-> Detect player input
-> Issue commands

Selection
-> Determine clicked entity
-> Manage selected entity
-> Update selection panel

Targeting
-> Determine valid attack targets
-> Handle target acquisition

Navigation
-> Calculate and follow movement paths

Combat
-> Check attack range
-> Execute attacks
-> Resolve hitboxes and hurtboxes

Cursor
-> Visually communicate available interactions

UI
-> Display information about the selected entity
```