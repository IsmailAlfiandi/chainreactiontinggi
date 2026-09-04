extends RigidBody2D
class_name StoneBlock

enum MaterialType { WOOD, STONE, STEEL, GLASS, TNT }

@export var material_type: MaterialType = MaterialType.STONE
@export var push_speed: float = 450.0
@export var destroy_speed: float = 900.0
@export var push_force_multiplier: float = 1.0

@export var max_health: float = 350.0
var current_health: float

@export var damage_multiplier: float = 0.05

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
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

func take_hit(
	arrow_velocity: Vector2,
	arrow: RigidBody2D = null
) -> bool:

	if current_health <= 0.0:
		return true

	var impact_speed: float = arrow_velocity.length()

	print("Impact speed: ", impact_speed)

	var damage: float = 0.0

	if impact_speed > 25.0:
		damage = 8.0 + (
			impact_speed * damage_multiplier
		)

		if impact_speed > destroy_speed * 0.7:
			damage *= 1.4

	_apply_damage(damage)

	if current_health > 0.0 and impact_speed >= push_speed:
		var direction: Vector2 = arrow_velocity.normalized()

		var force: Vector2 = (
			direction
			* impact_speed
			* push_force_multiplier
		)

		apply_central_impulse(force)

	print("Block HP: ", current_health)

	if current_health <= 0.0:
		return true

	return false

func take_explosion_damage(amount: float) -> void:
	if current_health <= 0.0:
		return
	_apply_damage(amount)

func _apply_damage(amount: float) -> void:
	if current_health <= 0.0:
		return

	current_health -= amount

	current_health = maxf(
		current_health,
		0.0
	)

	update_sprite()

	print(
		name,
		" HP: ",
		current_health
	)

	if current_health <= 0.0:
		destroy_block()

func update_sprite() -> void:
	if not anim:
		return

	var health_percent: float = (
		current_health / max_health
	)

	if health_percent > 0.6:
		anim.play("fullHealth")

	elif health_percent > 0.3:
		anim.play("halfHealth")

	else:
		anim.play("criticalHealth")

func destroy_block() -> void:
	if not is_instance_valid(self):
		return

	# Release arrows stuck in this block
	for arrow in get_tree().get_nodes_in_group("arrow"):
		if not is_instance_valid(arrow):
			continue

		if arrow.get("stuck_to") == self:
			if arrow.has_method("release_from_target"):
				arrow.release_from_target()

	ScoreManager.add_score(10)

	queue_free()
