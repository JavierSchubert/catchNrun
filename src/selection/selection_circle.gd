class_name SelectionCircle
extends Node2D
## Ring drawn under a selectable entity. Hover uses a thin stroke; selection uses a thick one.

const COLOR_OWN := Color(0.25, 0.85, 0.35, 0.95)
const COLOR_RUNNER_TEAM := Color(0.3, 0.55, 1.0, 0.95)
const COLOR_HUNTER := Color(0.95, 0.28, 0.28, 0.95)

const HOVER_WIDTH := 1.5
const SELECTED_WIDTH := 3.5
const ARC_POINTS := 48

var radius := 22.0
var circle_color := COLOR_OWN
var hovered := false
var selected := false


func _ready() -> void:
	z_index = -1
	queue_redraw()


func configure(next_radius: float, next_color: Color) -> void:
	radius = maxf(next_radius, 4.0)
	circle_color = next_color
	queue_redraw()


func set_hover(active: bool) -> void:
	if hovered == active:
		return
	hovered = active
	queue_redraw()


func set_selected(active: bool) -> void:
	if selected == active:
		return
	selected = active
	queue_redraw()


func _draw() -> void:
	if not hovered and not selected:
		return
	var width := SELECTED_WIDTH if selected else HOVER_WIDTH
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, ARC_POINTS, circle_color, width, true)
