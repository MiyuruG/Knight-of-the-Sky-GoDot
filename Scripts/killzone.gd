extends Area2D
<<<<<<< HEAD
@onready var timer = $Timer

func _on_body_entered(body: Node2D) -> void:
	print("You Died")
	timer.start()

=======

@onready var timer = $Timer

func _on_body_entered(body):
	print("You died!")
	timer.start()


>>>>>>> 6f10010 (Added stuff)
func _on_timer_timeout() -> void:
	get_tree().reload_current_scene()
