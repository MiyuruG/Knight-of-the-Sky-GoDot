extends CharacterBody2D

# Core stats
@export var max_health: int = 80
@export var move_speed: float = 120.0
@export var attack_damage: int = 15

# Territory settings
@export var territory_radius: float = 150.0  # How big is this enemy's territory
@export var attack_range: float = 30.0      # How close to get to attack intruder
@export var patrol_radius: float = 40.0     # How far from home position while patrolling

# Audio nodes
@onready var attack_sound: AudioStreamPlayer = $sfx_enemy_attack
@onready var hurt_sound: AudioStreamPlayer = $sfx_enemy_hurt  
@onready var death_sound: AudioStreamPlayer = $efx_enemy_die
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# State variables
var current_health: int
var player_ref: Node = null
var is_dead: bool = false
var can_attack: bool = true
var attack_cooldown: float = 2.0

# Territory variables
var home_position: Vector2
var patrol_target: Vector2
var is_defending: bool = false

# Hit and run behavior
var retreat_timer: float = 0.0
var is_retreating: bool = false
var retreat_position: Vector2

func _ready():
	current_health = max_health
	add_to_group("enemies")
	
	# Set home base
	home_position = global_position
	patrol_target = home_position
	
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")

func _physics_process(delta):
	if is_dead:
		return
	
	# Update attack cooldown
	if not can_attack:
		attack_cooldown -= delta
		if attack_cooldown <= 0:
			can_attack = true
			attack_cooldown = 2.0
	
	# Update retreat behavior
	if is_retreating:
		retreat_timer -= delta
		if retreat_timer <= 0:
			is_retreating = false
	
	find_player()
	territorial_behavior(delta)
	move_and_slide()

func find_player():
	if not player_ref or not is_instance_valid(player_ref):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0]

func territorial_behavior(delta):
	if not player_ref or not is_instance_valid(player_ref):
		patrol_territory()
		return
	
	if player_ref.has_method("is_player_dead") and player_ref.is_player_dead():
		patrol_territory()
		return
	
	var distance_to_player = global_position.distance_to(player_ref.global_position)
	var player_distance_from_home = home_position.distance_to(player_ref.global_position)
	
	# PLAYER INVADED TERRITORY - DEFEND!
	if player_distance_from_home <= territory_radius:
		is_defending = true
		defend_territory(distance_to_player)
	else:
		# Player left territory - return to patrol
		if is_defending:
			print("Intruder has left the territory!")
			is_defending = false
		patrol_territory()

func defend_territory(distance_to_player: float):
	print("DEFENDING TERRITORY! Player distance: ", distance_to_player)
	
	# Random retreat after attacking
	if randf() < 0.3 and can_attack and distance_to_player < 50:
		start_retreat()
		return
	
	# Currently retreating - move away from player
	if is_retreating:
		retreat_from_player()
		return
	
	# Close enough to attack the intruder
	if distance_to_player <= attack_range and can_attack:
		attack_intruder()
		return
	
	# Chase the intruder aggressively
	var direction = (player_ref.global_position - global_position).normalized()
	velocity = direction * move_speed * 1.5  # Faster when defending
	
	# Face the intruder
	if sprite:
		sprite.flip_h = direction.x < 0
	
	play_animation("fly")

func patrol_territory():
	var distance_to_patrol_target = global_position.distance_to(patrol_target)
	
	# Reached patrol point - pick new one
	if distance_to_patrol_target < 20.0:
		pick_new_patrol_point()
	
	# Move toward patrol target slowly
	var direction = (patrol_target - global_position).normalized()
	velocity = direction * (move_speed * 0.6)  # Slower patrol
	
	# Face movement direction
	if sprite:
		sprite.flip_h = direction.x < 0
	
	play_animation("idle")

func pick_new_patrol_point():
	# Pick random point within patrol radius of home
	var angle = randf() * TAU
	var distance = randf() * patrol_radius
	patrol_target = home_position + Vector2(cos(angle), sin(angle)) * distance

func attack_intruder():
	can_attack = false
	velocity = Vector2.ZERO  # Stop to attack
	
	print("ATTACKING INTRUDER!")
	
	# Play attack animation and sound
	play_animation("attack")
	if attack_sound:
		attack_sound.play()
	
	# Deal damage to the trespasser
	if player_ref.has_method("take_damage_from_enemy"):
		player_ref.take_damage_from_enemy(attack_damage, self)
	elif player_ref.has_method("take_damage"):
		player_ref.take_damage(attack_damage)
	
	# Random chance to retreat after attacking for hit-and-run feel
	if randf() < 0.4:
		start_retreat()

func start_retreat():
	is_retreating = true
	retreat_timer = randf_range(0.8, 1.5)  # Random retreat time
	
	# Calculate retreat position - away from player
	var direction_away = (global_position - player_ref.global_position).normalized()
	retreat_position = global_position + direction_away * randf_range(60, 100)
	
	print("Retreating for ", retreat_timer, " seconds!")

func retreat_from_player():
	# Move to retreat position
	var direction = (retreat_position - global_position).normalized()
	velocity = direction * move_speed * 1.8  # Fast retreat
	
	# Face retreat direction
	if sprite:
		sprite.flip_h = direction.x < 0
	
	play_animation("fly")

func play_animation(anim_name: String):
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)

func take_damage(damage: int):
	if is_dead:
		return
	
	current_health -= damage
	
	if hurt_sound:
		hurt_sound.play()
	
	# Flash red
	if sprite:
		var original_color = sprite.modulate
		sprite.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", original_color, 0.2)
	
	play_animation("hurt")
	
	# Getting hurt makes it more aggressive
	is_defending = true
	
	if current_health <= 0:
		die()

func die():
	if is_dead:
		return
	
	is_dead = true
	velocity = Vector2.ZERO
	
	print("Territory guardian defeated!")
	
	if death_sound:
		death_sound.play()
	
	play_animation("death")
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
	await tween.finished
	queue_free()

func get_health_ratio() -> float:
	return float(current_health) / float(max_health)

# Debug - show territory in editor
func _draw():
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, territory_radius, Color.RED, false, 2.0)
		draw_circle(Vector2.ZERO, patrol_radius, Color.YELLOW, false, 1.0)
