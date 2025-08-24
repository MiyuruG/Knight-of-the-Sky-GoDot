extends CharacterBody2D

@export var health: int = 100
@export var attack_damage: int = 20
@export var attack_range: float = 50.0
@export var attack_cooldown: float = 1.0

@onready var animated_sprite = $AnimatedSprite2D
var player: CharacterBody2D = null
var can_attack: bool = true
var player_in_range: bool = false

func _ready():
	# Set up the enemy sprite animation
	if animated_sprite:
		animated_sprite.play("idle")
	
	# Make enemy act like a wall - solid but doesn't push
	collision_layer = 2  # Put on layer 2 (walls)
	collision_mask = 0   # Don't detect anything for movement
	
	# Create an Area2D child for attack detection
	var detection_area = Area2D.new()
	var detection_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = attack_range
	
	add_child(detection_area)
	detection_area.add_child(detection_shape)
	detection_shape.shape = circle_shape
	
	# Connect area signals for player detection
	detection_area.body_entered.connect(_on_player_entered_range)
	detection_area.body_exited.connect(_on_player_exited_range)

func _physics_process(delta):
	# Enemy stays completely still - no physics movement at all
	velocity = Vector2.ZERO
	
	# Only attack if player is in range
	if player_in_range and player and can_attack:
		attack_player()

func _on_player_entered_range(body):
	if body.is_in_group("player"):
		player = body
		player_in_range = true
		print("Player entered attack range")

func _on_player_exited_range(body):
	if body.is_in_group("player"):
		player_in_range = false
		print("Player left attack range")

func attack_player():
	if not can_attack or not player_in_range:
		return
	
	can_attack = false
	
	# Play attack animation if available
	if animated_sprite:
		animated_sprite.play("attack")
	
	# Wait a brief moment for attack animation, then check range before damage
	await get_tree().create_timer(0.1).timeout
	
	# Final range check before dealing damage
	if player and is_instance_valid(player) and player_in_range:
		# Deal damage to player
		if player.has_method("take_damage_from_enemy"):
			player.take_damage_from_enemy(attack_damage, self)
		elif player.has_method("take_damage"):
			player.take_damage(attack_damage)
		print("Health is reduced by 20")
	
	# Continue cooldown
	await get_tree().create_timer(attack_cooldown - 0.1).timeout
	
	# Check if enemy still exists and reset attack capability
	if is_instance_valid(self):
		can_attack = true
		
		# Return to idle animation if still alive
		if animated_sprite and health > 0:
			animated_sprite.play("idle")

func take_damage(damage: int):
	print("=== ENEMY TAKE_DAMAGE CALLED ===")
	print("Damage received: ", damage)
	print("Health before damage: ", health)
	
	health -= damage
	
	print("Health after damage: ", health)
	print("Enemy's health is reduced by ", damage, " - Current health: ", health)

	# Play hurt animation if available
	if animated_sprite:
		animated_sprite.play("hurt")
		await animated_sprite.animation_finished
		if health > 0:
			animated_sprite.play("idle")
	
	# Check if enemy is dead
	print("Checking if enemy should die (health <= 0): ", health <= 0)
	if health <= 0:
		print("CALLING DIE FUNCTION!")
		die()
	else:
		print("Enemy still alive with ", health, " health")

func die():
	print("=== DIE FUNCTION CALLED ===")
	print("Enemy defeated! Health: ", health)
	
	# Stop any ongoing attacks
	can_attack = false
	
	# Remove from enemy group so it can't be targeted
	if is_in_group("enemies"):
		remove_from_group("enemies")
		print("Removed from enemies group")
	
	# Play death animation if available
	if animated_sprite:
		print("Playing death animation...")
		animated_sprite.play("death")
		# Wait for death animation to finish
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("death"):
			await animated_sprite.animation_finished
			print("Death animation finished")
		else:
			# If no death animation, wait a brief moment
			print("No death animation, waiting...")
			await get_tree().create_timer(0.5).timeout
	else:
		# No animated sprite, just wait briefly
		print("No animated sprite, waiting...")
		await get_tree().create_timer(0.5).timeout
	
	print("About to queue_free()")
	queue_free()
	print("queue_free() called - enemy should disappear next frame")

# Optional: Add the enemy to a group for easy reference
func _enter_tree():
	add_to_group("enemies")
