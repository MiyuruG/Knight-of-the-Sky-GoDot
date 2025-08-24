extends CharacterBody2D

# Mushroom stats
@export var health: int = 120
@export var walk_speed: float = 40.0
@export var angry_speed: float = 80.0
@export var jump_velocity: float = -250.0
@export var contact_damage: int = 10
@export var detection_range: float = 120.0

# Behavior settings
@export var patrol_distance: float = 80.0
@export var angry_duration: float = 6.0
@export var wall_check_distance: float = 25.0
@export var ground_check_distance: float = 35.0

# Movement smoothing
@export var acceleration: float = 300.0
@export var friction: float = 200.0

# Contact damage cooldown
var contact_damage_cooldown: float = 1.0
var contact_timer: float = 0.0

# Audio (optional - add these nodes if you have audio)
@onready var sfx_mushroom_hurt: AudioStreamPlayer = get_node_or_null("sfx_mushroom_hurt")
@onready var sfx_mushroom_die: AudioStreamPlayer = get_node_or_null("sfx_mushroom_die")

@onready var animated_sprite = $AnimatedSprite2D
@onready var wall_raycast = $WallRayCast2D
@onready var ground_raycast = $GroundRayCast2D
@onready var contact_area = $Area2D  # For contact damage

# State variables
var is_dead: bool = false
var is_angry: bool = false
var is_friendly: bool = true
var player: Node = null
var state: String = "patrol"

# Movement variables
var move_direction: int = 1  # 1 for right, -1 for left
var patrol_start_pos: Vector2
var angry_timer: float = 0.0
var target_velocity_x: float = 0.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	add_to_group("mobs")
	add_to_group("enemies")  # Add to enemies group so player can hit it
	patrol_start_pos = global_position
	
	# Set up raycasts
	setup_raycasts()
	
	# Set up contact damage area
	setup_contact_area()
	
	# Play initial animation
	play_animation_safe("idle")

func setup_raycasts():
	# Create wall raycast if it doesn't exist
	if not wall_raycast:
		wall_raycast = RayCast2D.new()
		add_child(wall_raycast)
		wall_raycast.position = Vector2.ZERO
	
	wall_raycast.target_position = Vector2(wall_check_distance, 0)
	wall_raycast.collision_mask = 1  # Adjust based on your wall layer
	wall_raycast.enabled = true
	
	# Create ground raycast if it doesn't exist
	if not ground_raycast:
		ground_raycast = RayCast2D.new()
		add_child(ground_raycast)
		ground_raycast.position = Vector2(ground_check_distance, 0)
	
	ground_raycast.target_position = Vector2(0, ground_check_distance)
	ground_raycast.collision_mask = 1  # Adjust based on your ground layer
	ground_raycast.enabled = true

func setup_contact_area():
	# Set up Area2D for contact damage if it exists
	if contact_area:
		if not contact_area.body_entered.is_connected(_on_area_2d_body_entered):
			contact_area.body_entered.connect(_on_area_2d_body_entered)
	else:
		print("Warning: No Area2D node found for contact damage!")

func _physics_process(delta):
	if is_dead:
		return
	
	# Add gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	update_timers(delta)
	find_player()
	update_mushroom_behavior(delta)
	apply_smooth_movement(delta)
	
	# Update raycast positions based on direction
	wall_raycast.target_position = Vector2(wall_check_distance * move_direction, 0)
	ground_raycast.position = Vector2(ground_check_distance * move_direction, 0)
	
	move_and_slide()

func has_animation(anim_name: String) -> bool:
	if animated_sprite and animated_sprite.sprite_frames:
		return animated_sprite.sprite_frames.has_animation(anim_name)
	return false

func play_animation_safe(anim_name: String):
	if animated_sprite and has_animation(anim_name) and animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

func update_timers(delta):
	# Update contact damage cooldown
	if contact_timer > 0:
		contact_timer -= delta
	
	# Update angry timer
	if angry_timer > 0:
		angry_timer -= delta
	else:
		if is_angry:
			is_angry = false
			is_friendly = true
			state = "patrol"
			print("Mushroom calmed down and became friendly again")

func find_player():
	if not player or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]

func update_mushroom_behavior(delta):
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
	
	# State machine
	match state:
		"patrol":
			if is_angry and distance_to_player <= detection_range:
				state = "chase"
				print("Angry mushroom spotted player!")
			else:
				patrol_behavior()
		
		"chase":
			if not is_angry:
				state = "patrol"
			else:
				chase_player()

func patrol_behavior():
	var current_speed = walk_speed
	
	# Check for walls or edges and jump if needed
	if should_turn_around():
		if should_jump():
			jump()
		else:
			turn_around()
	
	# Check if we've moved too far from start position
	var distance_from_start = abs(global_position.x - patrol_start_pos.x)
	if distance_from_start > patrol_distance:
		# Turn back towards start position
		if global_position.x > patrol_start_pos.x:
			move_direction = -1
		else:
			move_direction = 1
	
	# Set target velocity
	target_velocity_x = move_direction * current_speed
	
	# Update sprite direction (flip when moving left)
	if animated_sprite:
		animated_sprite.flip_h = move_direction < 0
	
	# Play walk animation if moving, idle if not
	if abs(target_velocity_x) > 5:
		play_animation_safe("walk")
	else:
		play_animation_safe("idle")

func chase_player():
	if not player:
		return
	
	var direction_to_player = sign(player.global_position.x - global_position.x)
	move_direction = direction_to_player
	
	# Check for obstacles and jump if needed
	if should_jump():
		jump()
	
	# Set target velocity
	target_velocity_x = move_direction * angry_speed
	
	# Update sprite direction (flip when moving left)
	if animated_sprite:
		animated_sprite.flip_h = move_direction < 0
	
	play_animation_safe("walk")

func apply_smooth_movement(delta):
	# Smooth horizontal movement
	if abs(target_velocity_x) > 5:
		# Accelerate towards target velocity
		velocity.x = move_toward(velocity.x, target_velocity_x, acceleration * delta)
	else:
		# Apply friction when stopping
		velocity.x = move_toward(velocity.x, 0, friction * delta)

func should_turn_around() -> bool:
	# Check for wall ahead
	if wall_raycast.is_colliding():
		return true
	
	# Check for edge (no ground ahead)
	if is_on_floor() and not ground_raycast.is_colliding():
		return true
	
	return false

func should_jump() -> bool:
	# Only jump if on ground and there's a wall obstacle (not an edge)
	return is_on_floor() and wall_raycast.is_colliding() and ground_raycast.is_colliding()

func turn_around():
	move_direction *= -1
	target_velocity_x = 0  # Stop smoothly when turning

func jump():
	if is_on_floor():
		velocity.y = jump_velocity
		print("Mushroom jumps over obstacle!")

func take_damage(damage: int):
	if is_dead:
		return
	
	health -= damage
	print("Mushroom took ", damage, " damage. Health: ", health)
	
	# Get angry when hurt (lose friendliness)
	get_angry()
	
	# Play hurt sound
	if sfx_mushroom_hurt:
		sfx_mushroom_hurt.play()
	
	# Play hurt animation
	if has_animation("hurt"):
		var original_state = state
		play_animation_safe("hurt")
		await get_tree().create_timer(0.3).timeout
		if not is_dead:
			if is_angry and state == "chase":
				play_animation_safe("walk")
			else:
				play_animation_safe("idle")
	
	# Flash red
	flash_damage()
	
	if health <= 0:
		die()

func get_angry():
	if is_dead:
		return
	
	is_angry = true
	is_friendly = false
	angry_timer = angry_duration
	state = "chase"
	print("Friendly mushroom got angry and will chase the player!")

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
	target_velocity_x = 0.0
	
	print("Mushroom defeated!")
	
	if sfx_mushroom_die:
		sfx_mushroom_die.play()
	
	# Play death animation
	if has_animation("death"):
		play_animation_safe("death")
		await animated_sprite.animation_finished
	else:
		# Fade out if no death animation
		if animated_sprite:
			var tween = create_tween()
			tween.tween_property(animated_sprite, "modulate:a", 0.0, 1.0)
			await tween.finished
	
	queue_free()

# Called when player touches the mushroom (connect this to Area2D signal)
func _on_area_2d_body_entered(body):
	if body.is_in_group("player") and not is_dead and contact_timer <= 0:
		# Deal contact damage to player
		var damage_dealt = false
		
		if body.has_method("take_damage_from_enemy"):
			body.take_damage_from_enemy(contact_damage, self)
			damage_dealt = true
		elif body.has_method("take_damage"):
			body.take_damage(contact_damage)
			damage_dealt = true
		
		if damage_dealt:
			contact_timer = contact_damage_cooldown  # Set cooldown
			var damage_type = "friendly" if is_friendly else "angry"
			print("Player touched ", damage_type, " mushroom and took ", contact_damage, " damage!")

# Helper functions
func is_player_nearby() -> bool:
	if not player:
		return false
	return global_position.distance_to(player.global_position) <= detection_range

func get_health_percentage() -> float:
	return float(health) / 30.0

func is_mushroom_friendly() -> bool:
	return is_friendly

func is_mushroom_angry() -> bool:
	return is_angry
