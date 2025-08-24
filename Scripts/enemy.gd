extends CharacterBody2D

# Enemy stats (updated values)
@export var health: int = 100
@export var speed: float = 120.0
@export var attack_damage: int = 10
@export var attack_range: float = 60.0
@export var detection_range: float = 200.0

# Enemy flight behavior
@export var hover_distance: float = 80.0  # How close to get to player
@export var attack_cooldown: float = 2.0
@export var hurt_retreat_time: float = 1.0
@export var horizontal_range: float = 150.0  # How far to fly horizontally
@export var fly_height_offset: float = -50.0  # Height above player

# Audio
@onready var sfx_enemy_attack: AudioStreamPlayer = $sfx_enemy_attack
@onready var sfx_enemy_hurt: AudioStreamPlayer = $sfx_enemy_hurt
@onready var efx_enemy_die: AudioStreamPlayer = $efx_enemy_die

@onready var animated_sprite = $AnimatedSprite2D
var can_attack: bool = true
var is_dead: bool = false
var player: Node = null
var state: String = "patrol"
var attack_timer: float = 0.0
var hurt_timer: float = 0.0
var is_hurt_retreating: bool = false

# Enemy positioning and horizontal flight
var target_position: Vector2
var horizontal_direction: int = 1  # 1 for right, -1 for left
var is_flying_horizontal: bool = false
var horizontal_start_pos: Vector2

func _ready():
	add_to_group("enemies")
	target_position = global_position
	
	if has_animation("fly"):
		animated_sprite.play("fly")
	elif has_animation("idle"):
		animated_sprite.play("idle")

func _physics_process(delta):
	if is_dead:
		return
		
	update_timers(delta)
	find_player()
	update_enemy_behavior(delta)
	apply_enemy_movement(delta)

func has_animation(anim_name: String) -> bool:
	if animated_sprite and animated_sprite.sprite_frames:
		return animated_sprite.sprite_frames.has_animation(anim_name)
	return false

func play_animation_safe(anim_name: String):
	if animated_sprite and has_animation(anim_name):
		animated_sprite.play(anim_name)

func update_timers(delta):
	if attack_timer > 0:
		attack_timer -= delta
	else:
		can_attack = true
		
	if hurt_timer > 0:
		hurt_timer -= delta
	else:
		is_hurt_retreating = false

func find_player():
	if not player or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]

func update_enemy_behavior(delta):
	if not player or not is_instance_valid(player):
		state = "patrol"
		patrol_behavior()
		return
	
	# Check if player is dead
	if player.has_method("is_player_dead") and player.is_player_dead():
		state = "patrol"
		patrol_behavior()
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# If hurt, retreat for a moment
	if is_hurt_retreating:
		hurt_retreat_behavior()
		return
	
	# Enemy behavior states
	match state:
		"patrol":
			if distance_to_player <= detection_range:
				state = "approach"
				print("Enemy spotted player!")
			else:
				patrol_behavior()
		
		"approach":
			if distance_to_player > detection_range * 1.3:
				state = "patrol"
			elif distance_to_player <= hover_distance:
				state = "horizontal_attack"
				setup_horizontal_flight()
			else:
				approach_player()
		
		"horizontal_attack":
			if distance_to_player > hover_distance * 2.0:
				state = "approach"
			else:
				horizontal_flight_attack()

func patrol_behavior():
	# Stay in place or gentle movement
	target_position = global_position
	velocity = velocity.move_toward(Vector2.ZERO, speed * 2.0 * get_physics_process_delta_time())
	
	if has_animation("fly"):
		play_animation_safe("fly")

func approach_player():
	if not player:
		return
	
	# Fly directly towards the player
	target_position = player.global_position
	
	# Face the player
	if animated_sprite:
		animated_sprite.flip_h = global_position.x > player.global_position.x
	
	play_animation_safe("fly")

func setup_horizontal_flight():
	if not player:
		return
	
	# Set up initial horizontal flight position
	var player_pos = player.global_position
	horizontal_start_pos = Vector2(player_pos.x - horizontal_range/2, player_pos.y + fly_height_offset)
	
	# Start flying from left to right or right to left randomly
	horizontal_direction = 1 if randf() > 0.5 else -1
	if horizontal_direction == 1:
		target_position = Vector2(player_pos.x - horizontal_range/2, player_pos.y + fly_height_offset)
	else:
		target_position = Vector2(player_pos.x + horizontal_range/2, player_pos.y + fly_height_offset)
	
	is_flying_horizontal = false

func horizontal_flight_attack():
	if not player:
		return
	
	var player_pos = player.global_position
	
	# Check if we've reached our target or need to turn around
	var distance_to_target = global_position.distance_to(target_position)
	
	if distance_to_target < 20.0 or not is_flying_horizontal:
		# Change direction and set new target
		horizontal_direction *= -1
		is_flying_horizontal = true
		
		if horizontal_direction == 1:
			# Flying right
			target_position = Vector2(player_pos.x + horizontal_range/2, player_pos.y + fly_height_offset)
		else:
			# Flying left
			target_position = Vector2(player_pos.x - horizontal_range/2, player_pos.y + fly_height_offset)
	
	# Face the direction we're flying
	if animated_sprite:
		animated_sprite.flip_h = horizontal_direction < 0
	
	# Attack if ready and close enough to player
	var distance_to_player = global_position.distance_to(player.global_position)
	if can_attack and distance_to_player <= attack_range:
		enemy_attack()
	else:
		play_animation_safe("fly")

func enemy_attack():
	if not player or not can_attack:
		return
		
	can_attack = false
	attack_timer = attack_cooldown
	
	print("Enemy attacks!")
	play_animation_safe("attack")
	
	if sfx_enemy_attack:
		sfx_enemy_attack.play()
	
	# Deal damage if close enough
	var distance = global_position.distance_to(player.global_position)
	if distance <= attack_range:
		if player.has_method("take_damage_from_enemy"):
			player.take_damage_from_enemy(attack_damage, self)
		elif player.has_method("take_damage"):
			player.take_damage(attack_damage)
		
		print("Enemy dealt ", attack_damage, " damage to player!")
	
	# Change direction occasionally for variety
	if randf() < 0.3:
		horizontal_direction *= -1

func hurt_retreat_behavior():
	if not player:
		return
	
	# Fly away from player quickly
	var direction_away = (global_position - player.global_position).normalized()
	target_position = global_position + direction_away * 120
	
	# Make sure it doesn't go too high or low
	target_position.y = clamp(target_position.y, player.global_position.y - 150, player.global_position.y + 50)

func apply_enemy_movement(delta):
	# Calculate movement toward target
	var direction = (target_position - global_position)
	var distance = direction.length()
	
	if distance > 8.0:
		direction = direction.normalized()
		
		# Different speeds for different behaviors
		var move_speed = speed
		if is_hurt_retreating:
			move_speed = speed * 1.5  # Faster retreat
		elif state == "approach":
			move_speed = speed * 1.2  # Faster approach
		elif state == "horizontal_attack":
			move_speed = speed * 0.8   # Slightly slower when flying horizontally
		
		velocity = direction * move_speed
	else:
		# Slow down when close to target
		velocity = velocity.move_toward(Vector2.ZERO, speed * delta * 4.0)
	
	# Keep enemy in reasonable bounds
	var min_y = -100
	var max_y = 600
	
	if global_position.y < min_y:
		velocity.y = max(0, velocity.y)
	elif global_position.y > max_y:
		velocity.y = min(-50, velocity.y)
	
	move_and_slide()

func take_damage(damage: int):
	if is_dead:
		return
		
	health -= damage
	print("Enemy took ", damage, " damage. Health: ", health)
	
	# Play hurt sound
	if sfx_enemy_hurt:
		sfx_enemy_hurt.play()
	
	# Start hurt retreat
	is_hurt_retreating = true
	hurt_timer = hurt_retreat_time
	state = "approach"  # Will return to approaching after retreat
	
	# Play hurt animation
	if has_animation("hurt"):
		play_animation_safe("hurt")
		await get_tree().create_timer(0.3).timeout
		if not is_dead and has_animation("fly"):
			play_animation_safe("fly")
	
	# Flash red
	flash_damage()
	
	if health <= 0:
		die()

func flash_damage():
	if animated_sprite:
		var original_modulate = animated_sprite.modulate
		animated_sprite.modulate = Color.RED
		await get_tree().create_timer(0.15).timeout
		if is_instance_valid(self) and animated_sprite:
			animated_sprite.modulate = original_modulate

func die():
	if is_dead:
		return
		
	is_dead = true
	velocity = Vector2.ZERO
	
	print("Enemy defeated!")
	
	if efx_enemy_die:
		efx_enemy_die.play()
	
	# Play death animation
	if has_animation("death") or has_animation("die"):
		var death_anim = "death" if has_animation("death") else "die"
		play_animation_safe(death_anim)
		await animated_sprite.animation_finished
	else:
		# Fade out if no death animation
		if animated_sprite:
			var tween = create_tween()
			tween.tween_property(animated_sprite, "modulate:a", 0.0, 1.0)
			await tween.finished
	
	queue_free()

# Helper function for checking if this enemy can attack
func can_perform_attack() -> bool:
	return can_attack and not is_dead and not is_hurt_retreating

# Helper function to get current health percentage
func get_health_percentage() -> float:
	return float(health) / 100.0
