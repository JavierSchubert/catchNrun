extends Node2D
## Interactive building-system sandbox: the real ConstructionManager + build UI +
## resource bar + grid, without needing the lobby -> role selection -> match flow.
##   godot --path . res://tests/construction/building_system_test.tscn
##
## Controls:
##   Click a build button (bottom-right panel) to arm a structure, move the mouse to
##   preview it snapped to the grid, LMB to place (spends Crystals and starts the few
##   seconds construction progress bar). RMB or Esc cancels placement.
##   Click a placed structure to see its details and Upgrade / Destroy it.
##
## What to look for (values come from EconomyConfig / the BuildingDef resources, so check
## them against those files rather than against the numbers quoted here):
##   - The top-center resource bar starts at 20 Crystals and is shown for both roles
##     (relaunch with --test-role=hunter to confirm it still appears).
##   - Build costs on the buttons read Mine 16 / Wall 8 / Tower 24; a button greys out
##     as soon as the balance drops below its cost.
##   - Once a Crystal Mine finishes building, the counter starts ticking up and the bar
##     grows a "+X/s" income readout; destroying the mine removes it again.
##   - Selecting a mine shows its output line ("N crystals / Ns"), a Tower shows
##     damage / range / attack speed / crit plus its pick counters and the 2x2 upgrade pick
##     grid (each button spends the level cost and takes that stat path), and a Wall shows
##     a plain Upgrade button. See tests/construction/tower_combat_test.tscn for the picks
##     actually changing a tower's shots.
##   - Upgrading a Wall repeatedly to its cap (level 20) must replace the upgrade area
##     with the "Max level reached" line. A Mine caps at level 11.

@onready var camera: Camera2D = %Camera2D


func _ready() -> void:
	GameManager.prepare_game_test()
	camera.position = Unit.MAP_BOUNDS.get_center()
	camera.enabled = DisplayServer.get_name() != "headless"
	if camera.enabled:
		camera.make_current()
	_spawn_blockers()


func _spawn_blockers() -> void:
	## A couple of pre-placed obstacles so placement validation has something to reject.
	_add_blocker(PhysicsLayers.WORLD | PhysicsLayers.OBSTACLE, Color(0.45, 0.35, 0.25, 0.95), Vector2(96, 96), Vector2(-200, -120))
	_add_blocker(PhysicsLayers.WORLD | PhysicsLayers.DESTRUCTIBLE, Color(0.85, 0.55, 0.2, 0.95), Vector2(48, 48), Vector2(180, 100))


func _add_blocker(layer: int, color: Color, size: Vector2, pos: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var visual := Polygon2D.new()
	var half := size * 0.5
	visual.color = color
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	body.add_child(visual)
	add_child(body)
