extends RigidBody2D

@export var lifetime: float = 8.0          # Auto destroy after this time
@export var stop_speed: float = 40.0       # Considered "landed" when slower than this

var has_landed := false
var camera_returned := false

func _ready():
	# continuous_cd = CCDMode.CAST_RAY  (uncomment if arrow tunnels through thin objects)

	# Auto destroy after some time
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta: float):
	# Detect when the arrow has almost stopped
	if not has_landed and linear_velocity.length() < stop_speed:
		has_landed = true
		_on_landed()

func _on_landed():
	# Wait a short moment so player can see the impact
	await get_tree().create_timer(1.0).timeout
	
	if not camera_returned:
		return_camera_to_player()
		camera_returned = true

func return_camera_to_player():
	var camera = get_tree().get_first_node_in_group("camera")
	var player = get_tree().get_first_node_in_group("player")
	if camera and camera.has_method("return_to_player"):
		camera.return_to_player()
		if player:
			player.after_hit()

# Optional: play hit effect when colliding
func _on_body_entered(body: Node):
	# You can add hit particles / sound here
	pass
