extends RigidBody2D
class_name BombArrow

@export var lifetime: float = 8.0
@export var stop_speed: float = 40.0
@export var explosion_radius: float = 130.0
@export var explosion_force: float = 1000.0
@export var explosion_damage: float = 90.0
@export var explosion_linger_time: float = 1.4
@export var stick_depth: float = 16.0
@export var explode_window: float = 3.0          # ← time window to explode (seconds)

var has_landed := false
var has_exploded := false
var camera_returned := false
var can_explode := true                          # ← new flag
var last_velocity: Vector2 = Vector2.ZERO

var stuck_to: Node2D = null
var stuck_offset: Vector2 = Vector2.ZERO
var stuck_rotation_offset: float = 0.0

@onready var explosion_area: Area2D = $ExplosionArea
@onready var anim: AnimatedSprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("arrow")
	anim.play("default")

	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	if explosion_area:
		explosion_area.monitoring = true
		explosion_area.monitorable = false

	# Start the explode window timer
	_start_explode_window()

	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self) and not has_exploded:
		queue_free()

func _start_explode_window() -> void:
	await get_tree().create_timer(explode_window).timeout
	if not is_instance_valid(self) or has_exploded:
		return

	# Time is over → cannot explode anymore
	can_explode = false

	# Return camera if it hasn't returned yet
	if not camera_returned:
		camera_returned = true
		return_camera_to_player()

func _physics_process(delta: float) -> void:
	if has_exploded:
		return

	if has_landed:
		if is_instance_valid(stuck_to):
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
	if has_landed or has_exploded:
		return

	if body.is_in_group("arrow"):
		return

	if body is WoodBlock or body is StoneBlock or body is SteelBlock or body is TNTBlock:
		_stick_to_body(body)
		body.take_hit(last_velocity, self)
		_notify_player()
		return

	if body is Ghost:
		body.take_hit(last_velocity, self)
		_freeze_arrow()
		_notify_player()
		return

	has_landed = true
	_on_landed()

func _stick_to_body(body: Node) -> void:
	if has_landed or not is_instance_valid(body):
		return

	has_landed = true
	stuck_to = body

	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	set_deferred("freeze", true)
	lock_rotation = true
	contact_monitor = false

	var col := get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)

	var push_dir := last_velocity.normalized()
	if push_dir.length_squared() < 0.01:
		push_dir = Vector2.RIGHT.rotated(global_rotation)

	global_position += push_dir * stick_depth
	global_rotation += deg_to_rad(randf_range(-3.0, 3.0))

	stuck_offset = body.to_local(global_position)
	stuck_rotation_offset = global_rotation - body.global_rotation

func _on_landed() -> void:
	_freeze_arrow()
	_notify_player()

func _freeze_arrow() -> void:
	has_landed = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	set_deferred("freeze", true)
	lock_rotation = true

	var col := get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)

func _notify_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("after_hit"):
		player.after_hit()

func return_camera_to_player() -> void:
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("return_to_player"):
		camera.return_to_player()

# ====================== EXPLOSION ======================
func explode() -> void:
	# Block explosion if time window is over or already exploded
	if has_exploded or not can_explode:
		return

	has_exploded = true
	can_explode = false
	camera_returned = true

	_freeze_arrow()
	anim.play("explode")

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()

	var shape = CircleShape2D.new()
	shape.radius = explosion_radius
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF

	var results = space_state.intersect_shape(query, 64)

	for result in results:
		_affect_body(result.collider)

	_notify_player()

	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("hold_at_explosion"):
		camera.hold_at_explosion(global_position, explosion_linger_time)

	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(self):
		queue_free()

func _affect_body(body: Node) -> void:
	if not is_instance_valid(body) or body == self:
		return

	var direction = (body.global_position - global_position).normalized()
	var distance = global_position.distance_to(body.global_position)
	var effective_radius = explosion_radius * 1.15
	var falloff = 1.0 - clamp(distance / effective_radius, 0.0, 1.0)

	if falloff <= 0.0:
		return

	# ---------- BLOCKS ----------
	if body is WoodBlock or body is StoneBlock or body is SteelBlock or body is TNTBlock:
		var damage = explosion_damage * falloff

		if body.has_method("take_explosion_damage"):
			body.take_explosion_damage(damage)
		elif body.has_method("_apply_damage"):
			body._apply_damage(damage)
		elif "current_health" in body:
			body.current_health = max(body.current_health - damage, 0.0)
			if body.has_method("update_sprite"):
				body.update_sprite()
			if body.current_health <= 0.0 and body.has_method("destroy_block"):
				body.destroy_block()

		if body is RigidBody2D:
			body.sleeping = false
			body.freeze = false
			body.apply_central_impulse(direction * explosion_force * falloff)

	# ---------- ENEMIES ----------
	elif body is Ghost:
		var damage = explosion_damage * falloff

		if body.has_method("take_explosion_damage"):
			body.take_explosion_damage(damage)
		elif body.has_method("take_damage"):
			body.take_damage(damage)
		elif body.has_method("take_hit"):
			body.take_hit(direction * 900.0, self)
