extends Camera2D

@export var follow_speed: float = 8.0
@export var default_target: Node2D          # usually the player

var target: Node2D = null

func _ready():
	target = default_target
	if target:
		global_position = target.global_position

func _physics_process(delta: float):
	if target and is_instance_valid(target):
		# Smooth follow
		global_position = global_position.lerp(target.global_position, follow_speed * delta)
	else:
		# Arrow was destroyed → optionally return to player
		if default_target:
			target = default_target

func follow(new_target: Node2D):
	target = new_target

func return_to_player():
	target = default_target
