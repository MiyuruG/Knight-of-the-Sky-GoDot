extends CharacterBody2D
@onready var health_bar := $HealthBar
@export var speed := 100
@export var detection_range := 100
@export var attack_range := 15
@export var max_health := 100
var current_health := max_health
func _readyhealth():
	update_health_bar()
func take_damage(amount: int):
	current_health = max(current_health - amount, 0)
	update_health_bar()
	if current_health == 0:
		die()

@onready var sprite := $AnimatedSprite2D
var player: Node2D

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("Player not found in group 'player'!")

func _physics_process(_delta):
	if not player or !is_instance_valid(player):
		return

	var distance_to_player = global_position.distance_to(player.global_position)

	if distance_to_player <= attack_range:
		velocity = Vector2.ZERO
		play_animation("attack")
	elif distance_to_player <= detection_range:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
		sprite.flip_h = direction.x < 0
		play_animation("run")
	else:
		velocity = Vector2.ZERO
		play_animation("idlefly")
func update_health_bar():
	health_bar.value = current_health
func play_animation(anim: String):
	if sprite.animation != anim:
		sprite.play(anim)
func die():
	queue_free()  # or any other logic for death
