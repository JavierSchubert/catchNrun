extends Node2D
## Match scene root. The host spawns one Player per peer through the MultiplayerSpawner,
## which creates the same players on every client. The host also pays gold income.

@export var player_scene: PackedScene

@onready var spawner: MultiplayerSpawner = $PlayerSpawner
@onready var players_root: Node2D = $Players
@onready var spawn_points: Node2D = $SpawnPoints
@onready var income_timer: Timer = $IncomeTimer


func _ready() -> void:
	# A custom spawn function lets us send role and position along with each spawn.
	# Every peer must set it before the first spawn arrives.
	spawner.spawn_function = _spawn_player
	if multiplayer.is_server():
		GameManager.all_players_loaded.connect(_spawn_all, CONNECT_ONE_SHOT)
		NetworkManager.peer_left.connect(_on_peer_left)
		income_timer.timeout.connect(_pay_income)
	GameManager.report_scene_ready.rpc_id(1)


func _spawn_all() -> void:
	var points := spawn_points.get_children()
	var i := 0
	for id: int in GameManager.players:
		var role: int = GameManager.players[id].role
		# Hunter gets the first spawn point; runners fill the rest.
		var point: Node2D = points[0] if role == RoleData.Role.HUNTER else points[1 + i % (points.size() - 1)]
		if role != RoleData.Role.HUNTER:
			i += 1
		spawner.spawn({"peer_id": id, "role": role, "position": point.global_position})
	income_timer.start()


func _spawn_player(data: Dictionary) -> Node:
	var player: Player = player_scene.instantiate()
	player.name = str(data.peer_id)
	player.role = data.role
	player.position = data.position
	player.sync_position = data.position
	return player


func _pay_income() -> void:
	for player: Player in players_root.get_children():
		if not player.health.is_dead:
			player.inventory.gold += player.role_data.gold_per_second


func _on_peer_left(peer_id: int) -> void:
	var player := players_root.get_node_or_null(str(peer_id))
	if player:
		player.queue_free() # The spawner removes it on the clients too.
