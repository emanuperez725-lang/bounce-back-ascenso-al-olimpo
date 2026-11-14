class_name Mushroom
extends Area2D
## Blue mushroom: landing on it throws Kira up (bounce back). Origin on the floor.

@export var speed := 640.0 ## ~7 tiles up; a full jump is ~3.5


func _ready() -> void:
	add_to_group("bouncer")
