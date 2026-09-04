extends CharacterBody2D
class_name Ghost2

@export var gravity: float = 980.0
@export var score_value: int = 50

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_dead: bool = false


func _ready() -> void:
	if sprite:
		sprite.play("idle")

	ScoreManager.register_enemy()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	move_and_slide()


func take_hit(
	_arrow_velocity: Vector2 = Vector2.ZERO,
	_arrow: RigidBody2D = null
) -> void:
	if is_dead:
		return

	die()


func die() -> void:
	if is_dead:
		return

	is_dead = true

	velocity = Vector2.ZERO
	set_physics_process(false)

	var collision := get_node_or_null("CollisionShape2D")
	if collision:
		collision.set_deferred("disabled", true)

	var detection := get_node_or_null("DetectionArea")
	if detection:
		detection.set_deferred("monitoring", false)
		detection.set_deferred("monitorable", false)

	ScoreManager.add_score(score_value)
	ScoreManager.enemy_killed()

	queue_free()
