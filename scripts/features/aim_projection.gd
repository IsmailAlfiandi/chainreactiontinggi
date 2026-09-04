extends Node2D

@export var max_time: float = 2.0
@export var time_step: float = 0.08
@export var max_points: int = 25
@export var dot_radius: float = 3.0

var trajectory_points: Array[Vector2] = []

func _ready() -> void:
	visible = false


func show_trajectory(
	aim_direction: Vector2,
	power: float
) -> void:
	visible = true
	
	trajectory_points.clear()
	
	var initial_velocity: Vector2 = aim_direction * power
	
	var gravity: float = ProjectSettings.get_setting(
		"physics/2d/default_gravity"
	)
	
	var point_count: int = min(
		int(max_time / time_step),
		max_points
	)
	
	for i in range(point_count):
		var t: float = i * time_step
		
		var point: Vector2 = (
			initial_velocity * t
			+ Vector2(0.0, 0.5 * gravity * t * t)
		)
		
		trajectory_points.append(point)
	
	queue_redraw()


func hide_trajectory() -> void:
	visible = false
	trajectory_points.clear()
	queue_redraw()


func _draw() -> void:
	for i in range(trajectory_points.size()):
		var point: Vector2 = trajectory_points[i]
		
		var ratio: float = float(i) / float(trajectory_points.size())
		var radius: float = lerp(4.0, 1.5, ratio)
		
		draw_circle(point, radius, Color.WHITE)
