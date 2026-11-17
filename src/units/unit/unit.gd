class_name Unit
extends CharacterBody2D
## Placeholder unit shared by the Hunter and Runner scenes.
##
## A local player right-clicks the ground to issue a move order. The host builds
## the path and follows it. Bots still send a circling direction. The host
## replicates `sync_position`. Other peers only slide toward that position.

const INTERPOLATION_SPEED := 12.0
const SNAP_DISTANCE := 200.0

@export var config: RoleConfig

var peer_id := 0
var sync_position := Vector2.ZERO
var stats := StatSheet.new()

var _intent := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite
@onready var name_label: Label = $NameLabel
@onready var camera: Camera2D = $Camera2D
@onready var movement: UnitMovement = $Movement


func _enter_tree() -> void:
	peer_id = name.to_int()
	# The host owns the replicated position. The owner still only sends intent.
	set_multiplayer_authority(1)


func _ready() -> void:
	add_to_group("units")
	if config == null:
		push_error("Unit %s is missing a role config." % name)
		return
	stats.stats_changed.connect(_apply_movement_speed)
	stats.set_base(_base_stats())
	sprite.modulate = config.color
	var entry: Dictionary = GameManager.players.get(peer_id, {})
	name_label.text = "%s (%s)" % [str(entry.get("name", "Peer %d" % peer_id)), config.display_name]
	camera.enabled = peer_id == multiplayer.get_unique_id() and LaunchOptions.bot_role.is_empty()


func _base_stats() -> StatBlock:
	if config.base_stats != null:
		return config.base_stats
	var block := StatBlock.new()
	block.movement_speed = config.move_speed
	return block


func _apply_movement_speed() -> void:
	movement.speed = stats.final_value(StatBlock.Stat.MOVEMENT_SPEED)


func _unhandled_input(event: InputEvent) -> void:
	if peer_id != multiplayer.get_unique_id() or not LaunchOptions.bot_role.is_empty():
		return
	if not event is InputEventMouseButton:
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_RIGHT:
		return
	if not _movement_allowed():
		return
	var destination := get_global_mouse_position()
	if multiplayer.is_server():
		movement.order_move(global_position, destination)
	else:
		_submit_move_order.rpc_id(1, destination)
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if peer_id == multiplayer.get_unique_id() and not LaunchOptions.bot_role.is_empty():
		var direction := _bot_direction()
		if multiplayer.is_server():
			_intent = direction
		else:
			_submit_input.rpc_id(1, direction)
	if multiplayer.is_server():
		if not _movement_allowed():
			_intent = Vector2.ZERO
			movement.clear_order()
		if not movement.has_order():
			movement.intent = _intent
		movement.apply(self)
		sync_position = position
	else:
		_follow_sync_position(delta)


func _bot_direction() -> Vector2:
	if not _movement_allowed():
		return Vector2.ZERO
	var seconds := Time.get_ticks_msec() / 1000.0
	return Vector2.from_angle(seconds * 1.3 + float(peer_id) * 0.7)


func _movement_allowed() -> bool:
	return GameManager.phase == GameManager.Phase.RUNNER_PREPARATION \
		or GameManager.phase == GameManager.Phase.HUNTER_ACTIVE


func _follow_sync_position(delta: float) -> void:
	if position.distance_to(sync_position) > SNAP_DISTANCE:
		position = sync_position
	else:
		position = position.lerp(sync_position, 1.0 - exp(-INTERPOLATION_SPEED * delta))


@rpc("any_peer", "reliable")
func _submit_move_order(destination: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if GameManager.sender_id(multiplayer) != peer_id:
		return
	if not _movement_allowed():
		return
	movement.order_move(global_position, destination)


@rpc("any_peer", "unreliable_ordered")
func _submit_input(direction: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if GameManager.sender_id(multiplayer) != peer_id:
		return
	_intent = direction.limit_length(1.0)
