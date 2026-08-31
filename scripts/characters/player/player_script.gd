extends CharacterBody2D
# === Movement ===
@export var speed: float = 220.0
@export var acceleration: float = 1800.0
@export var friction: float = 1600.0
@export var can_move: bool = true

# === Bow / Shooting ===
@export var max_power: float = 1400.0
@export var min_power: float = 300.0
@export var power_multiplier: float = 11.0

@onready var move_state: Sprite2D = $Weapon/spriteMove
@onready var aim_state: Sprite2D = $Weapon/spriteAim
@onready var bow_pivot: Node2D = $Weapon
@onready var arrow_spawn: Marker2D = $Weapon/BulletSpawn
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var arrow_scene = preload("res://resources/weapons/arrow/arrow.tscn")   # your projectile (RigidBody2D)

# States
enum State { MOVE, AIMING }
var state: State = State.MOVE

var current_power: float = 0.0
var aim_direction: Vector2 = Vector2.RIGHT
var is_facing_right: bool = true

func _ready():
	add_to_group("player")

func _physics_process(delta: float):
	match state:
		State.MOVE:
			handle_movement(delta)
			handle_aim_input()
		State.AIMING:
			handle_aiming(delta)
			velocity.x = move_toward(velocity.x, 0, friction * delta)

	move_and_slide()
	update_animation()

func handle_movement(delta: float):
	var direction = Input.get_axis("move_left", "move_right")
	if direction != 0 and can_move:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
		is_facing_right = direction > 0
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	animated_sprite.flip_h = not is_facing_right
	bow_pivot.scale.x = 1 if is_facing_right else -1

func handle_aim_input():
	if Input.is_action_just_pressed("shoot"):  # bind this to mouse left or space
		enter_aiming()

func enter_aiming():
	state = State.AIMING
	current_power = min_power

func handle_aiming(delta: float):
	can_move = false
	var mouse_pos = get_global_mouse_position()
	aim_direction = (mouse_pos - bow_pivot.global_position).normalized()
	
	bow_pivot.rotation = aim_direction.angle()
	
	var distance = bow_pivot.global_position.distance_to(mouse_pos)
	current_power = clamp(distance * power_multiplier, min_power, max_power)
	
	# Release to shoot
	if Input.is_action_just_pressed("shoot"):
		shoot()
		can_move = false
		state = State.MOVE

func shoot():
	var arrow = arrow_scene.instantiate()
	get_tree().current_scene.add_child(arrow)
	
	arrow.global_position = arrow_spawn.global_position
	arrow.rotation = aim_direction.angle()
	
	# Apply power as impulse
	arrow.apply_central_impulse(aim_direction * current_power)
	
	# Optional: small torque for realism
	arrow.apply_torque_impulse(randf_range(-30, 30))
	
	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		camera.follow(arrow)

	current_power = 0.0
	bow_pivot.rotation = 0.0
	can_move = true
	
func update_animation():
	match state:
		State.MOVE:
			move_state.visible = true
			aim_state.visible = false
			
			# Optional: flip the move sprite
			move_state.flip_h = not is_facing_right
			
		State.AIMING:
			move_state.visible = false
			aim_state.visible = true
			
			# Optional: flip the aim sprite too
			aim_state.flip_h = not is_facing_right
			
func after_hit():
	can_move = true
