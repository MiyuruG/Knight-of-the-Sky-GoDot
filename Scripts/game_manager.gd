extends Node

@onready var points_laber: Label = %Points_Laber

var points = 0

func add_point():
	points += 1
	print(points)
	points_laber.text = "Points:" + str(points)
