class_name Building
extends StaticBody2D
## Grid-placed structure. Footprint cells define the rectangular hitbox (building.README.md).
##
## `def == null` keeps the original CP-11 footprint-only behavior used by
## tests/construction/building_grid_test.tscn (plain hitbox, no health/levels/economy).
## `def != null` (wall / tower / crystal mine instances) drives health, construction time,
## leveling, and type-specific ticking entirely from BuildingDef — one script for every
## structure type, matching docs/construction.README.md §7.

enum State { UNDER_CONSTRUCTION, IDLE, UPGRADING }

const PROJECTILE_SCENE := preload("res://src/combat/projectile.tscn")
## Fallback only — defs set tower_projectile_speed.
const DEFAULT_PROJECTILE_SPEED := 650.0
## Absorbs float residue from the level-up heal, so a visibly full structure never turns a
## plain RMB into a repair.
const DAMAGED_EPSILON := 0.01

@export var def: BuildingDef
@export var footprint := Vector2i(1, 1)
@export var display_name := "Building"
@export var fill_color := Color(0.35, 0.7, 0.95, 0.9)

var anchor_cell := Vector2i.ZERO
var grid: BuildGrid
var owner_peer_id := 0
var level := 1
var state: int = State.UNDER_CONSTRUCTION
var max_health := 0.0
var progress_ratio := 0.0
## Shadow of health.current for replication (mirrors Unit.sync_health).
var sync_current_health := 0.0
## Wall shield. 0.0 below def.shield_unlock_level and for every non-wall structure.
var max_shield := 0.0
## Shadow of shield.current for replication.
var sync_current_shield := 0.0
## Tower combat stats. Seeded from def.tower_base_stats and re-derived from tower_picks.
## Structure HP never comes from here — def.hp_for_level() stays the sole HP authority.
var stats := StatSheet.new()
## One counter per BuildingDef.TowerPath, replicated so clients show the same tower.
var tower_picks := PackedInt32Array([0, 0, 0, 0])

var _build_seconds := 0.0
var _build_elapsed := 0.0
var _mine_timer := 0.0
var _target_level := 1
## Copy of tower_picks the sheet was last built from, so clients rebuild only on change.
var _applied_picks := PackedInt32Array()
## Host-only. TowerPath paid for with the running upgrade; -1 when none is pending.
var _pending_pick := -1

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: Polygon2D = $Visual
@onready var health: HealthComponent = $Health
@onready var health_bar: HealthBar = $HealthBar
@onready var shield: ShieldComponent = $Shield
@onready var shield_bar: HealthBar = $ShieldBar
@onready var progress_bar: ProgressBar = $BuildProgressBar
@onready var attack: AttackController = $Attack


func _enter_tree() -> void:
	## The host owns health / level / construction state; mirrors Unit._enter_tree().
	set_multiplayer_authority(1)


func _ready() -> void:
	collision_layer = PhysicsLayers.WORLD | PhysicsLayers.BUILDING
	collision_mask = 0
	add_to_group("buildings")
	add_to_group("clickable")
	if def != null:
		footprint = def.footprint
		display_name = def.display_name
	if grid != null:
		global_position = grid.footprint_center(anchor_cell, footprint)
	_apply_footprint_visual()
	if def == null:
		## Legacy footprint-only building (building_grid_test.tscn) — nothing else to do.
		if health_bar != null:
			health_bar.visible = false
		if shield_bar != null:
			shield_bar.visible = false
		if progress_bar != null:
			progress_bar.visible = false
		return
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	shield.shield_changed.connect(_on_shield_changed)
	_setup_tower_stats()
	_begin_construction(1)


func _physics_process(delta: float) -> void:
	if def == null or not is_inside_tree() or multiplayer == null:
		return
	if _is_net_server():
		server_tick(delta)
	else:
		_apply_synced_state()
	_refresh_visuals()


## Old call site kept intact: tests/construction/building_grid_test.gd places footprint-only
## buildings with no owner / economy / health via this exact signature.
func setup(p_grid: BuildGrid, p_anchor: Vector2i, p_footprint: Vector2i = Vector2i.ZERO) -> void:
	grid = p_grid
	anchor_cell = p_anchor
	if p_footprint != Vector2i.ZERO:
		footprint = BuildGrid.positive_footprint(p_footprint)
	if grid != null:
		global_position = grid.footprint_center(anchor_cell, footprint)
	_apply_footprint_visual()


func is_clickable() -> bool:
	return true


func is_player_character() -> bool:
	return false


func is_attackable() -> bool:
	return def != null and health != null and health.is_alive()


func is_alive() -> bool:
	return is_attackable()


func is_own(local_peer_id: int) -> bool:
	return owner_peer_id == local_peer_id


func selection_hit_radius() -> float:
	var size_cells := BuildGrid.positive_footprint(footprint)
	var cell := grid.cell_size if grid != null else 32.0
	return maxf(size_cells.x, size_cells.y) * cell * 0.55


func is_under_construction() -> bool:
	return state != State.IDLE


func build_progress() -> float:
	if _build_seconds <= 0.0:
		return 1.0
	return clampf(_build_elapsed / _build_seconds, 0.0, 1.0)


func build_cost() -> float:
	return def.cost_for_level(1) if def != null else 0.0


func can_upgrade() -> bool:
	return def != null and state == State.IDLE and level < def.max_level


func next_upgrade_cost() -> float:
	return def.cost_for_level(level + 1) if def != null else 0.0


func begin_upgrade() -> void:
	if not can_upgrade():
		return
	_begin_construction(level + 1)


## True for the four BuildingDef.TowerPath values. ConstructionManager rejects anything else
## on a Tower upgrade before spending a single Crystal.
static func is_valid_tower_pick(path: int) -> bool:
	return path >= 0 and path < BuildingDef.TowerPath.size()


func is_tower() -> bool:
	return def != null and def.kind == BuildingDef.Kind.TOWER


## Number of times `path` has been taken on this tower.
func tower_pick_count(path: int) -> int:
	if path < 0 or path >= tower_picks.size():
		return 0
	return tower_picks[path]


## Host-only. Stores the pick paid for with the upgrade that is about to start; it is
## applied in _complete_construction(), together with the level and the HP gain, so a tower
## never holds more picks than levels and the bonus waits for the build time like HP does.
## ConstructionManager calls this only after try_spend_crystals() has succeeded.
func queue_tower_pick(path: int) -> void:
	if not is_tower() or not is_valid_tower_pick(path):
		return
	_pending_pick = path


## The pick waiting for the running upgrade to finish, or -1.
func pending_tower_pick() -> int:
	return _pending_pick


## Test / tooling only. Records one pick immediately, bypassing the upgrade queue, so it can
## give a tower more picks than levels. Gameplay goes through queue_tower_pick().
func apply_tower_pick(path: int) -> void:
	if not is_tower() or not is_valid_tower_pick(path) or path >= tower_picks.size():
		return
	tower_picks[path] += 1
	_rebuild_tower_stats()


func is_damaged() -> bool:
	return def != null and health != null and health.is_alive() \
		and health.current < max_health - DAMAGED_EPSILON


## Host-only. The single entry point for damage against a structure: the wall shield soaks
## first, health takes the rest. Returns the total actually applied (shield + health), which
## is what the attacker's Crystal income is paid on.
func apply_damage(amount: float) -> float:
	if not is_attackable() or amount <= 0.0:
		return 0.0
	var absorbed := shield.absorb(amount)
	sync_current_shield = shield.current
	var applied := absorbed
	var rest := amount - absorbed
	if rest > 0.0:
		applied += health.take_damage(rest, max_health)
	sync_current_health = health.current
	return applied


## Host-only. Restores health, never the shield (that recharges on its own). A structure
## still under its first construction cannot be repaired; an upgrading one can.
func repair(amount: float) -> float:
	if not is_attackable() or amount <= 0.0 or state == State.UNDER_CONSTRUCTION:
		return 0.0
	var before := health.current
	health.heal(amount, max_health)
	sync_current_health = health.current
	return health.current - before


## Host-only per-physics-frame tick. Safe to call while offline (OfflineMultiplayerPeer
## counts the local peer as the server), matching the rest of the host-authoritative code.
func server_tick(delta: float) -> void:
	if not is_attackable():
		return
	match state:
		State.UNDER_CONSTRUCTION:
			_tick_construction(delta)
		State.UPGRADING:
			_tick_construction(delta)
			_tick_active(delta)
			shield.tick(delta)
		State.IDLE:
			progress_ratio = 0.0
			_tick_active(delta)
			shield.tick(delta)
	sync_current_health = health.current
	sync_current_shield = shield.current


func _begin_construction(target_level: int) -> void:
	_target_level = target_level
	state = State.UNDER_CONSTRUCTION if target_level <= 1 else State.UPGRADING
	_build_seconds = def.build_seconds_for_level(target_level) if def != null else 1.0
	_build_elapsed = 0.0
	progress_ratio = 0.0
	if target_level <= 1:
		level = 1
		max_health = def.hp_for_level(1) if def != null else 100.0
		health.setup(max_health)
		sync_current_health = health.current
		max_shield = _shield_for_level(1)
		shield.setup(
			max_shield,
			def.shield_recharge_delay if def != null else 0.0,
			def.shield_recharge_per_second if def != null else 0.0
		)
		sync_current_shield = shield.current


func _tick_construction(delta: float) -> void:
	_build_elapsed = minf(_build_elapsed + delta, _build_seconds)
	progress_ratio = build_progress()
	if _build_elapsed >= _build_seconds:
		_complete_construction()


func _complete_construction() -> void:
	level = _target_level
	if def != null:
		var new_max := def.hp_for_level(level)
		var delta_max := new_max - max_health
		max_health = new_max
		if delta_max > 0.0:
			health.heal(delta_max, max_health)
		max_shield = _shield_for_level(level)
		shield.set_maximum(max_shield)
		sync_current_shield = shield.current
		if _pending_pick >= 0 and _pending_pick < tower_picks.size():
			tower_picks[_pending_pick] += 1
		_pending_pick = -1
		_rebuild_tower_stats()
	state = State.IDLE
	progress_ratio = 0.0


func _tick_active(delta: float) -> void:
	if def == null:
		return
	match def.kind:
		BuildingDef.Kind.CRYSTAL_MINE:
			_tick_mine(delta)
		BuildingDef.Kind.TOWER:
			_tick_tower(delta)
		_:
			pass


func _tick_mine(delta: float) -> void:
	_mine_timer += delta
	if _mine_timer < def.mine_interval:
		return
	_mine_timer -= def.mine_interval
	GameManager.grant_crystals(owner_peer_id, def.mine_output_for_level(level))


func _tick_tower(delta: float) -> void:
	attack.tick(delta)
	var target := attack.pick_target(global_position, _hunter_candidates())
	if target == null or not attack.in_attack_range(global_position, target):
		return
	if not attack.can_swing():
		return
	attack.mark_swung()
	_perform_tower_attack(target as Unit)


func _hunter_candidates() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit == null or not unit.is_attackable():
			continue
		if unit.role() != RoleConfig.Role.HUNTER:
			continue
		result.append(unit)
	return result


## Host-only. The swing is resolved here but the HP only drops when the projectile lands,
## so the shot on screen and the damage number always agree.
func _perform_tower_attack(target: Unit) -> void:
	if target == null or not is_instance_valid(target):
		return
	var result := CombatDamage.resolve_ranged(stats, target.stats)
	_spawn_projectile(target, _on_projectile_hit.bind(float(result.damage), bool(result.critical)))
	_broadcast_projectile(target)


## Impact callback bound per shot. `hit_target` is supplied by the projectile, which only
## fires the callback while the target is still a valid, attackable instance.
func _on_projectile_hit(hit_target: Node2D, damage: float, critical: bool) -> void:
	var target := hit_target as Unit
	if target == null or not is_instance_valid(target) or not target.is_attackable():
		return
	if damage <= 0.0:
		return
	var target_max := target.stats.final_value(StatBlock.Stat.MAX_HEALTH)
	var applied: float = target.health.take_damage(damage, target_max)
	target.sync_health = target.health.current
	GameLog.info(
		"COMBAT",
		"%s (tower) hit %s for %.1f%s" % [
			name,
			str(target.peer_id),
			applied,
			" (crit)" if critical else "",
		]
	)


func _spawn_projectile(target: Node2D, on_hit: Callable) -> void:
	if target == null or not is_instance_valid(target) or not is_inside_tree():
		return
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	if host == null:
		return
	var projectile := PROJECTILE_SCENE.instantiate() as Projectile
	if projectile == null:
		return
	host.add_child(projectile)
	projectile.setup(global_position, target, _projectile_speed(), on_hit)


## Cosmetic copy for the other peers. Unreliable and unspawned on purpose: a dropped shot
## costs a missing sprite, never a desynced hit point. Skipped when nobody else is
## connected, which also covers the offline case (OfflineMultiplayerPeer has no peers), so
## a single-player host still sees exactly one projectile.
func _broadcast_projectile(target: Node2D) -> void:
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.get_peers().is_empty():
		return
	_rpc_show_projectile.rpc(target.get_path())


@rpc("authority", "unreliable")
func _rpc_show_projectile(target_path: NodePath) -> void:
	if _is_net_server():
		return
	var target := get_node_or_null(target_path) as Node2D
	if target == null:
		return
	_spawn_projectile(target, Callable())


func _projectile_speed() -> float:
	if def == null or def.tower_projectile_speed <= 0.0:
		return DEFAULT_PROJECTILE_SPEED
	return def.tower_projectile_speed


## Seeds the combat sheet once, at _ready. Never touches HealthComponent: a tower's HP is
## def.hp_for_level(level) and tower_base_stats.max_health is only a readable mirror of it.
func _setup_tower_stats() -> void:
	if not is_tower():
		return
	if def.tower_base_stats == null:
		## StatSheet would fall back to StatBlock defaults (attack_range 0): a tower that never fires.
		push_warning("%s: tower def '%s' has no tower_base_stats" % [name, def.id])
	stats.stats_changed.connect(_apply_derived_stats)
	stats.set_base(def.tower_base_stats)
	_rebuild_tower_stats()


## Mirrors Unit._apply_derived_stats(): the attack controller is a view of the stat sheet.
func _apply_derived_stats() -> void:
	if attack == null or not is_tower():
		return
	var attack_speed := stats.final_value(StatBlock.Stat.ATTACK_SPEED)
	if attack_speed > 0.0:
		attack.attack_interval = 1.0 / attack_speed
	var reach := stats.final_value(StatBlock.Stat.ATTACK_RANGE)
	attack.attack_range = reach
	attack.acquisition_range = reach


## Rebuilds the whole modifier list from tower_picks. Percentage modifiers sum (they do not
## compound), so three Damage picks are +90%, not 1.3^3. Crit must stay FLAT: the base crit
## chance is 0 and final_value is (base + flat) * (1 + percent), so a percentage crit pick
## would multiply zero and grant nothing.
func _rebuild_tower_stats() -> void:
	if not is_tower():
		return
	stats.clear_modifiers()
	## Only RANGED_DAMAGE, not StatModifier.Scope.ALL_DAMAGE: a tower never swings melee
	## and CombatDamage.resolve_ranged() reads this one stat.
	_add_pick_modifier(
		StatModifier.Kind.PERCENT,
		StatBlock.Stat.RANGED_DAMAGE,
		def.tower_damage_per_pick * tower_pick_count(BuildingDef.TowerPath.RANGED_DAMAGE)
	)
	_add_pick_modifier(
		StatModifier.Kind.PERCENT,
		StatBlock.Stat.ATTACK_SPEED,
		def.tower_attack_speed_per_pick * tower_pick_count(BuildingDef.TowerPath.ATTACK_SPEED)
	)
	_add_pick_modifier(
		StatModifier.Kind.FLAT,
		StatBlock.Stat.CRITICAL_CHANCE,
		def.tower_crit_chance_per_pick * tower_pick_count(BuildingDef.TowerPath.CRIT)
	)
	_add_pick_modifier(
		StatModifier.Kind.FLAT,
		StatBlock.Stat.CRITICAL_DAMAGE_MULTIPLIER,
		def.tower_crit_damage_per_pick * tower_pick_count(BuildingDef.TowerPath.CRIT)
	)
	_add_pick_modifier(
		StatModifier.Kind.PERCENT,
		StatBlock.Stat.ATTACK_RANGE,
		def.tower_range_per_pick * tower_pick_count(BuildingDef.TowerPath.ATTACK_RANGE)
	)
	_applied_picks = tower_picks.duplicate()
	_apply_derived_stats()


func _add_pick_modifier(kind: StatModifier.Kind, stat: StatBlock.Stat, value: float) -> void:
	if is_zero_approx(value):
		return
	var modifier := StatModifier.new()
	modifier.kind = kind
	modifier.scope = StatModifier.Scope.ONE_STAT
	modifier.stat = stat
	modifier.value = value
	stats.add_modifier(modifier)


## Only walls carry a shield; the def defaults (shield_base 0.0) would also yield 0.0 for the
## other kinds, but a tower or mine def must never grow one by accident.
func _shield_for_level(p_level: int) -> float:
	if def == null or def.kind != BuildingDef.Kind.WALL:
		return 0.0
	return def.shield_for_level(p_level)


func _apply_synced_state() -> void:
	max_health = def.hp_for_level(maxi(level, 1)) if def != null else max_health
	health.set_from_sync(sync_current_health, max_health)
	shield.set_from_sync(sync_current_shield, max_shield)
	if is_tower() and tower_picks != _applied_picks:
		## The replicated picks changed: remote players see the real tower stats.
		_rebuild_tower_stats()


func _refresh_visuals() -> void:
	if progress_bar != null:
		progress_bar.visible = state != State.IDLE
		progress_bar.value = progress_ratio * 100.0
	modulate = Color(1, 1, 1, 0.6) if state == State.UNDER_CONSTRUCTION else Color.WHITE


func _on_health_changed(current: float, maximum: float) -> void:
	if health_bar != null:
		health_bar.update_for_health(current, maximum)


func _on_shield_changed(current: float, maximum: float) -> void:
	if shield_bar == null:
		return
	shield_bar.visible = maximum > 0.0
	shield_bar.update_for_health(current, maximum)


func _on_died() -> void:
	if _is_net_server():
		GameLog.info("CONSTRUCTION", "%s destroyed" % name)
		queue_free()


func _is_net_server() -> bool:
	return is_inside_tree() and multiplayer != null and multiplayer.is_server()


func _apply_footprint_visual() -> void:
	var size_cells := BuildGrid.positive_footprint(footprint)
	var cell := grid.cell_size if grid != null else 32.0
	var pixel_size := Vector2(size_cells) * cell
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)
	var rect := RectangleShape2D.new()
	rect.size = pixel_size
	collision_shape.shape = rect
	collision_shape.position = Vector2.ZERO

	if visual == null:
		visual = get_node_or_null("Visual") as Polygon2D
	if visual == null:
		visual = Polygon2D.new()
		visual.name = "Visual"
		add_child(visual)
		move_child(visual, 0)
	var half := pixel_size * 0.5
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	visual.color = fill_color
