
extends RigidBody2D
class_name TNTBlock

enum MaterialType { WOOD, STONE, STEEL, TNT }

@export var material_type: MaterialType = MaterialType.TNT
@export var push_speed: float = 300.0
@export var destroy_speed: float = 700.0
@export var explosion_force: float = 800.0
@export var explosion_radius: float = 1000.0
@export var push_force_multiplier: float = 1.0

# === Health ===
@export var max_health: float = 100.0
var current_health: float = 100.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	anim.play("idle")

	match material_type:
		MaterialType.WOOD:
			mass = 2.0
			push_speed = 280.0
			destroy_speed = 750.0
			push_force_multiplier = 1.0
			max_health = 60.0

		MaterialType.STONE:
			mass = 6.0
			push_speed = 450.0
			destroy_speed = 900.0
			push_force_multiplier = 1.0
			max_health = 180.0

		MaterialType.STEEL:
			mass = 12.0
			push_speed = 700.0
			destroy_speed = 1300.0
			push_force_multiplier = 0.7
			max_health = 350.0

		MaterialType.TNT:
			mass = 3.0
			push_speed = 50.0
			destroy_speed = 80.0
			push_force_multiplier = 0.5
			max_health = 40.0

	current_health = max_health

	contact_monitor = true
	max_contacts_reported = 4

func take_hit(
	arrow_velocity: Vector2,
	arrow: RigidBody2D = null
) -> bool:

	if current_health <= 0.0:
		return true

	var impact_speed: float = arrow_velocity.length()

	print("TNT impact speed: ", impact_speed)

	# Calculate damage
	var damage: float = 0.0

	if impact_speed >= destroy_speed:
		# Strong hit = destroy immediately
		damage = current_health
	elif impact_speed >= push_speed:
		# Medium hit
		damage = impact_speed * 0.08
	else:
		# Weak hit
		damage = impact_speed * 0.03

	current_health -= damage
	current_health = maxf(current_health, 0.0)

	print("TNT HP: ", current_health)

	# PUSH TNT if it survives
	if current_health > 0.0 and impact_speed >= push_speed:
		var direction: Vector2 = arrow_velocity.normalized()
		var force: Vector2 = direction * impact_speed * push_force_multiplier

		apply_central_impulse(force)

		# Arrow loses some speed but remains moving
		if arrow != null:
			arrow.linear_velocity *= 0.55

	elif arrow != null:
		# Weak hit -> smaller slowdown
		arrow.linear_velocity *= 0.85

	# TNT destroyed
	if current_health <= 0.0:
		destroy_block()
		return true

	# TNT survived
	return false


# ============================================================
# EXPLOSION DAMAGE
# ============================================================
func take_explosion_damage(amount: float) -> void:
	if current_health <= 0.0:
		return

	_apply_damage(amount)


func _apply_damage(amount: float) -> void:
	if current_health <= 0.0:
		return

	current_health -= amount
	current_health = maxf(current_health, 0.0)

	if current_health <= 0.0:
		destroy_block()


# ============================================================
# SPRITE
# ============================================================
func update_sprite() -> void:
	pass


# ============================================================
# DESTROY / EXPLODE
# ============================================================
func destroy_block() -> void:
	if not is_instance_valid(self):
		return

	# ----------------------------------------------------------
	# Release arrows that were previously stuck in this TNT.
	# Do NOT queue_free() them.
	# ----------------------------------------------------------
	for arrow in get_tree().get_nodes_in_group("arrow"):
		if not is_instance_valid(arrow):
			continue

		if arrow.get("stuck_to") == self:
			if arrow.has_method("release_from_target"):
				arrow.release_from_target()

	# ----------------------------------------------------------
	# Get bodies inside explosion Area2D
	# ----------------------------------------------------------
	var explosion_area := get_node_or_null("Area2D")
	var bodies: Array = []

	if explosion_area:
		explosion_area.monitoring = true
		bodies = explosion_area.get_overlapping_bodies()

	# ----------------------------------------------------------
	# Fallback physics query if Area2D finds nothing
	# ----------------------------------------------------------
	if bodies.is_empty():
		var space_state := get_world_2d().direct_space_state

		var query := PhysicsShapeQueryParameters2D.new()

		var shape := CircleShape2D.new()
		shape.radius = explosion_radius

		var query_transform := Transform2D(
			0.0,
			global_position
		)

		query.shape = shape
		query.transform = query_transform
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.collision_mask = 0xFFFFFFFF
		query.exclude = [self.get_rid()]

		var results := space_state.intersect_shape(query, 32)

		for result in results:
			bodies.append(result.collider)

	# ----------------------------------------------------------
	# Explosion effects
	# ----------------------------------------------------------
	for body in bodies:
		if body == self:
			continue

		if not is_instance_valid(body):
			continue

		var offset: Vector2 = body.global_position - global_position
		var distance: float = offset.length()

		if distance <= 0.01:
			continue

		var direction: Vector2 = offset.normalized()

		var falloff: float = 1.0 - clamp(
			distance / explosion_radius,
			0.0,
			1.0
		)

		if falloff <= 0.05:
			continue

		# ------------------------------------------------------
		# PUSH
		# ------------------------------------------------------
		if body is RigidBody2D:
			body.sleeping = false
			body.freeze = false

			var explosion_impulse: Vector2 = (
				direction * explosion_force * falloff
			)

			body.apply_central_impulse(explosion_impulse)

		# ------------------------------------------------------
		# DAMAGE
		# ------------------------------------------------------
		var explosion_damage: float = 750.0

		if body is TNTBlock:
			# Chain reaction
			body.call_deferred("destroy_block")

		elif body.has_method("take_explosion_damage"):
			body.take_explosion_damage(
				explosion_damage * falloff
			)

		elif body.has_method("_apply_damage"):
			body._apply_damage(
				explosion_damage * falloff
			)

		elif body.get("current_health") != null:
			body.current_health -= (
				explosion_damage * falloff
			)

			body.current_health = maxf(
				body.current_health,
				0.0
			)

			if body.has_method("update_sprite"):
				body.update_sprite()

			if body.current_health <= 0.0:
				if body.has_method("destroy_block"):
					body.call_deferred("destroy_block")
				else:
					body.queue_free()

	anim.play("explode")
	ScoreManager.add_score(10)

	await anim.animation_finished

	if is_instance_valid(self):
		queue_free()
