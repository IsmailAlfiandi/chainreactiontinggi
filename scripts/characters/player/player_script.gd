extends CharacterBody2D
# === Movement ===
@export var speed: float = 220.0
@export var acceleration: float = 1800.0
@export var friction: float = 1600.0
@export var can_move: bool = true
@export var gravity: float = 980.0

# === Bow / Shooting ===
@export var max_power: float = 1900.0
@export var min_power: float = 300.0
@export var power_multiplier: float = 11.0
@export var can_shoot: bool = true
@export var arrow_type: int = 1
@export var bomb_cooldown: float = 1.8          # seconds you must wait after exploding a bomb
var bomb_ready_time: float = 0.0
var current_arrow: BombArrow = null
var block_shoot_until: float = 0.0

@onready var move_state: Sprite2D = $State/moveState
@onready var aim_state: Sprite2D = $State/aimState
@onready var bow_pivot: Node2D = $State
@onready var arrow_spawn: Marker2D = $State/bulletSpawn
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var aim_ui: Control = $AimUI

var arrow_scene = preload("res://resources/weapons/arrow/arrow.tscn")   # your projectile (RigidBody2D)
var arrowBomb_scene = preload("res://resources/weapons/arrow/arrowBomb.tscn")

# States
enum State { MOVE, AIMING }
var state: State = State.MOVE

var current_power: float = 0.0
var aim_direction: Vector2 = Vector2.RIGHT
var is_facing_right: bool = true

func _ready():
	add_to_group("player")

func _physics_process(delta: float):
	if not is_on_floor():
		velocity.y += gravity * delta
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
	var arrowone = Input.is_action_just_pressed("one")
	var arrowtwo = Input.is_action_just_pressed("two")
	if arrowone:
		arrow_type = 1
		
	if arrowtwo:
		arrow_type = 2

	if can_move:
		if direction != 0:
			velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
			is_facing_right = direction > 0
		else:
			velocity.x = move_toward(velocity.x, 0, friction * delta)
	
	# Flip body
	animated_sprite.flip_h = not is_facing_right
	
	# === Fix bow position in MOVE state ===
	bow_pivot.scale.x = 1
	bow_pivot.rotation = 0.0
	
	if is_facing_right:
		bow_pivot.position.x = abs(bow_pivot.position.x)
	else:
		bow_pivot.position.x = -abs(bow_pivot.position.x)

func handle_aim_input():
	if Time.get_ticks_msec() < block_shoot_until:
		return

	# Extra check: if trying to shoot bomb type while on cooldown → block
	if arrow_type == 2 and Time.get_ticks_msec() < bomb_ready_time:
		return

	if Input.is_action_just_pressed("shoot") and can_shoot and current_arrow == null:
		enter_aiming()

func enter_aiming():
	state = State.AIMING
	current_power = min_power

func handle_aiming(delta: float):
	var mouse_pos = get_global_mouse_position()
	aim_direction = (mouse_pos - global_position).normalized()
	
	# Decide facing
	if aim_direction.x > 0.05:
		is_facing_right = true
	elif aim_direction.x < -0.05:
		is_facing_right = false
	
	# Flip only the body
	animated_sprite.flip_h = not is_facing_right
	
	# Keep bow on the right side of the character (never move it to negative X)
	bow_pivot.position.x = abs(bow_pivot.position.x)
	bow_pivot.scale.x = 1          # important: never scale the bow
	
	# Rotate the bow
	if is_facing_right:
		bow_pivot.rotation = aim_direction.angle()
	else:
		# When facing left, we mirror the angle
		bow_pivot.rotation = aim_direction.angle() + PI
	
	# Power
	var distance = global_position.distance_to(mouse_pos)
	current_power = clamp(distance * power_multiplier, min_power, max_power)
	
	aim_ui.show_aim(current_power, aim_direction.angle(), max_power)
	
	# Cancel
	if Input.is_action_just_pressed("right_click"):
		state = State.MOVE
		bow_pivot.rotation = 0.0
		aim_ui.hide_aim()
	
	# Shoot
	if Input.is_action_just_pressed("shoot") and can_shoot and current_arrow == null:
		if arrow_type == 2 and Time.get_ticks_msec() < bomb_ready_time:
			return
		if Time.get_ticks_msec() < block_shoot_until:
			return
		can_shoot = false
		can_move = false
		shoot()
		state = State.MOVE
		bow_pivot.rotation = 0.0
		aim_ui.hide_aim()

func shoot():
	var arrow: RigidBody2D = null
	var power = current_power
	
	if arrow_type == 1:
		arrow = arrow_scene.instantiate()
	elif arrow_type == 2:
		arrow = arrowBomb_scene.instantiate()
		current_arrow = arrow as BombArrow
	
	if arrow == null:
		return
	
	get_tree().current_scene.add_child(arrow)
	
	arrow.global_position = arrow_spawn.global_position
	arrow.rotation = aim_direction.angle()
	
	# Apply the power we saved earlier
	arrow.apply_central_impulse(aim_direction * power)
	arrow.apply_torque_impulse(randf_range(-30, 30))
	
	# Camera follow
	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		camera.follow(arrow)
		arrow.tree_exited.connect(func():
			camera.follow(self)
			if current_arrow == arrow:
				current_arrow = null
		)
	
	arrow.tree_exited.connect(func():
		camera.follow(self)
		if current_arrow == arrow:
			current_arrow = null
		after_hit()
	)
	
	# Reset after shooting
	current_power = 0.0
	bow_pivot.rotation = 0.0
	
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
	can_shoot = true

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot") and current_arrow != null and is_instance_valid(current_arrow):
		current_arrow.explode()
		current_arrow = null

		# Start bomb cooldown
		bomb_ready_time = Time.get_ticks_msec() + (bomb_cooldown * 1000.0)

		# Small block so it doesn't immediately start aiming again
		block_shoot_until = Time.get_ticks_msec() + 150

		get_viewport().set_input_as_handled()
		
func _on_button_pressed() -> void:
	arrow_type = 1

func _on_button_2_pressed() -> void:
	arrow_type = 2
