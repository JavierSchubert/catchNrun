class_name UnitMovement
extends Node
## Applies a movement intent to a body. The match host is the only peer that calls apply().

var speed := 220.0
var intent := Vector2.ZERO


func apply(body: CharacterBody2D) -> void:
	body.velocity = intent.limit_length(1.0) * speed
	body.move_and_slide()
