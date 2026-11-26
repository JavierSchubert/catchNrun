extends Node2D
## Interactive wall-shield / Runner-repair sandbox: a level 1 Wall, a level 15 Wall (shield
## unlocked) and your Runner, so the shield, its recharge, and repair can be watched directly.
##   godot --path . res://tests/construction/wall_repair_test.tscn
##
## Nothing here depends on the lobby -> role selection -> match flow: the harness puts
## peer 1 in the roster as a Runner and places both walls (already finished) for you.
##
## Controls:
##   RMB on a damaged wall — the Runner walks over and repairs it (green ring on the wall).
##   RMB on the ground — walks there and cancels any repair.
##   "Damage walls" — hits both walls through Building.apply_damage(), the same entry
##   point the Hunter's melee uses.
##
## What to look for (numbers come from wall_def.tres and repair_def.tres):
##   - The level 1 wall has no shield bar; every hit goes straight to its HP.
##   - The level 15 wall shows a blue shield bar above its HP bar. A hit drains the shield
##     first and only the overflow reaches HP.
##   - shield_recharge_delay seconds after the last hit the shield starts refilling at
##     shield_recharge_per_second of its maximum per second. Another hit restarts the wait.
##   - Repair restores HP at value_per_second and never touches the shield. It stops by
##     itself at full HP; RMB on a full-HP wall is a plain move.

const WALL_SCENE := preload("res://src/buildings/wall.tscn")
const RUNNER_SCENE := preload("res://src/units/runner/runner.tscn")

const LOCAL_PEER_ID := 1
## Share of a wall's total pool (HP + shield) one press removes: never kills a full wall,
## and the Lv 15 wall's shield (900 of ~3.4k) holds the first press and breaks on the second.
const DAMAGE_SHARE_PER_PRESS := 0.2
const WALL_HALF_GAP_CELLS := 4

@onready var camera: Camera2D = %Camera2D
@onready var stats_label: Label = %StatsLabel
@onready var damage_button: Button = %DamageButton

var _walls: Array[Building] = []
var _runner: Unit
var _center := Vector2.ZERO


func _ready() -> void:
	GameManager.prepare_game_test()
	## prepare_game_test() picks the role from LaunchOptions; this harness needs a Runner.
	var entry: Dictionary = GameManager.players[LOCAL_PEER_ID]
	entry["role"] = RoleConfig.Role.RUNNER
	GameManager.players[LOCAL_PEER_ID] = entry
	_center = Unit.MAP_BOUNDS.get_center()
	camera.position = _center
	camera.enabled = DisplayServer.get_name() != "headless"
	if camera.enabled:
		camera.make_current()
	damage_button.pressed.connect(_on_damage_pressed)
	_spawn_wall("WallLv1", Vector2i(-WALL_HALF_GAP_CELLS, 0), 1)
	var shield_level := ConstructionManager.WALL_DEF.shield_unlock_level
	_spawn_wall("WallLv%d" % shield_level, Vector2i(WALL_HALF_GAP_CELLS, 0), shield_level)
	_spawn_runner()


func _process(_delta: float) -> void:
	_refresh_readout()


func _spawn_wall(node_name: String, cell_offset: Vector2i, target_level: int) -> void:
	var manager := _construction_manager()
	if manager == null:
		return
	var def := ConstructionManager.WALL_DEF
	var wall := WALL_SCENE.instantiate() as Building
	wall.name = node_name
	wall.owner_peer_id = LOCAL_PEER_ID
	wall.grid = manager.grid
	wall.anchor_cell = manager.grid.snap_anchor_cell(_center, def.footprint) + cell_offset
	manager.buildings_root.add_child(wall)
	## Skip the build timers: run the real upgrade path straight to the wanted level.
	wall.state = Building.State.IDLE
	while wall.level < target_level:
		wall.begin_upgrade()
		wall._complete_construction()
	_walls.append(wall)


func _spawn_runner() -> void:
	_runner = RUNNER_SCENE.instantiate() as Unit
	## Unit reads its peer id from the node name; peer 1 is the local, controllable player.
	_runner.name = str(LOCAL_PEER_ID)
	add_child(_runner)
	_runner.global_position = _center + Vector2(0.0, 160.0)


func _on_damage_pressed() -> void:
	_prune_destroyed_walls()
	for wall in _walls:
		wall.apply_damage(DAMAGE_SHARE_PER_PRESS * (wall.max_health + wall.max_shield))


## A typed-array loop over a freed Building would error, so drop destroyed walls first.
## By index: never hand a freed instance to a typed variable.
func _prune_destroyed_walls() -> void:
	for i in range(_walls.size() - 1, -1, -1):
		if not is_instance_valid(_walls[i]):
			_walls.remove_at(i)


func _refresh_readout() -> void:
	_prune_destroyed_walls()
	var lines: PackedStringArray = PackedStringArray()
	for wall in _walls:
		lines.append("%s  Lv %d" % [wall.name, wall.level])
		lines.append("  HP      %.0f / %.0f" % [wall.health.current, wall.max_health])
		if wall.max_shield > 0.0:
			lines.append("  Shield  %.0f / %.0f" % [wall.shield.current, wall.max_shield])
		else:
			lines.append("  Shield  none (unlocks at Lv %d)" % wall.def.shield_unlock_level)
	lines.append("")
	var repairing := _runner != null and is_instance_valid(_runner) and _runner.is_repairing()
	lines.append("Runner  %s" % ("repairing" if repairing else "idle"))
	lines.append("Repair  %.0f HP/s" % RepairSkill.DEF.value_per_second)
	stats_label.text = "\n".join(lines)


func _construction_manager() -> ConstructionManager:
	return get_tree().get_first_node_in_group("construction_manager") as ConstructionManager
