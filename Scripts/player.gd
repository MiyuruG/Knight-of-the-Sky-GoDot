extends CharacterBody2D

const SPEED = 100
const GRAVITY = 1250
const JUMP_FORCE = -300

@onready var sprite = $AnimatedSprite2D
@onready var jump_sfx = $"../sfx_jump"
@onready var run_sfx = $"../sfx_run"

var is_attacking = false
@export var attack_damage := 25
@export var attack_range := 50.0

func _ready():
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	print("Connected animation_finished and frame_changed signals")

func take_damage(amount):
	print("Player took", amount, "damage")
	# Subtract health here if needed

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		if not is_attacking:
			velocity.y = 0

	# Movement input
	var direction = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	velocity.x = direction * SPEED

	# Jumping
	if not is_attacking and is_on_floor() and Input.is_action_just_pressed("ui_accept"):
		velocity.y = JUMP_FORCE
		jump_sfx.play()

	# Attacking
	if not is_attacking and Input.is_action_just_pressed("attack"):
		is_attacking = true
		velocity.x = 0
		play_animation("attack")
		return

	move_and_slide()

	# Animation logic
	if is_attacking:
		return

	if not is_on_floor():
		play_animation("jump")
	elif direction != 0:
		sprite.flip_h = direction < 0
		play_animation("run")
		run_sfx.play()
	else:
		play_animation("idle")

func play_animation(anim: String):
	if sprite.animation != anim:
		sprite.play(anim)

func _on_animation_finished():
	if sprite.animation == "attack":
		is_attacking = false
		print("Attack finished")

func _on_frame_changed():
	if sprite.animation == "attack" and sprite.frame == 3:  # adjust frame as needed
		check_for_attack_hit()

func check_for_attack_hit():
	var space_state = get_world_2d().direct_space_state

	var direction: Vector2
	if not sprite.flip_h:
		direction = Vector2.RIGHT
	else:
		direction = Vector2.LEFT

	var attack_box_size = Vector2(attack_range, 20)
	var attack_pos = global_position + direction * (attack_range * 0.5)

	var shape = RectangleShape2D.new()
	shape.extents = attack_box_size / 2.0

	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, attack_pos)
	query.collision_mask = 1
	query.exclude = [self]

	var results = space_state.intersect_shape(query, 8)

	for result in results:
		var enemy = result.get("collider")
		if enemy and enemy.is_in_group("enemies"):
			print("Hit enemy:", enemy.name)
			enemy.take_damage(attack_damage)
