extends Area2D

@export var target_level : PackedScene

func _on_body_entered(body):
	if (body.name == "Player"):
		# Use call_deferred to avoid physics callback issues
		call_deferred("change_level")

func change_level():
	get_tree().change_scene_to_packed(target_level)
