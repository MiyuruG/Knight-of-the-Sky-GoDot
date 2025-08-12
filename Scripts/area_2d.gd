extends Area2D

func _on_area_entered(area):
	if area.is_in_group("player"):
		area.take_damage(10)  # assumes player has a `take_damage()` method
