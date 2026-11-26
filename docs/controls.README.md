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

#### Selectable vs controllable

Every clickable entity can be selected. Selection alone does not grant control.

Each player is their own control group. Only entities that belong to the local player's group can be controlled (movement, attack commands, and similar orders).

Selecting another player's unit (for example a Runner selecting the Hunter) shows that unit's permitted information and draws a selection circle, but does not allow commanding it. Selecting the local player's own unit again restores control of that unit.

```text
Left Click Entity
    |
    +-- Own control group
    |       -> Select
    |       -> Show stats / selection panel
    |       -> Accept control commands
    |
    +-- Other group / team entity
            -> Select
            -> Show permitted stats / selection panel
            -> Do not accept control commands
```

#### Selection circle

When an entity is selected, a selection circle is drawn under it. The circle radius scales with the entity's size (hitbox / visual footprint).

Hover and selection use the same circle, with different stroke weight:

| State | Circle |
| --- | --- |
| Hover (cursor over hitbox, not selected) | Thinner selection circle |
| Selected | Thicker selection circle |

If the hovered entity is also selected, only the selected (thicker) circle is shown.

#### Selection circle colors

Circle color depends on ownership and team relative to the local player:

| Relation to local player | Color |
| --- | --- |
| Own control group (local player's entities) | Green |
| Same team (Runner-team entities that are not the local player's) | Blue |
| Hunter | Red |

Own-group green takes priority over the Hunter red when the local player is the Hunter and has selected themselves.

#### Drag-box selection

Holding left mouse button and dragging draws a transparent rectangle selection box. On release, entities whose hitboxes intersect the box become selection candidates. Exactly one entity is chosen from those candidates using the priority rules below.

A short press without meaningful mouse travel remains a normal point-click selection. Dragging past a small movement threshold starts the box.

#### Selection priority (box or overlapping hits)

When more than one clickable entity is a candidate:

1. **Own unit first.** If the local player's controllable unit is among the candidates, select it.
2. **Player characters over NPCs.** Hunter / Runner (and other player figures) outrank NPCs and similar non-player clickables.
3. **Otherwise random.** Among multiple non-owned candidates in the same priority band, pick one at random.

```text
Candidates in box / under cursor
    |
    +-- Own unit present?
    |       -> Select own unit
    |
    +-- Else player figures (Hunter / Runner) present?
    |       -> Pick one at random among them
    |
    +-- Else NPCs / other clickables
            -> Pick one at random among them
```

#### Flow

Conceptually:

```text
Left Click / Drag Select
    |
    +-- Clickable Entity (or box candidates)
    |       -> Resolve priority
    |       -> Select entity
    |       -> Show selection circle (color by ownership / team)
    |       -> Determine entity groups / type
    |       -> Update selection panel
    |       -> Enable control commands only if own group
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
    +-- Own damaged, finished structure (Runner)
    |       -> Repair Command
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

A newly issued movement command replaces the current movement or attack command. Right-click on empty ground always takes priority: it cancels the current attack / attack-move / shift-click chain and walks to the click. Opportunistic auto-attack must not interrupt that plain player move while the path is still active.

#### Shift-click move chain

Hold `Shift` or `Ctrl` and right-click the ground (or the minimap) to queue **green** move waypoints. `Ctrl` is the browser-friendly alternative because some browsers bypass their context-menu suppression for Shift+right-click. Press `A`, then hold `Shift` or `Ctrl` and left-click to queue **red** attack-move waypoints (also on the minimap). Green and red legs can be mixed in one chain — for example red attack-move points, then more green Ctrl+RMB points.

Dotted lines and rings use the color of the waypoint they lead into. As the unit reaches a waypoint, that ring and its inbound dotted segment disappear.

While a chain is active, the path has priority over enemies in attack range — the unit keeps walking waypoints and does not stop to auto-attack. Cancel the whole chain with a plain right-click or a plain (non-Shift) `A` + left-click attack-move.

#### Attack Command

Right-clicking a valid attackable entity (with a selected unit that can attack, currently the Hunter) sets that entity as the current attack target. A red click ring flashes on the entity (move clicks stay blue).

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

#### Repair Command

A Runner right-clicking one of their **own** structures that is damaged and past its first construction starts the `repair` skill. A green click ring flashes on the structure.

```text
Right Click Own Damaged Structure (Runner)
    -> Walk into repair reach if necessary
    -> Restore HP at the skill's value_per_second (src/skills/defs/repair_def.tres)
    -> Stop on its own at full HP
```

Repair restores HP only, never a wall's shield. Any other command (move, chain waypoint, attack-move) cancels it. Right-clicking a structure that is at full HP, still under its first construction, or owned by someone else is a plain move. An enemy under the cursor outranks the structure only for a unit that can attack it — a Runner repairing a wall under attack can click right next to the Hunter.

### 1.3. Attack Move

Pressing `A` followed by a left click issues an attack-move command. The ground click ring is red (same attack color as a right-click attack). Escape or right-click cancels attack-move mode before the click.

```text
A
-> Left Click Position
-> Attack Move (red ground marker)
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

Pressing `C` centers the camera on the local player's own unit.

This always targets the local controllable character, even when another entity is currently selected for viewing. Selection does not change what `C` centers on.

Left-click on the **minimap** also recenters the camera on the corresponding world position (see `minimap.README.md` §2.3).

Eliminations and other roster updates must **not** auto-recenter the camera. A free camera stays where the player left it until `C`, a minimap click, or match start.

---

## 2. Camera

The camera can move independently from the controlled character.

Implementation: `game/camera/match_camera.gd` (`MatchCamera`).

### 2.1. Edge Scrolling

Moving the mouse cursor to the edges or corners of the screen moves the camera in the corresponding direction.

The edge detection margin is configurable in the `MatchCamera` inspector through `edge_margin` (in **screen** pixels; current default: `48` — nearer the screen edge). Scroll speed is `camera_speed` (world units / s; current default: `1600`).

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

Edge scroll is **disabled** while the cursor hovers a blocking UI control (`Viewport.gui_get_hovered_control()` is non-null). That covers the settings dock, minimap, sandbox chrome, and similar overlays so scrolling does not fight the UI. Edge scroll is also paused while middle-mouse drag is active.

### 2.1.1. Middle-mouse drag

Hold the middle mouse button and move the mouse to drag the camera. Release middle mouse to stop. The map follows the cursor (camera moves opposite to the drag delta, zoom-aware).

### 2.2. Map bounds and overscroll padding

The camera clamps to `Unit.MAP_BOUNDS`, but it is allowed to scroll **past** the map edge so that map corners are never glued to screen corners. Units standing on the map edge stay inset and readable.

| Export | Unit | Current default | Meaning |
| --- | --- | --- | --- |
| `edge_margin` | screen px | `48` | Trigger-zone offset from viewport edge for edge-scroll |
| `camera_speed` | world units / s | `1600` | Edge-scroll velocity |
| `zoom_factor` | multiplier | `1.0` | Applied to `Camera2D.zoom` |
| `bound_padding` | screen px | `360` | How far the map edge sits inside the viewport when fully scrolled |

`bound_padding` is converted to world space with the current zoom (`pad_world = padding / zoom`) so the **on-screen** inset stays consistent at every zoom level.

```text
half_view  = viewport_size / zoom / 2
pad_world  = bound_padding / zoom
min_center = map_origin + half_view - pad_world
max_center = map_end    - half_view + pad_world
```

If the view is wider/taller than the map, the camera centers on the map along that axis instead of clamping.

### 2.3. Zoom

`zoom_factor` is an exported float on `MatchCamera` (range roughly `0.25`–`8.0`). Changing it updates `Camera2D.zoom` directly. Match scenes should not hard-override zoom unless intentionally testing a different value.

---

## 3. Entity Interaction

Entities may expose different interaction capabilities.

### 3.1. Clickable Entities

Clickable entities can be selected with left click. Selection feedback uses the hover / selected circles described in §1.1. Being clickable does not imply being controllable; control is limited to the local player's own group.

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