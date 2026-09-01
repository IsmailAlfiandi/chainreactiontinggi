extends RigidBody2D

@export var break_speed: float = 500.0

func hit_by_arrow(arrow_speed: float):
	if arrow_speed >= break_speed:
		queue_free()
