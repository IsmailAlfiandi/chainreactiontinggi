extends RigidBody2D
class_name arrow

var stuck_to: Node2D = null
var stuck_offset: Vector2 = Vector2.ZERO
var stuck_rotation_offset: float = 0.0

@export var lifetime: float = 8.0
@export var stop_speed: float = 40.0
@export var camera_return_delay: float = 3.0
@export var stick_depth: float = 14.0

var has_landed := false
var last_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("arrow")
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta: float) -> void:
	if has_landed:
		if is_instance_valid(stuck_to):
			# Keep the arrow glued even if the block moves/rotates
			global_position = stuck_to.to_global(stuck_offset)
			global_rotation = stuck_to.global_rotation + stuck_rotation_offset
		return

	last_velocity = linear_velocity

	if linear_velocity.length() > 20.0:
		rotation = lerp_angle(rotation, linear_velocity.angle(), 12.0 * delta)

	if linear_velocity.length() < stop_speed:
		has_landed = true
		_on_landed()

func _on_body_entered(body: Node) -> void:
	if has_landed:
		return

	# Ignore other arrows
	if body.is_in_group("arrow"):
		return

	# Blocks
	if body is GlassBlock or body is WoodBlock or body is StoneBlock or body is SteelBlock or body is TNTBlock:
		var block_destroyed: bool = body.take_hit(last_velocity, self)

		if block_destroyed:
			# Destroyed block -> pierce through
			_pierce_block()
		else:
			# Block survives -> stick
			_stick_to_body(body)
			_start_return_sequence()

		return

	# Enemies -> pierce through
	if body is Ghost or body is Ghost2 or body is bat:
		body.take_hit(last_velocity, self)
		return

	# Everything else is a solid world object
	# Example: TileMap boundary / walls
	has_landed = true
	_on_landed()

func _stick_to_body(body: Node) -> void:
	if has_landed or not is_instance_valid(body):
		return

	has_landed = true
	stuck_to = body

	# Stop physics completely
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	set_deferred("freeze", true)
	lock_rotation = true
	contact_monitor = false

	# Disable collision so other arrows can still hit the block
	var col := get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)

	# Push the tip deeper into the surface
	var push_dir := last_velocity.normalized()
	if push_dir.length_squared() < 0.01:
		push_dir = Vector2.RIGHT.rotated(global_rotation)

	# Tune this value (usually 10–20 looks good)
	global_position += push_dir * randf_range(12.0, 18.0)
	global_rotation += deg_to_rad(randf_range(-4.0, 4.0))  # tiny tilt

	# Store relative transform
	stuck_offset = body.to_local(global_position)
	stuck_rotation_offset = global_rotation - body.global_rotation

func _finish_stick(body: Node) -> void:
	if not is_instance_valid(self) or not is_instance_valid(body):
		return

	# Remember current global transform
	var gtrans := global_transform

	# Reparent so the arrow follows the block
	get_parent().remove_child(self)
	body.add_child(self)
	global_transform = gtrans

	# Push the arrow a bit deeper into the surface along its flight direction
	var push_dir := last_velocity.normalized()
	if push_dir.length_squared() < 0.01:
		push_dir = Vector2.RIGHT.rotated(global_rotation)

	position += push_dir * stick_depth

	# Store relative offset AFTER the push
	stuck_offset = body.to_local(global_position)
	stuck_rotation_offset = global_rotation - body.global_rotation

	# Optional: make freeze mode explicit (STATIC is usually best for stuck projectiles)
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC

func _pierce_block() -> void:
	var speed: float = linear_velocity.length()
	var direction: Vector2 = linear_velocity.normalized()

	var pierce_speed_multiplier: float = 0.8

	linear_velocity = direction * speed * pierce_speed_multiplier

	global_position += direction * 10.0
	
func _on_landed() -> void:
	_freeze_arrow()
	_start_return_sequence()

func _freeze_arrow() -> void:
	has_landed = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	set_deferred("freeze", true)
	lock_rotation = true

	var col := get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)
		
func release_from_target() -> void:
	if not is_instance_valid(self):
		return

	# Stop following the destroyed block
	stuck_to = null
	stuck_offset = Vector2.ZERO
	stuck_rotation_offset = 0.0

	# Allow physics again
	has_landed = false
	freeze = false
	lock_rotation = false
	contact_monitor = true

	var col := get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", false)

	# Let the arrow fall naturally
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

func _start_return_sequence() -> void:
	var camera = get_tree().get_first_node_in_group("camera")

	if camera and camera.has_method("delay_return_to_player"):
		camera.delay_return_to_player(camera_return_delay)

	var player = get_tree().get_first_node_in_group("player")

	if player and player.has_method("after_hit"):
		player.after_hit()
