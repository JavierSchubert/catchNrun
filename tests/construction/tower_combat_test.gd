extends Node2D
## Interactive tower-combat sandbox: one Tower plus a dummy Hunter that patrols in and out
## of range, so projectiles and the four upgrade stat paths can be watched directly.
##   godot --path . res://tests/construction/tower_combat_test.tscn
##
## The harness grants a large Crystal balance up front and places the Tower for you, so
## nothing here depends on the lobby -> role selection -> match flow.
##
## Controls:
##   The four buttons on the left apply one upgrade pick each (Damage / Attack Speed /
##   Crit / Range). They go through the real ConstructionManager.request_upgrade(name, pick),
##   so each press also spends the level cost and starts a short upgrade build.
##   "Heal dummy" refills the target when you have ground it down.
##
## What to look for (every number is read from tower_def.tres and the Tower's StatSheet,
## so check them against those files rather than against anything quoted here):
##   - The Tower spends its first ~6 seconds under construction (translucent, progress bar)
##     and does not shoot. Once it turns solid it starts firing.
##   - A projectile sprite leaves the Tower, turns to face its travel direction, and homes
##     on the dummy while the dummy is moving. The dummy's HP only drops when the sprite
##     reaches it, never at the moment of firing.
##   - The dummy patrols left and right. Shots stop while it is outside the readout's
##     "Range" value and resume when it comes back in. No stray projectile is left hanging.
##   - Damage picks raise "DMG" by a fixed percentage of the base each time and they SUM:
##     three Damage picks give +90%, not 1.3^3.
##   - Attack Speed picks raise "atk/s" and visibly shorten the gap between shots.
##   - Range picks grow "Range"; the dummy then gets shot earlier in its patrol.
##   - Crit picks raise "Crit" from 0% and "CritDmg" above its base. Crit is the one path
##     that must still work from a zero base — if it stays at 0% the modifier is wrong.
##   - "HP" climbs on every upgrade regardless of the pick, because max HP is driven by
##     BuildingDef.hp_for_level() and not by any pick.
##   - A pick takes effect when its upgrade finishes, not on the press: the stats and the
##     pick counters stay put while the Tower shows "upgrading", and the buttons are disabled.
##   - The pick counters line ("Dmg 3 · Spd 1 · Crit 0 · Rng 2") must match what you pressed.

const TOWER_SCENE := preload("res://src/buildings/tower.tscn")
const UNIT_SCENE := preload("res://src/units/unit/unit.tscn")

const DUMMY_PEER_ID := 2
const DUMMY_MAX_HEALTH := 20000.0
## Wide enough that the dummy still leaves the reach of a tower with ~15 Range picks.
const PATROL_HALF_WIDTH := 1100.0
const PATROL_SECONDS := 10.0
const PATROL_OFFSET_Y := 60.0
const TEST_CRYSTALS := 1.0e9

@onready var camera: Camera2D = %Camera2D
@onready var stats_label: Label = %StatsLabel
@onready var pick_damage_button: Button = %PickDamageButton
@onready var pick_speed_button: Button = %PickSpeedButton
@onready var pick_crit_button: Button = %PickCritButton
@onready var pick_range_button: Button = %PickRangeButton
@onready var heal_button: Button = %HealButton

var _tower: Building
var _dummy: Unit
var _center := Vector2.ZERO
var _elapsed := 0.0
## Ordered to match BuildingDef.TowerPath.
var _pick_buttons: Array[Button] = []


func _ready() -> void:
	GameManager.prepare_game_test()
	## The economy is not what this harness tests — never run out mid-experiment.
	GameManager.grant_crystals(1, TEST_CRYSTALS)
	_center = Unit.MAP_BOUNDS.get_center()
	camera.position = _center
	camera.enabled = DisplayServer.get_name() != "headless"
	if camera.enabled:
		camera.make_current()
	_pick_buttons = [pick_damage_button, pick_speed_button, pick_crit_button, pick_range_button]
	for path in _pick_buttons.size():
		_pick_buttons[path].pressed.connect(_on_pick_pressed.bind(path))
	heal_button.pressed.connect(_on_heal_pressed)
	_spawn_tower()
	_spawn_dummy()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_drive_dummy()
	_refresh_readout()
	## A press during a running upgrade would be rejected by the host; say so visibly.
	var can_pick := _tower != null and is_instance_valid(_tower) and _tower.can_upgrade()
	for button in _pick_buttons:
		button.disabled = not can_pick


func _spawn_tower() -> void:
	var manager := _construction_manager()
	if manager == null:
		return
	var def := ConstructionManager.TOWER_DEF
	_tower = TOWER_SCENE.instantiate() as Building
	_tower.name = "TestTower"
	_tower.owner_peer_id = 1
	_tower.grid = manager.grid
	_tower.anchor_cell = manager.grid.snap_anchor_cell(_center, def.footprint)
	manager.buildings_root.add_child(_tower)


func _spawn_dummy() -> void:
	_dummy = UNIT_SCENE.instantiate() as Unit
	## Unit reads its peer id from the node name.
	_dummy.name = str(DUMMY_PEER_ID)
	_dummy.config = _dummy_config()
	add_child(_dummy)
	_dummy.global_position = _center + Vector2(PATROL_HALF_WIDTH, PATROL_OFFSET_Y)


## A Hunter that cannot move or fight on its own: the harness drives its position and the
## Tower is the only thing dealing damage.
func _dummy_config() -> RoleConfig:
	var block := StatBlock.new()
	block.max_health = DUMMY_MAX_HEALTH
	block.health_regeneration = 0.0
	block.defense = 0.0
	block.movement_speed = 0.0
	block.melee_damage = 0.0
	block.ranged_damage = 0.0
	block.magic_damage = 0.0
	block.critical_chance = 0.0
	block.lifesteal_chance = 0.0
	block.lifesteal_amount = 0.0
	var config := RoleConfig.new()
	config.role = RoleConfig.Role.HUNTER
	config.display_name = "Dummy"
	config.base_stats = block
	config.move_speed = 0.0
	config.attack_range = 0.0
	config.acquisition_range = 0.0
	config.attack_interval = 1.0
	return config


func _drive_dummy() -> void:
	if _dummy == null or not is_instance_valid(_dummy) or not _dummy.is_alive():
		return
	var phase := sin(_elapsed * TAU / PATROL_SECONDS)
	_dummy.global_position = _center + Vector2(phase * PATROL_HALF_WIDTH, PATROL_OFFSET_Y)


func _refresh_readout() -> void:
	if _tower == null or not is_instance_valid(_tower):
		stats_label.text = "No tower."
		return
	var def := _tower.def
	var stats := _tower.stats
	var distance := INF
	var dummy_hp := 0.0
	if _dummy != null and is_instance_valid(_dummy):
		distance = _tower.global_position.distance_to(_dummy.global_position)
		dummy_hp = _dummy.health.current
	var reach := stats.final_value(StatBlock.Stat.ATTACK_RANGE)
	stats_label.text = "\n".join([
		"Tower Lv %d / %d  (%s)" % [_tower.level, def.max_level, _state_text()],
		"HP        %.0f / %.0f" % [_tower.health.current, _tower.max_health],
		"DMG       %.1f" % stats.final_value(StatBlock.Stat.RANGED_DAMAGE),
		"atk/s     %.2f" % stats.final_value(StatBlock.Stat.ATTACK_SPEED),
		"Range     %.0f" % reach,
		"Crit      %.0f%%   CritDmg x%.2f" % [
			stats.final_value(StatBlock.Stat.CRITICAL_CHANCE) * 100.0,
			stats.final_value(StatBlock.Stat.CRITICAL_DAMAGE_MULTIPLIER),
		],
		"Picks     Dmg %d · Spd %d · Crit %d · Rng %d" % [
			_tower.tower_pick_count(BuildingDef.TowerPath.RANGED_DAMAGE),
			_tower.tower_pick_count(BuildingDef.TowerPath.ATTACK_SPEED),
			_tower.tower_pick_count(BuildingDef.TowerPath.CRIT),
			_tower.tower_pick_count(BuildingDef.TowerPath.ATTACK_RANGE),
		],
		"Next cost %d" % int(_tower.next_upgrade_cost()),
		"",
		"Dummy HP  %.0f / %.0f" % [dummy_hp, DUMMY_MAX_HEALTH],
		"Distance  %.0f  (%s)" % [distance, "in range" if distance <= reach else "out of range"],
	])


func _state_text() -> String:
	match _tower.state:
		Building.State.UNDER_CONSTRUCTION:
			return "building"
		Building.State.UPGRADING:
			return "upgrading"
	return "ready"


func _on_pick_pressed(path: int) -> void:
	var manager := _construction_manager()
	if manager == null or _tower == null or not is_instance_valid(_tower):
		return
	manager.request_upgrade(_tower.name, path)


func _on_heal_pressed() -> void:
	if _dummy == null or not is_instance_valid(_dummy):
		return
	_dummy.health.setup(DUMMY_MAX_HEALTH)
	_dummy.sync_health = _dummy.health.current


func _construction_manager() -> ConstructionManager:
	return get_tree().get_first_node_in_group("construction_manager") as ConstructionManager
