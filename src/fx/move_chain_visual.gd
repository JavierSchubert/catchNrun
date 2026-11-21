class_name MoveChainVisual
extends Node2D
## Local-only green waypoints + dotted path for shift-click move chaining.

const CHAIN_COLOR := Color(0.35, 0.9, 0.45, 0.95)
const WAYPOINT_RADIUS := 16.0
const WAYPOINT_WIDTH := 2.5
const DOT_RADIUS := 2.4
const DOT_SPACING := 16.0
const ARRIVE_DISTANCE := 16.0

var follow_unit: Node2D = null
var waypoints: Array[Vector2] = []


func _ready() -> void:
	z_index = 4
	set_process(true)


func _process(_delta: float) -> void:
	_consume_progress()
	queue_redraw()


func set_follow_unit(unit: Node2D) -> void:
	follow_unit = unit


func set_waypoints(points: Array[Vector2]) -> void:
	waypoints = points.duplicate()
	queue_redraw()


func append_waypoint(point: Vector2) -> void:
	waypoints.append(point)
	queue_redraw()


func clear() -> void:
	waypoints.clear()
	queue_redraw()


func is_empty() -> bool:
	return waypoints.is_empty()


func _consume_progress() -> void:
	if follow_unit == null or not is_instance_valid(follow_unit) or waypoints.is_empty():
		return
	var unit_pos := follow_unit.global_position
	## Reaching a chained click removes that green ring and the dotted segment into it.
	while not waypoints.is_empty() and unit_pos.distance_to(waypoints[0]) <= ARRIVE_DISTANCE:
		waypoints.pop_front()


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
			_draw_dotted_line(points[i], points[i + 1])
	for i in range(waypoints.size()):
		var local_wp := to_local(waypoints[i])
		draw_arc(local_wp, WAYPOINT_RADIUS, 0.0, TAU, 40, CHAIN_COLOR, WAYPOINT_WIDTH, true)
		draw_circle(local_wp, DOT_RADIUS, CHAIN_COLOR)


func _draw_dotted_line(from: Vector2, to: Vector2) -> void:
	var delta := to - from
	var length := delta.length()
	if length < 1.0:
		return
	var direction := delta / length
	var traveled := 0.0
	while traveled <= length:
		draw_circle(from + direction * traveled, DOT_RADIUS, CHAIN_COLOR)
		traveled += DOT_SPACING
