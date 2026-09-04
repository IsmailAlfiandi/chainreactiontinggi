# camera_controller.gd
extends Camera2D

@export var normal_speed: float = 6.0
@export var catch_up_speed: float = 25.0
@export var max_distance: float = 180.0
@export var default_target_path: NodePath

var is_lingering := false
var linger_timer: float = 0.0

var target: Node2D = null
var default_target: Node2D = null


func _ready() -> void:
	add_to_group("camera")

	if default_target_path:
		default_target = get_node_or_null(default_target_path)

	if not default_target:
		default_target = get_tree().get_first_node_in_group("player")

	if default_target:
		target = default_target
		global_position = target.global_position


func _physics_process(delta: float) -> void:
	if is_lingering:
		linger_timer -= delta

		if linger_timer <= 0.0:
			is_lingering = false
			return_to_player()

		return

	if not is_instance_valid(target):
		if is_instance_valid(default_target):
			target = default_target
		else:
			var player = get_tree().get_first_node_in_group("player")

			if player:
				target = player
				default_target = player

		return

	var distance := global_position.distance_to(target.global_position)

	var speed := normal_speed

	if distance > max_distance:
		speed = catch_up_speed
	elif distance > max_distance * 0.5:
		var t := (distance - max_distance * 0.5) / (max_distance * 0.5)
		speed = lerp(normal_speed, catch_up_speed, t)

	global_position = global_position.lerp(
		target.global_position,
		speed * delta
	)


func hold_at_explosion(pos: Vector2, duration: float = 1.4) -> void:
	is_lingering = true
	linger_timer = duration
	target = null
	global_position = pos


func follow(new_target: Node2D) -> void:
	if new_target and is_instance_valid(new_target):
		# Don't override an intentional camera linger
		if is_lingering:
			return

		target = new_target


func delay_return_to_player(delay: float = 3.0) -> void:
	# Restart the timer every time this is called.
	# This is important when multiple arrows are fired quickly.
	is_lingering = true
	linger_timer = delay


func return_to_player() -> void:
	is_lingering = false
	linger_timer = 0.0

	if is_instance_valid(default_target):
		target = default_target
	else:
		var player = get_tree().get_first_node_in_group("player")

		if player:
			target = player
			default_target = player
