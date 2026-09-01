extends RigidBody2D

@export var lifetime: float = 4.0
@export var stop_speed: float = 40.0
@export var break_speed: float = 500.0
@export var bounce_strength: float = 0.7

var has_landed := false
var camera_returned := false


func _ready():
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY

	body_entered.connect(_on_body_entered)

	# Lifetime arrow tetap 8 detik
	await get_tree().create_timer(lifetime).timeout

	if is_instance_valid(self):
		if not has_landed:
			has_landed = true
			_on_landed()


func _physics_process(delta: float):
	if has_landed:
		return

	# Arrow mengikuti arah terbang
	if linear_velocity.length() > 20.0:
		var target_angle = linear_velocity.angle()
		rotation = lerp_angle(rotation, target_angle, 12.0 * delta)

	# Arrow sudah terlalu pelan
	if linear_velocity.length() < stop_speed:
		has_landed = true
		_on_landed()


func _on_body_entered(body: Node):
	if has_landed:
		return

	var speed = linear_velocity.length()

	# =========================
	# KENA STEEL BLOCK
	# =========================
	if body.has_method("hit_by_arrow"):

		if speed >= break_speed:
			# Panah kencang → blok hancur
			body.hit_by_arrow(speed)

			# Panah nancep
			has_landed = true
			linear_velocity = Vector2.ZERO
			angular_velocity = 0.0
			freeze = true
			lock_rotation = true

			# Kamera balik ke player
			await get_tree().create_timer(0.3).timeout

			var player = get_tree().get_first_node_in_group("player")

			if player and player.has_method("after_hit"):
				player.after_hit()

			if not camera_returned and player:
				var camera = get_tree().get_first_node_in_group("camera")

				if camera and camera.has_method("follow"):
					camera.follow(player)

				camera_returned = true

			return

		else:
			# Panah pelan → mental
			var normal = (global_position - body.global_position).normalized()

			linear_velocity = linear_velocity.bounce(normal) * bounce_strength

			return

	# =========================
	# KENA BENDA LAIN
	# =========================
	has_landed = true
	_on_landed()


func _on_landed():
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true
	lock_rotation = true

	await get_tree().create_timer(0.4).timeout

	# Ambil player
	var player = get_tree().get_first_node_in_group("player")

	# Player bisa bergerak lagi
	if player and player.has_method("after_hit"):
		player.after_hit()

	# Kamera langsung kembali ke player
	if not camera_returned and player:
		var camera = get_tree().get_first_node_in_group("camera")

		if camera and camera.has_method("follow"):
			camera.follow(player)

		camera_returned = true


func return_camera_to_player():
	var camera = get_tree().get_first_node_in_group("camera")

	if camera and camera.has_method("return_to_player"):
		camera.return_to_player()
