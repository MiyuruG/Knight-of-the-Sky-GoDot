extends Node2D

func _process(_delta: float) -> void:
	if !$AudioStreamPlayer2D.playing:
		$AudioStreamPlayer2D.play()
