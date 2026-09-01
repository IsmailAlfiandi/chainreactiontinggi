extends RigidBody2D
class_name Block

enum MaterialType { WOOD, STONE, STEEL }
@export var material_type: MaterialType = MaterialType.WOOD
@export var push_speed: float = 300.0
@export var destroy_speed: float = 700.0

@export var push_force_multiplier: float = 1.0

# Different Material per Block
func _ready():
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

	contact_monitor = true
	max_contacts_reported = 4

# If hit by the arrow
func take_hit(arrow_velocity: Vector2, arrow: RigidBody2D) -> void:
	var impact_speed = arrow_velocity.length()
	
	print("Impact speed: ", impact_speed)
	if impact_speed >= destroy_speed:
		destroy_block()
	elif impact_speed >= push_speed:
		var direction = arrow_velocity.normalized()
		var force = direction * impact_speed * push_force_multiplier
		apply_central_impulse(force)
		
		# Slow down the arrow when hitting the block
		arrow.linear_velocity *= 0.6
	else:
		pass

func destroy_block() -> void:
	# Play particles / sound here if you want
	# Example:
	# $DestroyParticles.emitting = true
	# $DestroySound.play()
	
	queue_free()
