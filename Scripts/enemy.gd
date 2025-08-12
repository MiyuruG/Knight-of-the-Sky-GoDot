extends CharacterBody2D

@export var speed := 100
@export var detection_range := 300
@export var attack_range := 15

@onready var sprite := $AnimatedSprite2D
var player: Node2D

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("Player not found in group 'player'!")

func _physics_process(delta):
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

func play_animation(anim: String):
	if sprite.animation != anim:
		sprite.play(anim)
