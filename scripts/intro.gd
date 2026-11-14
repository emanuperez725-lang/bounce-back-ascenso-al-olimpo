extends Cutscene
## Intro (scenes/intro.tscn, the main scene): the lore. Melina turns to stone, the oracle
## names the Ambrosia Apple, Kira climbs Olympus, almost reaches it, and falls into the
## swamp. Last page: the title; a press starts the game.

@onready var _kira: Sprite2D = $Kira
@onready var _melina: Sprite2D = $Melina
@onready var _apple: Sprite2D = $Apple
@onready var _title: Label = $Title

var _move: Tween # Kira's current motion; a new beat replaces it


func _ready() -> void:
	_apple.modulate.a = 0.0
	_title.modulate.a = 0.0
	super._ready()


func _beat(i: int) -> void:
	match i:
		1: # the curse climbs from the feet to the heart
			create_tween().tween_property(_melina, "modulate", Cutscene.STONE, 3.0)
		2: # the oracle: the apple on the summit
			_apple.modulate.a = 1.0
			Fx.play(self, "Fantasy Spells/status_sparkling_001/status_sparkling_001_small_yellow", _apple.position, true)
		3: # Kira climbs, almost touching it
			_kira.frame = 10
			_move = create_tween()
			_move.tween_property(_kira, "position", Vector2(470, 150), 3.0)
		4: # ...and falls
			_kira.frame = 12
			if _move:
				_move.kill()
			var t := create_tween()
			t.tween_property(_kira, "position", Vector2(470, 420), 1.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			t.tween_callback(func() -> void: Fx.play(self, "Smoke Bursts/symmetrical_smoke_burst_001/symmetrical_smoke_burst_001_small_brown", Vector2(470, 350)))


func _finale() -> void:
	await fade(_title, 1.0)
