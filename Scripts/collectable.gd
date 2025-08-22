extends Area2D


@onready var game_manager: Node = %GameManager

@onready var collecting_sfx: AudioStreamPlayer = $coin_collecting_sfx

func _on_body_entered(body):
	if body.name == "Player":
		# Detach the sound so it survives after the coin is freed
		collecting_sfx.get_parent().remove_child(collecting_sfx)
		get_tree().get_root().add_child(collecting_sfx) # move to scene root
		collecting_sfx.play()
		
		# Remove coin immediately
		queue_free()
		game_manager.add_point()
