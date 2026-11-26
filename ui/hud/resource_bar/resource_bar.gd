class_name ResourceBar
extends Control
## Top-center HUD strip: a Crystal icon, the local player's Crystal balance, and — while
## they own finished Crystal Mines — the income those mines produce per second.
##
## Shown to both roles (the Hunter earns Crystals from the damage he applies), only while
## the local player is in an active match phase and not eliminated.
##
## Presentation only: the balance comes from GameManager and the per-mine rate from each
## BuildingDef. No economy rule is duplicated here (root README "Implementation Principle").

@onready var _crystal_icon: TextureRect = %CrystalIcon
@onready var _amount_label: Label = %AmountLabel
@onready var _income_label: Label = %IncomeLabel


func _ready() -> void:
	_crystal_icon.texture = BuildingIcons.crystal_icon()
	set_process(true)


func _process(_delta: float) -> void:
	var show_bar := _local_is_active_player()
	visible = show_bar
	if not show_bar:
		return
	var peer_id := _local_peer_id()
	_amount_label.text = "%d" % int(GameManager.crystals_for(peer_id))
	var income := _crystal_income_per_second(peer_id)
	_income_label.visible = income > 0.0
	_income_label.text = "+%.1f/s" % income


## Sum of what every finished Crystal Mine owned by `peer_id` yields per second.
## Read-only mirror of what Building._tick_mine() grants; the rates live in BuildingDef.
func _crystal_income_per_second(peer_id: int) -> float:
	var tree := get_tree()
	if tree == null:
		return 0.0
	var total := 0.0
	for node in tree.get_nodes_in_group("buildings"):
		var building := node as Building
		if building == null or building.def == null:
			continue
		if building.def.kind != BuildingDef.Kind.CRYSTAL_MINE:
			continue
		## A mine keeps producing while it upgrades — Building.server_tick() runs
		## _tick_active() in UPGRADING as well as IDLE, so only an unfinished
		## level-1 build contributes nothing.
		if building.owner_peer_id != peer_id or building.state == Building.State.UNDER_CONSTRUCTION:
			continue
		var interval := building.def.mine_interval
		if interval <= 0.0:
			continue
		total += building.def.mine_output_for_level(building.level) / interval
	return total


## Same phase / elimination gate as BuildingPanel._local_is_active_runner(), minus the
## role check — Crystals are shown to Runners and Hunters alike.
func _local_is_active_player() -> bool:
	var peer_id := _local_peer_id()
	if not GameManager.players.has(peer_id):
		return false
	if GameManager.phase != GameManager.Phase.RUNNER_PREPARATION and GameManager.phase != GameManager.Phase.HUNTER_ACTIVE:
		return false
	return not GameManager.is_eliminated(peer_id)


func _local_peer_id() -> int:
	if multiplayer != null and multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1
