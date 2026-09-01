extends RigidBody2D
class_name TNTBlock

enum MaterialType { WOOD, STONE, STEEL, TNT }

@export var material_type: MaterialType = MaterialType.TNT
@export var push_speed: float = 300.0
@export var destroy_speed: float = 700.0
@export var explosion_force: float = 800.0
@export var explosion_radius: float = 150.0
@export var push_force_multiplier: float = 1.0
@onready var anim = $AnimatedSprite2D

func _ready() -> void:
	anim.play("idle")
	match material_type:
		MaterialType.WOOD:
			mass = 2.0
			push_speed = 280.0
			destroy_speed = 750.0
			push_force_multiplier = 1.0
		MaterialType.STONE:
			mass = 6.0
			push_speed = 450.0
			destroy_speed = 900.0
			push_force_multiplier = 1.0
		MaterialType.STEEL:
			mass = 12.0
			push_speed = 700.0
			destroy_speed = 1300.0
			push_force_multiplier = 0.7
		MaterialType.TNT:
			mass = 3.0
			push_speed = 50.0
			destroy_speed = 80.0      # very easy to explode
			push_force_multiplier = 0.5

	contact_monitor = true
	max_contacts_reported = 4

func take_hit(arrow_velocity: Vector2, arrow: RigidBody2D = null) -> void:
	var impact_speed = arrow_velocity.length()
	
	if impact_speed >= destroy_speed:
		destroy_block()
	elif impact_speed >= push_speed:
		var direction = arrow_velocity.normalized()
		var force = direction * impact_speed * push_force_multiplier
		apply_central_impulse(force)
		
		if arrow != null:
			arrow.linear_velocity *= 0.55
	else:
		if arrow != null:
			arrow.linear_velocity *= 0.85

func destroy_block() -> void:
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
		var body = result.collider
		if body == self:
			continue
		
		# Wake up the body
		if body is RigidBody2D:
			body.sleeping = false
			body.freeze = false
		
		# Apply strong force
		if body is RigidBody2D:
			var direction = (body.global_position - global_position).normalized()
			var distance = global_position.distance_to(body.global_position)
			
			var force_strength = explosion_force * (1.0 - clamp(distance / explosion_radius, 0.0, 1.0))
			force_strength = max(force_strength, explosion_force * 0.4)
			
			body.apply_central_impulse(direction * force_strength * 4.0)  # stronger
		
		# Destroy other blocks safely
		if body is TNTBlock:
			# Call destroy directly (safer than take_hit with null)
			body.destroy_block()
		elif body.has_method("destroy_block"):
			body.destroy_block()
	
	# Optional: spawn explosion effect here
	anim.play("explode")
	await anim.animation_finished

	queue_free()
