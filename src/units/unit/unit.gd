class_name Unit
extends CharacterBody2D
## Placeholder unit shared by the Hunter and Runner scenes.
##
## A local player right-clicks the ground to move, or an enemy to attack.
## The host builds paths, resolves melee swings, and replicates position + health.
## Hunter bots chase the nearest living Runner and attack when in range.

const INTERPOLATION_SPEED := 12.0
const SNAP_DISTANCE := 200.0
## Matches PlateauMap.world_bounds() (40x28 tiles at 128px = 5120x3584).
const MAP_BOUNDS := Rect2(-2560.0, -1792.0, 5120.0, 3584.0)
const MAP_INSET := 20.0
const SPRITE_COUNT := 5
const RUNNER_SPRITES := [
	preload("res://assets/sprites/units/Player_1.png"),
	preload("res://assets/sprites/units/Player_2.png"),
	preload("res://assets/sprites/units/Player_3.png"),
	preload("res://assets/sprites/units/Player_4.png"),
	preload("res://assets/sprites/units/Player_5.png"),
]
const HUNTER_SPRITES := [
	preload("res://assets/sprites/units/Enemy_1.png"),
	preload("res://assets/sprites/units/Enemy_2.png"),
	preload("res://assets/sprites/units/Enemy_3.png"),
	preload("res://assets/sprites/units/Enemy_4.png"),
	preload("res://assets/sprites/units/Enemy_5.png"),
]

@export var config: RoleConfig

var peer_id := 0
var sync_position := Vector2.ZERO
var sync_health := 0.0
## Host-owned progression; replicated for the selection-panel XP ring / level badge.
var level := 1
var xp := 0.0
var stats := StatSheet.new()
## Host-owned Hunter rewards, replicated as accumulated bonuses for client stat sheets.
var hunter_upgrade_flat_bonuses := PackedFloat32Array()
var hunter_upgrade_percent_bonuses := PackedFloat32Array()
var pending_upgrade_levels := PackedInt32Array()
var pending_upgrade_choice_level := 0
var pending_upgrade_choice_stats := PackedInt32Array()
var pending_upgrade_choice_rarities := PackedInt32Array()
var pending_upgrade_choice_values := PackedFloat32Array()
## Host-owned list of purchased Item Shop entry ids (order = inventory slots).
var shop_inventory := PackedStringArray()

var _intent := Vector2.ZERO
var _eliminated := false
var _bot_chase_peer_id := -1
## When the hunter bot chases a structure, track by path (buildings have no peer_id).
var _bot_chase_building_path := NodePath()
## Accumulates tiny regen heals so floating numbers do not spam every physics frame.
var _regen_fx_accum := 0.0
## Seconds since this unit last lost health (out-of-combat regen gate).
var _since_damage := 0.0
var _last_health_for_regen := 0.0
var _bot_repath_in := 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var name_label: Label = $NameLabel
@onready var movement: UnitMovement = $Movement
@onready var health: HealthComponent = $Health
@onready var health_bar: HealthBar = $HealthBar
@onready var attack: AttackController = $Attack
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _selection_circle: SelectionCircle
var _selection_hovered := false
var _selection_selected := false
var _attack_flash_remaining := 0.0
## Server-authoritative shift-click waypoint queue (world positions).
var _move_chain: Array[Vector2] = []
## Local-only green dotted path / waypoint rings for the commanding player.
var _chain_visual: MoveChainVisual
## Host-only. Own structure this Runner is walking to / channelling `repair` on.
var _repair_target: Building = null
var _repair_repath_in := 0.0
## Host-only Hunter Seek timers (see SeekSkill / SeekPresentation).
var _seek_cooldown_left := 0.0
var _seek_active_left := 0.0
var _seek_sync_accum := 0.0
var _applied_max_health := 0.0
var _health_initialized := false
var _hunter_upgrade_modifiers: Array[StatModifier] = []
var _applied_upgrade_flat := PackedFloat32Array()
var _applied_upgrade_percent := PackedFloat32Array()
var _shop_modifiers: Array[StatModifier] = []
var _applied_shop_inventory := PackedStringArray()


func _enter_tree() -> void:
	peer_id = name.to_int()
	# The host owns the replicated position. The owner still only sends intent.
	set_multiplayer_authority(1)


func _ready() -> void:
	add_to_group("units")
	add_to_group("clickable")
	_ensure_selection_circle()
	if config == null:
		push_error("Unit %s is missing a role config." % name)
		return
	_ensure_hunter_upgrade_arrays()
	_clamp_to_map()
	sync_position = position
	stats.stats_changed.connect(_apply_derived_stats)
	stats.set_base(_base_stats())
	_apply_synced_hunter_upgrade_bonuses()
	_apply_synced_shop_inventory()
	attack.attack_range = config.attack_range
	attack.acquisition_range = config.acquisition_range
	_apply_derived_stats()
	health.died.connect(_on_died)
	health.health_changed.connect(_on_health_changed_for_regen)
	if health_bar != null:
		## Player characters always show their HP strip; structures hide theirs when full.
		health_bar.show_when_full = true
		health.health_changed.connect(health_bar.update_for_health)
	health.setup(stats.final_value(StatBlock.Stat.MAX_HEALTH))
	_health_initialized = true
	_last_health_for_regen = health.current
	## Start "out of combat" so opening regen is not gated until the first hit.
	_since_damage = config.regen_delay_after_damage if config != null else 0.0
	sync_health = health.current
	if health_bar != null:
		health_bar.update_for_health(health.current, stats.final_value(StatBlock.Stat.MAX_HEALTH))
	var player_data: Dictionary = GameManager.players.get(peer_id, {})
	sprite.texture = sprite_texture(int(player_data.get("sprite_index", 0)), config.role)
	sprite.modulate = Color.WHITE
	_refresh_label()
	refresh_selection_visual()
	GameManager.players_changed.connect(_on_players_changed)
	if GameManager.is_eliminated(peer_id):
		_apply_eliminated_visual()
	_notify_selection_manager_ready()


func _base_stats() -> StatBlock:
	if config.base_stats != null:
		return config.base_stats
	var block := StatBlock.new()
	block.movement_speed = config.move_speed
	if config.attack_interval > 0.0:
		block.attack_speed = 1.0 / config.attack_interval
	return block


func _apply_derived_stats() -> void:
	movement.speed = stats.final_value(StatBlock.Stat.MOVEMENT_SPEED)
	var attack_speed := stats.final_value(StatBlock.Stat.ATTACK_SPEED)
	if attack_speed > 0.0:
		attack.attack_interval = 1.0 / attack_speed
	elif config != null and config.attack_interval > 0.0:
		attack.attack_interval = config.attack_interval
	var next_max_health := stats.final_value(StatBlock.Stat.MAX_HEALTH)
	if _health_initialized and _applied_max_health > 0.0 \
			and next_max_health > _applied_max_health and _is_net_server():
		health.heal(next_max_health - _applied_max_health, next_max_health)
		sync_health = health.current
	_applied_max_health = next_max_health


func is_alive() -> bool:
	return not _eliminated and health.is_alive()


func is_attackable() -> bool:
	return is_alive()


func is_clickable() -> bool:
	return is_alive()


func is_player_character() -> bool:
	return true


func is_local_controllable(local_peer_id: int) -> bool:
	return peer_id == local_peer_id and is_alive()


func selection_hit_radius() -> float:
	return _body_radius() * 1.75


func selection_circle_radius() -> float:
	return _body_radius() * 1.45


func set_selection_hover(active: bool) -> void:
	_selection_hovered = active
	refresh_selection_visual()


func set_selection_selected(active: bool) -> void:
	_selection_selected = active
	refresh_selection_visual()


func refresh_selection_visual() -> void:
	_ensure_selection_circle()
	if _selection_circle == null:
		return
	if _attack_flash_remaining > 0.0:
		_selection_circle.configure(selection_circle_radius(), SelectionCircle.COLOR_HUNTER)
		_selection_circle.set_hover(false)
		_selection_circle.set_selected(true)
		return
	var local_id := _local_unique_id()
	_selection_circle.configure(selection_circle_radius(), selection_affinity_color(local_id))
	_selection_circle.set_hover(_selection_hovered and not _selection_selected)
	_selection_circle.set_selected(_selection_selected)


func flash_attack_target_circle(duration := 0.35) -> void:
	## Brief red ring when this unit is the target of an attack command.
	_attack_flash_remaining = maxf(duration, 0.05)
	refresh_selection_visual()


func selection_affinity_color(local_peer_id: int) -> Color:
	if is_local_controllable(local_peer_id):
		return SelectionCircle.COLOR_OWN
	if role() == RoleConfig.Role.HUNTER:
		return SelectionCircle.COLOR_HUNTER
	return SelectionCircle.COLOR_RUNNER_TEAM


## Minimap colors are viewer-relative: own = green, enemies = red, allied runners = blue.
func minimap_marker_color(local_peer_id: int) -> Color:
	if peer_id == local_peer_id:
		return SelectionCircle.COLOR_OWN
	var local_role := RoleConfig.Role.RUNNER
	if GameManager.players.has(local_peer_id):
		local_role = int(GameManager.players[local_peer_id].get("role", RoleConfig.Role.RUNNER))
	if local_role == RoleConfig.Role.HUNTER:
		## Hunter sees every Runner as an enemy (red).
		return SelectionCircle.COLOR_HUNTER
	if role() == RoleConfig.Role.HUNTER:
		return SelectionCircle.COLOR_HUNTER
	return SelectionCircle.COLOR_RUNNER_TEAM


func role() -> int:
	return config.role if config != null else RoleConfig.Role.RUNNER


## Team id for vision purposes: the role itself (Runners share one team, the Hunter the other).
func team_role() -> int:
	return role()


## Radius in pixels this unit reveals for its team (RoleConfig.vision_range).
func get_vision_range() -> float:
	return maxf(config.vision_range, 0.0) if config != null else 0.0


## Host-only. 1 XP per point of applied damage for Hunters. Runners stay level 1.
func grant_xp(amount: float) -> void:
	if not multiplayer.is_server() or amount <= 0.0:
		return
	if role() != RoleConfig.Role.HUNTER:
		return
	var before_level := level
	var result := XpProgress.apply_gain(level, xp, amount)
	level = int(result.level)
	xp = float(result.xp)
	if level > before_level:
		for gained_level in range(before_level + 1, level + 1):
			pending_upgrade_levels.append(gained_level)
		_offer_next_hunter_upgrade()
		GameLog.info(
			"XP",
			"%s reached level %d (%.0f XP into next)" % [
				name_label.text if name_label else str(peer_id),
				level,
				xp,
			]
		)


func request_hunter_upgrade(choice_index: int) -> void:
	if role() != RoleConfig.Role.HUNTER or not is_inside_tree():
		return
	if _is_net_server():
		_server_choose_hunter_upgrade(choice_index)
	else:
		rpc_id(1, "_submit_hunter_upgrade_choice", choice_index)


## Hunter Seek: self-cast directional reveal on the minimap (SeekSkill).
func request_seek() -> void:
	if role() != RoleConfig.Role.HUNTER or not is_inside_tree():
		return
	if _is_net_server():
		_server_cast_seek()
	else:
		rpc_id(1, "_submit_seek")


func seek_cooldown_left() -> float:
	## Prefer local presentation timer for the casting peer's UI.
	if peer_id == _local_unique_id() and SeekPresentation.cooldown_left > 0.0:
		return SeekPresentation.cooldown_left
	return _seek_cooldown_left


func seek_active_left() -> float:
	if peer_id == _local_unique_id() and SeekPresentation.active_left > 0.0:
		return SeekPresentation.active_left
	return _seek_active_left


func seek_is_ready() -> bool:
	return seek_cooldown_left() <= 0.0 and SeekSkill.can_cast(self)


@rpc("any_peer", "reliable")
func _submit_hunter_upgrade_choice(choice_index: int) -> void:
	if not _is_net_server() or GameManager.sender_id(multiplayer) != peer_id:
		return
	_server_choose_hunter_upgrade(choice_index)


func _ensure_hunter_upgrade_arrays() -> void:
	var stat_count := StatBlock.Stat.size()
	if hunter_upgrade_flat_bonuses.size() != stat_count:
		hunter_upgrade_flat_bonuses.resize(stat_count)
	if hunter_upgrade_percent_bonuses.size() != stat_count:
		hunter_upgrade_percent_bonuses.resize(stat_count)


func _offer_next_hunter_upgrade() -> void:
	if role() != RoleConfig.Role.HUNTER or pending_upgrade_choice_level > 0 \
			or pending_upgrade_levels.is_empty():
		return
	pending_upgrade_choice_level = pending_upgrade_levels[0]
	pending_upgrade_levels.remove_at(0)
	pending_upgrade_choice_stats.clear()
	pending_upgrade_choice_rarities.clear()
	pending_upgrade_choice_values.clear()
	var choices := HunterUpgradeProgression.roll_choices(
		stats.final_value(StatBlock.Stat.LUCK)
	)
	for choice in choices:
		pending_upgrade_choice_stats.append(int(choice.stat))
		pending_upgrade_choice_rarities.append(int(choice.rarity))
		pending_upgrade_choice_values.append(float(choice.value))


func _server_choose_hunter_upgrade(choice_index: int) -> void:
	if not _is_net_server() or role() != RoleConfig.Role.HUNTER:
		return
	var choice_count := pending_upgrade_choice_stats.size()
	if pending_upgrade_choice_level <= 0 or choice_index < 0 or choice_index >= choice_count:
		return
	if pending_upgrade_choice_rarities.size() != choice_count \
			or pending_upgrade_choice_values.size() != choice_count:
		return
	var stat_id := pending_upgrade_choice_stats[choice_index]
	if stat_id < 0 or stat_id >= StatBlock.Stat.size():
		return
	var value := pending_upgrade_choice_values[choice_index]
	var is_percent := HunterUpgradeProgression.is_percent_stat(stat_id)
	if is_percent:
		hunter_upgrade_percent_bonuses[stat_id] += value
	else:
		hunter_upgrade_flat_bonuses[stat_id] += value
	var modifier := StatModifier.new()
	modifier.kind = StatModifier.Kind.PERCENT if is_percent else StatModifier.Kind.FLAT
	modifier.stat = stat_id
	modifier.value = value
	_hunter_upgrade_modifiers.append(modifier)
	stats.add_modifier(modifier)
	_applied_upgrade_flat = hunter_upgrade_flat_bonuses.duplicate()
	_applied_upgrade_percent = hunter_upgrade_percent_bonuses.duplicate()
	GameLog.info(
		"XP",
		"%s chose %s at level %d" % [
			name_label.text if name_label else str(peer_id),
			HunterUpgradeProgression.format_bonus(stat_id, value),
			pending_upgrade_choice_level,
		]
	)
	pending_upgrade_choice_level = 0
	pending_upgrade_choice_stats.clear()
	pending_upgrade_choice_rarities.clear()
	pending_upgrade_choice_values.clear()
	_offer_next_hunter_upgrade()


func _apply_synced_hunter_upgrade_bonuses() -> void:
	if hunter_upgrade_flat_bonuses == _applied_upgrade_flat \
			and hunter_upgrade_percent_bonuses == _applied_upgrade_percent:
		return
	for modifier in _hunter_upgrade_modifiers:
		stats.remove_modifier(modifier)
	_hunter_upgrade_modifiers.clear()
	for stat_id in StatBlock.Stat.size():
		var flat_value := hunter_upgrade_flat_bonuses[stat_id]
		if not is_zero_approx(flat_value):
			_add_synced_hunter_modifier(stat_id, StatModifier.Kind.FLAT, flat_value)
		var percent_value := hunter_upgrade_percent_bonuses[stat_id]
		if not is_zero_approx(percent_value):
			_add_synced_hunter_modifier(stat_id, StatModifier.Kind.PERCENT, percent_value)
	_applied_upgrade_flat = hunter_upgrade_flat_bonuses.duplicate()
	_applied_upgrade_percent = hunter_upgrade_percent_bonuses.duplicate()


func _add_synced_hunter_modifier(stat_id: int, kind: StatModifier.Kind, value: float) -> void:
	var modifier := StatModifier.new()
	modifier.kind = kind
	modifier.stat = stat_id
	modifier.value = value
	_hunter_upgrade_modifiers.append(modifier)
	stats.add_modifier(modifier)


## Portrait ring fill 0–1. Runners always show a full violet ring at level 1.
func xp_fill_ratio() -> float:
	if role() == RoleConfig.Role.RUNNER:
		return 1.0
	return XpProgress.fill_ratio(level, xp)


static func sprite_texture(sprite_index: int, role_id: int) -> Texture2D:
	var textures: Array = HUNTER_SPRITES if role_id == RoleConfig.Role.HUNTER else RUNNER_SPRITES
	return textures[clampi(sprite_index, 0, SPRITE_COUNT - 1)] as Texture2D


func can_attack() -> bool:
	return is_alive() and stats.final_value(StatBlock.Stat.MELEE_DAMAGE) > 0.0


func issue_move(destination: Vector2) -> void:
	## Player move: cancels attack / attack-move / chain and shows the blue ground marker.
	if not _can_issue_commands():
		return
	_clear_chain_visual()
	_request_move(destination)
	_show_move_click_marker(destination)


func issue_chain_append(destination: Vector2) -> void:
	## Shift+RMB waypoint (green). Any controllable unit can chain.
	if not _can_issue_commands():
		return
	var clamped := _clamp_map_position(destination)
	_ensure_chain_visual()
	if _chain_visual != null:
		_chain_visual.append_waypoint(clamped, MoveChainVisual.MOVE_COLOR)
	_request_chain_append(clamped)


func issue_attack_chain_append(destination: Vector2) -> void:
	## Shift+A+LMB waypoint (red). Continues an existing green/red chain.
	if not _can_issue_commands() or not can_attack():
		return
	var clamped := _clamp_map_position(destination)
	_ensure_chain_visual()
	if _chain_visual != null:
		_chain_visual.append_waypoint(clamped, MoveChainVisual.ATTACK_COLOR)
	_request_chain_append(clamped)


func issue_attack_move(destination: Vector2) -> void:
	if not _can_issue_commands() or not can_attack():
		return
	_clear_chain_visual()
	_request_attack_move(destination)
	_show_attack_click_marker_at(destination)


func _exit_tree() -> void:
	## Stop ticking before the MultiplayerAPI is torn down during scene resets.
	set_physics_process(false)
	set_process_unhandled_input(false)
	_clear_chain_visual()


func _multiplayer_ready() -> bool:
	return is_inside_tree() and multiplayer != null


func _is_net_server() -> bool:
	return _multiplayer_ready() and multiplayer.is_server()


func _local_unique_id() -> int:
	return GameManager.local_peer_id()


func _unhandled_input(event: InputEvent) -> void:
	if not _multiplayer_ready():
		return
	if peer_id != _local_unique_id() or not LaunchOptions.bot_role.is_empty():
		return
	if not is_alive() or not _movement_allowed():
		return
	if event is InputEventKey and _handle_seek_hotkey(event as InputEventKey):
		return
	if not _can_issue_commands():
		return
	if not event is InputEventMouseButton:
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_RIGHT:
		return
	if _build_mode_armed():
		## The building UI owns RMB (cancel placement) while a structure is armed.
		return
	if _item_shop_ui_open():
		## Shop panel owns RMB (close) while open.
		return
	var world_pos := get_global_mouse_position()
	var chain_modifier_held := SelectionManager.is_chain_modifier_held(click)
	if chain_modifier_held:
		issue_chain_append(world_pos)
		get_viewport().set_input_as_handled()
		return
	var shop := _item_shop_at(world_pos)
	if shop != null and _in_shop_range(shop):
		_open_item_shop()
		get_viewport().set_input_as_handled()
		return
	var target := _clickable_enemy_at(world_pos)
	var building_target: Building = null
	if can_attack() and target == null:
		building_target = _clickable_enemy_building_at(world_pos)
	## An enemy only outranks the structure for a unit that can actually attack it: a Runner
	## repairing a wall under attack clicks right next to the Hunter.
	var structure: Building = null
	if (target == null and building_target == null) or not can_attack():
		structure = _repairable_structure_at(world_pos)
	if target != null and can_attack():
		## Attack only — cancels any active move chain.
		_clear_chain_visual()
		_request_attack(target)
		_show_attack_click_marker_on(target)
	elif building_target != null and can_attack():
		## Hunter RMB on a structure: explicit target (same combat path as A-move acquire).
		_clear_chain_visual()
		_request_attack_building(building_target)
		_show_attack_click_marker_on(building_target)
	elif structure != null:
		## Runner RMB on an own damaged structure = repair (RepairSkill).
		_clear_chain_visual()
		_request_repair(structure)
		MoveClickMarker.spawn_on(structure, MoveClickMarker.REPAIR_COLOR)
	else:
		## Ground RMB cancels chain / attack and walks to the click.
		_clear_chain_visual()
		_request_move(world_pos)
		_show_move_click_marker(world_pos)
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if _eliminated or not _multiplayer_ready():
		return

	_tick_attack_flash(delta)
	if peer_id == _local_unique_id() and role() == RoleConfig.Role.HUNTER:
		SeekPresentation.tick(delta)

	if peer_id == _local_unique_id() and not LaunchOptions.bot_role.is_empty():
		_bot_tick()

	if _is_net_server():
		if not _movement_allowed() or not is_alive():
			_intent = Vector2.ZERO
			movement.clear_order()
			attack.clear_target()
			_move_chain.clear()
			_repair_target = null
			_seek_active_left = 0.0
		else:
			_server_combat_tick(delta)
			if not movement.has_order():
				movement.intent = _intent
			movement.apply(self)
			## After applying motion, queue the next shift-click leg if the current one finished.
			_resume_move_chain_if_needed()
			_clamp_to_map()
		sync_position = position
		sync_health = health.current
	else:
		_follow_sync_position(delta)
		_clamp_to_map()
		_apply_synced_hunter_upgrade_bonuses()
		_apply_synced_shop_inventory()
		_apply_synced_health()


func _tick_attack_flash(delta: float) -> void:
	if _attack_flash_remaining <= 0.0:
		return
	_attack_flash_remaining = maxf(_attack_flash_remaining - delta, 0.0)
	if _attack_flash_remaining <= 0.0:
		refresh_selection_visual()


func _bot_tick() -> void:
	if not is_alive() or not _movement_allowed():
		return
	if config.role == RoleConfig.Role.HUNTER:
		_hunter_bot_chase()
	else:
		var direction := _runner_bot_direction()
		if _is_net_server():
			_intent = direction
		else:
			_submit_input.rpc_id(1, direction)


func _hunter_bot_chase() -> void:
	var target := _nearest_hunter_target()
	if target == null:
		_bot_chase_peer_id = -1
		_bot_chase_building_path = NodePath()
		return
	_bot_repath_in = maxf(_bot_repath_in - get_physics_process_delta_time(), 0.0)
	var in_range := attack.in_attack_range(global_position, target)
	var retarget := false
	if target is Unit:
		var unit := target as Unit
		retarget = unit.peer_id != _bot_chase_peer_id
		_bot_chase_peer_id = unit.peer_id
		_bot_chase_building_path = NodePath()
	else:
		var path := target.get_path()
		retarget = path != _bot_chase_building_path
		_bot_chase_building_path = path
		_bot_chase_peer_id = -1
	if in_range:
		_bot_repath_in = 0.0
		if _is_net_server():
			movement.clear_order()
			_intent = Vector2.ZERO
			attack.set_explicit_target(target)
		elif retarget:
			_bot_submit_attack(target)
		return
	var needs_path := retarget or _bot_repath_in <= 0.0 \
		or (_is_net_server() and not movement.has_order())
	if not needs_path:
		return
	_bot_repath_in = 0.35
	var destination := _combat_approach_point(target)
	if _is_net_server():
		attack.set_explicit_target(target)
		movement.order_move(global_position, destination)
	else:
		_bot_submit_attack(target)
		_submit_move_order.rpc_id(1, destination, false)


func _bot_submit_attack(target: Node2D) -> void:
	if target is Unit:
		_submit_attack_target.rpc_id(1, (target as Unit).peer_id)
	elif target is Building:
		_submit_attack_building.rpc_id(1, target.get_path())


func _runner_bot_direction() -> Vector2:
	var seconds := Time.get_ticks_msec() / 1000.0
	return Vector2.from_angle(seconds * 1.3 + float(peer_id) * 0.7)


func _server_combat_tick(delta: float) -> void:
	attack.tick(delta)
	_regen(delta)
	if config.role != RoleConfig.Role.HUNTER:
		server_repair_tick(delta)
		return
	_server_tick_seek(delta)
	if GameManager.phase != GameManager.Phase.HUNTER_ACTIVE:
		return
	if stats.final_value(StatBlock.Stat.MELEE_DAMAGE) <= 0.0:
		return

	## Shift-click chains always outrank in-range / auto-acquire combat.
	if not _move_chain.is_empty():
		_resume_move_chain_if_needed()
		return

	## Sandbox: the Hunter you are not playing stands down instead of hunting your Runner.
	## It still finishes an explicit order you gave it before switching away.
	if _sandbox_standing_down() and attack.explicit_target == null and not attack.attack_move_active:
		return

	var target := attack.pick_target(global_position, _enemy_candidates())
	if target == null:
		_resume_attack_move_if_needed()
		return

	var player_engage := attack.explicit_target != null or attack.attack_move_active
	## Plain RMB move outranks opportunistic auto-attack for the whole path (controls §1.2).
	## Do not clear the order when already in range — that re-engaged melee and made cancel impossible.
	if not player_engage and movement.has_order():
		return

	if not attack.in_attack_range(global_position, target):
		_chase_combat_target(target)
		return

	movement.clear_order()
	_intent = Vector2.ZERO
	if not attack.can_swing():
		return
	_perform_melee(target)


func _sandbox_standing_down() -> bool:
	return GameManager.sandbox_mode and peer_id != GameManager.sandbox_active_peer


## Target may be an enemy Unit or (Hunter only) a Runner-owned Building (src/buildings/).
func _perform_melee(target: Node2D) -> void:
	if target == null or not target.has_method("is_attackable") or not bool(target.call("is_attackable")):
		attack.clear_target()
		return
	if target is Unit:
		_perform_melee_on_unit(target as Unit)
	elif target is Building:
		_perform_melee_on_building(target as Building)
	else:
		attack.mark_swung()


func _perform_melee_on_unit(target: Unit) -> void:
	var result := CombatDamage.resolve_melee(stats, target.stats)
	attack.mark_swung()
	if result.damage <= 0.0:
		return
	var max_health := target.stats.final_value(StatBlock.Stat.MAX_HEALTH)
	var applied: float = target.health.take_damage(result.damage, max_health)
	target.sync_health = target.health.current
	if role() == RoleConfig.Role.HUNTER:
		GameManager.award_damage_crystals(peer_id, applied)
		grant_xp(applied)
	GameLog.info(
		"COMBAT",
		"%s hit %s for %.1f%s" % [
			name_label.text if name_label else str(peer_id),
			str(target.peer_id),
			applied,
			" (crit)" if result.critical else "",
		]
	)
	if applied > 0.0:
		var kind := FloatingNumber.Kind.CRIT if result.critical else FloatingNumber.Kind.DAMAGE
		_spawn_floating_number_on(target, applied, kind)
	if result.lifesteal > 0.0:
		var own_max := stats.final_value(StatBlock.Stat.MAX_HEALTH)
		## heal() is void — measure applied amount so full-HP swings do not fake a green popup.
		var before := health.current
		health.heal(result.lifesteal, own_max)
		sync_health = health.current
		var healed := health.current - before
		if healed > 0.0:
			_spawn_floating_number_on(self, healed, FloatingNumber.Kind.LIFESTEAL)


func _perform_melee_on_building(target: Building) -> void:
	attack.mark_swung()
	var raw := stats.final_value(StatBlock.Stat.MELEE_DAMAGE)
	if raw <= 0.0:
		return
	var critical := false
	if randf() < stats.final_value(StatBlock.Stat.CRITICAL_CHANCE):
		raw *= stats.final_value(StatBlock.Stat.CRITICAL_DAMAGE_MULTIPLIER)
		critical = true
	var applied := target.apply_damage(raw)
	if role() == RoleConfig.Role.HUNTER:
		GameManager.award_damage_crystals(peer_id, applied)
		grant_xp(applied)
	GameLog.info(
		"COMBAT",
		"%s hit building %s for %.1f%s" % [
			name_label.text if name_label else str(peer_id),
			target.name,
			applied,
			" (crit)" if critical else "",
		]
	)
	if applied > 0.0:
		var kind := FloatingNumber.Kind.CRIT if critical else FloatingNumber.Kind.DAMAGE
		_spawn_floating_number_on(target, applied, kind)
	if applied > 0.0 and randf() < stats.final_value(StatBlock.Stat.LIFESTEAL_CHANCE):
		var lifesteal := stats.final_value(StatBlock.Stat.LIFESTEAL_AMOUNT)
		var own_max := stats.final_value(StatBlock.Stat.MAX_HEALTH)
		var before := health.current
		health.heal(lifesteal, own_max)
		sync_health = health.current
		var healed := health.current - before
		if healed > 0.0:
			_spawn_floating_number_on(self, healed, FloatingNumber.Kind.LIFESTEAL)


func _on_health_changed_for_regen(current: float, _maximum: float) -> void:
	## Any HP loss restarts the out-of-combat delay (heals do not).
	if current < _last_health_for_regen:
		_since_damage = 0.0
		_regen_fx_accum = 0.0
	_last_health_for_regen = current


func _regen(delta: float) -> void:
	var regen := stats.final_value(StatBlock.Stat.HEALTH_REGENERATION)
	if regen <= 0.0 or not health.is_alive():
		return
	var delay := config.regen_delay_after_damage if config != null else 0.0
	if delay > 0.0:
		if _since_damage < delay:
			_since_damage = minf(_since_damage + delta, delay)
			return
	var maximum := stats.final_value(StatBlock.Stat.MAX_HEALTH)
	var before := health.current
	health.heal(regen * delta, maximum)
	var healed := health.current - before
	if healed <= 0.0:
		return
	sync_health = health.current
	_regen_fx_accum += healed
	## Batch sub-1 HP ticks so the popup stays readable.
	if _regen_fx_accum >= 1.0:
		_spawn_floating_number_on(self, _regen_fx_accum, FloatingNumber.Kind.REGEN)
		_regen_fx_accum = 0.0


## Host-only, Runner only. Walks toward the repair target until in reach, then channels
## RepairSkill.DEF.value_per_second; ends on its own once the structure is full or invalid.
func server_repair_tick(delta: float) -> void:
	if _repair_target == null:
		return
	if not is_instance_valid(_repair_target) or not RepairSkill.can_repair(self, _repair_target):
		_repair_target = null
		return
	if not RepairSkill.in_range(self, _repair_target):
		## Re-aim on a fixed cadence, order or not: a straight-line order blocked by another
		## structure never finishes on its own.
		_repair_repath_in = maxf(_repair_repath_in - delta, 0.0)
		if _repair_repath_in <= 0.0:
			_repair_repath_in = 0.5
			movement.order_move(
				global_position, _clamp_map_position(RepairSkill.approach_point(self, _repair_target))
			)
		return
	movement.clear_order()
	_intent = Vector2.ZERO
	_repair_target.repair(RepairSkill.DEF.value_per_second * delta)


func is_repairing() -> bool:
	return _repair_target != null and is_instance_valid(_repair_target)


func _on_died() -> void:
	if _eliminated:
		return
	_eliminated = true
	_repair_target = null
	movement.clear_order()
	attack.clear_target()
	_intent = Vector2.ZERO
	velocity = Vector2.ZERO
	sync_health = 0.0
	_apply_eliminated_visual()
	if _is_net_server():
		GameManager.eliminate_player(peer_id)


func _apply_eliminated_visual() -> void:
	visible = false
	set_physics_process(false)
	_selection_hovered = false
	_selection_selected = false
	if _selection_circle != null:
		_selection_circle.set_hover(false)
		_selection_circle.set_selected(false)


func _can_issue_commands() -> bool:
	var manager := _selection_manager()
	if manager == null:
		# Headless / isolated unit tests have no selection manager.
		return true
	return manager.selected == self and manager.is_controllable_selected()


func _selection_manager() -> SelectionManager:
	return SelectionQueries.manager(get_tree())


func _build_mode_armed() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var ui := tree.get_first_node_in_group("building_ui")
	return ui != null and ui.has_method("is_armed") and bool(ui.call("is_armed"))


func _notify_selection_manager_ready() -> void:
	var manager := _selection_manager()
	if manager != null:
		manager.notify_clickable_ready(self)


func _ensure_selection_circle() -> void:
	if _selection_circle != null:
		return
	_selection_circle = SelectionCircle.new()
	_selection_circle.name = "SelectionCircle"
	add_child(_selection_circle)
	move_child(_selection_circle, 0)


func _body_radius() -> float:
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		return (collision_shape.shape as CircleShape2D).radius
	return 16.0



func _apply_synced_health() -> void:
	var maximum := stats.final_value(StatBlock.Stat.MAX_HEALTH)
	if is_equal_approx(health.current, sync_health):
		return
	health.set_from_sync(sync_health, maximum)
	if sync_health <= 0.0 and not _eliminated:
		_on_died()


func _movement_allowed() -> bool:
	return GameManager.phase == GameManager.Phase.RUNNER_PREPARATION \
		or GameManager.phase == GameManager.Phase.HUNTER_ACTIVE


func _follow_sync_position(delta: float) -> void:
	if position.distance_to(sync_position) > SNAP_DISTANCE:
		position = sync_position
	else:
		position = position.lerp(sync_position, 1.0 - exp(-INTERPOLATION_SPEED * delta))


func _clamp_to_map() -> void:
	global_position = _clamp_map_position(global_position)


func _clamp_map_position(world_position: Vector2) -> Vector2:
	return Vector2(
		clampf(world_position.x, MAP_BOUNDS.position.x + MAP_INSET, MAP_BOUNDS.end.x - MAP_INSET),
		clampf(world_position.y, MAP_BOUNDS.position.y + MAP_INSET, MAP_BOUNDS.end.y - MAP_INSET)
	)


func _request_move(destination: Vector2, clear_attack := true) -> void:
	if not _multiplayer_ready():
		return
	if _is_net_server():
		_move_chain.clear()
		_repair_target = null
		if clear_attack:
			attack.clear_target()
			attack.clear_attack_move()
		movement.order_move(global_position, _clamp_map_position(destination))
	else:
		_submit_move_order.rpc_id(1, destination, clear_attack)


func _request_chain_append(destination: Vector2) -> void:
	if not _multiplayer_ready():
		return
	var clamped := _clamp_map_position(destination)
	if _is_net_server():
		_server_chain_append(clamped)
	else:
		_submit_chain_append.rpc_id(1, clamped)


func _server_chain_append(destination: Vector2) -> void:
	_repair_target = null
	attack.clear_target()
	attack.clear_attack_move()
	var was_empty := _move_chain.is_empty()
	_move_chain.append(destination)
	## Start walking the first leg immediately; further clicks only queue.
	if was_empty or not movement.has_order():
		movement.order_move(global_position, _move_chain[0])


func _request_attack_move(destination: Vector2) -> void:
	if not _multiplayer_ready():
		return
	var clamped := _clamp_map_position(destination)
	if _is_net_server():
		_move_chain.clear()
		_repair_target = null
		attack.begin_attack_move(clamped)
		movement.order_move(global_position, clamped)
	else:
		_submit_attack_move.rpc_id(1, clamped)


func _show_move_click_marker(world_pos: Vector2) -> void:
	## Local feedback only — not replicated.
	var host := _marker_host()
	MoveClickMarker.spawn(host, world_pos, MoveClickMarker.MOVE_COLOR)


func _show_attack_click_marker_at(world_pos: Vector2) -> void:
	var host := _marker_host()
	MoveClickMarker.spawn(host, world_pos, MoveClickMarker.ATTACK_COLOR)


func _show_attack_click_marker_on(target: Node2D) -> void:
	if target == null:
		return
	MoveClickMarker.spawn_on(target, MoveClickMarker.ATTACK_COLOR)
	if target.has_method("flash_attack_target_circle"):
		target.call("flash_attack_target_circle")


func _marker_host() -> Node:
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	return host


func _chase_combat_target(target: Node2D) -> void:
	if target == null:
		return
	var destination := _combat_approach_point(target)
	if attack.attack_move_active and not attack.attack_move_chasing:
		## Interrupt the attack-move destination once so we engage instead of walking past.
		attack.attack_move_chasing = true
		movement.order_move(global_position, destination)
		return
	if not movement.has_order():
		movement.order_move(global_position, destination)


func _combat_approach_point(target: Node2D) -> Vector2:
	if target is Building:
		return _clamp_map_position(
			StructureMelee.approach_point(global_position, attack.attack_range, target as Building)
		)
	return target.global_position


func _spawn_floating_number_on(target: Node2D, value: float, kind: FloatingNumber.Kind) -> void:
	## Host applies damage; broadcast visuals so clients see the same popups.
	FloatingNumber.spawn_replicated(self, target, value, kind)


@rpc("authority", "unreliable")
func _rpc_floating_number(target_path: NodePath, value: float, kind: int) -> void:
	FloatingNumber.receive_rpc(self, target_path, value, kind)


func _resume_attack_move_if_needed() -> void:
	if not attack.attack_move_active:
		return
	attack.attack_move_chasing = false
	if movement.has_order():
		return
	var destination := attack.attack_move_destination
	if global_position.distance_to(destination) <= 12.0:
		attack.clear_attack_move()
		return
	movement.order_move(global_position, destination)


func _resume_move_chain_if_needed() -> void:
	if _move_chain.is_empty():
		return
	attack.attack_move_chasing = false
	if movement.has_order():
		return
	## Drop waypoints the unit has already reached, then walk the next leg.
	while not _move_chain.is_empty() and global_position.distance_to(_move_chain[0]) <= 12.0:
		_move_chain.pop_front()
	if _move_chain.is_empty():
		return
	movement.order_move(global_position, _move_chain[0])


func _ensure_chain_visual() -> void:
	if peer_id != _local_unique_id():
		return
	if _chain_visual != null and is_instance_valid(_chain_visual):
		return
	var host := _marker_host()
	if host == null:
		return
	_chain_visual = MoveChainVisual.new()
	_chain_visual.name = "MoveChainVisual_%d" % peer_id
	host.add_child(_chain_visual)
	_chain_visual.set_follow_unit(self)


func _clear_chain_visual() -> void:
	if _chain_visual != null and is_instance_valid(_chain_visual):
		_chain_visual.clear()
		_chain_visual.queue_free()
	_chain_visual = null


func _request_attack(target: Unit) -> void:
	if not _multiplayer_ready():
		return
	if _is_net_server():
		_move_chain.clear()
		_repair_target = null
		attack.set_explicit_target(target)
		if not attack.in_attack_range(global_position, target):
			movement.order_move(global_position, target.global_position)
	else:
		_submit_attack_target.rpc_id(1, target.peer_id)


func _request_attack_building(target: Building) -> void:
	if not _multiplayer_ready() or target == null:
		return
	if _is_net_server():
		_server_attack_building(target)
	else:
		_submit_attack_building.rpc_id(1, target.get_path())


func _server_attack_building(target: Building) -> void:
	if target == null or not is_instance_valid(target) or not target.is_attackable():
		return
	_move_chain.clear()
	_repair_target = null
	attack.set_explicit_target(target)
	if not attack.in_attack_range(global_position, target):
		movement.order_move(global_position, _combat_approach_point(target))


func request_shop_buy(item_id: String) -> void:
	if not is_inside_tree() or item_id.is_empty():
		return
	if _is_net_server():
		_server_shop_buy(item_id)
	else:
		rpc_id(1, "_submit_shop_buy", item_id)


func request_shop_sell(inventory_index: int) -> void:
	if not is_inside_tree() or inventory_index < 0:
		return
	if _is_net_server():
		_server_shop_sell(inventory_index)
	else:
		rpc_id(1, "_submit_shop_sell", inventory_index)


@rpc("any_peer", "reliable")
func _submit_shop_buy(item_id: String) -> void:
	if not _is_net_server() or GameManager.sender_id(multiplayer) != peer_id:
		return
	_server_shop_buy(item_id)


@rpc("any_peer", "reliable")
func _submit_shop_sell(inventory_index: int) -> void:
	if not _is_net_server() or GameManager.sender_id(multiplayer) != peer_id:
		return
	_server_shop_sell(inventory_index)


func _server_shop_buy(item_id: String) -> void:
	if not _is_net_server() or not is_alive():
		return
	if role() != RoleConfig.Role.HUNTER:
		return
	var entry := ShopCatalog.item_by_id(item_id)
	if entry.is_empty():
		return
	var cost := float(entry.get("cost", 0.0))
	if not GameManager.try_spend_crystals(peer_id, cost):
		return
	shop_inventory.append(item_id)
	var modifier := ShopCatalog.make_modifier(entry)
	_shop_modifiers.append(modifier)
	stats.add_modifier(modifier)
	_applied_shop_inventory = shop_inventory.duplicate()
	if int(entry.get("stat", -1)) == StatBlock.Stat.MAX_HEALTH:
		var maximum := stats.final_value(StatBlock.Stat.MAX_HEALTH)
		health.heal(float(entry.get("value", 0.0)), maximum)
		sync_health = health.current
	GameLog.info(
		"SHOP",
		"%s bought %s for %d" % [
			name_label.text if name_label else str(peer_id),
			ShopCatalog.format_bonus(entry),
			int(cost),
		]
	)


func _server_shop_sell(inventory_index: int) -> void:
	if not _is_net_server() or not is_alive():
		return
	if inventory_index < 0 or inventory_index >= shop_inventory.size():
		return
	var item_id := str(shop_inventory[inventory_index])
	var entry := ShopCatalog.item_by_id(item_id)
	if entry.is_empty():
		shop_inventory.remove_at(inventory_index)
		_rebuild_shop_modifiers_from_inventory()
		return
	shop_inventory.remove_at(inventory_index)
	_rebuild_shop_modifiers_from_inventory()
	GameManager.grant_crystals(peer_id, float(entry.get("cost", 0.0)))
	GameLog.info(
		"SHOP",
		"%s sold %s for %d" % [
			name_label.text if name_label else str(peer_id),
			ShopCatalog.format_bonus(entry),
			int(float(entry.get("cost", 0.0))),
		]
	)


func _rebuild_shop_modifiers_from_inventory() -> void:
	for modifier in _shop_modifiers:
		stats.remove_modifier(modifier)
	_shop_modifiers.clear()
	for item_id in shop_inventory:
		var entry := ShopCatalog.item_by_id(str(item_id))
		if entry.is_empty():
			continue
		var modifier := ShopCatalog.make_modifier(entry)
		_shop_modifiers.append(modifier)
		stats.add_modifier(modifier)
	_applied_shop_inventory = shop_inventory.duplicate()


func _apply_synced_shop_inventory() -> void:
	if shop_inventory == _applied_shop_inventory:
		return
	_rebuild_shop_modifiers_from_inventory()


func _item_shop_at(world_pos: Vector2) -> ItemShop:
	var best: ItemShop = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("item_shop"):
		if not node is ItemShop:
			continue
		var shop := node as ItemShop
		var distance := world_pos.distance_to(shop.global_position)
		if distance <= shop.selection_hit_radius() and distance < best_distance:
			best_distance = distance
			best = shop
	return best


func _in_shop_range(shop: ItemShop) -> bool:
	if shop == null:
		return false
	return global_position.distance_to(shop.global_position) <= ItemShop.interaction_reach()


func _open_item_shop() -> void:
	var ui := get_tree().get_first_node_in_group("item_shop_ui")
	if ui != null and ui.has_method("open_shop"):
		ui.call("open_shop")


func _item_shop_ui_open() -> bool:
	var ui := get_tree().get_first_node_in_group("item_shop_ui")
	return ui != null and ui.has_method("is_open") and bool(ui.call("is_open"))


func _handle_seek_hotkey(key: InputEventKey) -> bool:
	if key.echo or not key.pressed:
		return false
	if key.keycode != KEY_Q and key.physical_keycode != KEY_Q:
		return false
	if role() != RoleConfig.Role.HUNTER:
		return false
	if not _can_issue_commands():
		return false
	if not seek_is_ready():
		get_viewport().set_input_as_handled()
		return true
	request_seek()
	get_viewport().set_input_as_handled()
	return true


func _server_cast_seek() -> void:
	if not _is_net_server():
		return
	if not SeekSkill.can_cast(self):
		return
	if _seek_cooldown_left > 0.0:
		return
	_seek_active_left = SeekSkill.DEF.duration
	_seek_cooldown_left = SeekSkill.DEF.cooldown
	_seek_sync_accum = 0.0
	_deliver_seek_started(SeekSkill.DEF.duration, SeekSkill.DEF.cooldown)
	_push_seek_targets()
	GameLog.info(
		"SKILL",
		"%s cast Seek (%.0fs)" % [
			name_label.text if name_label else str(peer_id),
			SeekSkill.DEF.duration,
		]
	)


func _server_tick_seek(delta: float) -> void:
	if _seek_cooldown_left > 0.0:
		_seek_cooldown_left = maxf(_seek_cooldown_left - delta, 0.0)
	if _seek_active_left <= 0.0:
		return
	_seek_active_left = maxf(_seek_active_left - delta, 0.0)
	_seek_sync_accum += delta
	if _seek_sync_accum >= 0.1 or _seek_active_left <= 0.0:
		_seek_sync_accum = 0.0
		if _seek_active_left > 0.0:
			_push_seek_targets()
		else:
			_deliver_seek_ended()


func _push_seek_targets() -> void:
	var positions := SeekSkill.gather_target_positions(self)
	_deliver_seek_targets(global_position, positions)


func _deliver_seek_started(duration: float, cooldown: float) -> void:
	if peer_id == GameManager.local_peer_id():
		SeekPresentation.begin(duration, cooldown)
		return
	if not _has_connected_seek_owner():
		return
	_rpc_seek_started.rpc_id(peer_id, duration, cooldown)


func _deliver_seek_targets(from: Vector2, positions: Array[Vector2]) -> void:
	if peer_id == GameManager.local_peer_id():
		SeekPresentation.update_targets(from, positions)
		return
	if not _has_connected_seek_owner():
		return
	var packed := PackedVector2Array()
	for point in positions:
		packed.append(point)
	_rpc_seek_targets.rpc_id(peer_id, from, packed)


func _deliver_seek_ended() -> void:
	if peer_id == GameManager.local_peer_id():
		SeekPresentation.end_active()
		return
	if not _has_connected_seek_owner():
		return
	_rpc_seek_ended.rpc_id(peer_id)


func _has_connected_seek_owner() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.get_peers().has(peer_id)


@rpc("authority", "reliable")
func _rpc_seek_started(duration: float, cooldown: float) -> void:
	SeekPresentation.begin(duration, cooldown)


@rpc("authority", "unreliable")
func _rpc_seek_targets(from: Vector2, positions: PackedVector2Array) -> void:
	var list: Array[Vector2] = []
	for point in positions:
		list.append(point)
	SeekPresentation.update_targets(from, list)


@rpc("authority", "reliable")
func _rpc_seek_ended() -> void:
	SeekPresentation.end_active()


@rpc("any_peer", "reliable")
func _submit_seek() -> void:
	if not _is_net_server() or GameManager.sender_id(multiplayer) != peer_id:
		return
	_server_cast_seek()


func _request_repair(structure: Building) -> void:
	if not _multiplayer_ready() or structure == null:
		return
	if _is_net_server():
		_server_begin_repair(structure)
	else:
		_submit_repair_target.rpc_id(1, structure.get_path())


## Host-only. Re-validates through RepairSkill: the client's check is a hint, not trust.
## A rejected repair (healed / destroyed meanwhile) still honours the click as a move, so the
## green marker the client already showed never leaves the previous order running.
func _server_begin_repair(structure: Building) -> void:
	_move_chain.clear()
	attack.clear_target()
	attack.clear_attack_move()
	_repair_target = null
	if structure == null or not is_instance_valid(structure):
		## Destroyed between click and RPC: stop rather than keep the previous order.
		movement.clear_order()
		_intent = Vector2.ZERO
		return
	if not RepairSkill.can_repair(self, structure):
		movement.order_move(global_position, _clamp_map_position(structure.global_position))
		return
	_repair_target = structure
	_repair_repath_in = 0.0
	if RepairSkill.in_range(self, structure):
		movement.clear_order()
		return
	_repair_repath_in = 0.5
	movement.order_move(global_position, _clamp_map_position(RepairSkill.approach_point(self, structure)))


## Runner RMB target: the nearest own structure under the cursor that RepairSkill accepts.
## Anything else (full HP, still being built, someone else's) falls through to a move.
func _repairable_structure_at(world_pos: Vector2) -> Building:
	if role() != RoleConfig.Role.RUNNER:
		return null
	var best: Building = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("buildings"):
		var structure := node as Building
		if structure == null or not RepairSkill.can_repair(self, structure):
			continue
		var hit_radius := maxf(structure.selection_hit_radius(), 24.0)
		var distance := world_pos.distance_to(structure.global_position)
		if distance <= hit_radius and distance < best_distance:
			best_distance = distance
			best = structure
	return best


func _clickable_enemy_at(world_pos: Vector2) -> Unit:
	var best: Unit = null
	var best_distance := INF
	for node in _enemy_candidates():
		var unit := node as Unit
		if unit == null or not unit.is_attackable():
			continue
		## Fog of war: a click cannot target an enemy the team does not see.
		if not VisionPresentation.can_local_see(unit):
			continue
		## Match selection feel, with a floor so large sprites stay easy to click.
		var hit_radius := maxf(unit.selection_hit_radius(), unit.selection_circle_radius() * 1.35)
		hit_radius = maxf(hit_radius, 56.0)
		var distance := world_pos.distance_to(unit.global_position)
		if distance <= hit_radius and distance < best_distance:
			best_distance = distance
			best = unit
	return best


func _clickable_enemy_building_at(world_pos: Vector2) -> Building:
	var best: Building = null
	var best_distance := INF
	for node in _enemy_candidates():
		if not node is Building:
			continue
		var building := node as Building
		if not building.is_attackable():
			continue
		## Fog of war: only structures the team currently sees can be clicked (ghosts cannot).
		if not VisionPresentation.can_local_see(building):
			continue
		## Same floor as unit clicks so 1×1 walls stay easy to RMB.
		var hit_radius := maxf(building.selection_hit_radius(), building.selection_circle_radius() * 1.15)
		hit_radius = maxf(hit_radius, 56.0)
		var distance := world_pos.distance_to(building.global_position)
		if distance <= hit_radius and distance < best_distance:
			best_distance = distance
			best = building
	return best


func _enemy_candidates() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("units"):
		if not node is Unit:
			continue
		var other := node as Unit
		if other.peer_id == peer_id or not other.is_attackable():
			continue
		if config.role == RoleConfig.Role.HUNTER and other.role() != RoleConfig.Role.RUNNER:
			continue
		if config.role == RoleConfig.Role.RUNNER and other.role() != RoleConfig.Role.HUNTER:
			continue
		result.append(other)
	if config.role == RoleConfig.Role.HUNTER:
		## Runner structures (src/buildings/) are also valid Hunter targets.
		for node in get_tree().get_nodes_in_group("buildings"):
			if node is Node2D and node.has_method("is_attackable") and bool(node.call("is_attackable")):
				result.append(node as Node2D)
	return result


func _nearest_living_runner() -> Unit:
	var best: Unit = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("units"):
		if not node is Unit:
			continue
		var other := node as Unit
		if other.role() != RoleConfig.Role.RUNNER or not other.is_attackable():
			continue
		var distance := global_position.distance_to(other.global_position)
		if distance < best_distance:
			best_distance = distance
			best = other
	return best


## Nearest attackable Runner unit or structure for the Hunter bot.
func _nearest_hunter_target() -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for node in _enemy_candidates():
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_method("is_attackable") or not bool(node.call("is_attackable")):
			continue
		var distance := global_position.distance_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best


func _on_players_changed() -> void:
	_refresh_label()
	if GameManager.is_eliminated(peer_id) and not _eliminated:
		_on_died()


func _refresh_label() -> void:
	var entry: Dictionary = GameManager.players.get(peer_id, {})
	var suffix := " [down]" if GameManager.is_eliminated(peer_id) else ""
	name_label.text = "%s (%s)%s" % [
		str(entry.get("name", "Peer %d" % peer_id)),
		config.display_name,
		suffix,
	]
	name_label.tooltip_text = name_label.text


@rpc("any_peer", "reliable")
func _submit_move_order(destination: Vector2, clear_attack := true) -> void:
	if not _is_net_server():
		return
	if GameManager.sender_id(multiplayer) != peer_id:
		return
	if not is_alive() or not _movement_allowed():
		return
	_move_chain.clear()
	_repair_target = null
	if clear_attack:
		attack.clear_target()
		attack.clear_attack_move()
	movement.order_move(global_position, _clamp_map_position(destination))


@rpc("any_peer", "reliable")
func _submit_chain_append(destination: Vector2) -> void:
	if not _is_net_server():
		return
	if GameManager.sender_id(multiplayer) != peer_id:
		return
	if not is_alive() or not _movement_allowed():
		return
	_server_chain_append(_clamp_map_position(destination))


@rpc("any_peer", "reliable")
func _submit_attack_target(target_peer_id: int) -> void:
	if not _is_net_server():
		return
	if GameManager.sender_id(multiplayer) != peer_id:
		return
	if not is_alive() or not _movement_allowed():
		return
	if stats.final_value(StatBlock.Stat.MELEE_DAMAGE) <= 0.0:
		return
	var target_node := get_parent().get_node_or_null(str(target_peer_id))
	if target_node == null or not target_node is Unit:
		return
	var target := target_node as Unit
	if not target.is_attackable():
		return
	_move_chain.clear()
	_repair_target = null
	attack.set_explicit_target(target)
	if not attack.in_attack_range(global_position, target):
		movement.order_move(global_position, target.global_position)


@rpc("any_peer", "reliable")
func _submit_attack_building(building_path: NodePath) -> void:
	if not _is_net_server():
		return
	if GameManager.sender_id(multiplayer) != peer_id:
		return
	if not is_alive() or not _movement_allowed():
		return
	if stats.final_value(StatBlock.Stat.MELEE_DAMAGE) <= 0.0:
		return
	var target := get_node_or_null(building_path) as Building
	_server_attack_building(target)


@rpc("any_peer", "reliable")
func _submit_attack_move(destination: Vector2) -> void:
	if not _is_net_server():
		return
	if GameManager.sender_id(multiplayer) != peer_id:
		return
	if not is_alive() or not _movement_allowed():
		return
	if stats.final_value(StatBlock.Stat.MELEE_DAMAGE) <= 0.0:
		return
	_move_chain.clear()
	_repair_target = null
	var clamped := _clamp_map_position(destination)
	attack.begin_attack_move(clamped)
	movement.order_move(global_position, clamped)


@rpc("any_peer", "reliable")
func _submit_repair_target(structure_path: NodePath) -> void:
	if not _is_net_server():
		return
	if GameManager.sender_id(multiplayer) != peer_id:
		return
	if not is_alive() or not _movement_allowed():
		return
	_server_begin_repair(get_node_or_null(structure_path) as Building)


@rpc("any_peer", "unreliable_ordered")
func _submit_input(direction: Vector2) -> void:
	if not _is_net_server():
		return
	if GameManager.sender_id(multiplayer) != peer_id:
		return
	if not is_alive():
		return
	_intent = direction.limit_length(1.0)
