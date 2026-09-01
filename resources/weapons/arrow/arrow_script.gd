extends RigidBody2D

@export var lifetime: float = 8.0
@export var stop_speed: float = 40.0

var has_landed := false
var camera_returned := false

# Store the velocity from the previous physics frame
var last_velocity: Vector2 = Vector2.ZERO

func _ready():
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = true
	max_contacts_reported = 4
	
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta: float):
	if has_landed:
		return
	
	# Always save the current velocity
	last_velocity = linear_velocity
	
	# Rotate while flying
	if linear_velocity.length() > 20.0:
		var target_angle = linear_velocity.angle()
		rotation = lerp_angle(rotation, target_angle, 12.0 * delta)
	
	# Normal ground landing
	if linear_velocity.length() < stop_speed:
		has_landed = true
		_on_landed()

func _on_body_entered(body: Node) -> void:
	if has_landed:
		return
	
	# Hit a Block?
	if body is Block:
		# Use the velocity from BEFORE the collision
		body.take_hit(last_velocity, self)
		
		# Stop the arrow after hitting the block
		has_landed = true
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		freeze = true
		lock_rotation = true
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.after_hit()
		return
	
	# Normal ground
	has_landed = true
	_on_landed()

func _on_landed():
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true
	lock_rotation = true
	
	await get_tree().create_timer(1.0).timeout
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("after_hit"):
		player.after_hit()
	
	if not camera_returned:
		return_camera_to_player()
		camera_returned = true

func return_camera_to_player():
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("return_to_player"):
		camera.return_to_player()
