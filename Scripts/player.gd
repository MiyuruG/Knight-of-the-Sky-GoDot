extends CharacterBody2D

const SPEED = 100
const GRAVITY = 1250
const JUMP_FORCE = -300

@onready var sprite = $AnimatedSprite2D
@onready var jump_sfx = $"../sfx_jump"
@onready var run_sfx = $"../sfx_run"

var is_attacking = false

func _ready():
	sprite.animation_finished.connect(_on_animation_finished)
	print("Connected animation_finished signal")
func take_damage(amount):
	print("Player took", amount, "damage")
	# You can subtract health here, play effects, etc.



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
	# Attack start
	if not is_attacking and Input.is_action_just_pressed("attack"):
		is_attacking = true
		velocity.x = 0  # optional: freeze horizontal movement during attack
		play_animation("attack")
		return  # skip rest of animation logic while attacking

	move_and_slide()

	# Animation logic (skip if attacking)
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
	# When attack animation finishes, allow movement and normal animations again
	print("Animation finished:", sprite.animation)
	if sprite.animation == "attack":
		is_attacking = false
