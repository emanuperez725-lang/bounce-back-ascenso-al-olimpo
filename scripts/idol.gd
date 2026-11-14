class_name Idol
extends Area2D
## Stone idol: shows `text` while Kira stands near it. With `grants_dash` it gives the
## Winged Sandals once (Hermes' idol). Place it with its origin on the floor.

@export_multiline var text := ""
@export var grants_dash := false

var _glow: Node2D


func _ready() -> void:
	add_to_group("readable")
	if grants_dash:
		_glow = Fx.play(self, "Fantasy Spells/spell_haste_001/spell_haste_001_small_green", Vector2(0, -30), true)


## Called by the room when Kira overlaps.
func touched(player: Player) -> void:
	if not grants_dash or _glow == null:
		return
	_glow.queue_free()
	_glow = null
	Fx.play(get_parent(), "Magic Bursts/round_sparkle_burst_001/round_sparkle_burst_001_small_blue", player.global_position)
	player.dash_unlocked = true
	player.dashes = player.max_dashes
