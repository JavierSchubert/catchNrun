# Minimap

## 1. Overview

The minimap provides a compact representation of the map and the information currently known to the local player's team.

It must respect fog of war and must never reveal live information that the Vision system has not made available.

## 2. Map Representation

The minimap shows a scaled copy of the current match map asset (for example the lava background) so the player can relate world layout to the compact view.

Entity and structure markers are drawn on top of that map image at positions that match their relative world coordinates: a unit at the top-left of the playable map appears at the top-left of the minimap, and so on.

Relevant structures and entities can be represented using configured pixel colors or compact icons.

The exact visual mapping should remain configurable.

Examples may include different representations for:

- Runner structures.
- Hunter-related structures.
- Runners.
- Hunter.
- Neutral / interactive objects.

### 2.1. Unit pixel colors (current milestone)

Until fog of war lands, living units are always shown on the minimap as small equal-sized pixels. Colors are **viewer-relative** (`Unit.minimap_marker_color`), not identical to selection-circle affinity in every case:

| Viewer | Own unit | Allied Runners | Enemy / Hunter |
| --- | --- | --- | --- |
| Runner | Green | Blue | Hunter = Red |
| Hunter | Green | — | Every Runner = Red |

Own and other units use the same pixel size. Selection circles may still use team affinity colors separately.

### 2.2. Camera frustum

The minimap draws a light outline of the current camera viewport so the player can see where they are looking relative to the map.

### 2.3. Minimap clicks

| Input | Result |
| --- | --- |
| Left-click | Recenter the match camera on the corresponding world position (`MatchCamera.center_on`) |
| Right-click | Issue a move command for the selected controllable unit to that world position (blue marker) |
| `A` then left-click | Issue an attack-move to that world position (red marker); requires an attacker selected |

World mapping uses the same `minimap_to_world` / `world_to_minimap` helpers as the unit dots. The minimap uses `MOUSE_FILTER_STOP` so clicks are captured and edge-scroll stays off while hovering it.

### 2.4. Scene / style resources

Layout and frame StyleBox live in:

```text
ui/hud/minimap/minimap.tscn
ui/hud/minimap/minimap_frame_style.tres
```

Instanced by `game/match/hud.tscn`. Runtime only binds map bounds / redraws unit dots.

## 3. Vision States

Minimap information reflects the three vision states defined by the Vision system:

```text
Unexplored
Currently Visible
Previously Seen
```

### Unexplored

Do not display entity information that has never been discovered.

### Currently Visible

Display current information and positions for minimap-relevant entities.

### Previously Seen

Display permitted last-known information without receiving hidden live updates.

## 4. Last-Known Structure Information

Static structures can remain visible on the minimap at their last-known position after leaving vision.

```text
Structure becomes visible
-> Create / update minimap representation

Structure leaves vision
-> Keep last-known representation
-> Stop updating hidden state

Area becomes visible again
-> Refresh representation from current world state
```

Example:

```text
Enemy Tower discovered
-> Tower appears on minimap

Tower leaves vision
-> Last-known Tower remains

Tower is destroyed outside vision
-> Minimap still shows the remembered Tower

Tower location becomes visible again
-> Vision detects no Tower
-> Remove Tower from minimap
```

## 5. Moving Units

Moving entities such as Runners and the Hunter should only expose information permitted by the Vision system.

A moving unit leaving vision must not continue to move live on the opposing team's minimap.

If last-known positions are displayed, the marker represents the last observed location rather than the current hidden location.

## 6. Team Separation

Runner and Hunter minimap knowledge is separate.

```text
Runner Minimap
-> Runner Team Vision and Knowledge

Hunter Minimap
-> Hunter Team Vision and Knowledge
```

Runner team members may share minimap knowledge if Runner vision is shared.

## 7. Responsibility Boundary

```text
Vision System
-> Determines what the team currently knows

Minimap
-> Converts known information into minimap presentation
```

The minimap should not perform independent hidden-entity detection.
