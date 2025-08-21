extends Node2D

const SPEED = 20

var direction = -1

@onready var ray_cast_right = $RayCastRight
@onready var ray_cast_left = $RayCastLeft
@onready var sprite = $AnimatedSprite2D # or $Sprite2D, depending on your node

func _process(delta):
	if ray_cast_right.is_colliding():
		direction = -1
	if ray_cast_left.is_colliding():
		direction = 1
	
	# Move
	position.x += direction * SPEED * delta
	
	# Flip sprite based on direction
	if direction == 1:
		sprite.flip_h = true   # facing right
	else:
		sprite.flip_h = false  # facing left
