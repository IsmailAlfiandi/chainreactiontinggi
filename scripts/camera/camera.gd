# camera_controller.gd
extends Camera2D

@export var normal_speed: float = 6.0
@export var catch_up_speed: float = 25.0
@export var max_distance: float = 180.0
@export var default_target_path: NodePath

var target: Node2D = null
var default_target: Node2D = null

func _ready():
	add_to_group("camera")
	
	if default_target_path:
		default_target = get_node(default_target_path)
		target = default_target
		global_position = target.global_position

func _physics_process(delta: float):
	if not target or not is_instance_valid(target):
		if default_target:
			target = default_target
		return

	var distance = global_position.distance_to(target.global_position)
	
	var speed = normal_speed
	if distance > max_distance:
		speed = catch_up_speed
	elif distance > max_distance * 0.5:
		var t = (distance - max_distance * 0.5) / (max_distance * 0.5)
		speed = lerp(normal_speed, catch_up_speed, t)

	global_position = global_position.lerp(target.global_position, speed * delta)

func follow(new_target: Node2D):
	if new_target:
		target = new_target

func return_to_player():
	target = default_target
