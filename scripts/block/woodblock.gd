extends RigidBody2D
class_name WoodBlock

enum MaterialType { WOOD, STONE, STEEL, GLASS, TNT }

@export var material_type: MaterialType = MaterialType.WOOD
@export var push_speed: float = 300.0
@export var destroy_speed: float = 700.0
@export var push_force_multiplier: float = 1.0

# --- Health System ---
@export var max_health: float = 100.0
var current_health: float

# Damage scaling (how much health is removed based on impact speed)
@export var damage_multiplier: float = 0.05   # tweak this value
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	match material_type:
		MaterialType.GLASS:
			mass = 2.0
			push_speed = 100.0
			destroy_speed = 250.0
			push_force_multiplier = 1.0
			max_health = 50.0
			damage_multiplier = 0.18
		MaterialType.WOOD:
			mass = 2.0
			push_speed = 280.0
			destroy_speed = 750.0
			push_force_multiplier = 1.0
			max_health = 200.0
			damage_multiplier = 0.18
		MaterialType.STONE:
			mass = 6.0
			push_speed = 450.0
			destroy_speed = 900.0
			push_force_multiplier = 1.0
			max_health = 350.0
			damage_multiplier = 0.12
		MaterialType.STEEL:
			mass = 12.0
			push_speed = 700.0
			destroy_speed = 1300.0
			push_force_multiplier = 0.7
			max_health = 500.0
			damage_multiplier = 0.08

	current_health = max_health
	contact_monitor = true
	max_contacts_reported = 4

	update_sprite()


func take_hit(arrow_velocity: Vector2, arrow: RigidBody2D) -> bool:
	var impact_speed = arrow_velocity.length()
	print("Impact speed: ", impact_speed)

	# Damage
	var damage := 0.0

	if impact_speed > 25.0:
		damage = 8.0 + (impact_speed * damage_multiplier)

		if impact_speed > destroy_speed * 0.7:
			damage *= 1.4

	current_health -= damage
	current_health = max(current_health, 0.0)

	print("Block HP: ", current_health)

	update_sprite()

	# Push force
	if impact_speed >= push_speed:
		var direction : Vector2 = arrow_velocity.normalized()
		var force : Vector2 = direction * impact_speed * push_force_multiplier
		apply_central_impulse(force)

	# Block destroyed
	if current_health <= 0:
		destroy_block()
		return true

	# Block survived
	return false

func update_sprite() -> void:
	if not anim:
		return

	var health_percent = current_health / max_health

	if health_percent > 0.6:
			anim.play("fullHealth")
	elif health_percent > 0.3:
			anim.play("halfHealth")
	else:
			anim.play("criticalHealth")


func destroy_block() -> void:
	# Release arrows stuck in this block
	for arrow in get_tree().get_nodes_in_group("arrow"):
		if is_instance_valid(arrow):
			if arrow.get("stuck_to") == self:
				arrow.release_from_target()

	ScoreManager.add_score(10)
	queue_free()
