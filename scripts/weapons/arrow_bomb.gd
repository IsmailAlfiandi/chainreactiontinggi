extends RigidBody2D
class_name BombArrow

# ============================================================
# SETTINGS
# ============================================================

@export var lifetime: float = 8.0
@export var stop_speed: float = 40.0

# Normal arrow-style piercing
@export var pierce_speed_multiplier: float = 0.8

# Camera
@export var camera_return_delay: float = 3.0

# Explosion
@export var explosion_radius: float = 500.0
@export var explosion_force: float = 1000.0
@export var explosion_damage: float = 650.0
@export var explosion_linger_time: float = 1.4

# Sticking
@export var stick_depth: float = 16.0

# How long the player can manually detonate the bomb
@export var explode_window: float = 3.0


# ============================================================
# STATE
# ============================================================

var has_landed: bool = false
var has_exploded: bool = false
var can_explode: bool = true

var last_velocity: Vector2 = Vector2.ZERO

var stuck_to: Node2D = null
var stuck_offset: Vector2 = Vector2.ZERO
var stuck_rotation_offset: float = 0.0


# ============================================================
# NODES
# ============================================================

@onready var explosion_area: Area2D = $ExplosionArea
@onready var anim: AnimatedSprite2D = $Sprite2D


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	add_to_group("arrow")

	if anim:
		anim.play("default")

	# High speed collision detection
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY

	contact_monitor = true
	max_contacts_reported = 4

	body_entered.connect(_on_body_entered)

	# Explosion detection area
	if explosion_area:
		explosion_area.monitoring = true
		explosion_area.monitorable = false

	# Start manual explosion timer
	_start_explode_window()

	# Lifetime
	await get_tree().create_timer(lifetime).timeout

	if is_instance_valid(self) and not has_exploded:
		queue_free()


# ============================================================
# EXPLOSION WINDOW
# ============================================================

func _start_explode_window() -> void:
	await get_tree().create_timer(explode_window).timeout

	if not is_instance_valid(self):
		return

	if has_exploded:
		return

	can_explode = false


# ============================================================
# PHYSICS
# ============================================================

func _physics_process(delta: float) -> void:
	if has_exploded:
		return

	# ----------------------------------------
	# Arrow is stuck to something
	# ----------------------------------------
	if has_landed:
		if is_instance_valid(stuck_to):
			global_position = stuck_to.to_global(stuck_offset)
			global_rotation = (
				stuck_to.global_rotation
				+ stuck_rotation_offset
			)
		else:
			# Target was destroyed
			release_from_target()

		return

	# Save velocity BEFORE collision
	last_velocity = linear_velocity

	# Rotate arrow toward movement direction
	if linear_velocity.length() > 20.0:
		rotation = lerp_angle(
			rotation,
			linear_velocity.angle(),
			12.0 * delta
		)

	# If arrow becomes too slow, land
	if linear_velocity.length() < stop_speed:
		has_landed = true
		_on_landed()


# ============================================================
# COLLISION
# ============================================================

func _on_body_entered(body: Node) -> void:
	if has_landed or has_exploded:
		return

	# Ignore other arrows
	if body.is_in_group("arrow"):
		return

	# ========================================================
	# BLOCKS
	# ========================================================

	if (
		body is GlassBlock
		or body is WoodBlock
		or body is StoneBlock
		or body is SteelBlock
		or body is TNTBlock
	):
		var block_destroyed: bool = body.take_hit(
			last_velocity,
			self
		)

		if block_destroyed:
			# Block died → penetrate through it
			_pierce_block()
		else:
			# Block survived → stick to it
			_stick_to_body(body)

			# Camera waits before returning
			_start_camera_return()

		return

	# ========================================================
	# ENEMIES
	# ========================================================

	if body is Ghost or body is Ghost2 or body is bat:
		body.take_hit(last_velocity, self)

		# Bomb arrow keeps flying through enemy
		return

	# ========================================================
	# WORLD BORDER / TILEMAP / WALL
	# ========================================================

	has_landed = true
	_on_landed()


# ============================================================
# STICK TO BLOCK
# ============================================================

func _stick_to_body(body: Node2D) -> void:
	if has_landed:
		return

	if not is_instance_valid(body):
		return

	has_landed = true
	stuck_to = body

	# Stop physics
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

	set_deferred("freeze", true)

	lock_rotation = true

	contact_monitor = false

	# Disable arrow collision
	var col := get_node_or_null("CollisionShape2D")

	if col:
		col.set_deferred("disabled", true)

	# Push deeper into block
	var push_dir: Vector2 = last_velocity.normalized()

	if push_dir.length_squared() < 0.01:
		push_dir = Vector2.RIGHT.rotated(global_rotation)

	global_position += push_dir * stick_depth

	global_rotation += deg_to_rad(
		randf_range(-3.0, 3.0)
	)

	# Store local transform
	stuck_offset = body.to_local(global_position)

	stuck_rotation_offset = (
		global_rotation
		- body.global_rotation
	)


# ============================================================
# PIERCE BLOCK
# ============================================================

func _pierce_block() -> void:
	if has_exploded:
		return

	var speed: float = linear_velocity.length()

	var direction: Vector2 = linear_velocity.normalized()

	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT.rotated(global_rotation)

	# Reduce speed after penetrating the block
	linear_velocity = (
		direction
		* speed
		* pierce_speed_multiplier
	)

	# Move beyond the destroyed block
	global_position += direction * 10.0

	# Keep physics active
	has_landed = false
	stuck_to = null

	freeze = false
	lock_rotation = false
	contact_monitor = true

	var col := get_node_or_null("CollisionShape2D")

	if col:
		col.set_deferred("disabled", false)

	print(
		"Bomb arrow pierced block. Speed = ",
		linear_velocity.length()
	)


# ============================================================
# LANDED
# ============================================================

func _on_landed() -> void:
	_freeze_arrow()
	_start_camera_return()


func _freeze_arrow() -> void:
	has_landed = true

	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

	set_deferred("freeze", true)

	lock_rotation = true

	var col := get_node_or_null("CollisionShape2D")

	if col:
		col.set_deferred("disabled", true)


# ============================================================
# RELEASE FROM DESTROYED BLOCK
# ============================================================

func release_from_target() -> void:
	if not is_instance_valid(self):
		return

	stuck_to = null

	stuck_offset = Vector2.ZERO
	stuck_rotation_offset = 0.0

	has_landed = false

	freeze = false
	lock_rotation = false

	contact_monitor = true

	var col := get_node_or_null("CollisionShape2D")

	if col:
		col.set_deferred("disabled", false)

	# Released arrow falls naturally
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0


# ============================================================
# CAMERA
# ============================================================

func _start_camera_return() -> void:
	var camera := get_tree().get_first_node_in_group("camera")

	if camera and camera.has_method("delay_return_to_player"):
		camera.delay_return_to_player(
			camera_return_delay
		)

	_notify_player()


func _notify_player() -> void:
	var player := get_tree().get_first_node_in_group("player")

	if player and player.has_method("after_hit"):
		player.after_hit()


# ============================================================
# EXPLOSION
# ============================================================

func explode() -> void:
	if has_exploded or not can_explode:
		return

	has_exploded = true
	can_explode = false

	# Stop the bomb arrow
	_freeze_arrow()

	# Make sure physics has updated before checking nearby bodies
	await get_tree().physics_frame

	# Play explosion animation
	if anim:
		anim.play("explode")

	var bodies: Array = []

	# =========================================================
	# Get bodies from ExplosionArea
	# =========================================================
	if explosion_area:
		explosion_area.global_position = global_position
		explosion_area.monitoring = true

		# Wait one physics frame so overlapping bodies are updated
		await get_tree().physics_frame

		bodies = explosion_area.get_overlapping_bodies()

	# =========================================================
	# Fallback: physics shape query
	# =========================================================
	if bodies.is_empty():
		var space_state := get_world_2d().direct_space_state

		var query := PhysicsShapeQueryParameters2D.new()

		var shape := CircleShape2D.new()
		shape.radius = explosion_radius

		query.shape = shape
		query.transform = Transform2D(
			0.0,
			global_position
		)

		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.collision_mask = 0xFFFFFFFF

		query.exclude = [get_rid()]

		var results := space_state.intersect_shape(query, 64)

		for result in results:
			if result.has("collider"):
				bodies.append(result.collider)

	# =========================================================
	# Apply explosion
	# =========================================================
	for body in bodies:
		_affect_body(body)

	# =========================================================
	# Camera
	# =========================================================
	var camera := get_tree().get_first_node_in_group("camera")

	if camera and camera.has_method("hold_at_explosion"):
		camera.hold_at_explosion(
			global_position,
			explosion_linger_time
		)

	_notify_player()

	await get_tree().create_timer(0.5).timeout

	if is_instance_valid(self):
		queue_free()


# ============================================================
# EXPLOSION AFFECT BODY
# ============================================================

func _affect_body(body: Node) -> void:
	if not is_instance_valid(body):
		return

	if body == self:
		return

	var offset: Vector2 = body.global_position - global_position
	var distance: float = offset.length()

	if distance > explosion_radius:
		return

	var direction: Vector2 = Vector2.RIGHT

	if distance > 0.01:
		direction = offset.normalized()

	# 1.0 at center, 0.0 at edge
	var falloff: float = 1.0 - clamp(
		distance / explosion_radius,
		0.0,
		1.0
	)

	var damage: float = explosion_damage * falloff
	var impulse: Vector2 = (
		direction
		* explosion_force
		* falloff
	)

	# =========================================================
	# BLOCKS
	# =========================================================
	if (
		body is GlassBlock
		or body is WoodBlock
		or body is StoneBlock
		or body is SteelBlock
		or body is TNTBlock
	):
		print(
			"Explosion hit block: ",
			body.name,
			" Damage: ",
			damage
		)

		# DAMAGE
		if body.has_method("take_explosion_damage"):
			body.take_explosion_damage(damage)

		elif body.has_method("_apply_damage"):
			body._apply_damage(damage)

		# PUSH ONLY IF BLOCK SURVIVED
		if is_instance_valid(body) and body.current_health > 0.0:
			body.sleeping = false
			body.freeze = false
			body.apply_central_impulse(impulse)

		return

	# =========================================================
	# ENEMIES
	# =========================================================
	if body is Ghost or body is Ghost2 or body is bat:
		print(
			"Explosion hit enemy: ",
			body.name,
			" Damage: ",
			damage
		)

		if body.has_method("take_explosion_damage"):
			body.take_explosion_damage(damage)

		elif body.has_method("take_damage"):
			body.take_damage(damage)

		elif body.has_method("take_hit"):
			body.take_hit(
				direction * explosion_force,
				self
			)

		return

	# =========================================================
	# OTHER RIGIDBODIES
	# =========================================================
	if body is RigidBody2D:
		body.sleeping = false
		body.freeze = false
		body.apply_central_impulse(impulse)
