class_name MoveChainVisual
extends Node2D
## Local-only waypoints + dotted path for shift-click chaining.
## Green = move chain. Red = attack-move chain. Mixed chains are allowed.

const MOVE_COLOR := Color(0.35, 0.9, 0.45, 0.95)
const ATTACK_COLOR := Color(0.95, 0.28, 0.28, 0.95)
const WAYPOINT_RADIUS := 16.0
const WAYPOINT_WIDTH := 2.5
const DOT_RADIUS := 2.4
const DOT_SPACING := 16.0
const ARRIVE_DISTANCE := 16.0

var follow_unit: Node2D = null
var waypoints: Array[Vector2] = []
var waypoint_colors: Array[Color] = []


func _ready() -> void:
	z_index = 4
	set_process(true)


func _process(_delta: float) -> void:
	_consume_progress()
	queue_redraw()


func set_follow_unit(unit: Node2D) -> void:
	follow_unit = unit


func append_waypoint(point: Vector2, color: Color = MOVE_COLOR) -> void:
	waypoints.append(point)
	waypoint_colors.append(color)
	queue_redraw()


func clear() -> void:
	waypoints.clear()
	waypoint_colors.clear()
	queue_redraw()


func is_empty() -> bool:
	return waypoints.is_empty()


func _consume_progress() -> void:
	if follow_unit == null or not is_instance_valid(follow_unit) or waypoints.is_empty():
		return
	var unit_pos := follow_unit.global_position
	## Reaching a chained click removes that ring and the dotted segment into it.
	while not waypoints.is_empty() and unit_pos.distance_to(waypoints[0]) <= ARRIVE_DISTANCE:
		waypoints.pop_front()
		if not waypoint_colors.is_empty():
			waypoint_colors.pop_front()


func _draw() -> void:
	if waypoints.is_empty():
		return
	var points: Array[Vector2] = []
	if follow_unit != null and is_instance_valid(follow_unit):
		points.append(to_local(follow_unit.global_position))
	for wp in waypoints:
		points.append(to_local(wp))
	if points.size() >= 2:
		for i in range(points.size() - 1):
			## Segment color matches the waypoint it leads into.
			var color_index := i if follow_unit != null and is_instance_valid(follow_unit) else i
			## points[0] is unit; waypoints[0] colors segment unit->wp0 → color index 0
			var color := _color_at(color_index)
			_draw_dotted_line(points[i], points[i + 1], color)
	for i in range(waypoints.size()):
		var local_wp := to_local(waypoints[i])
		var color := _color_at(i)
		draw_arc(local_wp, WAYPOINT_RADIUS, 0.0, TAU, 40, color, WAYPOINT_WIDTH, true)
		draw_circle(local_wp, DOT_RADIUS, color)


func _color_at(index: int) -> Color:
	if index >= 0 and index < waypoint_colors.size():
		return waypoint_colors[index]
	return MOVE_COLOR


func _draw_dotted_line(from: Vector2, to: Vector2, color: Color) -> void:
	var delta := to - from
	var length := delta.length()
	if length < 1.0:
		return
	var direction := delta / length
	var traveled := 0.0
	while traveled <= length:
		draw_circle(from + direction * traveled, DOT_RADIUS, color)
		traveled += DOT_SPACING
