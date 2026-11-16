class_name Unit
extends CharacterBody2D
## Placeholder unit shared by the Hunter and Runner scenes.
##
## The owning peer sends a movement direction. The host applies it and replicates
## `sync_position`. Other peers only slide toward that position.

const INTERPOLATION_SPEED := 12.0
const SNAP_DISTANCE := 200.0

@export var config: RoleConfig

var peer_id := 0
var sync_position := Vector2.ZERO

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
	movement.speed = config.move_speed
	sprite.modulate = config.color
	var entry: Dictionary = GameManager.players.get(peer_id, {})
	name_label.text = "%s (%s)" % [str(entry.get("name", "Peer %d" % peer_id)), config.display_name]
	camera.enabled = peer_id == multiplayer.get_unique_id() and LaunchOptions.bot_role.is_empty()


func _physics_process(delta: float) -> void:
	if peer_id == multiplayer.get_unique_id():
		var direction := _local_direction()
		if multiplayer.is_server():
			_intent = direction
		else:
			_submit_input.rpc_id(1, direction)
	if multiplayer.is_server():
		if not _movement_allowed():
			_intent = Vector2.ZERO
		movement.intent = _intent
		movement.apply(self)
		sync_position = position
	else:
		_follow_sync_position(delta)


func _local_direction() -> Vector2:
	if not _movement_allowed():
		return Vector2.ZERO
	if not LaunchOptions.bot_role.is_empty():
		var seconds := Time.get_ticks_msec() / 1000.0
		return Vector2.from_angle(seconds * 1.3 + float(peer_id) * 0.7)
	return Input.get_vector("left", "right", "up", "down")


func _movement_allowed() -> bool:
	return GameManager.phase == GameManager.Phase.RUNNER_PREPARATION \
		or GameManager.phase == GameManager.Phase.HUNTER_ACTIVE


func _follow_sync_position(delta: float) -> void:
	if position.distance_to(sync_position) > SNAP_DISTANCE:
		position = sync_position
	else:
		position = position.lerp(sync_position, 1.0 - exp(-INTERPOLATION_SPEED * delta))


@rpc("any_peer", "unreliable_ordered")
func _submit_input(direction: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if GameManager.sender_id(multiplayer) != peer_id:
		return
	_intent = direction.limit_length(1.0)
