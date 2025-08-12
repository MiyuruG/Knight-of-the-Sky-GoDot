extends CharacterBody2D

@export var damage := 10
@export var speed := 100
@onready var player := get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if player and is_instance_valid(player):
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
func _ready():
	$Hurtbox.area_entered.connect(_on_area_entered)

func _on_area_entered(area):
	if area.is_in_group("player"):
		if area.has_method("take_damage"):
			area.take_damage(damage)
			print(damage)
