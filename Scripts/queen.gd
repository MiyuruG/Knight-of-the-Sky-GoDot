extends Area2D
func _ready():
	$"../RichTextLabel".visible = false
func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		print("Saved the queen!")
		$"../RichTextLabel".visible = true
