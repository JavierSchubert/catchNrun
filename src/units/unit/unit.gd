class_name Unit
extends CharacterBody2D
## Placeholder unit shared by the Hunter and Runner scenes.
##
## A local player right-clicks the ground to move, or an enemy to attack.
## The host builds paths, resolves melee swings, and replicates position + health.
## Hunter bots chase the nearest living Runner and attack when in range.

const INTERPOLATION_SPEED := 12.0
const SNAP_DISTANCE := 200.0
## Matches PlateauMap.world_bounds() (60x40 tiles at 128px).
const MAP_BOUNDS := Rect2(-3840.0, -2560.0, 7680.0, 5120.0)
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
var stats := StatSheet.new()

var _intent := Vector2.ZERO
var _eliminated := false
var _bot_chase_peer_id := -1
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
	_clamp_to_map()
	sync_position = position
	stats.stats_changed.connect(_apply_derived_stats)
	stats.set_base(_base_stats())
	attack.attack_range = config.attack_range
	attack.acquisition_range = config.acquisition_range
	_apply_derived_stats()
	health.died.connect(_on_died)
	health.health_changed.connect(health_bar.update_for_health)
	health.setup(stats.final_value(StatBlock.Stat.MAX_HEALTH))
	sync_health = health.current
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
	var local_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
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
	## Shift+RMB waypoint. Any controllable unit can chain; hunters still auto-attack in range.
	if not _can_issue_commands():
		return
	var clamped := _clamp_map_position(destination)
	_ensure_chain_visual()
	if _chain_visual != null:
		_chain_visual.append_waypoint(clamped)
	_request_chain_append(clamped)


func issue_attack_move(destination: Vector2) -> void:
	if not _can_issue_commands() or not can_attack():
		return
	_clear_chain_visual()
	_request_attack_move(destination)
	_show_attack_click_marker_at(destination)


func _unhandled_input(event: InputEvent) -> void:
	if peer_id != multiplayer.get_unique_id() or not LaunchOptions.bot_role.is_empty():
		return
	if not is_alive() or not _movement_allowed():
		return
	if not _can_issue_commands():
		return
	if not event is InputEventMouseButton:
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_RIGHT:
		return
	var world_pos := get_global_mouse_position()
	var shift_held := click.shift_pressed or Input.is_key_pressed(KEY_SHIFT)
	if shift_held:
		issue_chain_append(world_pos)
		get_viewport().set_input_as_handled()
		return
	var target := _clickable_enemy_at(world_pos)
	if target != null and can_attack():
		## Attack only — cancels any active move chain.
		_clear_chain_visual()
		_request_attack(target)
		_show_attack_click_marker_on(target)
	else:
		## Ground RMB cancels chain / attack and walks to the click.
		_clear_chain_visual()
		_request_move(world_pos)
		_show_move_click_marker(world_pos)
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if _eliminated:
		return

	_tick_attack_flash(delta)

	if peer_id == multiplayer.get_unique_id() and not LaunchOptions.bot_role.is_empty():
		_bot_tick()

	if multiplayer.is_server():
		if not _movement_allowed() or not is_alive():
			_intent = Vector2.ZERO
			movement.clear_order()
			attack.clear_target()
			_move_chain.clear()
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
		if multiplayer.is_server():
			_intent = direction
		else:
			_submit_input.rpc_id(1, direction)


func _hunter_bot_chase() -> void:
	var target := _nearest_living_runner()
	if target == null:
		_bot_chase_peer_id = -1
		return
	_bot_repath_in = maxf(_bot_repath_in - get_physics_process_delta_time(), 0.0)
	var in_range := global_position.distance_to(target.global_position) <= attack.attack_range * 0.9
	var retarget := target.peer_id != _bot_chase_peer_id
	_bot_chase_peer_id = target.peer_id
	if in_range:
		_bot_repath_in = 0.0
		if multiplayer.is_server():
			movement.clear_order()
			_intent = Vector2.ZERO
			attack.set_explicit_target(target)
		elif retarget:
			_submit_attack_target.rpc_id(1, target.peer_id)
		return
	var needs_path := retarget or _bot_repath_in <= 0.0 \
		or (multiplayer.is_server() and not movement.has_order())
	if not needs_path:
		return
	_bot_repath_in = 0.35
	if multiplayer.is_server():
		attack.set_explicit_target(target)
		movement.order_move(global_position, target.global_position)
	else:
		_submit_attack_target.rpc_id(1, target.peer_id)
		_submit_move_order.rpc_id(1, target.global_position, false)


func _runner_bot_direction() -> Vector2:
	var seconds := Time.get_ticks_msec() / 1000.0
	return Vector2.from_angle(seconds * 1.3 + float(peer_id) * 0.7)


func _server_combat_tick(delta: float) -> void:
	attack.tick(delta)
	_regen(delta)
	if config.role != RoleConfig.Role.HUNTER:
		return
	if GameManager.phase != GameManager.Phase.HUNTER_ACTIVE:
		return
	if stats.final_value(StatBlock.Stat.MELEE_DAMAGE) <= 0.0:
		return

	var target := attack.pick_target(global_position, _enemy_candidates())
	if target == null:
		_resume_attack_move_if_needed()
		_resume_move_chain_if_needed()
		return

	var player_engage := attack.explicit_target != null \
		or attack.attack_move_active \
		or not _move_chain.is_empty()
	## A plain player move outranks opportunistic auto-attack; chains act like attack-move.
	if not player_engage and movement.has_order():
		return

	if not attack.in_attack_range(global_position, target):
		_chase_combat_target(target)
		return

	movement.clear_order()
	_intent = Vector2.ZERO
	if not attack.can_swing():
		return
	_perform_melee(target as Unit)


func _perform_melee(target: Unit) -> void:
	if target == null or not target.is_attackable():
		attack.clear_target()
		return
	var result := CombatDamage.resolve_melee(stats, target.stats)
	attack.mark_swung()
	if result.damage <= 0.0:
		return
	var max_health := target.stats.final_value(StatBlock.Stat.MAX_HEALTH)
	var applied: float = target.health.take_damage(result.damage, max_health)
	target.sync_health = target.health.current
	GameLog.info(
		"COMBAT",
		"%s hit %s for %.1f%s" % [
			name_label.text if name_label else str(peer_id),
			str(target.peer_id),
			applied,
			" (crit)" if result.critical else "",
		]
	)
	if result.lifesteal > 0.0:
		var own_max := stats.final_value(StatBlock.Stat.MAX_HEALTH)
		health.heal(result.lifesteal, own_max)
		sync_health = health.current


func _regen(delta: float) -> void:
	var regen := stats.final_value(StatBlock.Stat.HEALTH_REGENERATION)
	if regen <= 0.0 or not health.is_alive():
		return
	var maximum := stats.final_value(StatBlock.Stat.MAX_HEALTH)
	health.heal(regen * delta, maximum)


func _on_died() -> void:
	if _eliminated:
		return
	_eliminated = true
	movement.clear_order()
	attack.clear_target()
	_intent = Vector2.ZERO
	velocity = Vector2.ZERO
	sync_health = 0.0
	_apply_eliminated_visual()
	if multiplayer.is_server():
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
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("selection_manager") as SelectionManager


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
	if multiplayer.is_server():
		_move_chain.clear()
		if clear_attack:
			attack.clear_target()
			attack.clear_attack_move()
		movement.order_move(global_position, _clamp_map_position(destination))
	else:
		_submit_move_order.rpc_id(1, destination, clear_attack)


func _request_chain_append(destination: Vector2) -> void:
	var clamped := _clamp_map_position(destination)
	if multiplayer.is_server():
		_server_chain_append(clamped)
	else:
		_submit_chain_append.rpc_id(1, clamped)


func _server_chain_append(destination: Vector2) -> void:
	attack.clear_target()
	attack.clear_attack_move()
	var was_empty := _move_chain.is_empty()
	_move_chain.append(destination)
	## Start walking the first leg immediately; further clicks only queue.
	if was_empty or not movement.has_order():
		movement.order_move(global_position, _move_chain[0])


func _request_attack_move(destination: Vector2) -> void:
	var clamped := _clamp_map_position(destination)
	if multiplayer.is_server():
		_move_chain.clear()
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


func _show_attack_click_marker_on(target: Unit) -> void:
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
	var chaining := attack.attack_move_active or not _move_chain.is_empty()
	if chaining and not attack.attack_move_chasing:
		## Interrupt the destination / chain path once so we engage instead of walking past.
		attack.attack_move_chasing = true
		movement.order_move(global_position, target.global_position)
		return
	if not movement.has_order():
		movement.order_move(global_position, target.global_position)


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
	if peer_id != multiplayer.get_unique_id():
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
	if multiplayer.is_server():
		_move_chain.clear()
		attack.set_explicit_target(target)
		if not attack.in_attack_range(global_position, target):
			movement.order_move(global_position, target.global_position)
	else:
		_submit_attack_target.rpc_id(1, target.peer_id)


func _clickable_enemy_at(world_pos: Vector2) -> Unit:
	var best: Unit = null
	var best_distance := INF
	for node in _enemy_candidates():
		var unit := node as Unit
		if unit == null or not unit.is_attackable():
			continue
		## Match selection feel, with a floor so large sprites stay easy to click.
		var hit_radius := maxf(unit.selection_hit_radius(), unit.selection_circle_radius() * 1.35)
		hit_radius = maxf(hit_radius, 56.0)
		var distance := world_pos.distance_to(unit.global_position)
		if distance <= hit_radius and distance < best_distance:
			best_distance = distance
			best = unit
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


@rpc("any_peer", "reliable")
func _submit_move_order(destination: Vector2, clear_attack := true) -> void:
	if not multiplayer.is_server():
		return
	if GameManager.sender_id(multiplayer) != peer_id:
		return
	if not is_alive() or not _movement_allowed():
		return
	_move_chain.clear()
	if clear_attack:
		attack.clear_target()
		attack.clear_attack_move()
	movement.order_move(global_position, _clamp_map_position(destination))


@rpc("any_peer", "reliable")
func _submit_chain_append(destination: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if GameManager.sender_id(multiplayer) != peer_id:
		return
	if not is_alive() or not _movement_allowed():
		return
	_server_chain_append(_clamp_map_position(destination))


@rpc("any_peer", "reliable")
func _submit_attack_target(target_peer_id: int) -> void:
	if not multiplayer.is_server():
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
	attack.set_explicit_target(target)
	if not attack.in_attack_range(global_position, target):
		movement.order_move(global_position, target.global_position)


@rpc("any_peer", "reliable")
func _submit_attack_move(destination: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if GameManager.sender_id(multiplayer) != peer_id:
		return
	if not is_alive() or not _movement_allowed():
		return
	if stats.final_value(StatBlock.Stat.MELEE_DAMAGE) <= 0.0:
		return
	_move_chain.clear()
	var clamped := _clamp_map_position(destination)
	attack.begin_attack_move(clamped)
	movement.order_move(global_position, clamped)


@rpc("any_peer", "unreliable_ordered")
func _submit_input(direction: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if GameManager.sender_id(multiplayer) != peer_id:
		return
	if not is_alive():
		return
	_intent = direction.limit_length(1.0)
