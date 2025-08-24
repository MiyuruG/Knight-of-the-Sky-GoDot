extends CharacterBody2D

# Player stats
@export var health: int = 100
@export var max_health: int = 100
@export var speed: float = 150.0
@export var jump_velocity: float = -300.0
@export var acceleration: float = 800.0
@export var friction: float = 1000.0
@export var air_acceleration: float = 400.0
@export var air_friction: float = 200.0

# Combat parameters
@export var attack_damage: int = 25
@export var attack_range: float = 70.0
@export var attack_cooldown: float = 0.4

# Audio nodes
@onready var sfx_jump: AudioStreamPlayer = get_node_or_null("sfx_jump")
@onready var sfx_run: AudioStreamPlayer = get_node_or_null("sfx_run")
@onready var sfx_player_died: AudioStreamPlayer = get_node_or_null("sfx_player_died")
@onready var sfx_player_attack: AudioStreamPlayer = get_node_or_null("sfx_player_attack")
@onready var sfx_player_hurt: AudioStreamPlayer = get_node_or_null("sfx_player_hurt")

@onready var animated_sprite = $AnimatedSprite2D

# Player state
var can_attack: bool = true
var is_dead: bool = false
var is_hurt: bool = false

# Movement mechanics
var coyote_time: float = 0.1
var jump_buffer_time: float = 0.1
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# Get gravity from project settings
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	add_to_group("player")
	health = max_health
	
	if animated_sprite and has_animation("idle"):
		animated_sprite.play("idle")

func _physics_process(delta):
	if is_dead:
		return
		
	update_timers(delta)
	handle_movement(delta)
	handle_attack()

func update_timers(delta):
	# Update coyote time (allows jumping shortly after leaving ground)
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
	
	# Update jump buffer (allows early jump input)
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta

func has_animation(anim_name: String) -> bool:
	if animated_sprite and animated_sprite.sprite_frames:
		return animated_sprite.sprite_frames.has_animation(anim_name)
	return false

func play_animation_safe(anim_name: String):
	if animated_sprite and has_animation(anim_name):
		animated_sprite.play(anim_name)

func handle_movement(delta):
	# Handle jump input with buffer
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Execute jump with coyote time and jump buffer
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0
		coyote_timer = 0
		play_animation_safe("jump")
		
		# Play jump sound
		if sfx_jump and not sfx_jump.playing:
			sfx_jump.play()
	
	# Get horizontal input
	var direction = Input.get_axis("ui_left", "ui_right")
	
	# Apply horizontal movement with smooth acceleration/deceleration
	if direction != 0:
		# Choose appropriate acceleration based on ground state
		var accel = acceleration if is_on_floor() else air_acceleration
		velocity.x = move_toward(velocity.x, direction * speed, accel * delta)
		
		# Flip sprite based on direction
		if animated_sprite:
			animated_sprite.flip_h = direction < 0
		
		# Play running sound (only on ground and if not already playing)
		if is_on_floor() and sfx_run and not sfx_run.playing:
			sfx_run.play()
	else:
		# Apply friction
		var fric = friction if is_on_floor() else air_friction
		if is_on_floor():
			fric = friction * 3.0  # Extra friction for instant stop feel
		
		velocity.x = move_toward(velocity.x, 0, fric * delta)
		
		# Stop running sound
		if sfx_run and sfx_run.playing:
			sfx_run.stop()
	
	# Handle animations (only if not in special states)
	if animated_sprite and not is_hurt:
		var current_anim = animated_sprite.animation
		if current_anim not in ["attack", "hurt", "death", "die"]:
			if not is_on_floor():
				if velocity.y < -50:  # Rising
					play_animation_safe("jump")
				else:  # Falling
					if has_animation("fall"):
						play_animation_safe("fall")
					else:
						play_animation_safe("jump")
			elif abs(velocity.x) > 10:  # Moving threshold
				play_animation_safe("run")
			else:
				play_animation_safe("idle")
	
	move_and_slide()

func handle_attack():
	if Input.is_action_just_pressed("attack") and can_attack and not is_dead:
		attack()

func attack():
	if not can_attack or is_dead:
		return
		
	can_attack = false
	play_animation_safe("attack")
	
	print("Player attacks!")
	
	# Play attack sound
	if sfx_player_attack:
		sfx_player_attack.play()
	
	# Find and damage enemies in range
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy and is_instance_valid(enemy) and not enemy.is_dead:
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= attack_range:
				if enemy.has_method("take_damage"):
					enemy.take_damage(attack_damage)
					print("Player dealt ", attack_damage, " damage to enemy!")
				break  # Attack only one enemy at a time
	
	# Reset attack cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	if is_instance_valid(self):
		can_attack = true

func take_damage(damage: int):
	if is_dead:
		return
		
	health -= damage
	health = max(0, health)  # Ensure health doesn't go below 0
	
	print("Player took ", damage, " damage. Health: ", health)
	
	# Play hurt sound
	if sfx_player_hurt:
		sfx_player_hurt.play()
	
	# Update UI
	update_hearts_ui()
	
	# Flash damage effect
	flash_damage()
	
	# Play hurt animation
	if has_animation("hurt"):
		is_hurt = true
		play_animation_safe("hurt")
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(self):
			is_hurt = false
	
	# Check for death
	if health <= 0:
		die()

func take_damage_from_enemy(damage: int, enemy: Node):
	if is_dead or not enemy or not is_instance_valid(enemy):
		return
		
	var distance = global_position.distance_to(enemy.global_position)
	if distance <= enemy.attack_range:
		take_damage(damage)

func flash_damage():
	if animated_sprite:
		var original_modulate = animated_sprite.modulate
		animated_sprite.modulate = Color.RED
		await get_tree().create_timer(0.15).timeout
		if is_instance_valid(self) and animated_sprite:
			animated_sprite.modulate = original_modulate

func update_hearts_ui():
	# Try multiple possible UI paths
	var ui_hearts = get_node_or_null("../UI/Hearts/HBoxContainer")
	if not ui_hearts:
		ui_hearts = get_node_or_null("../UI/HBoxContainer")
	if not ui_hearts:
		ui_hearts = get_node_or_null("UI/Hearts/HBoxContainer")
	
	if ui_hearts:
		# Update hearts based on health percentage
		var health_per_heart = max_health / 3.0  # Assuming 3 hearts
		
		var heart1 = ui_hearts.get_node_or_null("Heart")
		var heart2 = ui_hearts.get_node_or_null("Heart2")
		var heart3 = ui_hearts.get_node_or_null("Heart3")
		
		if heart1: heart1.visible = health > health_per_heart * 2
		if heart2: heart2.visible = health > health_per_heart
		if heart3: heart3.visible = health > 0
	else:
		# Alternative: print health to console if no UI found
		print("Health: ", health, "/", max_health)

func die():
	if is_dead:
		return
		
	is_dead = true
	velocity = Vector2.ZERO
	
	print("Player died!")
	
	# Stop all sounds
	if sfx_run and sfx_run.playing:
		sfx_run.stop()
	
	# Play death sound
	if sfx_player_died:
		sfx_player_died.play()
	
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
	
	# Wait a moment before restarting
	await get_tree().create_timer(1.0).timeout
	
	# Reload scene
	if get_tree():
		get_tree().reload_current_scene()

# Helper functions
func is_player_dead() -> bool:
	return is_dead

func get_health() -> int:
	return health

func get_max_health() -> int:
	return max_health

func get_health_percentage() -> float:
	return float(health) / float(max_health)

func heal(amount: int):
	if is_dead:
		return
		
	health = min(max_health, health + amount)
	update_hearts_ui()
	print("Player healed for ", amount, ". Health: ", health)

func set_max_health(new_max: int):
	max_health = new_max
	health = min(health, max_health)
	update_hearts_ui()
