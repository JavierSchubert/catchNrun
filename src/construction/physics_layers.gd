class_name PhysicsLayers
extends RefCounted
## Named 2D physics layers from project.godot / building.README.md §5.


const WORLD := 1 << 0
const OBSTACLE := 1 << 1
const UNIT := 1 << 2
const BUILDING := 1 << 3
const DESTRUCTIBLE := 1 << 4
const ITEM := 1 << 5

## Layers that make a build footprint invalid when overlapped.
const BUILD_BLOCKERS := OBSTACLE | UNIT | BUILDING | DESTRUCTIBLE
