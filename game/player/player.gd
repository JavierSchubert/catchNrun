class_name Player
extends CharacterBody2D
## Who owns what on a player:
##   - Movement belongs to the controlling peer. It moves locally right away (no input
##     lag over the Steam relay), and OwnerSync sends its position to everyone else.
##   - Health, gold and items belong to the host (ServerSync). Clients only send
##     requests: attack, buy.
## Fine for a game among friends. If cheating ever matters, also move movement to the host.
##
## `name` (= peer id) and `role` are set by Match._spawn_player before the node enters the tree.

@export var hunter_role: RoleData
@export var runner_role: RoleData

const INTERPOLATION_SPEED := 15.0 ## Higher = remote players follow faster but less smoothly.
const SNAP_DISTANCE := 200.0 ## Bigger jumps (teleports, respawns) snap instead of sliding.

var peer_id := 1
var role: RoleData.Role = RoleData.Role.RUNNER
var role_data: RoleData
## Last position reported by the owner. OwnerSync replicates this instead of `position`,
## so remote players can smoothly slide toward it rather than jumping on each packet.
var sync_position := Vector2.ZERO

var _next_attack_msec := 0 # Host only.

@onready var stats: StatsComponent = $StatsComponent
@onready var health: HealthComponent = $HealthComponent
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var name_label: Label = $NameLabel
@onready var camera: Camera2D = $Camera2D


func _enter_tree() -> void:
	peer_id = name.to_int()
	set_multiplayer_authority(peer_id) # Recursive: the whole node tree belongs to the owner...
	$ServerSync.set_multiplayer_authority(1) # ...except ServerSync, which the host owns.


func _ready() -> void:
	add_to_group("players")
	role_data = hunter_role if role == RoleData.Role.HUNTER else runner_role
	stats.setup(role_data.base_stats)
	inventory.refresh() # Synced items can arrive before setup(), so apply them now.
	health.died.connect(_on_died)

	var entry: Dictionary = GameManager.players.get(peer_id, {})
	name_label.text = "%s (%s)" % [entry.get("name", "?"), role_data.display_name]
	camera.enabled = is_multiplayer_authority()

	if multiplayer.is_server():
		health.reset()
		inventory.gold = role_data.starting_gold


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		_follow_sync_position(delta)
		return
	if not health.is_dead and GameManager.phase == GameManager.Phase.IN_MATCH:
		var direction := Input.get_vector("left", "right", "up", "down")
		velocity = direction * stats.get_stat(StatBlock.Stat.MOVE_SPEED)
		move_and_slide()
		if Input.is_action_just_pressed("attack"):
			_request_attack.rpc_id(1)
	sync_position = position


func _follow_sync_position(delta: float) -> void:
	if position.distance_to(sync_position) > SNAP_DISTANCE:
		position = sync_position
	else:
		# Framerate-independent exponential smoothing.
		position = position.lerp(sync_position, 1.0 - exp(-INTERPOLATION_SPEED * delta))


func _draw() -> void:
	var color := role_data.color if role_data else Color.WHITE
	if health and health.is_dead:
		color.a = 0.3
	draw_circle(Vector2.ZERO, 16.0, color)


func is_local() -> bool:
	return peer_id == multiplayer.get_unique_id()


## Host only: checks the attack and applies damage to every enemy in range.
@rpc("any_peer", "call_local", "reliable")
func _request_attack() -> void:
	if not multiplayer.is_server() or GameManager.sender_id(multiplayer) != peer_id:
		return
	if health.is_dead or GameManager.phase != GameManager.Phase.IN_MATCH:
		return
	var attack_range := stats.get_stat(StatBlock.Stat.ATTACK_RANGE)
	var now := Time.get_ticks_msec()
	if attack_range <= 0.0 or now < _next_attack_msec:
		return
	_next_attack_msec = now + int(stats.get_stat(StatBlock.Stat.ATTACK_COOLDOWN) * 1000.0)

	for node in get_tree().get_nodes_in_group("players"):
		var other := node as Player
		if other == self or other.role == role or other.health.is_dead:
			continue # Hunter hits runners, runners hit the hunter.
		# Use the latest reported positions, not the smoothed (slightly behind) ones.
		if sync_position.distance_to(other.sync_position) <= attack_range:
			other.health.apply_damage(stats.get_stat(StatBlock.Stat.DAMAGE))
	_play_attack_fx.rpc()


# "any_peer" + sender check: this node's authority is its owner, but only the host sends this.
@rpc("any_peer", "call_local", "unreliable")
func _play_attack_fx() -> void:
	if GameManager.sender_id(multiplayer) != 1:
		return
	# Cosmetic only. Replace with an animation / sound.
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.06)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)


func _on_died() -> void:
	queue_redraw()
	if multiplayer.is_server():
		GameManager.server_report_death(peer_id)
