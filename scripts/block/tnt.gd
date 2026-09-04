extends RigidBody2D
class_name TNTBlock

enum MaterialType { WOOD, STONE, STEEL, TNT }

@export var material_type: MaterialType = MaterialType.TNT
@export var push_speed: float = 300.0
@export var destroy_speed: float = 700.0
@export var explosion_force: float = 800.0
@export var explosion_radius: float = 300.0
@export var push_force_multiplier: float = 1.0

# === Health ===
@export var max_health: float = 100.0
var current_health: float = 100.0

@onready var anim = $AnimatedSprite2D

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
			max_health = 40.0          # TNT is fragile
	
	current_health = max_health
	
	contact_monitor = true
	max_contacts_reported = 4

# Called by normal arrows
func take_hit(arrow_velocity: Vector2, arrow: RigidBody2D = null) -> void:
	var impact_speed = arrow_velocity.length()
	
	# Calculate damage from impact speed
	var damage = 0.0
	if impact_speed >= destroy_speed:
		damage = current_health          # one-shot kill
	elif impact_speed >= push_speed:
		damage = impact_speed * 0.08     # medium hit
	else:
		damage = impact_speed * 0.03     # weak hit
	
	_apply_damage(damage)
	
	# Still apply push force if it wasn't destroyed
	if current_health > 0 and impact_speed >= push_speed:
		var direction = arrow_velocity.normalized()
		var force = direction * impact_speed * push_force_multiplier
		apply_central_impulse(force)
		
		if arrow != null:
			arrow.linear_velocity *= 0.55
	elif arrow != null:
		arrow.linear_velocity *= 0.85

# Called by bomb arrow explosion
func take_explosion_damage(amount: float) -> void:
	_apply_damage(amount)

func _apply_damage(amount: float) -> void:
	if current_health <= 0:
		return
	
	current_health -= amount
	current_health = max(current_health, 0.0)
	
	# Optional: change sprite / flash when damaged
	# update_sprite()
	
	if current_health <= 0:
		destroy_block()

# Optional helper if you later add damaged frames
func update_sprite() -> void:
	# Example:
	# if current_health < max_health * 0.3:
	#     anim.play("damaged")
	pass

func destroy_block() -> void:
	if not is_instance_valid(self):
		return

	# Clean up stuck arrows
	for arrow in get_tree().get_nodes_in_group("arrow"):
		if is_instance_valid(arrow) and arrow.get("stuck_to") == self:
			arrow.queue_free()

	var explosion_area = get_node_or_null("Area2D")
	var bodies: Array = []

	if explosion_area:
		explosion_area.monitoring = true
		bodies = explosion_area.get_overlapping_bodies()

	if bodies.is_empty():
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsShapeQueryParameters2D.new()
		var shape = CircleShape2D.new()
		shape.radius = explosion_radius
		query.shape = shape
		query.transform = global_transform
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.collision_mask = 0xFFFFFFFF
		query.exclude = [self.get_rid()]

		var results = space_state.intersect_shape(query, 32)

		for result in results:
			bodies.append(result.collider)

	# --- Apply effects ---
	for body in bodies:
		if body == self or not is_instance_valid(body):
			continue

		var direction = (body.global_position - global_position).normalized()
		var distance = global_position.distance_to(body.global_position)
		var falloff = 1.0 - clamp(distance / explosion_radius, 0.0, 1.0)

		if falloff <= 0.05:
			continue

		# PUSH
		if body is RigidBody2D:
			body.sleeping = false
			body.freeze = false
			body.apply_central_impulse(direction * explosion_force * falloff)

		# DAMAGE
		var explosion_damage = 750.0

		if body is TNTBlock:
			body.call_deferred("destroy_block")
		elif body.has_method("take_explosion_damage"):
			body.take_explosion_damage(explosion_damage * falloff)
		elif body.has_method("_apply_damage"):
			body._apply_damage(explosion_damage * falloff)
		elif body.get("current_health") != null:
			body.current_health -= explosion_damage * falloff
			body.current_health = max(body.current_health, 0.0)

			if body.has_method("update_sprite"):
				body.update_sprite()

			if body.current_health <= 0.0:
				if body.has_method("destroy_block"):
					body.call_deferred("destroy_block")
				else:
					body.queue_free()

	# Play animation and remove
	anim.play("explode")
	ScoreManager.add_score(10)
	await anim.animation_finished
	queue_free()
