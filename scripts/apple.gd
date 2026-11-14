class_name AmbrosiaApple
extends Area2D
## The Ambrosia Apple: touching it ends the game (scripts/game.gd ending()).
## Place it with its origin on the floor.

var _t := 0.0
var _taken := false


func _ready() -> void:
	Fx.play(self, "Fantasy Spells/status_sparkling_001/status_sparkling_001_small_yellow", Vector2(0, -16), true)


func _physics_process(delta: float) -> void:
	_t += delta
	$Sprite.position.y = -16.0 + sin(_t * 2.5) * 3.0 # floats over the altar
	var player: Player = get_tree().get_first_node_in_group("player")
	if not _taken and player and overlaps_body(player):
		_taken = true
		Fx.play(get_parent(), "Magic Bursts/round_light_burst_001/round_light_burst_001_small_yellow", global_position + Vector2(0, -16))
		get_tree().get_first_node_in_group("game").ending()
