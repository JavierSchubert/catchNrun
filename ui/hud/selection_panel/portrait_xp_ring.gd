@tool
class_name PortraitXpRing
extends Control
## Double grey portrait frame with a dark band between rings.
## Violet fill in the band grows counterclockwise from the top (12 o'clock).

const GREY := Color(0.58, 0.58, 0.62, 0.95)
const BAND := Color(0.06, 0.06, 0.08, 0.95)
const VIOLET := Color(0.58, 0.28, 0.92, 1.0)

## Grey ring stroke width (outer and inner frame match).
const RING_W := 4.0
## Dark / XP band thickness between outer and inner frame.
const BAND_W := 7.0

@export_range(0.0, 1.0, 0.001) var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()

@export var show_fill := true:
	set(value):
		show_fill = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var outer_r := mini(size.x, size.y) * 0.5 - 1.0
	if outer_r <= RING_W * 2.0 + BAND_W:
		return
	var band_mid := outer_r - RING_W - BAND_W * 0.5
	var inner_mid := outer_r - RING_W - BAND_W - RING_W * 0.5

	## Dark band first so grey strokes sit on top of the edges.
	draw_arc(center, band_mid, 0.0, TAU, 72, BAND, BAND_W, true)
	## Outer grey ring.
	draw_arc(center, outer_r - RING_W * 0.5, 0.0, TAU, 72, GREY, RING_W, true)
	## Inner grey frame (same thickness as outer).
	draw_arc(center, inner_mid, 0.0, TAU, 72, GREY, RING_W, true)

	if not show_fill or progress <= 0.001:
		return
	## Godot arcs advance counterclockwise; start at top (−π/2).
	var start := -PI / 2.0
	var sweep := clampf(progress, 0.0, 1.0) * TAU
	draw_arc(center, band_mid, start, start + sweep, 72, VIOLET, BAND_W * 0.92, true)
