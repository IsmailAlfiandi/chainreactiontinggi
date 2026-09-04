extends CharacterBody2D
class_name Ghost

enum State { IDLE, WALK }
var current_state: State = State.WALK

@export var move_speed: float = 85.0
@export var idle_time: float = 2.5
@export var gravity: float = 980.0
@export var score_value: float = 50.0

var idle_timer: float = 0.0
var direction: Vector2 = Vector2.RIGHT

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready():
	change_state(State.WALK)
	ScoreManager.register_enemy()

func _physics_process(delta: float):
	if not is_on_floor():
		velocity.y += gravity * delta
	match current_state:
		State.IDLE:
			state_idle(delta)
		State.WALK:
			state_walk(delta)


func change_state(new_state: State) -> void:
	current_state = new_state
	
	match current_state:
		State.IDLE:
			idle_timer = idle_time
			velocity = Vector2.ZERO
			if sprite:
				sprite.play("idle")
		
		State.WALK:
			if sprite:
				sprite.play("walk")


func state_idle(delta: float) -> void:
	idle_timer -= delta
	if idle_timer <= 0:
		change_state(State.WALK)
		direction = -direction


func state_walk(delta: float) -> void:
	velocity = direction * move_speed
	move_and_slide()
	
	if direction.x != 0 and sprite:
		sprite.flip_h = direction.x < 0

var is_dead := false

func take_hit(_arrow_velocity: Vector2 = Vector2.ZERO, _arrow: RigidBody2D = null) -> void:
	if is_dead:
		return
	
	is_dead = true
	die()


func die() -> void:
	# Stop moving
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	# Optional: disable collision so arrow doesn't get stuck
	$CollisionShape2D.set_deferred("disabled", true)
	if has_node("DetectionArea"):
		$DetectionArea.set_deferred("monitoring", false)
		$DetectionArea.set_deferred("monitorable", false)
	
	ScoreManager.add_score(score_value)
	ScoreManager.enemy_killed()
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if current_state == State.WALK and area.is_in_group("idle_point"):
		change_state(State.IDLE)
