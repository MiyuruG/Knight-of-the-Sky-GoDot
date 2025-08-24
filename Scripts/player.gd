extends CharacterBody2D

@export var health: int = 100
@export var speed: float = 200.0
@export var jump_velocity: float = -400.0
@export var attack_damage: int = 20
@export var attack_range: float = 60.0

@onready var animated_sprite = $AnimatedSprite2D
var can_attack: bool = true
var attack_cooldown: float = 0.5

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	# Add player to group for easy reference
	add_to_group("player")
	if animated_sprite:
		animated_sprite.play("idle")

func _physics_process(delta):
	handle_movement()
	handle_attack()

func handle_movement():
	# Add gravity
	if not is_on_floor():
		velocity.y += gravity * get_physics_process_delta_time()
	
	# Handle jump
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
			if animated_sprite:
				animated_sprite.play("jump")
	
	# Get horizontal input direction
	var direction = 0
	if Input.is_action_pressed("ui_left"):
		direction -= 1
	if Input.is_action_pressed("ui_right"):
		direction += 1
	
	# Handle horizontal movement
	if direction != 0:
		velocity.x = direction * speed
		
		# Flip sprite based on movement direction
		if animated_sprite:
			if direction < 0:
				animated_sprite.flip_h = true
			elif direction > 0:
				animated_sprite.flip_h = false
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
	
	# Handle animations based on state
	if animated_sprite and animated_sprite.animation != "attack" and animated_sprite.animation != "hurt":
		if not is_on_floor():
			if velocity.y < 0:
				animated_sprite.play("jump")
			else:
				animated_sprite.play("fall")
		elif direction != 0:
			animated_sprite.play("walk")
		else:
			animated_sprite.play("idle")
	
	move_and_slide()

func handle_attack():
	# Check for attack input (separate from jump)
	if Input.is_action_just_pressed("attack"):
		if can_attack:
			attack()

func attack():
	if not can_attack:
		print("Attack on cooldown!")
		return
		
	can_attack = false
	print("Player attacking...")
	
	# Play attack animation
	if animated_sprite:
		animated_sprite.play("attack")
	
	# Find enemies in range - with detailed debugging
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("Found ", enemies.size(), " enemies in group")
	
	var found_target = false
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			var distance_to_enemy = global_position.distance_to(enemy.global_position)
			print("Distance to enemy: ", distance_to_enemy, " (attack range: ", attack_range, ")")
			
			if distance_to_enemy <= attack_range:
				print("Enemy in range! Attacking...")
				if enemy.has_method("take_damage"):
					enemy.take_damage(attack_damage)
					print("Damage dealt! Enemy health after attack: ", enemy.health)
					print("Player health: ", health)  # Show player's current health too
					found_target = true
				else:
					print("ERROR: Enemy doesn't have take_damage method!")
				break  # Attack only one enemy at a time
			else:
				print("Enemy too far away to attack")
	
	if not found_target:
		print("No enemies in attack range")
	
	# Use a Timer node instead of await to prevent interruption
	var timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(_on_attack_cooldown_finished)
	timer.start(attack_cooldown)

func _on_attack_cooldown_finished():
	can_attack = true
	print("Attack ready!")
	
	# Clean up the timer
	var timers = get_children().filter(func(child): return child is Timer)
	for timer in timers:
		timer.queue_free()
	
	# Return to appropriate animation
	if animated_sprite:
		if not is_on_floor():
			if velocity.y < 0:
				animated_sprite.play("jump")
			else:
				animated_sprite.play("fall")
		elif velocity.x != 0:
			animated_sprite.play("walk")
		else:
			animated_sprite.play("idle")

func take_damage(damage: int):
	print("=== PLAYER TAKE_DAMAGE CALLED ===")
	print("Damage received: ", damage)
	print("Player health before damage: ", health)
	
	health -= damage
	
	print("Player health after damage: ", health)
	print("Player's health is reduced by ", damage, " - Current health: ", health)
	
	# Play hurt animation if available
	if animated_sprite:
		animated_sprite.play("hurt")
		await animated_sprite.animation_finished
		if health > 0:
			if not is_on_floor():
				if velocity.y < 0:
					animated_sprite.play("jump")
				else:
					animated_sprite.play("fall")
			elif velocity.x != 0:
				animated_sprite.play("walk")
			else:
				animated_sprite.play("idle")
	
	# Check if player is dead
	if health <= 0:
		print("PLAYER CALLING DIE FUNCTION!")
		die()
	else:
		print("Player still alive with ", health, " health")

func take_damage_from_enemy(damage: int, enemy: Node):
	print("Player taking damage from enemy...")
	# Double-check we're still in range of the attacking enemy
	if enemy and is_instance_valid(enemy):
		var distance_to_enemy = global_position.distance_to(enemy.global_position)
		if distance_to_enemy <= enemy.attack_range:
			take_damage(damage)
		else:
			print("Player avoided damage - out of enemy range!")
	if health < 60:
		$"../UI/Hearts/HBoxContainer/Heart".visible = false
	if health < 30:
		$"../UI/Hearts/HBoxContainer/Heart2".visible = false
	if health < 1:
		$"../UI/Hearts/HBoxContainer/Heart3".visible = false

		# If out of range, don't take damage or play hurt animation

func die():
	print("=== PLAYER DIE FUNCTION CALLED ===")
	print("Game Over! Player health: ", health)
	
	# Play death animation first, THEN pause
	if animated_sprite:
		print("Playing player death animation...")
		animated_sprite.play("death")
		
		# Wait for death animation to finish before pausing
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("death"):
			await animated_sprite.animation_finished
			print("Player death animation finished")
		else:
			# If no death animation, wait a brief moment
			print("No death animation found, waiting...")
			await get_tree().create_timer(1.0).timeout
	else:
		# No animated sprite, just wait briefly
		print("No animated sprite, waiting before game over...")
		await get_tree().create_timer(1.0).timeout
	
	# NOW pause the game after animation is done
	print("Game paused - Player is dead")
	get_tree().reload_current_scene()
