# coin.gd
extends Area2D
@onready var game_manager: Node = %GameManager
@onready var coin_sfx = $coin_sfx

func _on_body_entered(body):
   game_manager.add_point()
   
   # Duplicate the sound node so it can live outside this coin
   var sfx = coin_sfx.duplicate()
   get_parent().add_child(sfx)
   sfx.play()
   # let the duplicated sound auto-free itself after finishing
   sfx.connect("finished", Callable(sfx, "queue_free"))
   queue_free() # coin disappears instantly
