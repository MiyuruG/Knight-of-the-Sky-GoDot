extends CharacterBody2D

# Dragon Enemy - FLYING, HUNTS PLAYER
@export var health: int = 80
@export var fly_speed: float = 120.0
@export var dive_speed: float = 220.0
@export var attack_damage: int = 35
@export var detection_range: float = 350.0
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.5

# Components
@onready var sprite = $AnimatedSprite2D
@onready var attack_sound = $sfx_enemy_attack
@onready var hurt_sound = $sfx_enemy_hurt
@onready var die_sound = $efx_enemy_die

# State
var player: Node
var is_dead = false
var can_attack = true
var attack_timer = 0.0
var patrol_direction: Vector2 = Vector2(1, 0).rotated(randf() * TAU)

func _ready():
	add_to_group("enemies")
	if sprite and sprite.sprite_frames:
		if sprite.sprite_frames.has_animation("fly"):
			sprite.play("fly")
		elif sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")

func _physics_process(delta):
	if is_dead:
		return

	# Attack cooldown
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

	find_player()

	if player and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)

		if distance <= detection_range:
			# CHASE / ATTACK
			chase_and_attack(delta)
		else:
			# Patrol flying when player not in range
			patrol(delta)
	else:
		# No player -> just fly around
		patrol(delta)

	move_and_slide()

func find_player():
	if not player or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]

func patrol(delta):
	# Simple random flying (patrol around)
	velocity = patrol_direction * fly_speed

	# Occasionally change direction
	if randf() < 0.01:
		patrol_direction = Vector2.RIGHT.rotated(randf() * TAU)

	# Flip sprite based on movement
	if sprite:
		sprite.flip_h = velocity.x < 0

func chase_and_attack(delta):
	if not player:
		return

	var player_pos = player.global_position
	var direction = (player_pos - global_position).normalized()
	var distance = global_position.distance_to(player_pos)

	# If close enough -> attack
	if distance <= attack_range and can_attack:
		attack()
		velocity = Vector2.ZERO
	else:
		# Fly directly toward player (dive chase)
		velocity = direction * dive_speed

	# Flip sprite based on movement
	if sprite:
		sprite.flip_h = velocity.x < 0

func attack():
	can_attack = false
	attack_timer = attack_cooldown

	print("🐉 Dragon attacks the player!")

	# Animation
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
		sprite.play("attack")

	# Sound
	if attack_sound:
		attack_sound.play()

	# Damage player
	if player:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)
		elif player.has_method("take_damage_from_enemy"):
			player.take_damage_from_enemy(attack_damage, self)

func take_damage(damage: int):
	if is_dead:
		return

	health -= damage
	print("Dragon took ", damage, " damage. Health: ", health)

	if hurt_sound:
		hurt_sound.play()

	# Flash red
	if sprite:
		var original = sprite.modulate
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		if sprite and is_instance_valid(self):
			sprite.modulate = original

	if health <= 0:
		die()

func die():
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO

	print("Dragon died!")

	if die_sound:
		die_sound.play()

	if sprite:
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
			sprite.play("death")
			await sprite.animation_finished
		else:
			var tween = create_tween()
			tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
			await tween.finished

	queue_free()
