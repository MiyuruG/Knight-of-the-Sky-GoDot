extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if (body.name == "Player"):
		# Heal the player to full health
		body.health = 100
		print("Player healed to full health: ", body.health)
		
		# Update the hearts UI
		if body.has_method("update_hearts_ui"):
			body.update_hearts_ui()
		
		# Remove the healing potion
		queue_free()
